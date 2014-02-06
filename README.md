# Linode StackScripts


### Please note

These scripts may be a bit outdated now although the solution served me well on many occasions. I have now moved to Ansible and other configuration management tools that are just much metter than the bash scripts approach, although you may pick up some configs and scripting ideas from here.

If there is an interest in a similar full-stack web-server setup go ahead and open a ticket and I can prepare a set of Ansible roles and playbooks with Nginx & uWSGI as the web server.


-------------------

### Original readme


A Linode.com StackScript shell script that configures a complete web environment with Apache, PostgreSQL/MySQL/MongoDB, Python, mod_wsgi, virtualenv and Django.

Optionally creates a PostgreSQL/MySQL user and database and installs MongoDB NoSQL database.

By default, it creates a VirtualHost using the reverse DNS of your Linode's primary IP and sets up a sample Django project in the /srv directory.

Installs common system and dev utilities, sets up postfix loopback, Uncomplicated Firewall and Fail2Ban.

Writes command output to /root/stackscript.log and records /etc changes using Mercurial. When completed notifies via email.
