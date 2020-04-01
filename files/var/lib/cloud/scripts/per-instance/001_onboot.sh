#!/bin/bash

#Generate Mysql root password.
root_mysql_pass=$(openssl rand -hex 24)
mailcoach_mysql_pass=$(openssl rand -hex 24)
debian_sys_maint_mysql_pass=$(openssl rand -hex 24)

# Don't enable Mailcoach until first login
cat >> /root/.bashrc <<EOM
chmod +x /var/opt/mailcoach/setup.sh
/var/opt/mailcoach/setup.sh
EOM

# Save the passwords
cat > /root/.digitalocean_password <<EOM
root_mysql_pass="${root_mysql_pass}"
mailcoach_mysql_pass="${mailcoach_mysql_pass}"
EOM

# Protect the droplet
ufw limit ssh
ufw allow https
ufw allow http
ufw --force enable

mysqladmin -u root -h localhost password "${root_mysql_pass}"

mysql -uroot -p"${root_mysql_pass}" \
      -e "ALTER USER 'mailcoach'@'localhost' IDENTIFIED BY '${mailcoach_mysql_pass}'"

mysql -uroot -p"${root_mysql_pass}" \
      -e "GRANT ALL PRIVILEGES ON mailcoach.* TO mailcoach@localhost"

mysql -uroot -p"${root_mysql_pass}" \
      -e "ALTER USER 'debian-sys-maint'@'localhost' IDENTIFIED BY '${debian_sys_maint_mysql_pass}'"

MYSQL_ROOT_PASSWORD=${mailcoach_mysql_pass}

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Press y|Y for Yes, any other key for No:\"
send \"n\r\"
expect \"New password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Re-enter new password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

cat > /etc/mysql/debian.cnf <<EOM
# Automatically generated for Debian scripts. DO NOT TOUCH!
[client]
host     = localhost
user     = debian-sys-maint
password = ${debian_sys_maint_mysql_pass}
socket   = /var/run/mysqld/mysqld.sock
[mysql_upgrade]
host     = localhost
user     = debian-sys-maint
password = ${debian_sys_maint_mysql_pass}
socket   = /var/run/mysqld/mysqld.sock
EOM

