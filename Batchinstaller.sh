#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Batchinstaller script must be run only as root user."
    exit 1
fi

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

PATH=/usr/local/bin:/usr/local/sbin:$PATH
export PATH

# CLI parameter parsing
if [ "$#" -lt 4 ]; then
    echo "========================================================================"
    echo "|           Ubilling batch installation script                          |"  
    echo "========================================================================"
    echo "Usage: $0 <type> <arch> <channel> <internal_interface> [external_interface] [mysql_pass] [stargazer_pass] [rscriptd_pass] [ubilling_serial]"
    echo ""
    echo "Required parameters:"
    echo "  type              - Installation type: NEW or MIG"
    echo "  arch              - Architecture: 143_6L, 142_6L, or 135_6L"
    echo "  channel           - Ubilling channel: STABLE or CURRENT"
    echo "  internal_interface - Internal network interface name"
    echo ""
    echo "Optional parameters:"
    echo "  external_interface - External network interface name (for NAS setup)"
    echo ""
    echo "Required for MIG type:"
    echo "  mysql_pass        - MySQL root password"
    echo "  stargazer_pass    - Stargazer admin password"
    echo "  rscriptd_pass     - rscriptd encryption password"
    echo "  ubilling_serial   - Ubilling serial number"
    echo ""
    echo "Examples:"
    echo "  $0 NEW 143_6L STABLE em0 - New installation on FreeBSD 14.3 amd64 with internal interface em0"
    echo "  $0 MIG 143_6L STABLE em0 em1 mys828223 stg883473 rsdbilochka66 UB0000000000000000000 - Migration from another server"
    exit 1
fi

PASSW_MODE="$1"
ARCH="$2"
UB_CHANNEL="$3"
LAN_IFACE="$4"

# Validate type
if [ "$PASSW_MODE" != "NEW" ] && [ "$PASSW_MODE" != "MIG" ]; then
    echo "Error: type must be NEW or MIG"
    exit 1
fi

# Validate channel
if [ "$UB_CHANNEL" != "STABLE" ] && [ "$UB_CHANNEL" != "CURRENT" ]; then
    echo "Error: channel must be STABLE or CURRENT"
    exit 1
fi

# Handle external interface and MIG parameters
if [ "$PASSW_MODE" = "MIG" ]; then
    # For MIG, check parameter count to determine if external interface is provided
    if [ "$#" -eq 9 ]; then
        # External interface provided: type arch channel internal external mysql stargazer rscriptd serial
        EXT_IF="$5"
        MYSQL_PASSWD="$6"
        STG_PASS="$7"
        RSD_PASS="$8"
        UBSERIAL="$9"
    elif [ "$#" -eq 8 ]; then
        # No external interface: type arch channel internal mysql stargazer rscriptd serial
        EXT_IF="none"
        MYSQL_PASSWD="$5"
        STG_PASS="$6"
        RSD_PASS="$7"
        UBSERIAL="$8"
    else
        echo "Error: MIG type requires mysql_pass, stargazer_pass, rscriptd_pass, and ubilling_serial parameters"
        echo "Usage: $0 MIG <arch> <channel> <internal_interface> [external_interface] <mysql_pass> <stargazer_pass> <rscriptd_pass> <ubilling_serial>"
        exit 1
    fi
else
    # For NEW, external interface is optional
    if [ "$#" -ge 5 ]; then
        EXT_IF="$5"
    else
        EXT_IF="none"
    fi
    
    # Generate passwords for NEW installation
    GEN_MYS_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5 | cut -b-8`
    MYSQL_PASSWD="mys${GEN_MYS_PASS}"
    
    GEN_STG_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5 | cut -b-8`
    STG_PASS="stg${GEN_STG_PASS}"
    
    GEN_RSD_PASS=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5 | cut -b-8`
    RSD_PASS="rsd${GEN_RSD_PASS}"
    
    UBSERIAL="auto"
fi

# Configure internal network
TMP_NET_DATA=`netstat -rn -f inet | grep ${LAN_IFACE} | grep "/" | cut -f 1 -d " "`
if [ -z "$TMP_NET_DATA" ]; then
    echo "Error: Cannot determine network for interface ${LAN_IFACE}"
    exit 1
fi
LAN_NETW=`echo ${TMP_NET_DATA} | cut -f 1 -d "/"`
LAN_CIDR=`echo ${TMP_NET_DATA} | cut -f 2 -d "/"`

# Determine NAS setup based on external interface
if [ "$EXT_IF" != "none" ]; then
    NAS_KERNEL=0
else
    NAS_KERNEL=1
fi

# Always use Stargazer 2.409 release
STG_VER="409REL"

echo "===================================================================="
echo "                                                                          "
echo "             Starting Ubilling installation...                            "
echo "                                                                          "
echo "             Type: ${PASSW_MODE}                                          "
echo "             Architecture: ${ARCH}                                        "
echo "             Channel: ${UB_CHANNEL}                                       "
echo "             LAN interface: ${LAN_IFACE}                                  "
echo "             LAN network: ${LAN_NETW}/${LAN_CIDR}                         "
echo "             WAN interface: ${EXT_IF}                                     "
echo "             Stargazer: ${STG_VER}                                        "
echo "                                                                          "
echo "===================================================================="

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


#botstrapping pkg ng
ASSUME_ALWAYS_YES=yes pkg bootstrap -y
#=======================================================

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
echo "Software installation is in progress. This takes a while."
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
echo "Stargazer download is in progress."
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
echo "Compiling Stargazer."
tar zxvf ${DL_STG_NAME} 2>> /var/log/ubinstaller.log
echo "Compiling Stargazer.."
cd ${DL_STG_RELEASE}/projects/stargazer/ 
./build >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
/usr/local/bin/gmake install >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
echo "Compiling Stargazer..."
#and configurators
cd ../sgconf 
./build >> /var/log/ubinstaller.log
/usr/local/bin/gmake >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
/usr/local/bin/gmake install >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
echo "Compiling Stargazer...."
cd ../sgconf_xml/ 
./build >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
/usr/local/bin/gmake >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
echo "Compiling Stargazer....."
/usr/local/bin/gmake install >> /var/log/ubinstaller.log 2>> /var/log/ubinstaller.log
echo "Stargazer installed."

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
echo "Ubilling download, unpacking and installation is in progress."
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
echo "Creating initial Stargazer DB"
cat docs/dumps/stargazer.sql | /usr/local/bin/mysql -u root --password=${MYSQL_PASSWD}

# starting stargazer
echo "Starting Stargazer"
/usr/sbin/stargazer
#changing stargazer admin default password
/usr/sbin/sgconf_xml -s localhost -p 5555 -a admin -w 123456 -r " <ChgAdmin Login=\"admin\" password=\"${STG_PASS}\" /> "
echo "Stargazer default password changed."
#stopping stargazer
echo "Stopping Stargazer."
killall stargazer

# restoring clean ubilling SQL dump
echo "Restoring Ubilling database"
cat docs/dumps/ubilling.sql | /usr/local/bin/mysql -u root  -p stg --password=${MYSQL_PASSWD}

echo "Installing OpenPayz database preset"
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
echo "dhcpd logging configured."

#first install flag setup for the future
touch ./exports/FIRST_INSTALL
chmod 777 ./exports/FIRST_INSTALL

# unpacking ubapi preset
cp -R /usr/local/ubinstaller/configs/ubapi /bin/
chmod a+x /bin/ubapi
echo "remote API wrapper installed"

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
echo "Ubilling rc script installed."

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
echo "Starting Stargazer"
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
echo "New Ubilling serial generated: ${NEW_UBSERIAL}"
;;
MIG)
NEW_UBSERIAL=${UBSERIAL}
echo "Using Ubilling serial: ${NEW_UBSERIAL}"
;;
esac
#loading default crontab preset
crontab ./docs/crontab/crontab.preconf
echo "Installing default crontab preset"
#updating serial in ubapi wrapper
perl -e "s/UB000000000000000000000000000000000/${NEW_UBSERIAL}/g" -pi /bin/ubapi
echo "New serial installed into ubapi wrapper"
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
echo "Stopping stargazer"
killall stargazer

# Setting up autoupdate script
if [ -f ./docs/presets/FreeBSD/ubautoupgrade.sh ];
then
cp -R ./docs/presets/FreeBSD/ubautoupgrade.sh /bin/
chmod a+x /bin/ubautoupgrade.sh
else
echo "Looks like this Ubilling release does not containing automatic upgrade preset"
fi

echo "==========================================================================="
echo "|             Ubilling installation has been completed!                    |"
echo "|                                                                          |"
echo "| Now you can access the web interface at:                                 |"
echo "| http://server_ip/billing/                                                |"
echo "| Login/password: admin/demo                                               |"
echo "|                                                                          |"
echo "| Please reboot your server to verify correct startup of all services.     |"
echo "|                                                                          |"
echo "==========================================================================="
