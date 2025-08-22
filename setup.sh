#!/bin/sh
#
# This script installs dependencies, sets up directories, and copies
# the OpenRC service script for the container workflow.
#

# --- GUARD CHECK: Ensure script is run as root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Aborting." >&2
  exit 1
fi
echo "Running as root. Proceeding."

# --- INSTALL DEPENDENCIES ---
echo "Updating package list and upgrading system..."
apk update && apk upgrade

# --- CREATE GROUPS WITH GUARD CHECKS ---
# The following checks prevent errors if the groups already exist.
if ! getent group storage >/dev/null; then
  echo "Creating group 'storage'..."
  addgroup -g 10000 storage
else
  echo "Group 'storage' already exists."
fi

# Add the 'root' user to the 'storage' group.
# This check prevents an error if the user is already in the group.
if ! groups root | grep -q '\<storage\>'; then
  echo "Adding user 'root' to group 'storage'..."
  addgroup root storage
else
  echo "User 'root' is already in group 'storage'."
fi

# Install necessary packages.
echo "Installing core packages..."
apk add nfs-utils nerdctl bash-completion findmnt shadow containerd --no-cache


echo "Creating network directories..."
mkdir -p /network/containers /network/media /network/downloads /network/backup


# --- CHANGE ROOT SHELL ---
# Check if the root user's shell is already set to bash.
if [ "$(grep '^root:' /etc/passwd | cut -d: -f7)" != "/bin/bash" ]; then
  echo "Changing root user's shell to bash..."
  chsh -s /bin/bash root
else
  echo "Root user's shell is already set to bash. Skipping."
fi

# --- ENABLE OPENRC SERVICES ---
echo "Enabling core OpenRC services..."
rc-update add netmount boot
rc-update add nfsmount default
rc-update add containerd default

# --- ADD FSTAB ENTRIES WITH GUARD CHECK ---
# Check if the fstab file exists in the current directory.
if [ -f "fstab" ]; then
  echo "Appending fstab entries from local 'fstab' file..."
  cat fstab >> /etc/fstab
else
  echo "WARNING: 'fstab' file not found in current directory" >&2
  exit 1
fi

# --- COPY SERVICE SCRIPT WITH GUARD CHECK ---
# Check if the 'app' file (the service script) exists.
if [ -f "app" ]; then
  echo "Copying OpenRC service script 'app' to /etc/init.d/..."
  cp app /etc/init.d/
  echo "Making the script executable..."
  chmod +x /etc/init.d/app
  echo "Adding 'app' service to default runlevel..."
  rc-update add app default
else
  echo "ERROR: 'app' service script not found in current directory. Aborting service setup." >&2
  exit 1
fi

# --- CLEANUP ---
echo "Cleaning up temporary files and caches..."
rm -rf /var/cache/apk/* /var/log/* /tmp/* /var/tmp/*

echo "Removing unnecessary packages..."
apk del shadow

echo "Disk usage after installation:"
du -d 1 -hx / | sort -hr

echo "Process completed successfully!"
