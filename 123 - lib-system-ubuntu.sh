#!/bin/bash
#
# System related utilities
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

function lower {
    # helper function
    echo $1 | tr '[:upper:]' '[:lower:]'
}

function system_get_codename {
    echo `lsb_release -sc`
}

function system_get_release {
    echo `lsb_release -sr`
}

function system_add_user {
    # $1 - username
    # $2 - password
    # $3 - groups
    USERNAME=`lower $1`
    PASSWORD=$2
    SUDO_GROUP=$3
    SHELL="/bin/bash"
    useradd --create-home --shell "$SHELL" --user-group --groups "$SUDO_GROUP" "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
}

function system_add_system_user {
    # $1 - username
    # $2 - home
    USERNAME=`lower $1`
    HOME_DIR=$2
    if [ -z "$HOME_DIR" ]; then
        useradd --system --no-create-home --user-group $USERNAME
    else
        useradd --system --no-create-home --home-dir "$HOME_DIR" --user-group $USERNAME
    fi;
}

function system_get_user_home {
    # $1 - username
    cat /etc/passwd | grep "^$1:" | cut --delimiter=":" -f6
}

function system_user_add_ssh_key {
    # $1 - username
    # $2 - ssh key
    USERNAME=`lower $1`
    USER_HOME=`system_get_user_home "$USERNAME"`
    sudo -u "$USERNAME" mkdir "$USER_HOME/.ssh"
    sudo -u "$USERNAME" touch "$USER_HOME/.ssh/authorized_keys"
    sudo -u "$USERNAME" echo "$2" >> "$USER_HOME/.ssh/authorized_keys"
    chmod 0600 "$USER_HOME/.ssh/authorized_keys"
}

function system_sshd_edit_bool {
    # $1 - param name
    # $2 - Yes/No
    VALUE=`lower $2`
    if [ "$VALUE" == "yes" ] || [ "$VALUE" == "no" ]; then
        sed -i "s/^#*\($1\).*/\1 $VALUE/" /etc/ssh/sshd_config
    fi
}

function system_sshd_permitrootlogin {
    system_sshd_edit_bool "PermitRootLogin" "$1"
}

function system_sshd_passwordauthentication {
    system_sshd_edit_bool "PasswordAuthentication" "$1"
}

function system_sshd_pubkeyauthentication {
    system_sshd_edit_bool "PubkeyAuthentication" "$1"
}

function system_sshd_passwordauthentication {
    system_sshd_edit_bool "PasswordAuthentication" "$1"
}

function system_enable_universe {
    sed -i 's/^#\(.*deb.*\) universe/\1 universe/' /etc/apt/sources.list
    aptitude update
}

function system_update_locale_en_US_UTF_8 {
    # locale-gen en_US.UTF-8
    dpkg-reconfigure locales
    update-locale LANG=en_US.UTF-8
}

function system_update_hostname {
    # $1 - system hostname
    if [ ! -n "$1" ]; then
        echo "system_update_hostname() requires the system hostname as its first argument"
        return 1;
    fi
    echo $1 > /etc/hostname
    hostname -F /etc/hostname
    echo -e "\n127.0.0.1 $1.local $1\n" >> /etc/hosts
}

function system_security_fail2ban {
    aptitude -y install fail2ban
}

function system_security_ufw_install {
    aptitude -y install ufw
}

function system_security_ufw_configure_basic {
    # see https://help.ubuntu.com/community/UFW
    ufw logging on    

    ufw default deny

    ufw allow ssh
    ufw allow http
    ufw allow https

    ufw enable
}

function system_security_logcheck {
    aptitude -y install logcheck logcheck-database
}
