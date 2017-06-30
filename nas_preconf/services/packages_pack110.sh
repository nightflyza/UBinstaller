#!/bin/sh

PLATFORM="NAS_110_64"
PKGPATH="/home/"${PLATFORM}

mkdir ${PKGPATH}

#setup needed software
pkg install expat2
pkg install bash
pkg install nginx
pkg install softflowd
pkg install vim-lite
pkg install nano
pkg install mtr-nox11
pkg install bandwidthd
pkg install trafshow
pkg install elinks
pkg install net-snmp
pkg install php56
pkg install php56-iconv
pkg install php56-gd
pkg install php56-curl
pkg install php56-bcmath
pkg install php56-snmp
pkg install php56-mbstring
pkg install php56-mysql
pkg install php56-xml
pkg install php56-imap
pkg install gcc
pkg install gmake

pkg create -a -o ${PKGPATH}
