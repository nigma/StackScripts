#!/bin/bash
#
# Install common utilities
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

function system_install_utils {
    aptitude -y install htop iotop bsd-mailx python-software-properties zsh
}

function system_install_build {
    aptitude -y install build-essential gcc
}

function system_install_subversion {
    aptitude -y install subversion
}

function system_install_git {
    aptitude -y install git-core
}

function system_install_mercurial {
    aptitude -y install mercurial
}

function system_start_etc_dir_versioning {
    hg init /etc
    hg add /etc
    hg commit -u root -m "Started versioning of /etc directory" /etc
    chmod -R go-rwx /etc/.hg
}

function system_record_etc_dir_changes {
    if [ ! -n "$1" ];
        then MESSAGE="Committed /etc changes"
        else MESSAGE="$1"
    fi
    hg addremove /etc
    hg commit -u root -m "$MESSAGE" /etc || echo > /dev/null # catch "nothing changed" return code
}
