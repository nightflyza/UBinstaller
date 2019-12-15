#!/bin/sh
BASEPATH="/usr/local/www/apache24/data/ubsnaps"
mkdir ${BASEPATH}/exported
cd ${BASEPATH}/tmp/
rm -fr ../ub_current.tgz > /dev/null
rm -fr ../RELEASE > /dev/null
rm -fr master.zip
/usr/local/bin/curl -k -s https://codeload.github.com/nightflyza/Ubilling/zip/master > master.zip
/usr/local/bin/unzip master.zip -d ../exported
cd ../exported/Ubilling-master/
rm -fr nbproject
echo > remote_nas.conf
tar cf - ./* | gzip > ../../ub_current.tgz
cp -R ./RELEASE ${BASEPATH}/RELEASE
cd ${BASEPATH}
rm -fr exported ./tmp/*


#ubinstaller current build
mkdir ${BASEPATH}/exported2
cd ${BASEPATH}/tmp/
rm -fr ../ubinstaller_current.tgz > /dev/null
rm -fr imaster.zip
/usr/local/bin/curl -k -s https://codeload.github.com/nightflyza/UBinstaller/zip/master > imaster.zip
/usr/local/bin/unzip imaster.zip -d ../exported2
mv ../exported2/UBinstaller-master ../exported2/ubinstaller
cd ../exported2/
tar cf - ./ubinstaller | gzip > ../ubinstaller_current.tar.gz
cd ${BASEPATH}
rm -fr exported2 ./tmp/*
