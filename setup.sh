#!/bin/sh env
apk update && apk upgrade
addgroup -g 10000 storage
addgroup root storage
apk add nfs-utils nerdctl bash-completion findmnt shadow containerd --no-cache
# Creating directories
mkdir -p /network/containers /network/media /network/downloads /network/backup

# Change shell to bash on subsequent logins
chsh -s /bin/bash root

#services
rc-update add netmount boot 
rc-update add nfsmount default
rc-update add containerd default


#Check if a file in this same dir called fstab exists and appends its contents to fstab

cat fstab >> /etc/fstab

#Adding the default app service to the right location
cp app /etc/init.d/
#Adding it to start automagically
rc-update add app default


# Cleaning useless files
rm -rf /var/cache/apk/* /var/log/* /tmp/* /var/tmp/*
# remove shadow package as it was only meant for the changing of the shell
apk del shadow
# Lets end this by showing the folders that using the most space
du -d 1 -hx / | sort -hr

echo "Process completed!"