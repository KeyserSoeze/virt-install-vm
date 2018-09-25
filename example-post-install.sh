#!/bin/bash
# Helper-Skript (part of virt-install-vm) for some system configs as late_command (as root) in debian-installer.

case "$1" in
  admin-login)
    mkdir /home/$2/.ssh
    cat /tmp/p-i/$(basename $3) > /home/$2/.ssh/authorized_keys
    chown -R $2:$2 /home/$2/.ssh
    chmod -R go-rwx /home/$2/.ssh
    echo "$2 ALL = (ALL:ALL) NOPASSWD: SETENV: ALL" > /etc/sudoers.d/10-$2
    chmod 440 /etc/sudoers.d/10-$2
    ;;
  ssh-nopassword)
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
    ;;
  inet-static-p2p)
    if [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ] && ip link | grep "$2"; then
      echo -e "iface $2 inet static\n  address $3\n  netmask 255.255.255.255\n  pointopoint $4\n  gateway $4" > /etc/network/interfaces.d/$2-inet-static-p2p
    fi
    ;;
  inet-dhcp)
    if [ -n "$2" ] && ip link | grep "$2"; then
      echo -e "allow-hotplug $2\niface $2 inet dhcp" > /etc/network/interfaces.d/$2-inet-dhcp
    fi
    ;;
  adm-group)
    if [ -n "$2" ]; then adduser $2 adm; fi
    ;;
  motd)
    if [ -f "$2" ]; then cat /tmp/p-i/$(basename $2) > /etc/motd; fi
    ;;
  doku-install-preseed)
    tar -cf /root/doku-install-preseed.tar -C /tmp p-i
    chmod 600 /root/doku-install-preseed.tar
    ;;
esac
