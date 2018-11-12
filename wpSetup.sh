#!/bin/bash

#Auther: Dikshant Musale

log=pkg.log

#This function will check that the given package is installed or not and if not it will install
pkgchk()
{
	pkgname=$1
	dpkg-query --show $pkgname &>>log
	if [ $? -ne 0 ]
	then
		echo "package does not exist!"
		apt-get install $pkgname -y
	else
		echo "$pkgname is already exists!"
	fi
}

#Checking root previleges
if [ $(id -u) -ne 0 ]
then
	echo "Script needs to run under root previleges"
	exit 1
fi

# update apt lists
echo "Updating apt package lists, this may take some time."
apt-get update &>> $log

pkgchk debconf-utils
pkgchk nginx

#setting up temporary paswword for mysql while installing
db_password="toor"
debconf-set-selections <<< "mysql-server mysql-server/root_password password $db_password" &>>$log
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $db_password" &>>$log
pkgchk mysql-server

# delete the installation configurations of mysql-server
echo "Deleting temporary configuration of mysql"
debconf-communicate mysql-server <<< 'PURGE' &>>$log

pkgchk php
pkgchk php-mysql

echo "Enter domain name: "
read domain
while [ -z $domain ]
do
	echo "domain name cannot be blank! Please enter a valid name: "
	read domain
done

#creating entry of domain name in /etc/hostst    
echo "Creating /etc/hosts entry for new site"
chown $(whoami) /etc/hosts &>>$log
sed -i "\$a127.0.0.1\t$domain" /etc/hosts &>>$log
chown root /etc/hosts &>>$log

#unzip utility if not available passing it to install function
pkgchk unzip
pkgchk curl

# create nginx configuration for domain
# check if nginx.conf exist
if [ ! -f nginx.conf ]
then 
	echo "nginx.conf file is missing in current directory. Aborting..." 1>&2
	exit 1
fi

echo "Creating nginx configuration for new site"
cp /etc/nginx/nginx.conf /etc/nginx/sites-available/$domain &>> $log
sed -i "s/domain_name/$domain/g" /etc/nginx/sites-available/$domain &>> $log
ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/ &>> $log
systemctl reload nginx.service &>> $log
systemctl restart mysql.service &>> $log

#Downloading latest wordpress and configuring it
echo "Downloading the latest wordpress.zip and extracting it in root directory"

curl -L http://wordpress.org/latest.zip -o wordpress.zip &>>$log
unzip wordpress.zip -d /tmp/ &>> $log
rm -f wordpress.zip &>>$log
mkdir /var/www/$domain &>>$log
mv /tmp/wordpress/* /var/www/$domain/&>>$log
rm -rf /tmp/wordpress&>>$log

#Database creation
echo "Creating database for new site"
db_name=$domain
mysql -u root -p$db_password -e "USE $db_name;" &>> $log
if [ $? -ne 0 ] 
then
	mysql -u root -p$db_password -e "CREATE DATABASE $db_name;" &>> $log
else
	echo "Database $db_name already exist."
fi

# create wp-config.php
echo "Creating wp-config.php for WordPress site"
cp /var/www/$domain_name/wp-config-sample.php /var/www/$domain_name/wp-config-sample.php &>> $log

sed -i "s/database_name_here/$db_name/g" /var/www/$domain_name/wp-config-sample.php &>> $log
sed -i "s/username_here/root/g" /var/www/$domain_name/wp-config-sample.php &>> $log
sed -i "s/password_here/$db_password/g" /var/www/$domain_name/wp-config-sample.php &>> $log

salts_keys=$(curl https://api.wordpress.org/secret-key/1.1/salt) 
salts_keys=$(echo $salts_keys | sed -e 's/\([[\/.*]\|\]\)/\\&/g')

sed -i "/_KEY/d" /var/www/$domain/wp-config-sample.php &>> $log
sed -i "/_SALT/d" /var/www/$domain/wp-config-sample.php &>> $log
sed -i "/define('DB_COLLATE', '');/a$salts_keys" /var/www/$domain/wp-config-sample.php &>> $log

systemctl restart nginx.service

# change the owner so that php-fpm will have write access
chown -R www-data:www-data /var/www/$domain/ &>> $log

echo -e "\nSite can be browsed at http://$domain"
echo "root directory of site: /var/www/$domain"
echo "nginx configuration of site: /etc/nginx/sites-available/$domain"
echo "Database user: root"
echo "Database password: $db_password"
echo "Database name: $db_name"
