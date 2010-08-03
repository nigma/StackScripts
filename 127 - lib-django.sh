#!/bin/bash
#
# Setup django project and add apache vhost configuration
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

function django_get_project_path {
    PROJECT_NAME="$1"
    echo "/srv/$PROJECT_NAME"
}

function django_change_project_owner {
    PROJECT_PATH="$1"
    USER="$2"
    GROUP="$3"
    if [ -z "$USER" ]; then
        USER="www-data"
    fi
    if [ -z "$GROUP" ]; then
        GROUP="$USER"
    fi
    chown -R "$USER:$GROUP" "$PROJECT_PATH"
}


function django_create_project {
    # $1 - name of the project to create create

    PROJECT_NAME="$1"
    if [ -z "$PROJECT_NAME" ]; then
        echo "django_create_project() requires the project name as the first argument"
        return 1;
    fi
    PROJECT_PATH=`django_get_project_path "$PROJECT_NAME"`

    mkdir -p "$PROJECT_PATH/app" "$PROJECT_PATH/app/conf/apache"
    mkdir -p "$PROJECT_PATH/logs" "$PROJECT_PATH/run/eggs"

    virtualenv --no-site-packages "$PROJECT_PATH/venv"
    pip -E "$PROJECT_PATH/venv" install django

    pushd "$PROJECT_PATH/app"
    "$PROJECT_PATH/venv/bin/python" "$PROJECT_PATH/venv/bin/django-admin.py" startproject webapp
    popd
    mkdir -p "$PROJECT_PATH/app/webapp/site_media"

    cat > "$PROJECT_PATH/app/conf/apache/django.wsgi" << EOF
import os
import sys

root_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
sys.path.insert(0, os.path.abspath(os.path.join(root_path, 'venv/lib/python2.6/site-packages/')))
sys.path.insert(0, os.path.abspath(os.path.join(root_path, 'app')))
sys.path.insert(0, os.path.abspath(os.path.join(root_path, 'app', 'webapp')))

os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'

import django.core.handlers.wsgi
application = django.core.handlers.wsgi.WSGIHandler()
EOF
}


function django_install_db_driver {
    # $1 - project root
    # $2 - driver package
    pip -E "$1/venv" install "$2"
}


function django_configure_db_settings {
    # $1 - project root
    # $2 - engine
    # $3 - name
    # $4 - user
    # $5 - password
    # $6 - host (optional)
    # $7 - port (optional)

    SETTINGS="$1/app/webapp/settings.py"
    sed -i -e "s/'ENGINE': 'django.db.backends.'/'ENGINE': 'django.db.backends.$2'/" "$SETTINGS"
    sed -i -e "s/'NAME': ''/'NAME': '$3'/" "$SETTINGS"
    sed -i -e "s/'USER': ''/'USER': '$4'/" "$SETTINGS"
    sed -i -e "s/'PASSWORD': ''/'PASSWORD': '$5'/" "$SETTINGS"
    if [ -n "$6" ]; then
        sed -i -e "s/'HOST': ''/'HOST': '$6'/" "$SETTINGS"
    fi
    if [ -n "$7" ]; then
        sed -i -e "s/'PORT': ''/'PORT': '$7'/" "$SETTINGS"
    fi
}


function django_configure_apache_virtualhost {

    # $1 - required - the hostname of the apache virtualhost to create
    # $2 - required - path to the django project
    # $3 - wsgi process user
    # $4 - wsgi process group

    VHOST_HOSTNAME="$1"
    PROJECT_PATH="$2"
    USER="$3"
    GROUP="$4"

    if [ -z "$VHOST_HOSTNAME" ]; then
        echo "django_configure_apache_virtualhost() requires the hostname as the first argument"
        return 1;
    fi

    if [ -z "$PROJECT_PATH" ]; then
        echo "django_configure_apache_virtualhost() requires path to the django project as the second argument"
        return 1;
    fi

    if [ -z "$USER" ]; then
        USER="www-data"
    fi
    if [ -z "$GROUP" ]; then
        GROUP="$USER"
    fi

    cat > "/etc/apache2/sites-available/$VHOST_HOSTNAME" << EOF
<VirtualHost *:80>
    ServerAdmin root@$VHOST_HOSTNAME
    ServerName $VHOST_HOSTNAME

    Alias /site_media/ $PROJECT_PATH/app/webapp/site_media/
    Alias /media/ $PROJECT_PATH/venv/lib/python2.6/site-packages/django/contrib/admin/media/
    Alias /robots.txt $PROJECT_PATH/app/webapp/site_media/robots.txt
    Alias /favicon.ico $PROJECT_PATH/app/webapp/site_media/favicon.ico

    CustomLog "|/usr/sbin/rotatelogs $PROJECT_PATH/logs/access.log.%Y%m%d-%H%M%S 5M" combined
    ErrorLog "|/usr/sbin/rotatelogs $PROJECT_PATH/logs/error.log.%Y%m%d-%H%M%S 5M"
    LogLevel warn

    WSGIDaemonProcess $VHOST_HOSTNAME user=$USER group=$GROUP processes=1 threads=15 maximum-requests=10000 python-path=$PROJECT_PATH/venv/lib/python2.6/site-packages python-eggs=$PROJECT_PATH/run/eggs
    WSGIProcessGroup $VHOST_HOSTNAME
    WSGIScriptAlias / $PROJECT_PATH/app/conf/apache/django.wsgi

    <Directory $PROJECT_PATH/app/webapp/site_media>
        Order deny,allow
        Allow from all
        Options -Indexes FollowSymLinks
    </Directory>

    <Directory $PROJECT_PATH/app/conf/apache>
        Order deny,allow
        Allow from all
    </Directory>

 </VirtualHost>
EOF

    a2ensite "$VHOST_HOSTNAME"
}
