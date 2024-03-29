#!/bin/sh

region="$1"
city="$2"
locale="$3"
hostname="$4"
username="$5"
password="$6"

swap() {
    if [[ $(sudo cat /proc/meminfo | grep MemTotal | awk '{print $2}') -lt 8388608 ]]; then
         dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
         chmod 0600 /swapfile
         mkswap -U clear /swapfile
         swapon /swapfile
         echo "/swapfile none swap defaults 0 0" >> /etc/fstab
    fi
}

package_update() {
    pacman -Syu --noconfirm
}

time_zone() {
    ln -sf /usr/share/zoneinfo/"$1"/"$2" /etc/localtime
    hwclock --systohc
}

localization() {
    echo "$1.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=$1.UTF-8" >> /etc/locale.conf
}

network_configuration() {
    echo "$1" >> /etc/hostname

    echo "127.0.0.1 localhost" >> /etc/hosts
    echo "::1 localhost" >> /etc/hosts
    echo "127.0.1.1 $1.localdomain $1" >> /etc/hosts

    pacman -S networkmanager --noconfirm
    systemctl enable NetworkManager
}

boot_loader() {
    pacman -S grub efibootmgr os-prober --noconfirm
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    mkdir /boot/grub
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
    grub-mkconfig -o /boot/grub/grub.cfg
}

microcode_updates() {
    microcode=$(cat /proc/cpuinfo | grep "model name" | uniq | awk '{print tolower($4)}')
    if [[ $microcode == "amd" || $microcode == "intel" ]]; then
        pacman -S "$microcode-ucode" --noconfirm
    fi
}

default_packages() {
    pacman -S --noconfirm zsh git openssh
    echo "ZDOTDIR=/home/norpie/.config/zsh" >> /etc/zsh/zshenv
    systemctl enable sshd
}

user_setup() {
    useradd $1 &&
    echo "$1 ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers &&
    echo -e "$2\n$2" | passwd $1 &&
    echo -e "$2\n$2" | passwd &&
    echo -e "/bin/zsh" | chsh $1 &&
    echo -e "/bin/zsh" | chsh &&
    mkdir -p /home
}

setup_dots() {
    cd /home
    git clone https://github.com/norpie-dev/dots --recursive
    mv dots $1
    cd $1
    mv ".git" ".dots"
    cd ..
    chown $1:$1 $1 -R
}

swap &&
package_update &&
time_zone $region $city &&
localization $locale &&
network_configuration $hostname &&
boot_loader &&
microcode_updates &&
default_packages &&
user_setup $username $password &&
setup_dots $username &&
exit
