#!/bin/sh

#
# README!
# Please put this script on a level upper of your ubilling installation
# backup manually directory billing at first time before running this updater
#

######################## CONFIG SECTION ########################

# fetch software
FETCH="fetch"

# path to your apache data
APACHE_DATA_PATH="/usr/local/www/APVER_MACRO/data/"

# ubilling path
UBILLING_PATH="./billing/"

#ubilling release url
UBILLING_RELEASE_URL="http://ubilling.net.ua/"

#ubilling archive name
UBILLING_RELEASE_NAME="ub.tgz"

#kill default admin account after update?
DEFADM_KILL="NO"


#use DN online detection?
DN_ONLINE_LINKING="NO"

######################## END OF CONFIG ########################

echo "=== Start Ubilling auto update ==="
cd ${APACHE_DATA_PATH}
cd ${UBILLING_PATH}

echo "=== Downloading new release ==="
$FETCH ${UBILLING_RELEASE_URL}${UBILLING_RELEASE_NAME}

if [ -f ${UBILLING_RELEASE_NAME} ];
then

echo "=== Create restore point ==="
mkdir ../ub_restore
rm -fr ../ub_restore/*

echo "=== Move new release to safe place ==="
cp -R ${UBILLING_RELEASE_NAME} ../ub_restore/

echo "=== Backup current data ==="

mkdir ../ub_restore/config
mkdir ../ub_restore/content
mkdir ../ub_restore/multinet
mkdir ../ub_restore/userstats
mkdir ../ub_restore/userstats/config
mkdir ../ub_restore/customs



cp .htaccess ../ub_restore/
cp favicon.ico ../ub_restore/
cp remote_nas.conf ../ub_restore/
cp -R ./multinet ../ub_restore/
cp ./config/alter.ini ../ub_restore/config/
cp ./config/billing.ini ../ub_restore/config/
cp ./config/mysql.ini ../ub_restore/config/
cp ./config/catv.ini ../ub_restore/config/
cp ./config/ymaps.ini ../ub_restore/config/
cp -R ./config/dhcp ../ub_restore/config/
cp -R ./content/users ../ub_restore/content/
cp -R ./content/reports ../ub_restore/content/
cp -R ./content/documents ../ub_restore/content/
cp ./config/printcheck.tpl ../ub_restore/config/
cp ./userstats/config/mysql.ini ../ub_restore/userstats/config/
cp ./userstats/config/userstats.ini ../ub_restore/userstats/config/
cp ./userstats/config/tariffmatrix.ini ../ub_restore/userstats/config/



echo "=== Cleanup ==="
rm -fr ./*


echo "=== Unpacking new release ==="
cp  -R ../ub_restore/${UBILLING_RELEASE_NAME} ./
tar zxvf ${UBILLING_RELEASE_NAME}
rm -fr ${UBILLING_RELEASE_NAME}

echo "=== Restoring configs ==="
cp -R ../ub_restore/* ./
rm -fr ${UBILLING_RELEASE_NAME}

#kill default admin
case $DEFADM_KILL in
NO)
echo "=== Default admin account skipped ===";;
YES)
rm -fr ./content/users/admin
echo "=== Default admin account removed ===";;
esac

#clean customs
rm -fr ./customs

echo "=== Setting permissions ==="
chmod -R 777 content/ config/ multinet/ exports/ remote_nas.conf

case $DN_ONLINE_LINKING in 
NO)
echo "=== No DN online ==";;
YES)
ln -fs /etc/stargazer/dn ${APACHE_DATA_PATH}${UBILLING_PATH}/content/dn
chmod 777 /etc/stargazer/dn ${APACHE_DATA_PATH}${UBILLING_PATH}/content/dn
echo "=== Linking True Online ===";;
esac

cat RELEASE
echo "===Update complete ==="

#release file not dowloaded
else
echo "===Error: no new release file found, aborting. ==="
fi
