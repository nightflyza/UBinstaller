#!/bin/sh

############ CONFIG SECTION #############


#external internet interface
EXT_IF="igb1"
EXT_IP="1.2.3.5"

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
#supported NAS_93_64 or NAS_103_64 and NAS_110_64 and NAS_111_64
DL_NAME="NAS_111_64"
DL_EXT=".tar.gz"
#stargazer sources
DL_STG_URL="http://ubilling.net.ua/stg/"
DL_STG_REL="stg-2.409-rc2"
DL_STG_EXT=".tar.gz"

#########################################

sh pkgng.installer


#setting up binary packages
DL_URL=${DL_REPO}${DL_NAME}${DL_EXT}
fetch ${DL_URL}
tar zxvf ${DL_NAME}${DL_EXT}
cd ${DL_NAME}
pkg add ./*

#back to setup dir
cd /tmp/nas_preconf/

#update rc.conf
cat rcconf/append_rc.conf >> /etc/rc.conf

#update sysctl.conf
cat rcconf/append_sysctl.conf >> /etc/sysctl.conf

#unpack firewall
cp -R etc/${FIREWALL_PRESET} /etc/firewall.conf
cat fwcustoms >> /etc/firewall.conf
chmod a+x /etc/firewall.conf

#update crontab
cat etc/crontab >> /etc/crontab

#php opts
cat etc/php.ini >> /usr/local/etc/php.ini

#adding needed options to loader conf
cat kern/loader.preconf >> /boot/loader.conf


#setup rscriptd
cd /tmp/nas_preconf/
cd stg/
fetch ${DL_STG_URL}${DL_STG_REL}${DL_STG_EXT}
tar zxvf ${DL_STG_REL}${DL_STG_EXT}
cd ${DL_STG_REL}/projects/rscriptd/
./build
gmake install

#update configs
cd /tmp/nas_preconf/
cp -R ./etc/rscriptd /etc/
chmod -R a+x /etc/rscriptd
cp -R ./etc/stargazer /etc/
chmod -R a+x /etc/stargazer
chmod -R 777 /etc/stargazer/dn
cp -R ./etc/rc.d /etc/
chmod a+x /etc/rc.d/rscriptd
cp ./etc/bandwidthd.conf /usr/local/bandwidthd/etc/
mkdir /var/stargazer/ 

#unpack helpful scripts
cd /tmp/nas_preconf/
cp -R ./bin/checkspeed /bin/
cp -R ./bin/renat /bin/
cp -R ./etc/lactrl.php /usr/local/etc/
chmod a+x /bin/renat /bin/checkspeed /usr/local/etc/lactrl.php



#symlink magic
mkdir /usr/local/www/data
mv /usr/local/bandwidthd/htdocs /usr/local/www/data/${BANDWIDTHD_PATH}
ln -fs /usr/local/www/data/${BANDWIDTHD_PATH}/ /usr/local/bandwidthd/htdocs
cp -R ./etc/nginx.conf  /usr/local/etc/nginx/
chmod a-x /etc/rc.d/sendmail
echo "NO WAY!" > /usr/local/www/data/index.html



############## updating configs ##############

#snmp 
echo "rocommunity ${SNMPCOMM}" > /usr/local/etc/snmpd.config
echo "smuxsocket  1.0.0.0" >> /usr/local/etc/snmpd.config


#update ub handlers config and rscriptd
perl -e "s/DB_HOST/${MYSQL_HOST}/g" -pi /etc/rscriptd/config
perl -e "s/DB_LOGIN/${MYSQL_LOGIN}/g" -pi /etc/rscriptd/config
perl -e "s/DB_PASS/${MYSQL_PASSWORD}/g" -pi /etc/rscriptd/config
perl -e "s/DB_DB/${MYSQL_DB}/g" -pi /etc/rscriptd/config
perl -e "s/RS_KEY/${RSCRIPTD_KEY}/g" -pi /etc/rscriptd/rscriptd.conf
perl -e "s/RS_KEY/${RSCRIPTD_KEY}/g" -pi /etc/stargazer/rscriptd.conf
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /bin/renat

#update firewall
perl -e "s/NF_HOST/${NETFLOW_HOST}/g" -pi /etc/firewall.conf
perl -e "s/INTERNAL_NETWORK/${INT_NET}\/${INT_NET_CIDR}/g" -pi /etc/firewall.conf
perl -e "s/EXTERNAL_IP/${EXT_IP}/g" -pi /etc/firewall.conf
perl -e "s/INT_ADDR//${INT_IP}\/${INT_NET_CIDR}/g" -pi /etc/firewall.conf
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /etc/firewall.conf
perl -e "s/INTERNAL_INTERFACE/${INT_IF}/g" -pi /etc/firewall.conf
perl -e "s/DB_HOST/${MYSQL_HOST}/g" -pi /etc/firewall.conf

#update dnswitch
perl -e "s/DB_HOST/${MYSQL_HOST}/g" -pi /etc/stargazer/dnswitch.php
perl -e "s/DB_LOGIN/${MYSQL_LOGIN}/g" -pi /etc/stargazer/dnswitch.php
perl -e "s/DB_PASS/${MYSQL_PASSWORD}/g" -pi /etc/stargazer/dnswitch.php
perl -e "s/DB_DB/${MYSQL_DB}/g" -pi /etc/stargazer/dnswitch.php
perl -e "s/INTERNAL_INTERFACE/${INT_IF}/g" -pi /etc/stargazer/dnswitch.php

#update bandwidthd config
perl -e "s/INTERNAL_INTERFACE/${INT_IF}/g" -pi /usr/local/bandwidthd/etc/bandwidthd.conf
perl -e "s/INTERNAL_NETWORK/${INT_NET}\/${INT_NET_CIDR}/g" -pi /usr/local/bandwidthd/etc/bandwidthd.conf

echo "==== NAS setup complete ===="
