#!/bin/sh
OS_VERSION=`cat /etc/centos-release`
CENTOS6='CentOS release 6.9 (Final)'
USERNAME=$1
echo $OS_VERSION
echo $CENTOS6
echo $USERNAME

yum install -y vim
echo 'set nu
set ts=4' > .vimrc
cat .vimrc

if [ "$OS_VERSION" == "$CENTOS6" ];
then 
	vim /etc/sysconfig/network
else
	vim /etc/hostname
fi

echo '10.0.2.4 CentOS6
10.0.2.5 CentOS7
10.0.2.6 CentOS7-1908' >> /etc/hosts
cat /etc/hosts

chmod 755 /home/$USERNAME
mkdir -p /home/$USERNAME/www
cd /home/$USERNAME/www
touch test.php
echo '<?php
phpinfo();
?>' > test.php
cat /home/$USERNAME/www/test.php

yum install -y httpd php php-mysql
yum install -y php-mbstring php-mcrypt php-gd php-xml
yum install -y mod_ssl mod_perl mod_auth_mysql

if [ "$OS_VERSION" == "$CENTOS6" ];
then
	yum install -y mysql mysql-server	
	service mysqld start
	chkconfig mysqld on
	/usr/bin/mysqladmin -u root password 'centos'
else
	yum install -y mariadb mariadb-server	
	systemctl start mariadb
	systemctl enable mariadb
	/usr/bin/mysql_secure_installation
fi

cd /home/$USERNAME
yum install -y wget
wget https://files.phpmyadmin.net/phpMyAdmin/4.0.10.20/phpMyAdmin-4.0.10.20-all-languages.tar.gz
tar -zxvf phpMyAdmin-4.0.10.20-all-languages.tar.gz
mv phpMyAdmin-4.0.10.20-all-languages /home/$USERNAME/www/phpMyAdmin
cd /home/$USERNAME/www/phpMyAdmin
cp config.sample.inc.php config.inc.php

cd /home/$USERNAME
wget https://tw.wordpress.org/wordpress-5.1.3-zh_TW.tar.gz
tar -zxvf wordpress-5.1.3-zh_TW.tar.gz
mv wordpress /home/$USERNAME/www/
cd /home/$USERNAME/www/wordpress
cp wp-config-sample.php wp-config.php
vim wp-config.php
echo "/** 設定 WordPress 變數和包含的檔案。 */
require_once(ABSPATH . 'wp-settings.php');
define('FS_METHOD','direct');
define('FTP_BASE', '/www/');
define('FTP_CONTENT_DIR', '/www/wordpress/wp-content/');
define('FTP_PLUGIN_DIR', '/www/wordpress/wp-content/plugins/');
define('FTP_THEMES_DIR ', '/www/wordpress/wp-content/themes/');
/** Override default file permissions */
if(is_admin()) {
    add_filter('filesystem_method', create_function('$a', 'return "direct";' ));
    define( 'FS_CHMOD_DIR', 0751 );
}" >> wp-config.php

if [ "$OS_VERSION" == "$CENTOS6" ];
then
	vim /etc/httpd/conf/httpd.conf
else
	vim /etc/httpd/conf.d/userdir.conf
fi

if [ "$OS_VERSION" == "$CENTOS6" ];
then
	service httpd restart
	chkconfig httpd on
else
	systemctl restart httpd
	systemctl enable httpd
fi

firewall-cmd --add-service=http --permanent
firewall-cmd --reload

setsebool -P httpd_can_network_connect 1
setsebool -P httpd_can_network_connect_db 1
setsebool -P httpd_enable_homedirs 1

GROUP_NAME=$(groups $USERNAME | awk '{print $3}')
echo $GROUP_NAME
chown -R $USERNAME:$GROUP_NAME /home/$USERNAME
chown -R apache:apache /home/$USERNAME/www/wordpress

chcon -t user_home_dir_t /home/$USERNAME/
chcon -R -t httpd_sys_content_t /home/$USERNAME/www/
chcon -R -t httpd_sys_script_rw_t /home/$USERNAME/www/wordpress