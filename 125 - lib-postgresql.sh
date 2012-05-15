#!/bin/bash
#
# Install PostgreSQL
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

function postgresql_install {
    aptitude -y install postgresql postgresql-contrib postgresql-dev libpq-dev
}

function postgresql_create_user {
    # postgresql_create_user(username, password)
    if [ -z "$1" ]; then
        echo "postgresql_create_user() requires username as the first argument"
        return 1;
    fi
    if [ -z "$2" ]; then
        echo "postgresql_create_user() requires a password as the second argument"
        return 1;
    fi

    echo "CREATE ROLE $1 WITH LOGIN ENCRYPTED PASSWORD '$2';" | sudo -i -u postgres psql
}

function postgresql_create_database {
    # postgresql_create_database(dbname, owner)
    if [ -z "$1" ]; then
        echo "postgresql_create_database() requires database name as the first argument"
        return 1;
    fi
    if [ -z "$2" ]; then
        echo "postgresql_create_database() requires an owner username as the second argument"
        return 1;
    fi

    sudo -i -u postgres createdb --owner=$2 $1
}
