#!/bin/bash
#
# Install and configure apache and mod_wsgi
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

function apache_worker_install {
    aptitude -y install apache2-mpm-worker apache2-dev
}

function apache_mod_wsgi_install {
    aptitude -y install libapache2-mod-wsgi
}

function apache_mod_wsgi_install_from_source {
    #$1 - version

    VERSION=$1
    pushd /tmp
    wget http://modwsgi.googlecode.com/files/mod_wsgi-$VERSION.tar.gz
    tar xvfz mod_wsgi-$VERSION.tar.gz
    cd mod_wsgi-$VERSION
    ./configure
    make
    make install
    cd ..
    rm -rf mod_wsgi-$VERSION
    popd

    echo "LoadModule wsgi_module /usr/lib/apache2/modules/mod_wsgi.so" > /etc/apache2/mods-available/wsgi.load

    a2enmod wsgi
}

function apache_cleanup {
    a2dissite default # disable default vhost
}
