#!/bin/bash

#Auther: Dikshant Musale

log_file=pkg.log

#the function for ensuring package availability and installation.

pkg_chk() 
{
	pkg_name=$1
	dpkg-query --show $pkg_name &>> $log_file
	if [ $0 -ne 0 ]
	then
		echo "Installing $pkg_name ..."
		apt-get install $pkg_name -y &>>$log_file
		if [ $? -ne 0 ]
		then
			echo "installation of $pkg_name failed!" 1>&2
			exit 1
		else
			echo "done!"
		fi
		else
			echo "$pkg_name is already exists!"
	fi
}

echo -e "Installing PHP NGINX MYSQL on the system..."

#checking for root previleges

if [ $(id -u) -ne 0 ]
then
	echo "Script needs to run under root previleges"
	exit 1
fi

#update apt lists

echo "updating the package lists, this may take some time..."
apt-get update &>>$log_file

pkg_chk nginx
pkg_chk debconf-utils

#setting temporary configurations for MySql-server
db_password="tempass123"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $db_password" &>>$log_file
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $db_password" &>>$log_file
pkg_chk mysql-server

#deleting temporary configurations of mysql-server

debconf-communicate mysql-server <<< 'PURGE' &>> $log_file

pkg_chk php7.0-fpm
pkg_chk php-mysql

#asking for domain anme 

echo "Enter domain name: "
read domain

echo "Creating /etc/hosts entry for your site..."
chown $(whoami) /etc/hosts &>>log_file
sed -i "\$a127.0.0.1\t$domain" /etc/hosts &>>$log_file
chown root /etc/hosts &>>$log_file

echo "Downloading the latest wordpress.zip and extracting it in root directory"

#unzip utility if not available passing it to install function

pkg_chk unzip

#Downloading latest wordpress and configuring it

curl -L http://wordpress.org/latest.zip -o wordpress.zip &>>$log_file
unzip wordpress.zip -d /tmp/ &>> $log_file
rm -f wordpress.zip &>>$log_file
mkdir /var/www/$domain &>>$log_file
mv /tmp/wordpress/* /var/www/$domain/&>>$log_file
rm -rf /tmp/wordpress&>>$log_file

#database creation

echo "Creating database..."

db_name = ${domain//./_}_db
mysql -u root -p$db_password -e "USE $db_name;"&>>$log_file
if [ $? -ne 0 ] 
then
	mysql -u root -p$db_password -e "CREATE DATABASE $db_name;"&>>$log_file
else
	echo "Database $db_name already exists"
fi

echo "Creating wp-config.php for wordpress site"
cp /var/www/$domain/wp-config.php /var/www/$domain/wp-config.php &>>$log_file
sed -i "s/database_name_here/$db_name/g" /var/www/$domain/wp-config.php &>>$log_file
sed -i "s/username_here/root/g" /var/www/$domain/wp-config.php &>>$log_file
sed -i "s/password_here/$db_password/g" /var/www/$domain/wp-config.php &>>$log_file

salts_keys=$(echo $salts_keys | sed -e 's/\([[\/.*]\|\]\)/\\&/g')
sed -i "/_KEY/d" /var/www/$domain/wp-config.php &>>$log_file
sed -i "/_SALT/d" /var/www/$domain/wp-config.php &>>$log_file
sed -i "/define('DB_COLLATE'.');/a$salts_keys" /var/www/$domain/wp-config.php &>>$log_file

#ownership permissions

chown -R www-data:www-data /var/www/$domain &>>$log_File

echo -e "\nSite can be browsed at http://$domain"

echo "root directory : /var/www/$domain"
echo "nginx configuration : /etc/nginx/sites-available/$domain"
echo "Database user : root"
echo "Databse name : $db_name"
echo "Databse password : $db_password"
