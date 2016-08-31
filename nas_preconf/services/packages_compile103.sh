#!/bin/sh

PLATFORM="NAS_103_64"
PKGPATH="/home/"${PLATFORM}

mkdir ${PKGPATH}


#updating ports tree
#portsnap fetch
#portsnap extract
#portsnap update

#setup needed software
cd /usr/ports/textproc/expat2 && make BATCH=yes install
cd /usr/ports/shells/bash/ && make BATCH=yes install
cd /usr/ports/www/nginx/ && make BATCH=yes install
cd /usr/ports/net-mgmt/softflowd/ && make BATCH=yes install
cd /usr/ports/editors/vim-lite/ && make BATCH=yes install
cd /usr/ports/net/mtr-nox11/ && make BATCH=yes install
cd /usr/ports/net-mgmt/bandwidthd/ && make BATCH=yes install
cd /usr/ports/net/trafshow/ && make BATCH=yes install
cd /usr/ports/www/elinks/ && make BATCH=yes install
cd /usr/ports/net-mgmt/net-snmp/ && make WITH_MFD_REWRITES=yes BATCH=yes install
cd /usr/ports/lang/php5 && make WITH_CLI=yes WITHOUT_APACHE=yes BATCH=yes install
cd /usr/ports/lang/php5-extensions/ && make WITH_MYSQL=yes WITH_MBSTRING=yes WITH_ICONV=yes WITH_GD=yes WITH_BCMATH=yes WITH_XML=yes BATCH=yes install
cd /usr/ports/lang/gcc/ && make BATCH=yes install
cd /usr/ports/devel/gmake && make BATCH=yes install

pkg create -a -o ${PKGPATH}

