#!/bin/bash
#
# Installs MongoDB.
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb


function mongodb_install {
    aptitude -y install mongodb
}
