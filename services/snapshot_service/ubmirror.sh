#!/bin/sh
cd /usr/local/www/apache24/data/ubmirror/
rm -fr ub.tgz
rm -fr ubinstaller.tar.gz
wget http://ubilling.net.ua/ubinstaller.tar.gz
wget http://ubilling.net.ua/ub.tgz

chmod 777 ub.tgz ubinstaller.tar.gz

