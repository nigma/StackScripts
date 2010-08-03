#!/bin/bash
#
# Installs MongoDB from 10gen.com repository.
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

function system_configure_mongodb_repository {
    RELEASE=`lsb_release -sr | sed 's/\.0/\./'`
    echo -e "\n##MongoDB repository by 10gen\ndeb http://downloads.mongodb.org/distros/ubuntu $RELEASE 10gen\n" >> /etc/apt/sources.list
    apt-key adv --keyserver pgp.mit.edu --recv 7F0CEB10 || apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
    aptitude update
}

function mongodb_install {
    BASE_DIRECTORY=$1 # /var/lib or /srv 
    aptitude -y install mongodb-stable
    if [ -n "$BASE_DIRECTORY" ]; then
        DATA_DIRECTORY="$BASE_DIRECTORY/mongodb"
        mkdir -p "$DATA_DIRECTORY"
        chown mongodb:mongodb "$DATA_DIRECTORY"
        sed -i "s:dbpath=.*:dbpath=$DATA_DIRECTORY:" /etc/mongodb.conf
    fi;
    touch /tmp/restart-mongodb
}
