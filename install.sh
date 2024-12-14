#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

apt-get update
apt-get install -y debootstrap arch-install-scripts

echo "Enter your drive name:"
read DRIVE

if [ -z "$DRIVE" ]; then
    echo "No drive specified. Exiting."
    exit 1
fi

if [[ "$DRIVE" == *nvme* ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

parted --script "$DRIVE" mklabel gpt \
    mkpart primary fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart primary ext4 513MiB 100%

EFI_PART="${DRIVE}${PART_SUFFIX}1"
mkfs.fat -F32 "$EFI_PART"
ROOT_PART="${DRIVE}${PART_SUFFIX}2"
mkfs.ext4 "$ROOT_PART"

mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/EFI
mount "$EFI_PART" /mnt/boot/EFI

debootstrap noble /mnt
genfstab /mnt >> /mnt/etc/fstab

mount -t proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev

chroot /mnt apt-get update
chroot /mnt apt-get install -y gnupg

cp linuxmint-keyring.deb /mnt/tmp
chroot /mnt dpkg -i /tmp/linuxmint-keyring.deb
rm /mnt/tmp/linuxmint-keyring.deb

rm -r /mnt/etc/apt
cp -R apt /mnt/etc
chroot /mnt apt-get update
chroot /mnt apt-get upgrade -y
chroot /mnt apt-get full-upgrade -y
chroot /mnt apt-get install -y mint-meta-core

chroot /mnt apt-get install -y linux-image-generic
chroot /mnt apt-get install -y grub-efi-amd64
chroot /mnt grub-install
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
chroot /mnt apt-get install -y network-manager

echo Setting root password...
chroot /mnt passwd

chroot /mnt dpkg-reconfigure locales
chroot /mnt dpkg-reconfigure tzdata
chroot /mnt dpkg-reconfigure keyboard-configuration

chroot /mnt apt-get install -y gufw mint-meta-codecs timeshift mintchat

chroot /mnt apt-get autoremove -y
chroot /mnt apt-get clean

echo Done.
