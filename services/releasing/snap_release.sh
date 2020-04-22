#!/bin/sh
rm -fr ub.tgz RELEASE > /dev/null
wget http://snaps.ubilling.net.ua/ub_current.tgz
mv ub_current.tgz ub.tgz
tar -zxvf ub.tgz ./RELEASE
echo "=== Release Done ==="

rm -fr ubinstaller_current.tar.gz > /dev/null
wget http://snaps.ubilling.net.ua/ubinstaller_current.tar.gz
mv ubinstaller_current.tar.gz ubinstaller.tar.gz
echo "=== Ubinstaller builded ==="
