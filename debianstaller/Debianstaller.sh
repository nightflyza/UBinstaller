#!/usr/bin/bash

#some predefined paths and URLs here
DIALOG="dialog"
FETCH="/usr/bin/wget"

TARGET_SYSTEM="Debian 13 Trixie"

APACHE_VERSION="apache24"
APACHE_DATA_PATH="/var/www/html/"
APACHE_CONFIG_DIR="/etc/apache2/"
APACHE_INIT_SCRIPT="/usr/sbin/service apache2"
APACHE_CONFIG_PRESET_NAME="apache2.conf"
APACHE_CONFIG_NAME="apache2.conf"
PHP_CONFIG_PRESET="php8.ini"
PHP_CONFIG_DIR="/etc/php/8.4/apache2/"

#some remote paths here
DL_PACKAGES_URL="http://ubilling.net.ua/packages/"
DL_PACKAGES_EXT=".tar.gz"
DL_UB_URL="http://ubilling.net.ua/"
DL_UB_NAME="ub.tgz"
DL_STG_URL="http://ubilling.net.ua/stg/"
DL_STG_NAME="stg-2.409-rc5.tar.gz"
DL_STG_RELEASE="stg-2.409-rc5"


#initial repos update
echo "Preparing to installation.."
apt update >> /var/log/debianstaller.log  2>&1
apt -y upgrade >> /var/log/debianstaller.log  2>&1

#installation of basic software required for installer
echo "Installing basic software required for Debianstaller.."
apt install -y dialog >> /var/log/debianstaller.log  2>&1
apt install -y net-tools >> /var/log/debianstaller.log  2>&1
apt install -y gnupg2 >> /var/log/debianstaller.log  2>&1


clear
$DIALOG --title "Ubilling installation" --msgbox "This wizard helps you to install Stargazer and Ubilling to your server with ${TARGET_SYSTEM}. This installer is experimental(!) and not recommended for real usage at this moment." 10 50
clear

#new or migration installation
clear
$DIALOG --menu "Type of Ubilling installation" 10 75 8 \
                   NEW "This is new Ubilling installation"\
                   MIG "Migrating existing Ubilling setup from another server"\
            2> /tmp/insttype

clear

#configuring stargazer release
clear
$DIALOG --menu "Choose Stargazer release" 16 50 8 \
				   409REL "Stargazer 2.409-release (stable)"\
                   409RC5 "Stargazer 2.409-rc5 (legacy)"\
                   409RC2 "Stargazer 2.409-rc2 (legacy)"\
            2> /tmp/stgver
clear

#configuring LAN interface
ALL_IFACES=`basename -a /sys/class/net/* | grep -v lo | tr "\n" " "`

INTIF_DIALOG_START="$DIALOG --menu \"Select LAN interface that interracts with your INTERNAL network\" 15 85 6 \\"
INTIF_DIALOG="${INTIF_DIALOG_START}"

for EACH_IFACE in $ALL_IFACES
do
   	LIIFACE_IP=`ifconfig ${EACH_IFACE} | grep "inet " | xargs`
  	INTIF_DIALOG="${INTIF_DIALOG}${EACH_IFACE} \\ \"${LIIFACE_IP}\" "
done

INTIF_DIALOG="${INTIF_DIALOG} 2> /tmp/ubiface"

sh -c "${INTIF_DIALOG}"
clear 


#configuring internal network
TMP_LAN_IFACE=`cat /tmp/ubiface`
TMP_NET_DATA=`netstat -rn -f inet | grep -v UG | grep ${TMP_LAN_IFACE}`
TMP_LAN_NETW=`echo ${TMP_NET_DATA} | cut -f 1 -d " "`
TMP_LAN_CIDR=`ip address show dev ${TMP_LAN_IFACE} | grep "inet " | cut -f 2 -d "/" | cut -f 1 -d " " | xargs`
echo ${TMP_LAN_NETW} > /tmp/ubnetw
echo ${TMP_LAN_CIDR} > /tmp/ubcidr

#NAT etc presets setup
clear
$DIALOG --title "Setup NAS"   --yesno "Do you want to install firewall/nat/shaper presets for setup all-in-one Billing+NAS server" 10 40
NAS_KERNEL=$?
clear

case $NAS_KERNEL in
0)
#NAS kernel setup with preconfigured firewall
#configuring WAN interface
ALL_IFACES=`basename -a /sys/class/net/* | grep -v lo | tr "\n" " "`

EXTIF_DIALOG_START="$DIALOG --menu \"Select WAN interface for NAT that interracts with Internet\" 15 85 6 \\"
EXTIF_DIALOG="${EXTIF_DIALOG_START}"

for EACH_IFACE in $ALL_IFACES
do
   LIIFACE_IP=`ifconfig ${EACH_IFACE} | grep "inet " | xargs`
   EXTIF_DIALOG="${EXTIF_DIALOG}${EACH_IFACE} \\ \"${LIIFACE_IP}\" "
done

EXTIF_DIALOG="${EXTIF_DIALOG} 2> /tmp/ubextif"

sh -c "${EXTIF_DIALOG}"
clear 
EXT_IF=`cat /tmp/ubextif`
;;

1)
EXT_IF="none"
;;
esac

#some passwords generation or manual input
PASSW_MODE=`cat /tmp/insttype`

case $PASSW_MODE in
NEW)
#generating mysql password
GEN_MYS_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
echo "mys"${GEN_MYS_PASS} > /tmp/ubmypass

#getting stargazer admin password
GEN_STG_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
echo "stg"${GEN_STG_PASS} > /tmp/ubstgpass

#getting rscriptd encryption password
GEN_RSD_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
echo "rsd"${GEN_RSD_PASS} > /tmp/ubrsd

;;
MIG)
request previous MySQL/Stargazer/rscriptd passwords
clear
$DIALOG --title "MySQL root password"  --inputbox "Enter your previous installation MySQL root password" 8 60 2> /tmp/ubmypass
clear
$DIALOG --title "Stargazer password"  --inputbox "Enter your previous installation Stargazer password" 8 60 2> /tmp/ubstgpass
clear
$DIALOG --title "rscriptd password"  --inputbox "Enter your previous installation rscriptd password" 8 60 2> /tmp/ubrsd
clear
$DIALOG --title "Ubilling serial"  --inputbox "Enter your previous installation Ubilling serial number" 8 60 2> /tmp/ubsrl
;;
esac



LAN_IFACE=`cat /tmp/ubiface`
MYSQL_PASSWD=`cat /tmp/ubmypass`
LAN_NETW=`cat /tmp/ubnetw`
LAN_CIDR=`cat /tmp/ubcidr`
STG_PASS=`cat /tmp/ubstgpass`
RSD_PASS=`cat /tmp/ubrsd`
ARCH=`hostnamectl | grep System | xargs`
STG_VER=`cat /tmp/stgver`

case $PASSW_MODE in
NEW)
UBSERIAL="auto"
;;
MIG)
UBSERIAL=`cat /tmp/ubsrl`
;;
esac

# cleaning temp files
rm -fr /tmp/ubiface
rm -fr /tmp/ubmypass
rm -fr /tmp/ubnetw
rm -fr /tmp/ubcidr
rm -fr /tmp/ubstgpass
rm -fr /tmp/ubrsd
rm -fr /tmp/ubextif
rm -fr /tmp/stgver
rm -fr /tmp/insttype
rm -fr /tmp/ubsrl

#last chance to exit
$DIALOG --title "Check settings"   --yesno "Are all of these settings correct? \n \n LAN interface: ${LAN_IFACE} \n LAN network: ${LAN_NETW}/${LAN_CIDR} \n WAN interface: ${EXT_IF} \n MySQL password: ${MYSQL_PASSWD} \n Stargazer password: ${STG_PASS} \n Rscripd password: ${RSD_PASS} \n System: ${ARCH} \n Stargazer: ${STG_VER}\n Ubilling serial: ${UBSERIAL}\n" 18 70
AGREE=$?
clear

case $AGREE in
0)
$DIALOG --infobox "Everything is okay! Installation is starting..." 4 60
mkdir /usr/local/ubinstaller/
cp -R ./* /usr/local/ubinstaller/
cd /usr/local/ubinstaller/

#Selecting stargazer release to install
case $STG_VER in
409RC5)
DL_STG_NAME="stg-2.409-rc5.tar.gz"
DL_STG_RELEASE="stg-2.409-rc5"
;;

409RC2)
DL_STG_NAME="stg-2.409-rc2.tar.gz"
DL_STG_RELEASE="stg-2.409-rc2"
;;

409REL)
DL_STG_NAME="stg-2.409.tar.gz"
DL_STG_RELEASE="stg-2.409"
;;
esac


# install binary packages from repos
$DIALOG --infobox "Software installation is in progress. This takes a while." 4 70

#MariaDB setup
apt install -y software-properties-common dirmngr >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing MariaDB" 4 60
$DIALOG --infobox "Installing MariaDB..." 4 60
apt install -y mariadb-server >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing MariaDB...." 4 60
apt install -y mariadb-client >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing MariaDB....." 4 60
apt install -y libmariadb-dev >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing MariaDB......" 4 60
apt install -y default-libmysqlclient-dev >> /var/log/debianstaller.log  2>&1

$DIALOG --infobox "MariaDB installed" 4 60
mariadb --version >> /var/log/debianstaller.log  2>&1

systemctl start mariadb  >> /var/log/debianstaller.log  2>&1
systemctl enable mariadb  >> /var/log/debianstaller.log  2>&1

$DIALOG --infobox "MariaDB startup enabled" 4 60

$DIALOG --infobox "Installing some required software" 4 60
apt install -y expat >> /var/log/debianstaller.log  2>&1
apt install -y libexpat1-dev >> /var/log/debianstaller.log  2>&1
apt install -y sudo >> /var/log/debianstaller.log  2>&1
apt install -y curl >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing Apache server" 4 60
apt install -y apache2 >> /var/log/debianstaller.log  2>&1
apt install -y libapache2-mod-php8.4 >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing DHCP server" 4 60
apt install -y isc-dhcp-server >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing misc software" 4 60
apt install -y build-essential >> /var/log/debianstaller.log  2>&1
apt install -y bind9 >> /var/log/debianstaller.log  2>&1
DEBIAN_FRONTEND=noninteractive apt install -y bandwidthd >> /var/log/debianstaller.log  2>&1
DEBIAN_FRONTEND=noninteractive apt install -y softflowd >> /var/log/debianstaller.log  2>&1
apt install -y libxmlrpc-c++8-dev >> /var/log/debianstaller.log  2>&1
apt install -y ipset >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing memory caching servers" 4 60
apt install -y memcached >> /var/log/debianstaller.log  2>&1
apt install -y redis >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing PHP and required extensions" 4 60
apt install -y php8.4-cli >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-mysql >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-mysqli >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-mbstring >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-bcmath >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-curl >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-gd >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-snmp >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-soap >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-zip >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-imap >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-tokenizer >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-xml >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-xmlreader >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-xmlwriter >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-simplexml >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-sqlite3 >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-sockets >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-opcache >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-json >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-pdo >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-pdo-sqlite >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-phar >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-posix >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-memcached >> /var/log/debianstaller.log  2>&1
apt install -y php8.4-redis >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Installing some optional software" 4 60
apt install -y graphviz >> /var/log/debianstaller.log  2>&1
apt install -y vim-tiny >> /var/log/debianstaller.log  2>&1
apt install -y arping >> /var/log/debianstaller.log  2>&1
apt install -y elinks >> /var/log/debianstaller.log  2>&1
apt install -y mc >> /var/log/debianstaller.log  2>&1
apt install -y nano >> /var/log/debianstaller.log  2>&1
apt install -y nmap >> /var/log/debianstaller.log  2>&1
apt install -y mtr >> /var/log/debianstaller.log  2>&1
apt install -y expect >> /var/log/debianstaller.log  2>&1
apt install -y bwm-ng >> /var/log/debianstaller.log  2>&1
apt install -y ifstat >> /var/log/debianstaller.log  2>&1
apt install -y arpwatch >> /var/log/debianstaller.log  2>&1
apt install -y git >> /var/log/debianstaller.log  2>&1
apt install -y ffmpeg >> /var/log/debianstaller.log  2>&1
apt install -y bmon >> /var/log/debianstaller.log  2>&1
apt install -y iftop >> /var/log/debianstaller.log  2>&1
apt install -y netdiag >> /var/log/debianstaller.log  2>&1
apt install -y htop >> /var/log/debianstaller.log  2>&1
apt install -y rsyslog >> /var/log/debianstaller.log  2>&1

$DIALOG --infobox "Installing FreeRADIUS server" 4 60
apt install -y freeradius freeradius-mysql >> /var/log/debianstaller.log  2>&1


#back to installation directory
cd /usr/local/ubinstaller/

#installing stargazer
$DIALOG --infobox "Stargazer download is in progress." 4 60
$FETCH ${DL_STG_URL}${DL_STG_NAME} >> /var/log/debianstaller.log  2>&1
if [ -f ${DL_STG_NAME} ];
then
$DIALOG --infobox "Stargazer distro download has been completed." 4 60
else
echo "=== Error: stargazer sources are not available. Installation is aborted. ==="
exit
fi
$DIALOG --infobox "Compiling Stargazer." 4 60
tar zxvf ${DL_STG_NAME} >> /var/log/debianstaller.log  2>&1
cd ${DL_STG_RELEASE}/projects/stargazer/ 
./build >> /var/log/debianstaller.log  2>&1
/usr/bin/gmake install >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Compiling Stargazer..." 4 60
#and configurators
cd ../sgconf 
./build >> /var/log/debianstaller.log  2>&1
/usr/bin/gmake >> /var/log/debianstaller.log  2>&1
/usr/bin/gmake install >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Compiling Stargazer...." 4 60
cd ../sgconf_xml/ 
./build >> /var/log/debianstaller.log  2>&1
/usr/bin/gmake >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Compiling Stargazer....." 4 60
/usr/bin/gmake install >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Stargazer installed." 4 60

#stopping apache
${APACHE_INIT_SCRIPT} stop

# copying prepared configs
cd /usr/local/ubinstaller/configs/
cp -R ${APACHE_CONFIG_PRESET_NAME} ${APACHE_CONFIG_DIR}${APACHE_CONFIG_NAME}
cp -R ${PHP_CONFIG_PRESET} ${PHP_CONFIG_DIR}php.ini
cp -R stargazer.conf /etc/stargazer/
cp -R bandwidthd.conf /etc/bandwidthd/bandwidthd.conf
perl -e "s/em0/${LAN_IFACE}/g" -pi /etc/bandwidthd/bandwidthd.conf
perl -e "s/NETW/${LAN_NETW}\/${LAN_CIDR}/g" -pi /etc/bandwidthd/bandwidthd.conf

cp -R sudoers_preset /etc/sudoers.d/ubilling

#setting up default web awesomeness
cp -R inside.html ${APACHE_DATA_PATH}/index.html

#fixing maria issues
service mariadb stop
cp -R 50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
service mariadb start


#starting apache with new configs
${APACHE_INIT_SCRIPT} start

#Setting MySQL root password
mysqladmin -u root password ${MYSQL_PASSWD}

######################
# unpacking Ubilling
######################
$DIALOG --infobox "Ubilling download, unpacking and installation is in progress." 4 60
cd /usr/local/ubinstaller/
$FETCH ${DL_UB_URL}${DL_UB_NAME} >> /var/log/debianstaller.log  2>&1
#check is ubilling distro download complete
if [ -f ${DL_UB_NAME} ];
then
$DIALOG --infobox "Ubilling download has been completed." 4 60
else
echo "=== Error: Ubilling release is not available. Installation is aborted. ==="
exit
fi

mkdir ${APACHE_DATA_PATH}billing/
cp ${DL_UB_NAME} ${APACHE_DATA_PATH}billing/
cd ${APACHE_DATA_PATH}billing/
tar zxvf ${DL_UB_NAME} >> /var/log/debianstaller.log  2>&1
chmod -R 777 content/ config/ multinet/ exports/ remote_nas.conf 
chmod -R 777 userstats/config/

# updating passwords and login in mysql.ini
perl -e "s/mylogin/root/g" -pi ./config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./config/mysql.ini
#userstats
perl -e "s/mylogin/root/g" -pi ./userstats/config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./userstats/config/mysql.ini
#alter
perl -e "s/rl0/${LAN_IFACE}/g" -pi ./config/alter.ini

# and in stargazer.conf
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi /etc/stargazer/stargazer.conf
# change rscriptd password
perl -e "s/secretpassword/${RSD_PASS}/g" -pi /etc/stargazer/stargazer.conf
# change default Mikrotik presets password
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./docs/presets/MikroTik/config.ini
# OpenPayz may be?
perl -e "s/mylogin/root/g" -pi ./docs/openpayz/config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./docs/openpayz/config/mysql.ini

#fixing paths to linux specific
perl -e "s/\/usr\/local\/bin\/sudo/\/usr\/bin\/sudo/g" -pi ./config/billing.ini
perl -e "s/\/usr\/bin\/top -b/\/usr\/bin\/top -b -n1/g" -pi ./config/billing.ini
perl -e "s/\/usr\/local\/etc\/rc.d\/isc-dhcpd/\/etc\/init.d\/isc-dhcp-server/g" -pi ./config/billing.ini
perl -e "s/\/sbin\/ping/\/usr\/bin\/ping/g" -pi ./config/billing.ini
perl -e "s/\/usr\/local\/bin\/wget/\/usr\/bin\/wget/g" -pi ./config/billing.ini
perl -e "s/\/usr\/local\/bin\/expect/\/usr\/bin\/expect/g" -pi ./config/billing.ini

perl -e "s/\/usr\/local\/bin\/mysqldump/\/usr\/bin\/mysqldump/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/mysql/\/usr\/bin\/mysql/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/snmpset/\/usr\/bin\/snmpset/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/snmpwalk/\/usr\/bin\/snmpwalk/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/nmap/\/usr\/bin\/nmap/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/bin\/radclient/\/usr\/bin\/radclient/g" -pi ./config/alter.ini
perl -e "s/\/usr\/local\/sbin\/arping/\/usr\/sbin\/arping/g" -pi ./config/alter.ini
perl -e "s/-c 10 -w 20000/-c 10 -W 0.1/g" -pi ./config/alter.ini

#fixing apache rights
chmod -R 777 /var/log/apache2

#creating stargazer database
$DIALOG --infobox "Creating initial Stargazer DB" 4 60
cat docs/dumps/stargazer.sql | /usr/bin/mysql -u root --password=${MYSQL_PASSWD} >> /var/log/debianstaller.log  2>&1

# starting stargazer 
$DIALOG --infobox "Starting Stargazer" 4 60
/usr/sbin/stargazer
sleep 3

#changing default password
/usr/sbin/sgconf_xml -s localhost -p 5555 -a admin -w 123456 -r " <ChgAdmin Login=\"admin\" password=\"${STG_PASS}\" /> " >> /var/log/debianstaller.log  2>&1
$DIALOG --infobox "Stargazer default password changed." 4 60
#stopping stargazer
$DIALOG --infobox "Stopping Stargazer." 4 60
killall stargazer
sleep 10


# restoring default Ubilling SQL dump
$DIALOG --infobox "Restoring Ubilling database" 4 60
cat docs/dumps/ubilling.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD} >> /var/log/debianstaller.log  2>&1

$DIALOG --infobox "Installing OpenPayz database preset" 4 60
cat docs/dumps/openpayz.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD} >> /var/log/debianstaller.log  2>&1

# apply hotfix for stargazer 2.408 and change passwords in configs
cat /usr/local/ubinstaller/configs/admin_rights_hotfix.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
perl -e "s/123456/${STG_PASS}/g" -pi ./config/billing.ini
perl -e "s/123456/${STG_PASS}/g" -pi ./userstats/config/userstats.ini
perl -e "s/123456/${STG_PASS}/g" -pi ./docs/openpayz/config/openpayz.ini

#preconfiguring dhcpd logging
cat /usr/local/ubinstaller/configs/rsyslog.preconf >> /etc/rsyslog.conf
perl -e "s/NMLEASES = \/var\/log\/messages/NMLEASES = \/var\/log\/dhcpd.log/g" -pi ./config/alter.ini
$DIALOG --infobox "dhcpd logging configured." 4 60

#first install flag setup for the future
touch ./exports/FIRST_INSTALL
chmod 777 ./exports/FIRST_INSTALL


# unpacking ubapi preset
cp -R /usr/local/ubinstaller/configs/ubapi /bin/
chmod a+x /bin/ubapi
$DIALOG --infobox "remote API wrapper installed" 4 60


#starting stargazer
$DIALOG --infobox "Starting stargazer" 4 60
/usr/sbin/stargazer
sleep 3

#initial crontab configuration
cd ${APACHE_DATA_PATH}billing
if [ -f ./docs/crontab/crontab.preconf ];
then

#generating new Ubilling serial or using predefined
case $PASSW_MODE in
NEW)
#generating new Ubilling serial
/usr/bin/curl -o /dev/null "http://127.0.0.1/billing/?module=remoteapi&action=identify&param=save" >> /var/log/debianstaller.log  2>&1
#waiting saving data
sleep 2
NEW_UBSERIAL=`cat ./exports/ubserial`
$DIALOG --infobox "New Ubilling serial generated: ${NEW_UBSERIAL}" 4 60
;;
MIG)
NEW_UBSERIAL=${UBSERIAL}
$DIALOG --infobox "Using Ubilling serial: ${NEW_UBSERIAL}" 4 60
;;
esac


if [ -n "$NEW_UBSERIAL" ];
then
echo "OK: new Ubilling serial ${NEW_UBSERIAL}" >> /var/log/debianstaller.log  2>&1
else
$DIALOG --infobox "New Ubilling serial generated: ${NEW_UBSERIAL}" 4 60
echo "Installation failed and aborted. Empty Ubilling serial. Retry your attempt."
echo "FATAL: empty new Ubilling serial" >> /var/log/debianstaller.log  2>&1
exit
fi

crontab ./docs/crontab/crontab.preconf
$DIALOG --infobox "Installing default crontab preset" 4 60
#updating serial in ubapi wrapper
perl -e "s/UB000000000000000000000000000000000/${NEW_UBSERIAL}/g" -pi /bin/ubapi
$DIALOG --infobox "New serial installed into ubapi wrapper" 4 60
else
echo "Looks like this Ubilling release is not supporting automatic crontab configuration"
fi

#installing default htaccess file with compression and client-side cachig optimizations
cd ${APACHE_DATA_PATH}billing
if [ -f ./docs/webspeed/speed_hta ];
then
cp -R ./docs/webspeed/speed_hta ${APACHE_DATA_PATH}billing/.htaccess
else
echo "Looks like this Ubilling release does not containing default htaccess preset"
fi

#Multigen/FreeRADIUS3 preconfiguration
cd ${APACHE_DATA_PATH}billing
cp -R ./docs/multigen/raddb3/* /etc/freeradius/3.0/
cp -R ./docs/multigen/debian/radiusd.conf /etc/freeradius/3.0/radiusd.conf
RADVER=`freeradius -v | grep "radiusd: FreeRADIUS Version" | awk '{print $4}' | tr -d ,`
$DIALOG --infobox "Configuring FreeRADIUS ${RADVER} and MultiGen" 4 70
perl -e "s/\/usr\/local\/share\/freeradius\/dictionary/\/usr\/share\/freeradius\/dictionary/g" -pi /etc/freeradius/3.0/dictionary
perl -e "s/\/usr\/local\/etc\/raddb\/dictionary_preset/\/etc\/freeradius\/3.0\/dictionary_preset/g" -pi /etc/freeradius/3.0/dictionary
cat ./docs/multigen/dump.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
cat ./docs/multigen/radius3_fix.sql | /usr/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
perl -e "s/yourmysqlpassword/${MYSQL_PASSWD}/g" -pi /etc/freeradius/3.0/sql.conf

#sphinxsearch preconf
$DIALOG --infobox "Installing Sphinx search service" 4 60
cd /opt
wget http://sphinxsearch.com/files/sphinx-3.4.1-efbcc65-linux-amd64.tar.gz >> /var/log/debianstaller.log  2>&1
tar zxvf sphinx-3.4.1-efbcc65-linux-amd64.tar.gz >> /var/log/debianstaller.log  2>&1
mv sphinx-3.4.1 sphinx
cd sphinx
mkdir -p sphinxdata/logs
touch sphinxdata/logs/searchd.log
cp -R ${APACHE_DATA_PATH}billing/docs/sphinxsearch/sphinx3.conf /opt/sphinx/etc/sphinx.conf
perl -e "s/rootpassword/${MYSQL_PASSWD}/g" -pi /opt/sphinx/etc/sphinx.conf
/opt/sphinx/bin/indexer --config /opt/sphinx/etc/sphinx.conf --all >> /var/log/debianstaller.log  2>&1
/opt/sphinx/bin/searchd --config /opt/sphinx/etc/sphinx.conf >> /var/log/debianstaller.log  2>&1
cp -R /usr/local/ubinstaller/configs/searchd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable searchd.service >> /var/log/debianstaller.log  2>&1


#stopping stargazer
$DIALOG --infobox "Stopping stargazer" 4 60
killall stargazer
sleep 10

#installing systemd stargazer startup part
cp -R /usr/local/ubinstaller/configs/stargazer.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable stargazer.service >> /var/log/debianstaller.log  2>&1

#all-in-one box presets if required
case $NAS_KERNEL in
0)
$DIALOG --infobox "Installing NAS presets" 4 60
cd /usr/local/ubinstaller/
cat configs/sysctl.preconf >> /etc/sysctl.conf
cp -R configs/furrywall /etc/
chmod a+x /etc/furrywall
perl -e "s/INTERNAL_INTERFACE/${LAN_IFACE}/g" -pi /etc/furrywall
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /etc/furrywall
perl -e "s/INTERNAL_NETWORK/${LAN_NETW}/g" -pi /etc/furrywall
perl -e "s/INTERNAL_CIDR/${LAN_CIDR}/g" -pi /etc/furrywall
cp -R configs/furrywall.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable furrywall.service >> /var/log/debianstaller.log  2>&1
cp -R configs/softflowd.preconf /etc/softflowd/default.conf
perl -e "s/INTERNAL_INTERFACE/${LAN_IFACE}/g" -pi /etc/softflowd/default.conf

#stargazer user init scripts preset
cd ${APACHE_DATA_PATH}billing/
cp -f docs/presets/Debian/etc/stargazer/* /etc/stargazer/
chmod a+x /etc/stargazer/*
perl -e "s/mylogin/root/g" -pi /etc/stargazer/config
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi /etc/stargazer/config
perl -e "s/INTERNAL_INTERFACE/${LAN_IFACE}/g" -pi /etc/stargazer/OnConnect
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /etc/stargazer/OnConnect
perl -e "s/INTERNAL_INTERFACE/${LAN_IFACE}/g" -pi /etc/stargazer/OnDisconnect
perl -e "s/EXTERNAL_INTERFACE/${EXT_IF}/g" -pi /etc/stargazer/OnDisconnect

#bandwidthd service setup
systemctl enable bandwidthd.service >> /var/log/debianstaller.log  2>&1

;;
1)
$DIALOG --infobox "No NAS presets required" 4 60
;;
esac


#some magic
mkdir /etc/stargazer/dn
chmod -R 777 /etc/stargazer/dn
mkdir ${APACHE_DATA_PATH}billing/content/dn
chmod 777 ${APACHE_DATA_PATH}billing/content/dn
cp -R /usr/local/ubinstaller/configs/dhcp_preset /etc/default/isc-dhcp-server
perl -e "s/LAN_IFACE/${LAN_IFACE}/g" -pi /etc/default/isc-dhcp-server
ln -fs /var/www/html/billing/multinet /usr/local/etc/multinet
ln -fs /var/lib/bandwidthd/htdocs/ /var/www/html/band
ln -fs ${APACHE_DATA_PATH}billing/remote_nas.conf /etc/stargazer/remote_nas.conf

#disabling apparmor
systemctl stop apparmor >> /var/log/debianstaller.log  2>&1
systemctl disable apparmor >> /var/log/debianstaller.log  2>&1

# Setting up autoupdate script
if [ -f ./docs/presets/Debian/ubautoupgrade.sh ];
then
cp -R ./docs/presets/Debian/ubautoupgrade.sh /bin/
chmod a+x /bin/ubautoupgrade.sh
else
echo "Looks like this Ubilling release does not containing automatic upgrade preset"
fi


$DIALOG --title "Ubilling installation has been completed" --msgbox "Now you can access your web-interface by address http://server_ip/billing/ with login and password: admin/demo. Please reboot your server to check correct startup of all services" 15 50

############################## END OF CONFIRMED SETUP #####################
;;
1)
echo "Installation has been aborted"
exit
;;
esac
