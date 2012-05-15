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

function apache_cleanup {
    a2dissite default # disable default vhost
}
