#!/bin/bash
#
# Setup django project and add apache vhost configuration
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

PROJECT_CODE_DIR=app
DJANGO_PROJECT=webapp

function django_change_project_owner {
    # django_change_project_owner(project_path, user)
    PROJECT_PATH="$1"
    USER="$2"
    chown -R "$USER:$USER" "$PROJECT_PATH"
}

function django_create_project {
    # django_create_project(project_path)

    PROJECT_PATH="$1"
    if [ -z "$PROJECT_PATH" ]; then
        echo "django_create_project() requires the project root path as the first argument"
        return 1;
    fi

    mkdir -p "$PROJECT_PATH/$PROJECT_CODE_DIR/conf/apache"
    mkdir -p "$PROJECT_PATH/logs" "$PROJECT_PATH/run/eggs"

    virtualenv "$PROJECT_PATH/venv"
    $PROJECT_PATH/venv/bin/pip install Django

    pushd "$PROJECT_PATH/$PROJECT_CODE_DIR"
    "$PROJECT_PATH/venv/bin/python" "$PROJECT_PATH/venv/bin/django-admin.py" startproject "$DJANGO_PROJECT" .
    popd
    mkdir -p "$PROJECT_PATH/$PROJECT_CODE_DIR/$DJANGO_PROJECT/static"

    echo "Django" >> "$PROJECT_PATH/$PROJECT_CODE_DIR/requirements.txt"
}

function django_install_db_driver {
    # django_install_db_driver(project_path, driver_package)
    $1/venv/bin/pip install "$2"
    echo "$2" >> "$PROJECT_PATH/$PROJECT_CODE_DIR/requirements.txt"
}

function django_configure_db_settings {
    # django_configure_db_settings(project_path, engine, name, user, password, [host, [port]])
    PROJECT_PATH="$1"
    SETTINGS="$PROJECT_PATH/$PROJECT_CODE_DIR/$DJANGO_PROJECT/settings.py"
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
    APACHE_CONF_PATH="$PROJECT_PATH/$PROJECT_CODE_DIR/conf/apache/$APACHE_CONF"

    cat > "$APACHE_CONF_PATH" << EOF
<VirtualHost *:80>
    ServerAdmin root@$VHOST_HOSTNAME
    ServerName $VHOST_HOSTNAME
    ServerSignature Off

    Alias /static/ $PROJECT_PATH/$PROJECT_CODE_DIR/$DJANGO_PROJECT/static/
    Alias /robots.txt $PROJECT_PATH/$PROJECT_CODE_DIR/$DJANGO_PROJECT/static/robots.txt
    Alias /favicon.ico $PROJECT_PATH/$PROJECT_CODE_DIR/$DJANGO_PROJECT/static/favicon.ico

    SetEnvIf User_Agent "monit/*" dontlog
    CustomLog "|/usr/sbin/rotatelogs $PROJECT_PATH/logs/access.log.%Y%m%d-%H%M 5M" combined env=!dontlog
    ErrorLog "|/usr/sbin/rotatelogs $PROJECT_PATH/logs/error.log.%Y%m%d-%H%M 5M"
    LogLevel warn

    WSGIScriptAlias / $PROJECT_PATH/$PROJECT_CODE_DIR/$DJANGO_PROJECT/wsgi.py

    WSGIDaemonProcess $VHOST_HOSTNAME user=$USER group=$GROUP processes=2 threads=10 maximum-requests=10000 display-name=%{GROUP} python-path=$PROJECT_PATH/$PROJECT_CODE_DIR:$PROJECT_PATH/venv/lib/python2.7/site-packages python-eggs=$PROJECT_PATH/run/eggs
    WSGIProcessGroup $VHOST_HOSTNAME
    WSGIScriptAlias / $PROJECT_PATH/$PROJECT_CODE_DIR/$DJANGO_PROJECT/wsgi.py

    <Directory $PROJECT_PATH/$PROJECT_CODE_DIR/$DJANGO_PROJECT/static>
        Order deny,allow
        Allow from all
        Options -Indexes FollowSymLinks
    </Directory>

    <Directory $PROJECT_PATH/$PROJECT_CODE_DIR/conf/apache>
        Order deny,allow
        Allow from all
    </Directory>

 </VirtualHost>
EOF

    ln -s -t /etc/apache2/sites-available/ "$APACHE_CONF_PATH"
    a2ensite "$APACHE_CONF"
}
