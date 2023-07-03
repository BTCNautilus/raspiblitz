#!/bin/bash

# check basics for formatting
if [ "$1" = "format" ]; then
  # check valid format
  if [ "$2" = "btrfs" ]; then
    echo "# DATA DRIVE - FORMATTING to BTRFS layout (new)"
  elif [ "$2" = "ext4" ]; then
    echo "# DATA DRIVE - FORMATTING to EXT4 layout (old)"
  else
    echo "# missing valid second parameter: 'btrfs' or 'ext4'"
    echo "error='missing parameter'"
    exit 1
  fi

  # get device name to format
  hdd=$3
  if [ ${#hdd} -eq 0 ]; then
    echo "# missing valid third parameter as the device (like 'sda')"
    echo "# run 'status' to see candidate devices"
    echo "error='missing parameter'"
    exit 1
  fi

  # check if device is existing and a disk (not a partition)
  if [ "$2" = "btrfs" ]; then
    echo "lsblk -o NAME,TYPE | grep disk | grep -c \"${hdd}\""
  else
    # check if device is existing (its OK when its a partition)
    echo "lsblk -o NAME,TYPE | grep -c \"${hdd}\""
  fi
  
  echo "# Stop services"
  echo "sudo systemctl stop lnd"
  echo "sudo systemctl stop bitcoind"
  echo "sudo systemctl stop electrs"

  # get basic info on data drive 
  echo "source <(/home/admin/config.scripts/blitz.datadrive.sh status)"
  if [ ${isSwapExternal} -eq 1 ] && [ "${hdd}" == "${datadisk}" ]; then
    echo "# Switching off external SWAP of system drive"
    echo "dphys-swapfile swapoff"
    echo "dphys-swapfile uninstall"
  fi
  echo "# Unmounting all partitions of this device"
  # remove device from all system mounts (also fstab)
  echo "lsblk -o UUID,NAME | grep \"${hdd}\" | cut -d \" \" -f 1 | grep \"-\" | while read -r uuid ; do
    if [ ${#uuid} -gt 0 ]; then
      echo \"# Cleaning /etc/fstab from ${uuid}\"
      echo \"sed -i \\\"/UUID=${uuid}/d\\\" /etc/fstab\"
      echo sync
    else
      echo \"# skipping empty result\"
    fi
  done"
  echo "mount -a"
  if [ "${hdd}" == "${datadisk}" ]; then
    echo "# Make sure system drives are unmounted .."
    echo "umount /mnt/hdd"
    echo "umount /mnt/temp"
    echo "umount /mnt/storage"
  fi

  echo "# Now formatting ..."
  if [ "$2" = "btrfs" ]; then
    echo "wipefs -a /dev/${hdd}"
    echo "parted -s /dev/${hdd} mklabel gpt"
    echo "parted -s /dev/${hdd} mkpart primary 0% 100%"
    echo "mkfs.btrfs /dev/${hdd}1"
    echo "mount /dev/${hdd}1 /mnt/hdd"
    echo "btrfs subvolume create /mnt/hdd/bitcoin"
    echo "btrfs subvolume create /mnt/hdd/temp"
    echo "btrfs subvolume create /mnt/hdd/app-storage"
    echo "umount /mnt/hdd"
  elif [ "$2" = "ext4" ]; then
    echo "wipefs -a /dev/${hdd}"
    echo "mkfs.ext4 /dev/${hdd} -F"
    echo "mount /dev/${hdd} /mnt/hdd"
  fi

  echo "mkdir /mnt/hdd/bitcoin"
  echo "mkdir /mnt/hdd/temp"
  echo "mkdir /mnt/hdd/app-storage"

  # make sure this was not a temp boot drive
  echo "sed -i \"s/^tmpfs/#tmpfs/g\" /etc/fstab"

  echo "# Updating /etc/fstab"
  echo "UUID=$(blkid -o export /dev/${hdd}1 | grep '^UUID=' | cut -d '=' -f 2)"
  if [ "$2" = "btrfs" ]; then
    echo "echo \"UUID=\${UUID} /mnt/hdd btrfs defaults,commit=600 0 0\" >> /etc/fstab"
    echo "echo \"UUID=\${UUID} /mnt/bitcoin btrfs subvol=bitcoin,defaults,commit=600 0 0\" >> /etc/fstab"
    echo "echo \"UUID=\${UUID} /mnt/temp btrfs subvol=temp,defaults,commit=600 0 0\" >> /etc/fstab"
    echo "echo \"UUID=\${UUID} /mnt/app-storage btrfs subvol=app-storage,defaults,commit=600 0 0\" >> /etc/fstab"
  elif [ "$2" = "ext4" ]; then
    echo "echo \"UUID=\${UUID} /mnt/hdd ext4 defaults,commit=600 0 0\" >> /etc/fstab"
  fi
  echo "mount -a"

  echo "# Restarting services"
  echo "sudo systemctl start lnd"
  echo "sudo systemctl start bitcoind"
  echo "sudo systemctl start electrs"

  echo "exit 0"
fi
