#!/bin/bash

#### PREREQUISITES ##########

# Linux pre-requisites
pre_requisites=("epel-release" "gcc" "openssl" "python3" "python3-devel" "python39-devel" "genisoimage" "kpartx" "unzip" )

yumcmd="sudo yum install -y"
# shellcheck disable=SC2068
for var in ${pre_requisites[@]}
do
    if ! rpm --quiet --query $var; then
        yumcmd="$yumcmd $var"
    fi
done

echo "Installing Linux dependencies using the command: $yumcmd"
eval $yumcmd

sudo yum install nginx -y

# Online installation of Python modules
sudo python3 -m pip install --upgrade pip
sudo python3 -m pip install wheel
sudo python3 -m pip install -r requirements.txt
# Offline installation of Python moddules
#sudo python3 -m pip install --no-index --find-links=pythonpackages/ --upgrade pip
#sudo python3 -m pip install --no-index --find-links=pythonpackages/ -r requirements.txt

#### END PREREQUISITES ##########

# Create a system user for this app
# And add bma to nginx user group
# Make /var/lib as root dir
sudo useradd -r -m -b /var/lib bma -G root,nginx
sudo chown -R bma:nginx /var/lib/bma

sudo cp service/secure-file-server.service /etc/systemd/system/
sudo cp service/bma-utils.service /etc/systemd/system/

# configure firewall to allow https and http for NGINX
sudo firewall-cmd --add-service=http
sudo firewall-cmd --add-service=https
sudo firewall-cmd --runtime-to-permanent

sudo mkdir -p /usr/share/nginx/html/images
sudo mkdir -p /usr/share/nginx/html/apidocs
# Give full ownership to BMA and read-only access to NGINX
sudo chown -R bma:nginx /usr/share/nginx/html/images
sudo chmod -R 755 /usr/share/nginx/html/images
# Copy swagger file for API docs
sudo cp apidocs/* /usr/share/nginx/html/apidocs/
sudo chown -R bma:nginx /usr/share/nginx/html/apidocs
sudo chmod -R 755 /usr/share/nginx/html/apidocs

# TODO Review the following SSL params
sudo cp nginx/ssl.conf /etc/nginx/conf.d/ssl.conf
sudo cp nginx/ssl-redirect.conf /etc/nginx/default.d/

sudo mkdir -p /usr/local/bma/bin
sudo mkdir -p /usr/local/bma/utils
sudo mkdir -p /usr/local/bma/conf
sudo mkdir -p /usr/local/bma/logs

# Commented for offline installer
#sudo curl -o /usr/local/bma/tftpboot/menu/wimboot -L https://github.com/ipxe/wimboot/releases/download/v2.7.4/wimboot
# Below line for offline installer
#sudo cp wimboot /usr/local/bma/tftpboot/menu/wimboot
#sudo firewall-cmd --add-service=dhcp --permanent
#sudo firewall-cmd --add-service=tftp --permanent
#sudo firewall-cmd --add-service=dns --permanent
#sudo firewall-cmd --reload

sudo cp -Rf bin/* /usr/local/bma/bin/
sudo cp -Rf utils/* /usr/local/bma/utils/
sudo cp -R scripts /usr/local/bma/
sudo cp -R etc /usr/local/bma/

# web gui
sudo mkdir -p /usr/share/nginx/html/ui
sudo rm -rf /usr/share/nginx/html/ui/*
sudo cp -Rf dist/* /usr/share/nginx/html/ui/
sudo chown -R bma:nginx /usr/share/nginx/html/ui

# Allow NGINX to access uwsgi socket file by setting httpd_t permissive
# Note that this command permanently sets httpd_t type SELinux context to permissive.
# Be aware of potential security holes.
# TODO Temp commented code
#sudo semanage permissive -a httpd_t

# Below command sets httpd to act as relay and allow NGINX to use http to interface with uswsgi
# Ref https://www.nginx.com/blog/using-nginx-plus-with-selinux/
echo "Configuring SELinux for BMA and NGINX integration..."
sudo setsebool -P httpd_can_network_relay 1
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P nis_enabled 1

# Copy the SSL/TLS certificates
sudo mkdir -p /etc/ssl/private
sudo chmod 700 /etc/ssl/private

echo "Installing application certificates..."
sudo cp certs/dhparam.pem /etc/ssl/certs/
sudo cp certs/nginx-selfsigned.crt /etc/ssl/private/
sudo cp certs/nginx-selfsigned.key /etc/ssl/private/

# IP address is needed for forming URLs for HTTP file server that is built into BMA
ip_addresses=`hostname -I`
echo "Choose the host IP address for HTTP File Server from {$ip_addresses}"
while [[ $ip1 == "" ]]
do
  read -p "Enter the host IP address: " ip1;
  echo "Confirm IP address = " $ip1;
  read -p "yes/no: " confirm;
  if [[ $confirm == "Yes" ]]; then
    echo $ip1 " selected"
  elif [[ $confirm == "yes" ]]; then
    echo $ip1 " selected"
  else
    ip1=""
  fi
done

sed -i "/^server=/s/=.*/=$ip1/" /usr/local/bma/etc/config.ini

# Set permissions
echo "Setting permissions to files..."
sudo chown -R bma:nginx /usr/local/bma
sudo chown -R root:root /usr/local/bma/utils

echo "Starting the services for the application..."
sudo systemctl daemon-reload
sleep 20
#sudo systemctl restart bma-es
#sleep 20
sudo systemctl restart bma-utils
sudo systemctl restart secure-file-server
sudo systemctl restart nginx