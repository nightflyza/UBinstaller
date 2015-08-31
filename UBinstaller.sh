#!/bin/sh
DIALOG=${DIALOG=dialog}
FETCH="/usr/bin/fetch"
APACHE_VERSION="apache24"
APACHE_DATA_PATH="/usr/local/www/apache24/data/"
APACHE_CONFIG_DIR="/usr/local/etc/apache24/"
APACHE_INIT_SCRIPT="/usr/local/etc/rc.d/apache24"
APACHE_CONFIG_PRESET_NAME="httpd24f.conf"
APACHE_CONFIG_NAME="httpd.conf"


#some remote paths here
DL_PACKAGES_URL="http://ubilling.net.ua/packages/"
DL_PACKAGES_EXT=".tar.gz"
DL_UB_URL="http://ubilling.net.ua/"
DL_UB_NAME="ub.tgz"
DL_STG_URL="http://ubilling.net.ua/stg/"
DL_STG_NAME="stg-2.409-rc1.tar.gz"
DL_STG_RELEASE="stg-2.409-rc1"

set PATH=/usr/local/bin:/usr/local/sbin:$PATH

# config interface section 
$DIALOG --title "Ubilling installation" --msgbox "This wizard helps you to install Stargazer and Ubilling of the latest stable versions to CLEAN (!) FreeBSD distribution" 10 40
clear
$DIALOG --menu "Choose FreeBSD version and architecture" 16 50 8 \
 	   	   93_64F "FreeBSD 9.3 amd64"\
 	   	   93_32F "FreeBSD 9.3 i386"\
 	   	   102_64 "FreeBSD 10.2 amd64"\
 	   	   102_32 "FreeBSD 10.2 i386"\
            2> /tmp/ubarch
clear


# no more manual transmission anymore
echo "BIN" > /tmp/ubimode

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


#generating mysql password
GEN_MYS_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5 | cut -b-8`
echo "mys"${GEN_MYS_PASS} > /tmp/ubmypas

#getting stargazer admin password
GEN_STG_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5 | cut -b-8`
echo "stg"${GEN_STG_PASS} > /tmp/ubstgpass


#getting rscriptd encryption password
GEN_RSD_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5 | cut -b-8`
echo "rsd"${GEN_RSD_PASS} > /tmp/ubrsd


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



LAN_IFACE=`cat /tmp/ubiface`
MYSQL_PASSWD=`cat /tmp/ubmypas`
LAN_NETW=`cat /tmp/ubnetw`
LAN_CIDR=`cat /tmp/ubcidr`
STG_PASS=`cat /tmp/ubstgpass`
RSD_PASS=`cat /tmp/ubrsd`
ARCH=`cat /tmp/ubarch`
UBI_MODE=`cat /tmp/ubimode`

# cleaning temp files
rm -fr /tmp/ubiface
rm -fr /tmp/ubmypas
rm -fr /tmp/ubnetw
rm -fr /tmp/ubcidr
rm -fr /tmp/ubstgpass
rm -fr /tmp/ubrsd
rm -fr /tmp/ubextif
rm -fr /tmp/ubarch
rm -fr /tmp/ubimode


#last chance to exit
$DIALOG --title "Check settings"   --yesno "Are all of these settings correct? \n \n LAN interface: ${LAN_IFACE} \n LAN network: ${LAN_NETW}/${LAN_CIDR} \n WAN interface: ${EXT_IF} \n MySQL password: ${MYSQL_PASSWD} \n Stargazer password: ${STG_PASS} \n Rscripd password: ${RSD_PASS} \n System: ${ARCH} \n Mode: ${UBI_MODE}" 18 60
AGREE=$?
clear

# preparing for installation
mkdir /usr/local/ubinstaller/
cp -R ./* /usr/local/ubinstaller/
cd /usr/local/ubinstaller/

case $AGREE in
0)
echo "Everything is okay! Installation is starting."
#######################################
#  Platform specific issues handling  #
#######################################
case $ARCH in
93_64F)
#FreeBSD 9.3 x64 Release 
sed -I "" "s/apache22_enable/apache24_enable/g" ./configs/rc.preconf
/bin/sh pkgng.installer
;;


93_32F)
#FreeBSD 9.3 x32 Release
sed -I "" "s/apache22_enable/apache24_enable/g" ./configs/rc.preconf
/bin/sh pkgng.installer
;;


102_64)
#FreeBSD 10.2 x64 Release need to use CC and CXX env
sed -I "" "s/apache22_enable/apache24_enable/g" ./configs/rc.preconf
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++
;;

esac
#=======================================================


#check is FreeBSD installation clean
PKG_COUNT=`/usr/sbin/pkg info | /usr/bin/wc -l`
if [ $PKG_COUNT -ge 2 ]
then
echo "UBinstaller supports setup only for clean FreeBSD distribution. Installation is aborted."
exit
fi


# install binary packages or needed software from ports
$DIALOG --infobox "Software installation is in progress. This takes a while." 4 60
case $UBI_MODE in
BIN)
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

tar zxvf ${ARCH}${DL_PACKAGES_EXT} 2>> /tmp/ubpack.log
cd ${ARCH}
pkg add ./*  >> /tmp/ubpack.log 2>> /tmp/ubpack.log
;;
SRC)
echo "Ubilling ports installation not supported at this moment. Installation is aborted."
exit
;;
esac


#back to installation directory
cd /usr/local/ubinstaller/

#installing stargazer
$DIALOG --infobox "Stargazer installation is in progress." 4 60
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

tar zxvf ${DL_STG_NAME} 2>> /tmp/ubstg.log
cd ${DL_STG_RELEASE}/projects/stargazer/ 
./build >> /tmp/ubstg.log 2>> /tmp/ubstg.log
/usr/local/bin/gmake install >> /tmp/ubstg.log 2>> /tmp/ubstg.log
#and configurators
cd ../sgconf 
./build >> /tmp/ubstg.log
/usr/local/bin/gmake >> /tmp/ubstg.log 2>> /tmp/ubstg.log
/usr/local/bin/gmake install >> /tmp/ubstg.log 2>> /tmp/ubstg.log
cd ../sgconf_xml/ 
./build >> /tmp/ubstg.log 2>> /tmp/ubstg.log
/usr/local/bin/gmake >> /tmp/ubstg.log 2>> /tmp/ubstg.log
/usr/local/bin/gmake install >> /tmp/ubstg.log 2>> /tmp/ubstg.log

# adding needed boot options
cat /usr/local/ubinstaller/configs/rc.preconf >> /etc/rc.conf
perl -e "s/LAN_IFACE/${LAN_IFACE}/g" -pi /etc/rc.conf

# copying prepared configs
cd /usr/local/ubinstaller/configs/
cp -R ${APACHE_CONFIG_PRESET_NAME} ${APACHE_CONFIG_DIR}${APACHE_CONFIG_NAME}
cp -R php.ini /usr/local/etc/
cp -R stargazer.conf /etc/stargazer/
cp -R bandwidthd.conf /usr/local/bandwidthd/etc/

#set up and fix autoupdater paths
perl -e "s/APVER_MACRO/${APACHE_VERSION}/g" -pi ../autoubupdate.sh
cp -R ../autoubupdate.sh $APACHE_DATA_PATH



# start services
${APACHE_INIT_SCRIPT} start
/usr/local/etc/rc.d/mysql-server start


#echo "Setting MySQL root password"
mysqladmin -u root password ${MYSQL_PASSWD}

######################
# unpacking Ubilling
######################
$DIALOG --infobox "Ubilling unpacking and installation is in progress." 4 60
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
tar zxvf ${DL_UB_NAME} 2>> /tmp/ubweb.log
chmod -R 777 content/ config/ multinet/ exports/ remote_nas.conf 

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
#change rscriptd password
perl -e "s/secretpassword/${RSD_PASS}/g" -pi /etc/stargazer/stargazer.conf

# starting stargazer for creating DB
/usr/sbin/stargazer
#changing default password
/usr/sbin/sgconf_xml -s localhost -p 5555 -a admin -w 123456 -r " <ChgAdmin Login=\"admin\" password=\"${STG_PASS}\" /> "

#stopping stargazer
killall stargazer

# restoring ubilling SQL dump
cat docs/test_dump.sql | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}

# apply hotfix for stargazer 2.408 and change passwords in configs
cat /usr/local/ubinstaller/configs/admin_rights_hotfix.sql | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
perl -e "s/123456/${STG_PASS}/g" -pi ./config/billing.ini
perl -e "s/123456/${STG_PASS}/g" -pi ./userstats/config/userstats.ini

#clean default stargazer users and tariffs
echo "TRUNCATE TABLE users" | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}
echo "TRUNCATE TABLE tariffs" | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}


# unpacking start scripts templates
cp -f docs/presets/FreeBSD/etc/stargazer/* /etc/stargazer/
chmod a+x /etc/stargazer/*

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
cp -R /usr/local/ubinstaller/configs/rc.billing /etc/rc.d/billing
chmod a+x /etc/rc.d/billing

#ugly hack for starting stargazer without NAS-es
echo "127.0.0.1/32 127.0.0.1" > /etc/stargazer/remote_nas.conf


#kernel compile 
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


$DIALOG --title "Ubilling installation has been completed" --msgbox "Now you can access your web-interface by address http://server_ip/billing/ with login and password: admin/demo. Please reboot your server to check correct startup of all services" 15 50

;;
1)
echo "Installation has been aborted"
exit
;;
esac
