#!/bin/sh

# 
# Per aspera ad astra
# 

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: UBinstaller script must be run only as root user."
    exit 1
fi

DIALOG=${DIALOG=dialog}
FETCH="/usr/bin/fetch"
APACHE_VERSION="apache24"
APACHE_DATA_PATH="/usr/local/www/apache24/data/"
APACHE_CONFIG_DIR="/usr/local/etc/apache24/"
APACHE_INIT_SCRIPT="/usr/local/etc/rc.d/apache24"
APACHE_CONFIG_PRESET_NAME="httpd24f8.conf"
APACHE_CONFIG_NAME="httpd.conf"
PHP_CONFIG_PRESET="php8.ini"

#some remote paths here
DL_PACKAGES_URL="http://ubilling.net.ua/packages/"
DL_PACKAGES_EXT=".tar.gz"
DL_UB_URL="http://ubilling.net.ua/"
DL_UB_NAME="ub.tgz"
DL_STG_URL="http://ubilling.net.ua/stg/"
DL_STG_NAME="stg-2.409.tar.gz"
DL_STG_RELEASE="stg-2.409"

set PATH=/usr/local/bin:/usr/local/sbin:$PATH

# config interface section 
clear
$DIALOG --title "Ubilling installation" --msgbox "This wizard helps you to install Stargazer and Ubilling of the latest stable versions to CLEAN (!) FreeBSD distribution" 10 50
clear

#new or migration installation
clear
$DIALOG --menu "Type of Ubilling installation" 10 75 8 \
                   NEW "This is new Ubilling installation"\
                   MIG "Migrating existing Ubilling setup from another server"\
            2> /tmp/insttype

clear

#chosing FreeBSD version and architecture
$DIALOG --menu "Choose FreeBSD version and architecture" 16 50 8 \
       143_6L "FreeBSD 14.3 amd64"\
       142_6L "FreeBSD 14.2 amd64"\
       135_6L "FreeBSD 13.5 amd64"\
 	    2> /tmp/ubarch
clear

#configuring stargazer release
clear
$DIALOG --menu "Choose Stargazer release" 16 50 8 \
				   409REL "Stargazer 2.409-release (stable)"\
                   409RC5 "Stargazer 2.409-rc5 (legacy)"\
                   409RC2 "Stargazer 2.409-rc2 (legacy)"\
            2> /tmp/stgver
clear

#selecting Ubilling installation channel
clear
$DIALOG --menu "Choose Ubilling installation channel" 11 54 4 \
				       STABLE "Latest stable release (recommended)"\
                   CURRENT "Nightly build (current development)"\
            2> /tmp/ubchannel
clear

#configuring LAN interface
ALL_IFACES=`grep rnet /var/run/dmesg.boot | cut -f 1 -d ":" | tr "\n" " "`

INTIF_DIALOG_START="$DIALOG --menu \"Select LAN interface that interracts with your INTERNAL network\" 15 65 6 \\"
INTIF_DIALOG="${INTIF_DIALOG_START}"

for EACH_IFACE in $ALL_IFACES
do
   LIIFACE_MAC=`grep rnet /var/run/dmesg.boot | grep ${EACH_IFACE} | cut -f 4 -d " "`
   LIIFACE_IP=`ifconfig ${EACH_IFACE} | grep "inet " | cut -f 2 -d ' ' | tr -d ' '`
   INTIF_DIALOG="${INTIF_DIALOG}${EACH_IFACE} \\ \"${LIIFACE_IP} - ${LIIFACE_MAC}\" "
done

INTIF_DIALOG="${INTIF_DIALOG} 2> /tmp/ubiface"

sh -c "${INTIF_DIALOG}"
clear 

#configuring internal network
TMP_LAN_IFACE=`cat /tmp/ubiface`
TMP_NET_DATA=`netstat -rn -f inet | grep ${TMP_LAN_IFACE} | grep "/" | cut -f 1 -d " "`
TMP_LAN_NETW=`echo ${TMP_NET_DATA} | cut -f 1 -d "/"`
TMP_LAN_CIDR=`echo ${TMP_NET_DATA} | cut -f 2 -d "/"`
echo ${TMP_LAN_NETW} > /tmp/ubnetw
echo ${TMP_LAN_CIDR} > /tmp/ubcidr


#NAT etc presets setup
clear
$DIALOG --title "Setup NAS"   --yesno "Do you want to install firewall/nat/shaper presets for setup all-in-one Billing+NAS server" 10 40
NAS_KERNEL=$?
clear

case $NAS_KERNEL in
0)
#if setup NAS kernel with preconfigured firewall
#configuring WAN interface
ALL_IFACES=`grep rnet /var/run/dmesg.boot | cut -f 1 -d ":" | tr "\n" " "`

EXTIF_DIALOG_START="$DIALOG --menu \"Select WAN interface for NAT that interracts with Internet\" 15 65 6 \\"
EXTIF_DIALOG="${EXTIF_DIALOG_START}"

for EACH_IFACE in $ALL_IFACES
do
   LIIFACE_MAC=`grep rnet /var/run/dmesg.boot | grep ${EACH_IFACE} | cut -f 4 -d " "`
   LIIFACE_IP=`ifconfig ${EACH_IFACE} | grep "inet " | cut -f 2 -d ' ' | tr -d ' '`
   EXTIF_DIALOG="${EXTIF_DIALOG}${EACH_IFACE} \\ \"${LIIFACE_IP} - ${LIIFACE_MAC}\" "
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
GEN_MYS_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5 | cut -b-8`
echo "mys"${GEN_MYS_PASS} > /tmp/ubmypass

#getting stargazer admin password
GEN_STG_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5 | cut -b-8`
echo "stg"${GEN_STG_PASS} > /tmp/ubstgpass


#getting rscriptd encryption password
GEN_RSD_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5 | cut -b-8`
echo "rsd"${GEN_RSD_PASS} > /tmp/ubrsd
;;
MIG)
#request previous MySQL/Stargazer/rscriptd passwords
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
ARCH=`cat /tmp/ubarch`
STG_VER=`cat /tmp/stgver`
UB_CHANNEL=`cat /tmp/ubchannel`

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
rm -fr /tmp/ubarch
rm -fr /tmp/stgver
rm -fr /tmp/insttype
rm -fr /tmp/ubsrl
rm -fr /tmp/ubchannel

#last chance to exit
$DIALOG --title "Check settings" --yesno "\
Are all of these settings correct?

LAN interface: ${LAN_IFACE}
LAN network: ${LAN_NETW}/${LAN_CIDR}
WAN interface: ${EXT_IF}
MySQL password: ${MYSQL_PASSWD}
Stargazer password: ${STG_PASS}
Rscripd password: ${RSD_PASS}
System: ${ARCH}
Stargazer: ${STG_VER}
Ubilling channel: ${UB_CHANNEL}
Ubilling serial: ${UBSERIAL}
" 18 60
AGREE=$?
clear

case $AGREE in
0)
echo "Everything is okay! Installation is starting."

# preparing for installation
mkdir /usr/local/ubinstaller/
cp -R ./* /usr/local/ubinstaller/
cd /usr/local/ubinstaller/

#######################################
#  Platform specific issues handling  #
#######################################

#FreeBSD 10+ need to use CC and CXX env with clang
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++

#FreeBSD 13.3/14.0 requires specific CXXFLAGS env
export CXXFLAGS=-std=c++11

case $ARCH in

140_6K)
#14.0K contains PHP 8.3 binaries
APACHE_CONFIG_PRESET_NAME="httpd24f8.conf"
PHP_CONFIG_PRESET="php8.ini"

# FreeBSD 14.0 requires custom clang flags
# or gcc13 build
# export CC=/usr/local/bin/gcc13
# export CXX=/usr/local/bin/g++13
# export LD=/usr/local/bin/g++13
# export CXXFLAGS=-std=c++11
;;
esac	


#botstrapping pkg ng
pkg info
#=======================================================

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

#selecting Ubilling release to install
case $UB_CHANNEL in
STABLE)
#noting here, its default now
;;
CURRENT)
DL_UB_URL="http://snaps.ubilling.net.ua/"
DL_UB_NAME="ub_current.tgz"
;;
esac

#check is FreeBSD installation clean
PKG_COUNT=`/usr/sbin/pkg info | /usr/bin/wc -l`
if [ $PKG_COUNT -ge 2 ]
then
echo "UBinstaller supports setup only for clean FreeBSD distribution. Installation is aborted."
exit
fi


# install prebuilded binary packages
$DIALOG --infobox "Software installation is in progress. This takes a while." 4 60
cd packages
$FETCH ${DL_PACKAGES_URL}${ARCH}${DL_PACKAGES_EXT}
#check is binary packages download has beed completed
if [ -f ${ARCH}${DL_PACKAGES_EXT} ];
then
echo "Binary packages download has been completed."
else
echo "=== Error: binary packages are not available. Installation is aborted. ==="
exit
fi

tar zxvf ${ARCH}${DL_PACKAGES_EXT} 2>> /var/log/ubinstaller.log
cd ${ARCH}
ls -1 | xargs -n 1 pkg add >> /var/log/ubinstaller.log

#back to installation directory
cd /usr/local/ubinstaller/

#installing stargazer
$DIALOG --infobox "Stargazer download is in progress." 4 60
cd ./distfiles/
$FETCH ${DL_STG_URL}${DL_STG_NAME}
#check is stargazer sources download complete
if [ -f ${DL_STG_NAME} ];
then
echo "Stargazer distro download has been completed."
else
echo "=== Error: stargazer sources are not available. Installation is aborted. ==="
exit
fi
$DIALOG --infobox "Compiling Stargazer." 4 60
tar zxvf ${DL_STG_NAME} 2>> /var/log/ubinstaller.log
$DIALOG --infobox "Compiling Stargazer.." 4 60
cd ${DL_STG_RELEASE}/projects/stargazer/ 
./build >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
/usr/local/bin/gmake install >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
$DIALOG --infobox "Compiling Stargazer..." 4 60
#and configurators
cd ../sgconf 
./build >> /var/log/ubinstaller.log
/usr/local/bin/gmake >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
/usr/local/bin/gmake install >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
$DIALOG --infobox "Compiling Stargazer...." 4 60
cd ../sgconf_xml/ 
./build >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
/usr/local/bin/gmake >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
$DIALOG --infobox "Compiling Stargazer....." 4 60
/usr/local/bin/gmake install >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
$DIALOG --infobox "Stargazer installed." 4 60

# adding needed boot options
cat /usr/local/ubinstaller/configs/rc.preconf >> /etc/rc.conf
perl -e "s/LAN_IFACE/${LAN_IFACE}/g" -pi /etc/rc.conf

# copying prepared configs
cd /usr/local/ubinstaller/configs/
cp -R ${APACHE_CONFIG_PRESET_NAME} ${APACHE_CONFIG_DIR}${APACHE_CONFIG_NAME}
cp -R ${PHP_CONFIG_PRESET} /usr/local/etc/php.ini
cp -R stargazer.conf /etc/stargazer/
cp -R bandwidthd.conf /usr/local/bandwidthd/etc/

#setting up default web awesomeness
cp -R inside.html ${APACHE_DATA_PATH}/index.html

# database specific issues handling

# MySQL 8.0 requires custom config
cp -R 80_my.cnf /usr/local/etc/mysql/my.cnf 
echo "MySQL 8.0 config replaced"

# start services
${APACHE_INIT_SCRIPT} start
/usr/local/etc/rc.d/mysql-server start

#Setting MySQL root password
mysqladmin -u root password ${MYSQL_PASSWD}

######################
# unpacking Ubilling
######################
$DIALOG --infobox "Ubilling download, unpacking and installation is in progress." 4 60
cd /usr/local/ubinstaller/distfiles/
$FETCH ${DL_UB_URL}${DL_UB_NAME}
#check is ubilling distro download complete
if [ -f ${DL_UB_NAME} ];
then
echo "Ubilling download has been completed."
else
echo "=== Error: Ubilling release is not available. Installation is aborted. ==="
exit
fi
mkdir ${APACHE_DATA_PATH}billing/
cp ${DL_UB_NAME} ${APACHE_DATA_PATH}billing/
cd ${APACHE_DATA_PATH}billing/
tar zxvf ${DL_UB_NAME} 2>> /var/log/ubinstaller.log
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
# change default mukrotik presets password
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./docs/presets/MikroTik/config.ini
# OpenPayz may be?
perl -e "s/mylogin/root/g" -pi ./docs/openpayz/config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./docs/openpayz/config/mysql.ini

# creating stargazer database
$DIALOG --infobox "Creating initial Stargazer DB" 4 60
cat docs/dumps/stargazer.sql | /usr/local/bin/mysql -u root --password=${MYSQL_PASSWD}

# starting stargazer
$DIALOG --infobox "Starting Stargazer" 4 60
/usr/sbin/stargazer
#changing stargazer admin default password
/usr/sbin/sgconf_xml -s localhost -p 5555 -a admin -w 123456 -r " <ChgAdmin Login=\"admin\" password=\"${STG_PASS}\" /> "
$DIALOG --infobox "Stargazer default password changed." 4 60
#stopping stargazer
$DIALOG --infobox "Stopping Stargazer." 4 60
killall stargazer

# restoring clean ubilling SQL dump
$DIALOG --infobox "Restoring Ubilling database" 4 60
cat docs/dumps/ubilling.sql | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}

$DIALOG --infobox "Installing OpenPayz database preset" 4 60
cat docs/dumps/openpayz.sql | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}

# apply hotfix for stargazer 2.408 and change passwords in configs
cat /usr/local/ubinstaller/configs/admin_rights_hotfix.sql | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
perl -e "s/123456/${STG_PASS}/g" -pi ./config/billing.ini
perl -e "s/123456/${STG_PASS}/g" -pi ./userstats/config/userstats.ini
perl -e "s/123456/${STG_PASS}/g" -pi ./docs/openpayz/config/openpayz.ini

#preconfiguring dhcpd logging
cat /usr/local/ubinstaller/configs/syslog.preconf >> /etc/syslog.conf
touch /var/log/dhcpd.log
/usr/local/etc/rc.d/isc-dhcpd restart > /dev/null 2> /dev/null
/etc/rc.d/syslogd restart > /dev/null
perl -e "s/NMLEASES = \/var\/log\/messages/NMLEASES = \/var\/log\/dhcpd.log/g" -pi ./config/alter.ini
$DIALOG --infobox "dhcpd logging configured." 4 60

#first install flag setup for the future
touch ./exports/FIRST_INSTALL
chmod 777 ./exports/FIRST_INSTALL

# unpacking ubapi preset
cp -R /usr/local/ubinstaller/configs/ubapi /bin/
chmod a+x /bin/ubapi
$DIALOG --infobox "remote API wrapper installed" 4 60

# unpacking start scripts templates
cp -f docs/presets/FreeBSD/etc/stargazer/* /etc/stargazer/
chmod a+x /etc/stargazer/*
echo "default user initialization scripts installed."

# changing mysql and interface parameters
perl -e "s/mylogin/root/g" -pi /etc/stargazer/config
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi /etc/stargazer/config
perl -e "s/rl0/${LAN_IFACE}/g" -pi /etc/stargazer/OnConnect
perl -e "s/em0/${LAN_IFACE}/g" -pi /usr/local/bandwidthd/etc/bandwidthd.conf
perl -e "s/NETW/${LAN_NETW}\/${LAN_CIDR}/g" -pi /usr/local/bandwidthd/etc/bandwidthd.conf


#editing sudoers
echo "User_Alias BILLING = www" >> /usr/local/etc/sudoers
echo "BILLING         ALL = NOPASSWD: ALL" >> /usr/local/etc/sudoers


#symlink magic
mkdir /etc/stargazer/dn
chmod -R 777 /etc/stargazer/dn
ln -fs ${APACHE_DATA_PATH}billing/multinet /usr/local/etc/multinet
ln -fs ${APACHE_DATA_PATH}billing/remote_nas.conf /etc/stargazer/remote_nas.conf
mkdir ${APACHE_DATA_PATH}billing/content/dn
chmod 777 ${APACHE_DATA_PATH}billing/content/dn
ln -fs /usr/local/bandwidthd/htdocs ${APACHE_DATA_PATH}band

#creating rc.script
cp -R /usr/local/ubinstaller/configs/rc.billing /usr/local/etc/rc.d/billing
chmod a+x /usr/local/etc/rc.d/billing
$DIALOG --infobox "Ubilling rc script installed." 4 60

#ugly hack for starting stargazer without NAS-es
echo "127.0.0.1/32 127.0.0.1" > /etc/stargazer/remote_nas.conf


#kernel options setup 
case $NAS_KERNEL in
0)
cat /usr/local/ubinstaller/configs/loader.preconf >> /boot/loader.conf
cp -R /usr/local/ubinstaller/configs/firewall.conf /etc/
chmod a+x /etc/firewall.conf
cat /usr/local/ubinstaller/configs/rc-fw.preconf >> /etc/rc.conf
cat /usr/local/ubinstaller/configs/sysctl.preconf >> /etc/sysctl.conf
#update settings in firewall sample
perl -e "s/USERS_NET/${LAN_NETW}/g" -pi /etc/firewall.conf
perl -e "s/CIDR/${LAN_CIDR}/g" -pi /etc/firewall.conf
perl -e "s/EXT_IF/${EXT_IF}/g" -pi /etc/firewall.conf
perl -e "s/INT_IF/${LAN_IFACE}/g" -pi /etc/firewall.conf;;
1)
echo "no NAS setup required";;
esac

#disabling mysql>=5.6 strict trans tables in various config locations
if [ -f /usr/local/my.cnf ];
then
perl -e "s/,STRICT_TRANS_TABLES//g" -pi /usr/local/my.cnf
echo "Disabling MySQL STRICT_TRANS_TABLES in /usr/local/my.cnf done"
else
echo "Looks like no MySQL STRICT_TRANS_TABLES disable required in /usr/local/my.cnf"
fi

if [ -f /usr/local/etc/my.cnf ];
then
perl -e "s/,STRICT_TRANS_TABLES//g" -pi /usr/local/etc/my.cnf
echo "Disabling MySQL STRICT_TRANS_TABLES in /usr/local/etc/my.cnf done"
else
echo "Looks like no MySQL STRICT_TRANS_TABLES disable required in /usr/local/etc/my.cnf"
fi

if [ -f /usr/local/etc/mysql/my.cnf ];
then
perl -e "s/,STRICT_TRANS_TABLES//g" -pi /usr/local/etc/mysql/my.cnf
echo "Disabling MySQL STRICT_TRANS_TABLES in /usr/local/etc/mysql/my.cnf done"
else
echo "Looks like no MySQL STRICT_TRANS_TABLES disable required in /usr/local/etc/mysql/my.cnf"
fi

#Multigen/FreeRADIUS3 preconfiguration
cd ${APACHE_DATA_PATH}billing
cp -R ./docs/multigen/raddb3/* /usr/local/etc/raddb/
RADVER=`radiusd -v | grep "radiusd: FreeRADIUS Version" | awk '{print $4}' | tr -d ,`
sed -i.bak "s/\/usr\/local\/lib\/freeradius-3.0.16/\/usr\/local\/lib\/freeradius-${RADVER}/" /usr/local/etc/raddb/radiusd.conf
cat ./docs/multigen/dump.sql | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
cat ./docs/multigen/radius3_fix.sql | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
perl -e "s/yourmysqlpassword/${MYSQL_PASSWD}/g" -pi /usr/local/etc/raddb/sql.conf
#adding current hostname to fix resolve issues
CURR_HOSTNAME=`hostname`
echo "127.0.0.1 ${CURR_HOSTNAME} ${CURR_HOSTNAME}.localdomain" >> /etc/hosts


#starting stargazer
$DIALOG --infobox "Starting Stargazer" 4 60
/usr/sbin/stargazer

#initial crontab configuration
cd ${APACHE_DATA_PATH}billing
if [ -f ./docs/crontab/crontab.preconf ];
then
#generating new Ubilling serial or using predefined
case $PASSW_MODE in
NEW)
/usr/local/bin/curl -o /dev/null "http://127.0.0.1/billing/?module=remoteapi&action=identify&param=save"
NEW_UBSERIAL=`cat ./exports/ubserial`
$DIALOG --infobox "New Ubilling serial generated: ${NEW_UBSERIAL}" 4 60
;;
MIG)
NEW_UBSERIAL=${UBSERIAL}
$DIALOG --infobox "Using Ubilling serial: ${NEW_UBSERIAL}" 4 60
;;
esac
#loading default crontab preset
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

#stopping stargazer again to prevent data corruption and force server rebooting
$DIALOG --infobox "Stopping stargazer" 4 60
killall stargazer

# Setting up autoupdate script
if [ -f ./docs/presets/FreeBSD/ubautoupgrade.sh ];
then
cp -R ./docs/presets/FreeBSD/ubautoupgrade.sh /bin/
chmod a+x /bin/ubautoupgrade.sh
else
echo "Looks like this Ubilling release does not containing automatic upgrade preset"
fi

$DIALOG --title "Ubilling installation has been completed" --msgbox "\
Now you can access the web interface at:

  http://server_ip/billing/

Login / password: admin / demo

Please reboot your server to verify correct startup of all services.
" 15 50

;;
1)
echo "Installation has been aborted"
exit
;;
esac

# I am the chosen one, keep till the rising sun
