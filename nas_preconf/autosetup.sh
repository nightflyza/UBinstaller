#!/bin/sh

############ CONFIG SECTION #############

#binary packages distro (141_6K, 140_6K, 133_6K, 132_6E available)
DL_NAME="141_6T"

#external internet interface
EXT_IF="igb1"

#internal lan interface
INT_IF="igb0"
INT_IP="172.16.0.2"
INT_NET="172.16.0.0"
INT_NET_CIDR="22"

#ubilling database host settings
MYSQL_HOST="172.16.0.1"
MYSQL_LOGIN="somelogin"
MYSQL_PASSWORD="somepassword"
MYSQL_DB="stg"

#stargazer and SNMP settings
RSCRIPTD_KEY="kotiki"
NETFLOW_HOST="172.16.0.1:42111"
SNMPCOMM="changeme"

#bandwidthd http path
BANDWIDTHD_PATH="band"

#firewall preset script
FIREWALL_PRESET="firewall.conf"


########## end of config section ########

#binary packages repo
DL_REPO="http://ubilling.net.ua/packages/"

DL_EXT=".tar.gz"
#stargazer sources
DL_STG_URL="http://ubilling.net.ua/stg/"
DL_STG_REL="stg-2.409"
DL_STG_EXT=".tar.gz"

#########################################

#botstrapping pkgng
pkg info

#check is FreeBSD installation clean
PKG_COUNT=`/usr/sbin/pkg info | /usr/bin/wc -l`
if [ $PKG_COUNT -ge 2 ]
then
echo "rscriptd NAS installer supports setup only for clean FreeBSD distribution. Installation is aborted."
exit
fi

#setting up binary packages
DL_URL=${DL_REPO}${DL_NAME}${DL_EXT}
fetch ${DL_URL}

#check is binary packages download has beed completed
if [ -f ${DL_NAME}${DL_EXT} ];
then
echo "Binary packages download has been completed."
else
echo "=== Error: binary packages are not available. Installation is aborted. ==="
exit
fi

echo "Unpacking binary packages..."
tar zxvf ${DL_NAME}${DL_EXT}
cd ${DL_NAME}

#installing packages
echo "Installing required software..."
ls -1 | xargs -n 1 pkg add

#installing nginx
pkg install -y nginx

#back to setup dir
cd /tmp/nas_preconf/

#update rc.conf
cat configs/append_rc.conf >> /etc/rc.conf

#update sysctl.conf
cat configs/append_sysctl.conf >> /etc/sysctl.conf

#unpack firewall
cp -R configs/${FIREWALL_PRESET} /etc/firewall.conf
cat configs/fwcustoms >> /etc/firewall.conf
chmod a+x /etc/firewall.conf

#update crontab
cat configs/crontab >> /etc/crontab

#php opts
cat configs/php.ini >> /usr/local/etc/php.ini

#adding needed options to loader conf
cat configs/loader.preconf >> /boot/loader.conf

#FreeBSD 10+ need to use CC and CXX env
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++
#FreeBSD 13.3/14.0 requires specific CXXFLAGS env
export CXXFLAGS=-std=c++11

#rscriptd build and setup 
cd /tmp/nas_preconf/
mkdir stg
cd stg/
echo "Downloading stargazer distro..."
fetch ${DL_STG_URL}${DL_STG_REL}${DL_STG_EXT}
tar zxvf ${DL_STG_REL}${DL_STG_EXT}
cd ${DL_STG_REL}/projects/rscriptd/
echo "Compiling rscriptd..."
./build
gmake install
echo "rscript installed..."

#updating init scritps and rscriptd configs
echo "Installing init scripts..."
cd /tmp/nas_preconf/
cp -R ./configs/rscriptd /etc/
chmod -R a+x /etc/rscriptd
cp -R ./configs/stargazer /etc/
chmod -R a+x /etc/stargazer
chmod -R 777 /etc/stargazer/dn
cp -R ./configs/rc.d /etc/
chmod a+x /etc/rc.d/rscriptd
cp ./configs/bandwidthd.conf /usr/local/bandwidthd/etc/
mkdir /var/stargazer/ 

#installing some helpful scripts
echo "Installing misc scripts..."
cd /tmp/nas_preconf/
cp -R ./apps/checkspeed /bin/
cp -R ./apps/renat /bin/
cp -R ./apps/lactrl.php /usr/local/etc/
chmod a+x /bin/renat /bin/checkspeed /usr/local/etc/lactrl.php



#symlink magic
mkdir /usr/local/www/data
mv /usr/local/bandwidthd/htdocs /usr/local/www/data/${BANDWIDTHD_PATH}
ln -fs /usr/local/www/data/${BANDWIDTHD_PATH}/ /usr/local/bandwidthd/htdocs
cp -R ./configs/nginx.conf  /usr/local/etc/nginx/
chmod a-x /etc/rc.d/sendmail
echo "NO WAY!" > /usr/local/www/data/index.html
touch /var/log/torture.log



############## updating configs ##############
echo "Updating configuration files..."

#snmp 
echo "rocommunity ${SNMPCOMM}" > /usr/local/etc/snmpd.config
echo "smuxsocket  1.0.0.0" >> /usr/local/etc/snmpd.config


#update ub handlers config and rscriptd
perl -e "s/localhost/${MYSQL_HOST}/g" -pi /etc/rscriptd/config
perl -e "s/mylogin/${MYSQL_LOGIN}/g" -pi /etc/rscriptd/config
perl -e "s/newpassword/${MYSQL_PASSWORD}/g" -pi /etc/rscriptd/config
perl -e "s/stg/${MYSQL_DB}/g" -pi /etc/rscriptd/config

perl -e "s/RS_KEY/${RSCRIPTD_KEY}/g" -pi /etc/rscriptd/rscriptd.conf
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /bin/renat

#update firewall
perl -e "s/NF_HOST/${NETFLOW_HOST}/g" -pi /etc/firewall.conf
perl -e "s/INTERNAL_NETWORK/${INT_NET}\/${INT_NET_CIDR}/g" -pi /etc/firewall.conf
perl -e "s/INT_ADDR/${INT_IP}\/${INT_NET_CIDR}/g" -pi /etc/firewall.conf
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /etc/firewall.conf
perl -e "s/INTERNAL_INTERFACE/${INT_IF}/g" -pi /etc/firewall.conf
perl -e "s/DB_HOST/${MYSQL_HOST}/g" -pi /etc/firewall.conf

#update dnswitch
perl -e "s/localhost/${MYSQL_HOST}/g" -pi /etc/stargazer/dnswitch.php
perl -e "s/mylogin/${MYSQL_LOGIN}/g" -pi /etc/stargazer/dnswitch.php
perl -e "s/newpassword/${MYSQL_PASSWORD}/g" -pi /etc/stargazer/dnswitch.php
perl -e "s/stg/${MYSQL_DB}/g" -pi /etc/stargazer/dnswitch.php

#update bandwidthd config
perl -e "s/INTERNAL_INTERFACE/${INT_IF}/g" -pi /usr/local/bandwidthd/etc/bandwidthd.conf
perl -e "s/INTERNAL_NETWORK/${INT_NET}\/${INT_NET_CIDR}/g" -pi /usr/local/bandwidthd/etc/bandwidthd.conf

echo "==== NAS setup complete! ===="
echo "Reboot your server."
