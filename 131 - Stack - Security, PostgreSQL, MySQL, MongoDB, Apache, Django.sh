#!/bin/bash
#
# Installs a complete web environment with Apache, Python, Django and PostgreSQL.
#
# Copyright (c) 2010 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb

# <UDF name="user_name" label="Unprivileged user account name" />
# <UDF name="user_password" label="Unprivileged user password" />
# <UDF name="user_sshkey" label="Public Key for user" default="" />

# <UDF name="sshd_permitrootlogin" label="Permit SSH root login" oneof="No,Yes" default="No" />
# <UDF name="sshd_passwordauth" label="Use SSH password authentication" oneOf="Yes,No" default="Yes" example="Turn off password authentication if you have added a Public Key" />

# <UDF name="sys_hostname" Label="System hostname" default="myvps" example="Name of your server, i.e. linode1" />

# <UDF name="base_data_directory" Label="Base data directory for PostgreSQL and MongoDB" oneof="/srv,/var/lib" default="/srv" />

# <UDF name="setup_postgresql" label="Configure PostgreSQL and create database?" oneof="Yes,No", default="Yes" />
# <UDF name="postgresql_database" Label="PostgreSQL database name" example="PostgreSQL database name, ASCII only" default="" />
# <UDF name="postgresql_user" Label="PostgreSQL database user" example="PostgreSQL database user name, ASCII only" default="" />
# <UDF name="postgresql_password" Label="PostgreSQL user password" example="PostgreSQL user password" default="" />

# <UDF name="setup_mysql" label="Configure MySQL and create database?" oneof="Yes,No", default="No" />
# <UDF name="mysql_database_password" Label="MySQL root Password" default="" />
# <UDF name="mysql_database" Label="MySQL database name" example="MySQL database name, ASCII only" default="" />
# <UDF name="mysql_user" Label="MySQL database user" example="MySQL database user name, ASCII only" default="" />
# <UDF name="mysql_password" Label="MySQL user password" example="MySQL user password" default="" />

# <UDF name="setup_mongodb" label="Install MongoDB" oneof="Yes,No", default="Yes" />

# <UDF name="setup_django_project" label="Configure sample django/mod_wsgi project?" oneof="Yes,No", default="Yes" />
# <UDF name="django_domain" Label="Django domain" default="" example="Your server domain. Leave blank for RDNS (*.members.linode.com)" />
# <UDF name="django_project_name" Label="Django project name" default="my_project" example="Name of your django project (if 'Create sample project' is selected), i.e. sample_project" />
# <UDF name="django_user" Label="Django project owner user" default="django" example="System user that will be used to run the mod-wsgi project process" />

# <UDF name="notify_email" Label="Send email finish notification to" default="" example="Optional email address to send notification to when setup is completed." />

USER_GROUPS=sudo

exec &> /root/stackscript.log

source <ssinclude StackScriptID="1"> # StackScript Bash Library
system_update
goodstuff

source <ssinclude StackScriptID="123"> # lib-system-ubuntu
system_enable_universe

source <ssinclude StackScriptID="124"> # lib-system
system_install_mercurial
system_start_etc_dir_versioning

# source <ssinclude StackScriptID="123"> # lib-system-ubuntu
# Configure system
system_update_locale_en_US_UTF_8
system_record_etc_dir_changes "Updated locale" # SS124
system_update_hostname "$SYS_HOSTNAME"
system_record_etc_dir_changes "Updated hostname" # SS124

# Create user account
system_add_user "$USER_NAME" "$USER_PASSWORD" "$USER_GROUPS"
if [ "$USER_SSHKEY" ]; then
    system_user_add_ssh_key "$USER_NAME" "$USER_SSHKEY"
fi
system_record_etc_dir_changes "Added unprivileged user account" # SS124

# Configure sshd
system_sshd_permitrootlogin "$SSHD_PERMITROOTLOGIN"
system_sshd_passwordauthentication "$SSHD_PASSWORDAUTH"
system_sshd_pubkeyauthentication "yes"
touch /tmp/restart-ssh
system_record_etc_dir_changes "Configured sshd" # SS124

# Setup firewall
system_security_ufw_install
system_record_etc_dir_changes "Installed UFW" # SS124
system_security_ufw_configure_basic
system_record_etc_dir_changes "Configured UFW" # SS124

# Setup fail2ban
system_security_fail2ban
system_record_etc_dir_changes "Installed fail2ban" # SS124

# Setup logcheck
system_security_logcheck
system_record_etc_dir_changes "Installed logcheck" # SS124

# Install postfix
postfix_install_loopback_only # SS1
system_record_etc_dir_changes "Installed postfix loopback" # SS124

source <ssinclude StackScriptID="126"> # lib-python
python_install
system_record_etc_dir_changes "Installed python" # SS124

# source <ssinclude StackScriptID="124"> # lib-system
system_install_utils
system_install_build
system_install_subversion
system_install_git
system_record_etc_dir_changes "Installed common utils"

# Install and configure apache and mod_wsgi
source <ssinclude StackScriptID="122"> # lib-apache
apache_worker_install
system_record_etc_dir_changes "Installed apache" # SS124
#apache_mod_wsgi_install
apache_mod_wsgi_install_from_source "3.2" # install a more recent mod-wsgi version
system_record_etc_dir_changes "Installed mod-wsgi" # SS124
apache_cleanup
system_record_etc_dir_changes "Cleaned up apache config" # SS124

# Install PostgreSQL and setup database
if [ "$SETUP_POSTGRESQL" == "Yes" ]; then
    source <ssinclude StackScriptID="125"> # lib-postgresql
    postgresql_install
    postgresql_recreate_cluster "$BASE_DATA_DIRECTORY"
    system_record_etc_dir_changes "Installed PostgreSQL"
    postgresql_create_user "$POSTGRESQL_USER" "$POSTGRESQL_PASSWORD"
    postgresql_create_database "$POSTGRESQL_DATABASE" "$POSTGRESQL_USER"
    system_record_etc_dir_changes "Configured PostgreSQL"
fi

# Install MySQL and setup database
if [ "$SETUP_MYSQL" == "Yes" ]; then
    mysql_install "$MYSQL_DATABASE_PASSWORD" && mysql_tune 30
    mysql_create_database "$MYSQL_DATABASE_PASSWORD" "$MYSQL_DATABASE"
    mysql_create_user "$MYSQL_DATABASE_PASSWORD" "$MYSQL_USER" "$MYSQL_PASSWORD"
    mysql_grant_user "$MYSQL_DATABASE_PASSWORD" "$MYSQL_USER" "$MYSQL_DATABASE"
    system_record_etc_dir_changes "Configured MySQL"
fi

# Install MongoDB
if [ "$SETUP_MONGODB" == "Yes" ]; then
    source <ssinclude StackScriptID="128"> # lib-mongodb
    system_configure_mongodb_repository
    system_record_etc_dir_changes "Added MongoDB repository to sources.list"
    mongodb_install "$BASE_DATA_DIRECTORY"
    system_record_etc_dir_changes "Installed MongoDB"
fi

# Setup and configure sample django project
if [ ! -n "$DJANGO_DOMAIN" ]; then
    DJANGO_DOMAIN=$(get_rdns_primary_ip)
fi
if [ "$SETUP_DJANGO_PROJECT" == "Yes" ]; then
    source <ssinclude StackScriptID="127"> # lib-django

    DJANGO_PROJECT_PATH=`django_get_project_path "$DJANGO_PROJECT_NAME"`
    django_create_project "$DJANGO_PROJECT_NAME"

    system_add_system_user "$DJANGO_USER" "$DJANGO_PROJECT_PATH"
    chsh -s /bin/bash "$DJANGO_USER"

    django_configure_apache_virtualhost "$DJANGO_DOMAIN" "$DJANGO_PROJECT_PATH" "$DJANGO_USER"
    if [ "$SETUP_POSTGRESQL" == "Yes" ]; then
        django_install_db_driver "$DJANGO_PROJECT_PATH" "psycopg2"
        django_configure_db_settings "$DJANGO_PROJECT_PATH" "postgresql_psycopg2" "$POSTGRESQL_DATABASE" "$POSTGRESQL_USER" "$POSTGRESQL_PASSWORD" "127.0.0.1"
    fi
    if [ "$SETUP_MYSQL" == "Yes" ]; then
        django_install_db_driver "$DJANGO_PROJECT_PATH" "MySQL-python"
    fi
    django_change_project_owner "$DJANGO_PROJECT_PATH" "$DJANGO_USER"
    system_record_etc_dir_changes "Configured django project '$DJANGO_PROJECT_NAME'"
    touch /tmp/restart-apache2
fi;

restartServices


# Send info message
if [ -n "$NOTIFY_EMAIL" ]; then
    mail -s "Your Linode VPS is configured" "$NOTIFY_EMAIL" <<EOD
Hi,

Your Linode VPS configuration is completed.

You can now navigate to http://${DJANGO_DOMAIN}/ to see your web server running.

Thanks for using this StackScript.

-- 
http://en.ig.ma/
EOD
fi
