#!/sbin/openrc-run
# It is designed for Alpine Linux using OpenRC.
# The script will be placed in /etc/init.d/
#
# Usage:
# rc-update add app default
#
# The script uses the HOSTNAME variable to find the correct
# compose file inside an NFS share /network/containers/compose/$HOSTNAME

# A descriptive name for the service
name="App service"
description="Starts the container with the same hostname as the machine running at /network/containers/compose/${HOSTNAME}/compose.yaml using nerdctl compose."


check_ready() {
  local retries=3     # Number of retries
  local retry_delay=10 # Delay between retries in seconds
  local i=1

  echo "Waiting for NFS mount to be ready..."

  # Loop for retries with a delay.
  while [ $i -le $retries ]; do
    # This check is now two-part:
    # 1. Check if the directory is a valid mount point.
    # 2. Check if the expected sub-directory within the mount exists.
    # Checks for the 'compose' folder to see if the mount was successful
    if findmnt -M /network/containers &>/dev/null && [ -d "/network/containers/compose" ]; then
      echo "NFS mount is ready and container path is accessible. Proceeding."
      return 0
    fi
    echo "Attempt $i/$retries: NFS mount or container path not ready. Retrying in $retry_delay seconds..."
    sleep $retry_delay
    i=$((i+1))
  done

  if ! findmnt -M /network/containers &>/dev/null || ! [ -d "/network/containers/compose" ]; then
    echo "NFS mount check failed after $retries retries. Aborting start."
    return 1
  fi
}

depend() {
  # The `need netmount` dependency ensures the networking is up.
  # need nfsmount ensure the NFS service is started.
  # `need containerd` makes sure the container engine service started as well
  need netmount
  need nfsmount
  need containerd
}

start() {
  # Call the readiness check function first.
  check_ready
  if [ $? -ne 0 ]; then
    eerror "Readiness check failed. Service ${HOSTNAME} will not start."
    return 1
  fi

  # Now that the dependency is confirmed ready, run the main command.
  ebegin "Starting nerdctl compose for ${HOSTNAME}"
  local COMPOSE_DIR="/network/containers/compose/${HOSTNAME}"
  if [ -d "$COMPOSE_DIR" ]; then
    cd "$COMPOSE_DIR" && \
    /usr/bin/nerdctl compose up -d --remove-orphans
    eend $?
  else
    eerror "Compose directory not found: $COMPOSE_DIR"
    eend 1
  fi
}

stop() {
  ebegin "Stopping nerdctl compose for ${HOSTNAME}"
  local COMPOSE_DIR="/network/containers/compose/${HOSTNAME}"
  if [ -d "$COMPOSE_DIR" ]; then
    cd "$COMPOSE_DIR" && \
    /usr/bin/nerdctl compose down
    eend $?
  else
    eerror "Compose directory not found: $COMPOSE_DIR"
    eend 1
  fi
}
