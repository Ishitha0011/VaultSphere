#!/bin/bash

#### PREREQUISITES ##########

# Linux pre-requisites
pre_requisites=("gcc" "openssl" "python3" "python3-devel" "genisoimage" "kpartx" "nginx" "unzip")

yumcmd="sudo yum install -y"

# shellcheck disable=SC2068
for var in ${pre_requisites[@]}
do
    if ! rpm --quiet --query $var; then
        yumcmd="$yumcmd $var"
    fi
done

echo "ABOUT TO EXECUTE: $yumcmd"

#eval $yumcmd

#sudo python3 -m pip install --upgrade pip
#sudo python3 -m pip install -r requirements.txt
#### END PREREQUISITES ##########


# Create a system user for this app
# And add bma to nginx user group
# Make /var/lib as root dir
sudo useradd -r -m -b /var/lib bma -G root,nginx
sudo chown -R bma:nginx /var/lib/bma

# Below lines can be deleted!
#sudo usermod -a bma -G nginx
#sudo usermod -a bma -G root

sudo cp service/bma-server.service /etc/systemd/system/
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
sudo cp swagger/dist/* /usr/share/nginx/html/apidocs/
sudo chown -R bma:nginx /usr/share/nginx/html/apidocs
sudo chmod -R 755 /usr/share/nginx/html/apidocs

# TODO Review the following SSL params
sudo cp nginx/ssl.conf /etc/nginx/conf.d/ssl.conf
sudo cp nginx/ssl-redirect.conf /etc/nginx/default.d/

sudo mkdir -p /usr/local/bma/bin
sudo mkdir -p /usr/local/bma/utils
sudo mkdir -p /usr/local/bma/conf
sudo mkdir -p /usr/local/bma/logs

mkdir -p build/bma-utils/
cp -f src/bma-utils/*.py build/bma-utils/
#/usr/local/bin/sourcedefender encrypt docker/bma-utils/*.py
sudo cp -f build/bma-utils/*.py /usr/local/bma/utils/
sudo cp -f build/bma-utils/service.py /usr/local/bma/utils/

mkdir -p build/bma-server/
cp -f src/bma-server/*.py build/bma-server/
#/usr/local/bin/sourcedefender encrypt docker/secure-file-server/*.py
sudo cp -f build/bma-server/*.py /usr/local/bma/bin/
sudo cp -f build/bma-server/wsgi.py /usr/local/bma/bin/
sudo cp -rf etc/bma.ini /usr/local/bma/bin/

#sudo cp -R kickstarts /usr/local/bma/
sudo cp -R scripts /usr/local/bma/
#sudo cp -R etc /usr/local/bma/
sudo chown -R bma:nginx /usr/local/bma
sudo chown -R root:root /usr/local/bma/utils

# Allow NGINX to access uwsgi socket file by setting httpd_t permissive
# Note that this command permanently sets httpd_t type SELinux context to permissive.
# Be aware of potential security holes.

# When semanage command fails, run this command to fix: # sudo dnf reinstall platform-python-setuptools
#sudo semanage permissive -a httpd_t
sudo setsebool -P httpd_can_network_relay 1

#sudo cp certs/dhparam.pem /etc/ssl/certs/
#sudo cp certs/nginx-selfsigned.crt /etc/ssl/private/
#sudo cp certs/nginx-selfsigned.key /etc/ssl/private/

sudo systemctl daemon-reload
#sudo systemctl restart bma-es
sleep 20
sudo systemctl restart bma-utils
sudo systemctl restart bma-server
sudo systemctl restart nginx
