#!/bin/sh

PLATFORM="NAS_120_64"
PKGPATH="/home/"${PLATFORM}

mkdir ${PKGPATH}

#setting up pkgng
pkg info

#setup needed software
pkg install -y  expat2
pkg install -y  bash
pkg install -y  nginx
pkg install -y  softflowd
pkg install -y  vim-tiny
pkg install -y  nano
pkg install -y  mtr-nox11
pkg install -y  bandwidthd
pkg install -y  trafshow
#elinks may not be accessible
pkg install -y  elinks
pkg install -y  net-snmp
pkg install -y  php56
pkg install -y  php56-iconv
pkg install -y  php56-gd
pkg install -y  php56-curl
pkg install -y  php56-bcmath
pkg install -y  php56-snmp
pkg install -y  php56-mbstring
pkg install -y  php56-mysql
pkg install -y  php56-xml
pkg install -y  php56-imap
pkg install -y  gcc
pkg install -y  gmake

pkg create -a -o ${PKGPATH}
