#!/bin/bash
#
# Mailcoach activation script
#
# This script will configure Apache with the domain
# provided by the user and offer the option to set up
# LetsEncrypt as well.

# Enable Mailcoach on firstlogin
echo "This script will copy the Mailcoach installation into"
echo "your web root and move the existing one to /var/www/html.old"
echo "--------------------------------------------------"
echo "This setup requires a domain name and a license key."
echo "If you do not have one yet, you may cancel this setup, press Ctrl+C."
echo "This script will run again on your next login"
echo "--------------------------------------------------"
echo "Enter the domain name for your new Mailcoach site."
echo "(ex. example.org or test.example.org) do not include www or http/s"
echo "--------------------------------------------------"
a=0
while [ $a -eq 0 ]
do
 read -p "Domain/Subdomain name: " dom
 host $dom 2>&1 > /dev/null
 if [ $? -eq 0 ]
 then
  a=1
 else
  a=0
  echo "Please provide a valid domain or subdomain name that resolves to an ip to continue or press Ctrl+C to cancel"
fi
done

# Set some default zero values
license=""
validLicense=""
email="0"
username="0"
pass="0"

echo -en "Enter your license key for Mailcoach."

while [[ $license == "" && $validLicense == "" ]]
do
 echo -en "\n"
 read -p "Your License key: " license

 if [ -z "$license" ]
 then
  validLicense=""
  echo "Please provide a valid license to continue or press Ctrl+C to cancel"
 else
  response=$(curl --write-out %{http_code} --silent --output /dev/null "https://mailcoach.app/is-valid-license/$license")
  if [ $response == "200" ]
  then
   validLicense="true"
  else
   echo "Please provide a valid license to continue or press Ctrl+C to cancel"
   validLicense=""
   license=""
  fi
 fi
done

sed -i "s/\$domain/$dom/g"  /etc/nginx/nginx.conf

echo -en "\n\n"
echo "Next, you have the option of configuring LetsEncrypt to secure your new site."
echo "Before doing this, be sure that you have pointed your domain or subdomain to this server's IP address."
echo "You can also run LetsEncrypt certbot later with the command 'certbot --nginx'"
echo "--------------------------------------------------"
echo -en "\n\n"

validYn="0"
while [ $validYn == "0" ]
do
  read -p "Would you like to use LetsEncrypt (certbot) to configure SSL(https) for your new site? (y/n): " yn
      case $yn in
          [Yy]* )
            if certbot --nginx
            then
              echo "Mailcoach has been enabled at https://$dom.";
              validYn=1;
            else
              echo -en "ERROR: Something went wrong during certbot validation, check the error above."
              exit 1 # Error
            fi
            break;;
          [Nn]* )
            echo "Skipping LetsEncrypt certificate generation";
            validYn=1;
            break;;
          * ) echo "Please answer y or n.";;
      esac
done

echo -en "Please provide the credentials for your admin user of Mailcoach."
while [ $email == "0" ]
do
 echo -en "\n"
 read -p "Email Address: " email
done
while [ $username == "0" ]
do
 echo -en "\n"
 read -p  "Name: " username
done

while [ $pass == "0" ]
do
  echo -en "\n"
  read -s -p "Password: " pass
done

echo "Finalizing installation..."

echo -en "Completing the configuration for Mailcoach..."
echo -en "\n\n"
echo -en "Setting composer auth."
export COMPOSER_ALLOW_SUPERUSER=1
composer config http-basic.satis.spatie.be user $license --global --quiet

if [ ! -f "/var/www/mailcoach/composer.json" ]; then
  echo -en "Installing Mailcoach..."
  echo -en "\n\n"
  if composer create-project spatie/mailcoach:dev-main /var/www/mailcoach --no-dev --no-progress --prefer-dist --repository=https://satis.spatie.be
  then
    echo -en "Mailcoach installed."
    echo -en "\n\n"
  else
    echo -en "ERROR: Something went wrong during composer."
    exit 1 # Error
  fi
else
  echo -en "Project already created. Skipping."
  echo -en "\n\n"
fi

cd /var/www/mailcoach

echo -en "Setting env files..."
echo -en "\n\n"
export $(cat /root/.digitalocean_password | xargs)

# populate the Mailcoach .env file
sed -e "s/DB_USERNAME=root/DB_USERNAME=mailcoach/g" \
    -e "s/DB_PASSWORD=/DB_PASSWORD=\"${mailcoach_mysql_pass}\"/g" \
    -e "s/APP_URL=.*/APP_URL=\"https:\/\/${dom}\"/g" \
    -e "s/APP_ENV=local.*/APP_ENV=production/g" \
    -e "s/DEBUG=true.*/DEBUG=false/g" \
    -i .env

chown -Rf www-data:www-data /var/www/mailcoach

echo -en "Migrating database..."
echo -en "\n\n"
if php artisan migrate --force
then
  echo -en "Migrated database"
  echo -en "\n\n"
else
  echo -en "ERROR: Something went wrong during migration, check the error above."
  exit 1 # Error
fi

echo -en "Creating user..."
echo -en "\n\n"
if php artisan mailcoach:make-user --username="$username" --email="$email" --password="$pass"
then
  echo -en "User created"
  echo -en "\n\n"
else
  echo -en "ERROR: Something went wrong during user creation, check the error above."
  exit 1 # Error
fi

if [ ! -f "/var/www/html/composer.json" ]; then
  echo -en "Moving files..."
  echo -en "\n\n"
  mv /var/www/html /var/www/html.old
  mv /var/www/mailcoach /var/www/html
  chown -Rf www-data:www-data /var/www/html
else
  echo -en "Files already moved. Skipping."
  echo -en "\n\n"
fi

chmod +x /var/www/html/artisan
mkdir -p /var/log/mailcoach
rm -rf ~/~rias

cd /var/www/html
php artisan storage:link

service nginx restart

echo -en "Starting Horizon..."
echo -en "\n\n"
redis-cli config set stop-writes-on-bgsave-error no >> /dev/null
supervisorctl restart horizon

mkdir -p /var/www/html/storage/framework/cache
chown -Rf www-data.www-data /var/www/
php artisan cache:clear

cp /etc/skel/.bashrc /root
source /root/.bashrc
echo "Installation complete. Access your new Mailcoach site in a browser to continue. Database credentials can be found in /root/.digitalocean_password"
