#!/bin/sh

#
# Per aspera ad astra
#

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: UBinstaller script must be run only as root user."
    exit 1
fi

if [ -z "$DIALOG" ]; then
    if command -v dialog >/dev/null 2>&1; then
        DIALOG=dialog
    elif command -v bsddialog >/dev/null 2>&1; then
        DIALOG=bsddialog
    else
        echo "Error: Neither 'dialog' (gnu-dialog) nor 'bsddialog' is available."
        exit 1
    fi
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BATCHINSTALLER="${SCRIPT_DIR}/Batchinstaller.sh"

if [ ! -f "${BATCHINSTALLER}" ]; then
    echo "Error: Batchinstaller.sh not found in ${SCRIPT_DIR}."
    exit 1
fi

clear
$DIALOG --title "Ubilling installation" --msgbox "This wizard helps you to install Stargazer and Ubilling of the latest stable versions to CLEAN (!) FreeBSD distribution" 10 50
clear

clear
$DIALOG --menu "Type of Ubilling installation" 10 75 8 \
    NEW "This is new Ubilling installation" \
    MIG "Migrating existing Ubilling setup from another server" \
    2> /tmp/insttype
clear

clear
$DIALOG --menu "Choose FreeBSD version and architecture" 16 50 8 \
    151_6M "FreeBSD 15.1 amd64" \
    150_6M "FreeBSD 15.0 amd64" \
    144_6M "FreeBSD 14.4 amd64" \
    143_6M "FreeBSD 14.3 amd64" \
    143_6L "FreeBSD 14.3 amd64" \
    135_6L "FreeBSD 13.5 amd64" \
    2> /tmp/ubarch
clear

clear
$DIALOG --menu "Choose Ubilling installation channel" 11 54 4 \
    STABLE "Latest stable release (recommended)" \
    CURRENT "Nightly build (current development)" \
    2> /tmp/ubchannel
clear

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

TMP_LAN_IFACE=`cat /tmp/ubiface`
TMP_NET_DATA=`netstat -rn -f inet | grep ${TMP_LAN_IFACE} | grep "/" | cut -f 1 -d " "`
TMP_LAN_NETW=`echo ${TMP_NET_DATA} | cut -f 1 -d "/"`
TMP_LAN_CIDR=`echo ${TMP_NET_DATA} | cut -f 2 -d "/"`

clear
$DIALOG --title "Setup NAS" --yesno "Do you want to install firewall/nat/shaper presets for setup all-in-one Billing+NAS server" 10 40
NAS_KERNEL=$?
clear

case $NAS_KERNEL in
0)
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

PASSW_MODE=`cat /tmp/insttype`

case $PASSW_MODE in
NEW)
MYSQL_PASSWD="auto-generated"
STG_PASS="auto-generated"
RSD_PASS="auto-generated"
UBSERIAL="auto"
;;
MIG)
clear
$DIALOG --title "MySQL root password" --inputbox "Enter your previous installation MySQL root password" 8 60 2> /tmp/ubmypass
clear
$DIALOG --title "Stargazer password" --inputbox "Enter your previous installation Stargazer password" 8 60 2> /tmp/ubstgpass
clear
$DIALOG --title "rscriptd password" --inputbox "Enter your previous installation rscriptd password" 8 60 2> /tmp/ubrsd
clear
$DIALOG --title "Ubilling serial" --inputbox "Enter your previous installation Ubilling serial number" 8 60 2> /tmp/ubsrl
clear

MYSQL_PASSWD=`cat /tmp/ubmypass`
STG_PASS=`cat /tmp/ubstgpass`
RSD_PASS=`cat /tmp/ubrsd`
UBSERIAL=`cat /tmp/ubsrl`
;;
esac

LAN_IFACE=`cat /tmp/ubiface`
LAN_NETW="${TMP_LAN_NETW}"
LAN_CIDR="${TMP_LAN_CIDR}"
ARCH=`cat /tmp/ubarch`
UB_CHANNEL=`cat /tmp/ubchannel`

rm -fr /tmp/ubiface /tmp/ubmypass /tmp/ubstgpass /tmp/ubrsd /tmp/ubextif /tmp/ubarch /tmp/insttype /tmp/ubsrl /tmp/ubchannel

$DIALOG --title "Check settings" --yesno "\
Are all of these settings correct?

LAN interface: ${LAN_IFACE}
LAN network: ${LAN_NETW}/${LAN_CIDR}
WAN interface: ${EXT_IF}
MySQL password: ${MYSQL_PASSWD}
Stargazer password: ${STG_PASS}
Rscripd password: ${RSD_PASS}
System: ${ARCH}
Ubilling channel: ${UB_CHANNEL}
Ubilling serial: ${UBSERIAL}
" 18 60
AGREE=$?
clear

case $AGREE in
0)
echo "Everything is okay! Installation is starting."

case $PASSW_MODE in
NEW)
if [ "$EXT_IF" != "none" ]; then
    exec "${BATCHINSTALLER}" "${PASSW_MODE}" "${ARCH}" "${UB_CHANNEL}" "${LAN_IFACE}" "${EXT_IF}"
else
    exec "${BATCHINSTALLER}" "${PASSW_MODE}" "${ARCH}" "${UB_CHANNEL}" "${LAN_IFACE}"
fi
;;
MIG)
if [ "$EXT_IF" != "none" ]; then
    exec "${BATCHINSTALLER}" "${PASSW_MODE}" "${ARCH}" "${UB_CHANNEL}" "${LAN_IFACE}" "${EXT_IF}" "${MYSQL_PASSWD}" "${STG_PASS}" "${RSD_PASS}" "${UBSERIAL}"
else
    exec "${BATCHINSTALLER}" "${PASSW_MODE}" "${ARCH}" "${UB_CHANNEL}" "${LAN_IFACE}" "${MYSQL_PASSWD}" "${STG_PASS}" "${RSD_PASS}" "${UBSERIAL}"
fi
;;
esac
;;
1)
echo "Installation has been aborted"
exit 1
;;
esac
