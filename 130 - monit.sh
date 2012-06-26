#!/bin/bash
#
# Monit system monitoring. See also http://mmonit.com/wiki/Monit/ConfigurationExamples
#
# Copyright (c) 2012 Filip Wasilewski <en@ig.ma>.
#
# My ref: http://www.linode.com/?r=aadfce9845055011e00f0c6c9a5c01158c452deb


function monit_install {
    aptitude -y install monit
}

function monit_configure_email {
    # system_monit_configure_email(email)
cat <<EOT >/etc/monit/conf.d/email-interface
  set mailserver localhost
  set alert $1
EOT
}

function monit_configure_web {
    # system_monit_configure_web(domain)
cat <<EOT >/etc/monit/conf.d/web-interface
  set httpd port 2812 and
    use address $1
    allow $(randomString 10):$(randomString 30)
    allow @sudo readonly
    signature disable
EOT
ufw allow 2812/tcp
}

function monit_def_system {
    # monit_def_system(hostname)
cat <<EOT >/etc/monit/conf.d/system.cfg
  check system $1
    if loadavg (1min) > 10 then alert
    if loadavg (5min) > 7 then alert
    if memory usage > 85% then alert
    if swap usage > 25% then alert
    if cpu usage (user) > 90% then alert
    if cpu usage (system) > 60% then alert
    if cpu usage (wait) > 50% then alert
    group system
EOT
}

function monit_def_rootfs {
cat <<EOT >/etc/monit/conf.d/rootfs.cfg
  check filesystem rootfs with path /
    if space usage > 80% for 5 times within 15 cycles then alert
    if inode usage > 85% then alert
    group system
EOT
}

function monit_def_cron {
cat <<EOT >/etc/monit/conf.d/cron.cfg
  check process cron with pidfile /var/run/crond.pid
    start program = "/sbin/start cron"
    stop  program = "/sbin/stop cron"
    if 5 restarts within 5 cycles then timeout
    depends on cron_rc
    group system

  check file cron_rc with path /etc/init.d/cron
    if failed checksum then unmonitor
    if failed permission 755 then unmonitor
    if failed uid root then unmonitor
    if failed gid root then unmonitor
    group system
EOT
}

function monit_def_sshd {
cat <<EOT >/etc/monit/conf.d/sshd.cfg
  check process sshd with pidfile /var/run/sshd.pid
    start program "/etc/init.d/ssh start"
    stop program "/etc/init.d/ssh stop"
    # if failed port 22 protocol ssh then restart
    # if 3 restarts within 3 cycles then timeout
EOT
}

function monit_def_ping_google {
cat <<EOT >/etc/monit/conf.d/ping_google.cfg
  check host google-ping with address google.com
    if failed port 80 proto http then alert
    group server
EOT
}

function monit_def_postfix {
cat <<EOT >/etc/monit/conf.d/postfix.cfg
  check process postfix with pidfile /var/spool/postfix/pid/master.pid
    start program = "/etc/init.d/postfix start"
    stop  program = "/etc/init.d/postfix stop"
    if cpu > 60% for 2 cycles then alert
    if cpu > 80% for 5 cycles then restart
    if totalmem > 200.0 MB for 5 cycles then restart
    if children > 250 then restart
    if loadavg(5min) greater than 10 for 8 cycles then stop
    if failed host localhost port 25 protocol smtp with timeout 15 seconds then alert
    if failed host localhost port 25 protocol smtp for 3 cycles then restart
    if 3 restarts within 5 cycles then timeout
    group mail

  check file postfix_rc with path /etc/init.d/postfix
    if failed checksum then unmonitor
    if failed permission 755 then unmonitor
    if failed uid root then unmonitor
    if failed gid root then unmonitor
    group mail
EOT
}


function monit_def_postgresql {
cat <<EOT >/etc/monit/conf.d/postgresql.cfg
  check process postgres with pidfile /var/run/postgresql/9.1-main.pid
    start program = "/etc/init.d/postgresql start"
    stop program = "/etc/init.d/postgresql stop"
    if failed unixsocket /var/run/postgresql/.s.PGSQL.5432 protocol pgsql then restart
    if failed host localhost port 5432 protocol pgsql then restart
    if 5 restarts within 5 cycles then timeout
    depends on postgresql_bin
    depends on postgresql_rc
    group database

  check file postgresql_bin with path /usr/lib/postgresql/9.1/bin/postgres
    if failed checksum then unmonitor
    if failed permission 755 then unmonitor
    if failed uid root then unmonitor
    if failed gid root then unmonitor
    group database

  check file postgresql_rc with path /etc/init.d/postgresql
    if failed checksum then unmonitor
    if failed permission 755 then unmonitor
    if failed uid root then unmonitor
    if failed gid root then unmonitor
    group database

  check file postgresql_log with path /var/log/postgresql/postgresql-9.1-main.log
    if size > 100 MB then alert
    group database
EOT
}

function monit_def_mysql {
cat <<EOT > /etc/monit/conf.d/mysql.cfg
  check process mysqld with pidfile /var/run/mysqld/mysqld.pid
    start program = "/sbin/start mysql" with timeout 20 seconds
    stop program = "/sbin/stop mysql"
    if failed host localhost port 3306 protocol mysql then restart
    if failed unixsocket /var/run/mysqld/mysqld.sock protocol mysql then restart
    if 5 restarts within 5 cycles then timeout
    depends on mysql_bin
    depends on mysql_rc
    group database

  check file mysql_bin with path /usr/sbin/mysqld
    if failed checksum then unmonitor
    if failed permission 755 then unmonitor
    if failed uid root then unmonitor
    if failed gid root then unmonitor
    group database

  check file mysql_rc with path /etc/init.d/mysql
    if failed checksum then unmonitor
    if failed permission 755 then unmonitor
    if failed uid root then unmonitor
    if failed gid root then unmonitor
    group database
EOT
}

function monit_def_mongodb {
cat <<EOT >/etc/monit/conf.d/mongodb.cfg
  check process mongodb with pidfile /var/lib/mongodb/mongod.lock
    start program = "/sbin/start mongodb"
    stop  program = "/sbin/stop mongodb"
    if failed host localhost port 28017 protocol http
      and request "/" with timeout 10 seconds then restart
    if 5 restarts within 5 cycles then timeout
    group database
EOT
}

function monit_def_memcached {
cat <<EOT >/etc/monit/conf.d/memcached.cfg
  check process memcached with pidfile /var/run/memcached.pid
    start program = "/etc/init.d/memcached start"
    stop program = "/etc/init.d/memcached stop"
    if 5 restarts within 5 cycles then timeout
    group database
EOT
}

function monit_def_apache {
cat <<EOT >/etc/monit/conf.d/apache2.cfg
  check process apache with pidfile /var/run/apache2.pid
    start program = "/etc/init.d/apache2 start"
    stop  program = "/etc/init.d/apache2 stop"
    if cpu > 60% for 2 cycles then alert
    if cpu > 80% for 5 cycles then alert
    if totalmem > 200.0 MB for 5 cycles then alert
    if children > 250 then alert
    if loadavg(5min) greater than 10 for 8 cycles then stop
    if failed host localhost port 80 protocol HTTP request / within 2 cycles then alert
    if failed host localhost port 80 protocol apache-status
        dnslimit > 25% or  loglimit > 80% or waitlimit < 20% retry 2 within 2 cycles then alert
    #if 5 restarts within 5 cycles then timeout
    depends on apache_bin
    depends on apache_rc
    group www

  check file apache_bin with path /usr/sbin/apache2
    if failed checksum then unmonitor
    if failed permission 755 then unmonitor
    if failed uid root then unmonitor
    if failed gid root then unmonitor
    group www

  check file apache_rc with path /etc/init.d/apache2
    if failed checksum then unmonitor
    if failed permission 755 then unmonitor
    if failed uid root then unmonitor
    if failed gid root then unmonitor
    group www
EOT
}
