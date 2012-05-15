#!/bin/bash
#
# Install python and base packages
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

function python_install {
    aptitude -y install python python-dev python-setuptools
    easy_install pip
    pip install virtualenv virtualenvwrapper
}
