#!/bin/bash
#
# Setup django project and add apache vhost configuration
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb


function django_get_user_or_default {
    # django_get_user_or_default([user])
    if [ -z "$1" ];
		then USER="www-data"
		else USER="$1"
	fi
    echo "$USER"
}

function django_get_project_path {
    # django_get_project_path(project_name)
    PROJECT_NAME="$1"
    echo "/srv/$PROJECT_NAME"
}

function django_change_project_owner {
    # django_change_project_owner(project_path, user)
    PROJECT_PATH="$1"
    USER="$2"
    GROUP="$USER"
    chown -R "$USER:$GROUP" "$PROJECT_PATH"
}

function django_create_project {
    # django_create_project(project_name)

    PROJECT_NAME="$1"
    if [ -z "$PROJECT_NAME" ]; then
        echo "django_create_project() requires the project name as the first argument"
        return 1;
    fi
    PROJECT_PATH=`django_get_project_path "$PROJECT_NAME"`

    mkdir -p "$PROJECT_PATH/app/conf/apache"
    mkdir -p "$PROJECT_PATH/logs" "$PROJECT_PATH/run/eggs"

    virtualenv "$PROJECT_PATH/venv"
    $PROJECT_PATH/venv/bin/pip install django

    pushd "$PROJECT_PATH/app"
    "$PROJECT_PATH/venv/bin/python" "$PROJECT_PATH/venv/bin/django-admin.py" startproject webapp .
    popd
    mkdir -p "$PROJECT_PATH/app/webapp/static"
}

function django_install_db_driver {
    # django_install_db_driver(project_path, driver_package)
    $1/venv/bin/pip install django "$2"
}

function django_configure_db_settings {
    # django_configure_db_settings(project_path, engine, name, user, password, [host, [port]])

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
    # django_configure_apache_virtualhost(hostname, project_path, wsgi_user)

    VHOST_HOSTNAME="$1"
    PROJECT_PATH="$2"
    USER="$3"
	GROUP="$USER"

    if [ -z "$VHOST_HOSTNAME" ]; then
        echo "django_configure_apache_virtualhost() requires the hostname as the first argument"
        return 1;
    fi

    if [ -z "$PROJECT_PATH" ]; then
        echo "django_configure_apache_virtualhost() requires path to the django project as the second argument"
        return 1;
    fi

    APACHE_CONF="200-$VHOST_HOSTNAME"
    APACHE_CONF_PATH="$PROJECT_PATH/app/conf/apache/$APACHE_CONF"

    cat > "$APACHE_CONF_PATH" << EOF
<VirtualHost *:80>
    ServerAdmin root@$VHOST_HOSTNAME
    ServerName $VHOST_HOSTNAME
    ServerSignature Off

    Alias /static/ $PROJECT_PATH/app/webapp/static/
    Alias /robots.txt $PROJECT_PATH/app/webapp/static/robots.txt
    Alias /favicon.ico $PROJECT_PATH/app/webapp/static/favicon.ico

    CustomLog "|/usr/sbin/rotatelogs $PROJECT_PATH/logs/access.log.%Y%m%d-%H%M 5M" combined
    ErrorLog "|/usr/sbin/rotatelogs $PROJECT_PATH/logs/error.log.%Y%m%d-%H%M 5M"
    LogLevel warn

    WSGIScriptAlias / $PROJECT_PATH/app/webapp/wsgi.py

    WSGIDaemonProcess $VHOST_HOSTNAME user=$USER group=$GROUP processes=2 threads=10 maximum-requests=10000 display-name=%{GROUP} python-path=$PROJECT_PATH/app:$PROJECT_PATH/venv/lib/python2.7/site-packages python-eggs=$PROJECT_PATH/run/eggs
    WSGIProcessGroup $VHOST_HOSTNAME
    WSGIScriptAlias / $PROJECT_PATH/app/webapp/wsgi.py

    <Directory $PROJECT_PATH/app/webapp/static>
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

    ln -t /etc/apache2/sites-available/ "$APACHE_CONF_PATH"
    a2ensite "$APACHE_CONF"
}
