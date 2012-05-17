#!/bin/bash
#
# Installs a complete web environment with Apache, Python, Django and PostgreSQL.
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

# <UDF name="notify_email" Label="Send email notification to" example="Email address to send notification and system alerts." />

# <UDF name="user_name" label="Unprivileged user account name" example="This is the account that you will be using to log in." />
# <UDF name="user_password" label="Unprivileged user password" />
# <UDF name="user_sshkey" label="Public Key for user" default="" example="Recommended method of authentication. It is more secure than password log in." />
# <UDF name="sshd_passwordauth" label="Use SSH password authentication" oneof="Yes,No" default="No" example="Turn off password authentication if you have added a Public Key." />
# <UDF name="sshd_permitrootlogin" label="Permit SSH root login" oneof="No,Yes" default="No" example="Root account should not be exposed." />

# <UDF name="user_shell" label="Shell" oneof="/bin/zsh,/bin/bash" default="/bin/bash" />

# <UDF name="sys_hostname" label="System hostname" default="myvps" example="Name of your server, i.e. linode1." />

# <UDF name="setup_postgresql" label="Configure PostgreSQL and create database?" oneof="Yes,No" default="Yes" />
# <UDF name="postgresql_database" label="PostgreSQL database name" example="PostgreSQL database name, ASCII only." default="" />
# <UDF name="postgresql_user" label="PostgreSQL database user" example="PostgreSQL database user name, ASCII only." default="" />
# <UDF name="postgresql_password" label="PostgreSQL user password" default="" />

# <UDF name="setup_mysql" label="Configure MySQL and create database?" oneof="Yes,No" default="No" />
# <UDF name="mysql_database_password" label="MySQL root Password" default="" />
# <UDF name="mysql_database" label="MySQL database name" example="MySQL database name, ASCII only." default="" />
# <UDF name="mysql_user" label="MySQL database user" example="MySQL database user name, ASCII only." default="" />
# <UDF name="mysql_password" label="MySQL user password" default="" />

# <UDF name="setup_mongodb" label="Install MongoDB" oneof="Yes,No" default="No" />

# <UDF name="setup_apache" label="Install Apache" oneof="Yes,No" default="Yes" />

# <UDF name="setup_django_project" label="Configure sample django/mod_wsgi project?" oneof="Standalone,InUserHome,InUserHomeRoot,No" default="Standalone" example="Standalone: project will be created in /srv/project_name directory under new user account; InUserHome: project will be created in /home/$user/project_name; InUserHomeRoot: project will be created in user's home directory (/home/$user)." />
# <UDF name="django_domain" label="Django domain" default="" example="Your server domain configured in the DNS. Leave blank for RDNS (*.members.linode.com)." />
# <UDF name="django_project_name" label="Django project name" default="my_project" example="Name of your django project (if 'Create sample project' is selected), i.e. my_website." />
# <UDF name="django_user" label="Django project owner user" default="django" example="System user that will be used to run the mod-wsgi project process in the 'Standalone' setup mode." />

# <UDF name="sys_private_ip" Label="Private IP" default="" example="Configure network card to listen on this Private IP (if enabled in Linode/Remote Access settings tab). See http://library.linode.com/networking/configuring-static-ip-interfaces" />
# <UDF name="setup_monit" label="Install Monit system monitoring?" oneof="Yes,No" default="Yes" />

set -e
set -u
#set -x

USER_GROUPS=sudo

exec &> /root/stackscript.log

source <ssinclude StackScriptID="1"> # StackScript Bash Library
system_update

source <ssinclude StackScriptID="124"> # lib-system
system_install_mercurial
system_start_etc_dir_versioning #start recording changes of /etc config files

# Configure system
source <ssinclude StackScriptID="123"> # lib-system-ubuntu
system_update_hostname "$SYS_HOSTNAME"
system_record_etc_dir_changes "Updated hostname" # SS124

# Create user account
system_add_user "$USER_NAME" "$USER_PASSWORD" "$USER_GROUPS" "$USER_SHELL"
if [ "$USER_SSHKEY" ]; then
    system_user_add_ssh_key "$USER_NAME" "$USER_SSHKEY"
fi
system_record_etc_dir_changes "Added unprivileged user account" # SS124

# Configure sshd
system_sshd_permitrootlogin "$SSHD_PERMITROOTLOGIN"
system_sshd_passwordauthentication "$SSHD_PASSWORDAUTH"
touch /tmp/restart-ssh
system_record_etc_dir_changes "Configured sshd" # SS124

# Lock user account if not used for login
if [ "SSHD_PERMITROOTLOGIN" == "No" ]; then
    system_lock_user "root"
    system_record_etc_dir_changes "Locked root account" # SS124
fi

# Install Postfix
postfix_install_loopback_only # SS1
system_record_etc_dir_changes "Installed postfix loopback" # SS124

# Setup logcheck
system_security_logcheck
system_record_etc_dir_changes "Installed logcheck" # SS124

# Setup fail2ban
system_security_fail2ban
system_record_etc_dir_changes "Installed fail2ban" # SS124

# Setup firewall
system_security_ufw_configure_basic
system_record_etc_dir_changes "Configured UFW" # SS124

source <ssinclude StackScriptID="126"> # lib-python
python_install
system_record_etc_dir_changes "Installed python" # SS124

# lib-system - SS124
system_install_utils
system_install_build
system_install_subversion
system_install_git
system_record_etc_dir_changes "Installed common utils"

# Install and configure apache and mod_wsgi
if [ "$SETUP_APACHE" == "Yes" ]; then
    source <ssinclude StackScriptID="122"> # lib-apache
    apache_worker_install
    system_record_etc_dir_changes "Installed apache" # SS124
    apache_mod_wsgi_install
    system_record_etc_dir_changes "Installed mod-wsgi" # SS124
    apache_cleanup
    system_record_etc_dir_changes "Cleaned up apache config" # SS124
fi

# Install PostgreSQL and setup database
if [ "$SETUP_POSTGRESQL" == "Yes" ]; then
    source <ssinclude StackScriptID="125"> # lib-postgresql
    postgresql_install
    system_record_etc_dir_changes "Installed PostgreSQL"
    postgresql_create_user "$POSTGRESQL_USER" "$POSTGRESQL_PASSWORD"
    postgresql_create_database "$POSTGRESQL_DATABASE" "$POSTGRESQL_USER"
    system_record_etc_dir_changes "Configured PostgreSQL"
fi

# Install MySQL and setup database
if [ "$SETUP_MYSQL" == "Yes" ]; then
    set +u # ignore undefined variables in Linode's SS1
    mysql_install "$MYSQL_DATABASE_PASSWORD" && mysql_tune 30
    mysql_create_database "$MYSQL_DATABASE_PASSWORD" "$MYSQL_DATABASE"
    mysql_create_user "$MYSQL_DATABASE_PASSWORD" "$MYSQL_USER" "$MYSQL_PASSWORD"
    mysql_grant_user "$MYSQL_DATABASE_PASSWORD" "$MYSQL_USER" "$MYSQL_DATABASE"
    set -u
    system_record_etc_dir_changes "Configured MySQL"
fi

# Install MongoDB
if [ "$SETUP_MONGODB" == "Yes" ]; then
    source <ssinclude StackScriptID="128"> # lib-mongodb
    mongodb_install
    system_record_etc_dir_changes "Installed MongoDB"
fi

# Setup and configure sample django project
RDNS=$(get_rdns_primary_ip)
DJANGO_PROJECT_PATH=""

if [ "$SETUP_DJANGO_PROJECT" != "No" ]; then
    source <ssinclude StackScriptID="127"> # lib-django

    if [ -z "$DJANGO_DOMAIN" ]; then DJANGO_DOMAIN=$RDNS; fi

    case "$SETUP_DJANGO_PROJECT" in
    Standalone)
        DJANGO_PROJECT_PATH="/srv/$DJANGO_PROJECT_NAME"
        if [ -n "$DJANGO_USER" ]; then
            if [ "$DJANGO_USER" != "$USER_NAME" ]; then
                system_add_system_user "$DJANGO_USER" "$DJANGO_PROJECT_PATH" "$USER_SHELL"
            else
                mkdir -p "$DJANGO_PROJECT_PATH"
            fi
        else
            DJANGO_USER="www-data"
        fi
      ;;
    InUserHome)
        DJANGO_USER=$USER_NAME
        DJANGO_PROJECT_PATH=$(system_get_user_home "$USER_NAME")/$DJANGO_PROJECT_NAME
      ;;
    InUserHomeRoot)
        DJANGO_USER=$USER_NAME
        DJANGO_PROJECT_PATH=$(system_get_user_home "$USER_NAME")
      ;;
    esac

    django_create_project "$DJANGO_PROJECT_PATH"
    django_change_project_owner "$DJANGO_PROJECT_PATH" "$DJANGO_USER"

    if [ "$SETUP_APACHE" == "Yes" ]; then
        django_configure_apache_virtualhost "$DJANGO_DOMAIN" "$DJANGO_PROJECT_PATH" "$DJANGO_USER"
        touch /tmp/restart-apache2
    fi
    if [ "$SETUP_POSTGRESQL" == "Yes" ]; then
        django_install_db_driver "$DJANGO_PROJECT_PATH" "psycopg2"
        django_configure_db_settings "$DJANGO_PROJECT_PATH" "postgresql_psycopg2" "$POSTGRESQL_DATABASE" "$POSTGRESQL_USER" "$POSTGRESQL_PASSWORD" "127.0.0.1" ""
    fi
    if [ "$SETUP_MYSQL" == "Yes" ]; then
        django_install_db_driver "$DJANGO_PROJECT_PATH" "MySQL-python"
    fi
    system_record_etc_dir_changes "Configured django project '$DJANGO_PROJECT_NAME'"
fi

if [ -n "$SYS_PRIVATE_IP" ]; then
    system_configure_private_network "$SYS_PRIVATE_IP"
    system_record_etc_dir_changes "Configured private network"
fi

restart_services
restart_initd_services

if [ "$SETUP_MONIT" == "Yes" ]; then
    source <ssinclude StackScriptID="129"> # lib-monit
    monit_install
    system_record_etc_dir_changes "Installed Monit"

    monit_configure_email "$NOTIFY_EMAIL"
    monit_configure_web $(system_primary_ip)
    system_record_etc_dir_changes "Configured Monit interfaces"

    monit_def_system "$SYS_HOSTNAME"
    monit_def_rootfs
    monit_def_cron
    monit_def_postfix
    monit_def_ping_google
    if [ "$SETUP_POSTGRESQL" == "Yes" ]; then monit_def_postgresql; fi
    if [ "$SETUP_MYSQL" == "Yes" ]; then monit_def_mysql; fi
    if [ "$SETUP_MONGODB" == "Yes" ]; then monit_def_mongodb; fi
    if [ "$SETUP_APACHE" == "Yes" ]; then monit_def_apache; fi
    #if [ "$SETUP_MEMCACHE" == "Yes" ]; then monit_def_memcached; fi
    system_record_etc_dir_changes "Created Monit rules for installed services"
    monit reload
fi

# Send info message
cat > ~/setup_message <<EOD
Hi,

Your Linode VPS configuration is completed.

EOD

if [ "$SETUP_DJANGO_PROJECT" != "No" ]; then
    cat >> ~/setup_message <<EOD
You can now navigate to http://${DJANGO_DOMAIN}/ to see your web server running.
The Django project files are in $DJANGO_PROJECT_PATH/app.

EOD
fi

if [ "$SETUP_MONIT" == "Yes" ]; then
    cat >> ~/setup_message <<EOD
Monit web interface is at http://${RDNS}:2812/ (use your system username/password).

EOD
fi

cat >> ~/setup_message <<EOD
To access your server ssh to $USER_NAME@$RDNS

Thanks for using this StackScript. Follow http://github.com/nigma/StackScripts for updates.

Need help with developing web apps? Email me at en@ig.ma.

Best,
Filip
--
http://en.ig.ma/
EOD

mail -s "Your Linode VPS is ready" "$NOTIFY_EMAIL" < ~/setup_message
