#!/bin/bash
#
# Install PostgreSQL
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

function postgresql_install {
    aptitude -y install postgresql postgresql-contrib postgresql-dev postgresql-client libpq-dev
}


function postgresql_recreate_cluster {
    # WARNING: this procedure removes all data in the main cluster
    # drop default cluster and recreate it with UTF-8 encoding
    # $1 - root data dicrecotry, i.e. /var/lib or /srv
    BASE_DIRECTORY=$1
    pg_dropcluster -stop 8.4 main
    if [ -z "$BASE_DIRECTORY" ]; then
        pg_createcluster -start -e UTF-8 8.4 main
    else
        DATA_DIRECTORY="$BASE_DIRECTORY/postgresql"
        mkdir -p "$DATA_DIRECTORY/8.4/main"
        chown -R postgres:postgres "$DATA_DIRECTORY"
        pg_createcluster -start -e UTF-8 -d "$DATA_DIRECTORY/8.4/main" 8.4 main
    fi;
}

function postgresql_create_user {
    # $1 - the user to create
    # $2 - their password

    if [ ! -n "$1" ]; then
        echo "postgresql_create_user() requires username as the first argument"
        return 1;
    fi
    if [ ! -n "$2" ]; then
        echo "postgresql_create_user() requires a password as the second argument"
        return 1;
    fi

    echo "CREATE ROLE $1 WITH LOGIN ENCRYPTED PASSWORD '$2';" | sudo -u postgres psql
}

function postgresql_create_database {
    # $1 - the db name to create
    # $2 - the db owner user

    if [ ! -n "$1" ]; then
        echo "postgresql_create_database() requires database name as the first argument"
        return 1;
    fi
    if [ ! -n "$2" ]; then
        echo "postgresql_create_database() requires an owner username as the second argument"
        return 1;
    fi

    sudo -u postgres createdb --owner=$2 $1
}
