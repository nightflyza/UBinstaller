#!/bin/sh

#
# README!
# Please put this script on a level upper of your ubilling installation
# backup manually directory billing at first time before running this updater
# something like cp -R billing billing_helpplz
#

######################## CONFIG SECTION ########################

#dialog
DIALOG="/usr/bin/dialog"

#fetch software
FETCH="/usr/bin/fetch"

#pwd command
PWD="/bin/pwd"

#apache version macro
APVER_VAR="APVER_MACRO"

# path to your apache data
APACHE_DATA_PATH="/usr/local/www/${APVER_VAR}/data/"

# ubilling path
UBILLING_PATH="./billing/"

#kill default admin account after update?
DEFADM_KILL="NO"

#use DN online detection?
DN_ONLINE_LINKING="YES"

#update log file
LOG_FILE="/var/log/ubillingupdate.log"

######################## INTERFACE SECTION ####################

$DIALOG --title "Ubilling update" --msgbox "This wizard help you to update your Ubilling installation to the the latest stable or current development release" 10 40
clear
$DIALOG --menu "Choose a Ubilling release branch to which you want to update." 12 65 6 \
 	   	   STABLE "Ubilling latest stable release (recommended)"\
 	   	   MIRROR "Ubilling latest stable release mirror"\
 	   	   CURRENT "Ubilling current development snapshot"\
            2> /tmp/auprelease
clear

BRANCH=`cat /tmp/auprelease`
rm -fr /tmp/auprelease

case $BRANCH in
STABLE)
UBILLING_RELEASE_URL="http://ubilling.net.ua/"
UBILLING_RELEASE_NAME="ub.tgz"
;;

MIRROR)
UBILLING_RELEASE_URL="http://mirror.ubilling.net.ua/"
UBILLING_RELEASE_NAME="ub.tgz"
;;

CURRENT)
UBILLING_RELEASE_URL="http://snaps.ubilling.net.ua/"
UBILLING_RELEASE_NAME="ub_current.tgz"
;;
esac

#detecting current directory
CUR_DIR=`${PWD}`/

#last chance to exit
$DIALOG --title "Check settings"   --yesno "Are all of these settings correct? \n \n Ubilling release: ${BRANCH} \n Kill default admin: ${DEFADM_KILL} \n DN online linking: ${DN_ONLINE_LINKING} \n Apache data path: ${APACHE_DATA_PATH} \n Current directory: ${CUR_DIR}" 12 60
AGREE=$?
clear

#checking current directory
if [ ${CUR_DIR} == ${APACHE_DATA_PATH} ]
then



######################## END OF CONFIG ########################
case $AGREE in
0)
echo "=== Start Ubilling auto update ==="
cd ${APACHE_DATA_PATH}
cd ${UBILLING_PATH}

echo "=== Downloading new release ==="
$FETCH ${UBILLING_RELEASE_URL}${UBILLING_RELEASE_NAME}

if [ -f ${UBILLING_RELEASE_NAME} ];
then

echo "=== Create restore point ==="
mkdir ../ub_restore 2> /dev/null
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


# backup of actual configs and administrators
cp .htaccess ../ub_restore/ 2> /dev/null
cp favicon.ico ../ub_restore/ 2> /dev/null
cp remote_nas.conf ../ub_restore/
cp -R ./multinet ../ub_restore/
cp ./config/alter.ini ../ub_restore/config/
cp ./config/billing.ini ../ub_restore/config/
cp ./config/mysql.ini ../ub_restore/config/
cp ./config/catv.ini ../ub_restore/config/
cp ./config/ymaps.ini ../ub_restore/config/
cp ./config/config.ini ../ub_restore/config/
cp -R ./config/dhcp ../ub_restore/config/
cp -R ./content/users ../ub_restore/content/
cp -R ./content/reports ../ub_restore/content/
cp -R ./content/documents ../ub_restore/content/
cp ./config/printcheck.tpl ../ub_restore/config/
cp ./userstats/config/mysql.ini ../ub_restore/userstats/config/
cp ./userstats/config/userstats.ini ../ub_restore/userstats/config/
cp ./userstats/config/tariffmatrix.ini ../ub_restore/userstats/config/



echo "=== Billing directory cleanup ==="
rm -fr ./*


echo "=== Unpacking new release ==="
cp  -R ../ub_restore/${UBILLING_RELEASE_NAME} ./
echo `date` >> ${LOG_FILE}
echo "====================" >> ${LOG_FILE}
tar zxvf ${UBILLING_RELEASE_NAME} 2>> ${LOG_FILE}
rm -fr ${UBILLING_RELEASE_NAME}

echo "=== Restoring configs ==="
cp -R ../ub_restore/* ./
rm -fr ${UBILLING_RELEASE_NAME}
echo "deny from all" > ../ub_restore/.htaccess

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
chmod -R 777 userstats/config/

case $DN_ONLINE_LINKING in 
NO)
echo "=== No DN online ==";;
YES)
mkdir ${APACHE_DATA_PATH}${UBILLING_PATH}/content/dn
chmod 777 /etc/stargazer/dn ${APACHE_DATA_PATH}${UBILLING_PATH}/content/dn
echo "=== Linking True Online ===";;
esac

NEW_RELEASE=`cat RELEASE`
$DIALOG --title "Ubilling update" --msgbox "Ubilling update successfully complete. Now your installation release is: ${NEW_RELEASE}" 10 40


#release file not dowloaded
else
$DIALOG --title "Ubilling update error" --msgbox "No new Ubilling release file found, aborting update." 10 40
fi

;;
1)
$DIALOG --title "Ubilling update" --msgbox "Update has been canceled" 10 40
exit
;;
esac

else
$DIALOG --title "Ubilling update error" --msgbox "Update has been aborted: wrong current directory" 10 40
fi
