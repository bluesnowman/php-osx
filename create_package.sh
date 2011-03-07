#!/bin/sh
# creates a local.ch package for the packager

ORIPWD=$PWD

# name of the package
NAME=frontenddev
# package type (subfolder in packager)
TYPE=tools
# create a revision
REL=$(date +%Y%m%d-%H%M%S)
# root folder for the package creation
root="/tmp/$NAME-package"

USER=chregu

# check if php was build localy
if  [ ! -d "/usr/local/php5" ]; then
	echo "you need to build php first!"
	exit 1
fi
if [ -h "/usr/local/php5" ]; then
	echo "Target is a symbolic link! Looks like you have a php5 package installed! Done..."
	exit 1
fi

echo "packaging ..."

# remove root if it exists
[ -d "$root" ] && rm -rf $root

#create the package root folder
mkdir $root
mkdir -p $root/usr/local/

# copy the php5 package contents
cp -R /usr/local/php5 $root/usr/local/php5-$REL

# create metadata
mkdir $root/pkg
echo "name: $TYPE-$NAME
version: $REL
depends: tools-memcached
" >$root/pkg/info

#echo "downloading latest php.ini-development"
#curl http://svn.php.net/viewvc/php/php-src/trunk/php.ini-development?view=co > $root/usr/local/php5-$REL/lib/php.ini-development
echo "using php.ini-development"
cp src/php-5.*/php.ini-development $root/usr/local/php5-$REL/lib/php.ini-development

echo "downloading and latest php.ini-liip"
curl https://svn.liip.ch/repos/public/misc/php-ini/php.ini-development >> $root/usr/local/php5-$REL/php.d/99-liip-developer.ini

# generate post-initial (executed only on the inital, first installation)
cp deploy/post-initial $root/pkg/post-initial

# generate post-install
echo "# post-install" >$root/pkg/post-install
echo "# symlink" >>$root/pkg/post-install
echo "rm -f '/usr/local/php5' && ln -s '/usr/local/php5-$REL' '/usr/local/php5'" >>$root/pkg/post-install
echo "# create php.ini based on php.ini-development" >>$root/pkg/post-install
echo "cp /usr/local/php5/lib/php.ini-development /usr/local/php5/lib/php.ini" >>$root/pkg/post-install
echo "# restart apache" >>$root/pkg/post-install
echo "echo 'Reloading Apache'" >>$root/pkg/post-install
echo "/usr/sbin/apachectl configtest && /usr/sbin/apachectl graceful" >>$root/pkg/post-install

# tar the package
cd $root
tar -czf ../$TYPE-$NAME-$REL.tar.gz . || exit 1

# upload to liip
UPLOADDIR=/Volumes/s3-liip/php-osx.liip.ch/
UPLOADDIR=/tmp/
mkdir -p $UPLOADDIR/install/$TYPE/$NAME/

cd $ORIPWD

php uploadFile.php $root/../$TYPE-$NAME-$REL.tar.gz install/$TYPE/$NAME/$TYPE-$NAME-$REL.tar.gz "application/x-gzip"

echo "install/$TYPE/$NAME/$TYPE-$NAME-$REL.tar.gz" > $UPLOADDIR/install/$TYPE-$NAME-latest.dat

php uploadFile.php $root/../install/$TYPE-$NAME-latest.dat install/$TYPE-$NAME-latest.dat "text/plain"

php uploadFile.php packager/packager.tgz packager/packager.tgz "application/x-gzip"

echo "$TYPE-$NAME-$REL</li></ul> </body></html>" > index.html.bottom
cat index.html.tmpl index.html.bottom > index.html


php uploadFile.php index.html index.html "text/html"
php uploadFile.php install.sh install.sh "text/plain"

#scp ../$TYPE-$NAME-$REL.tar.gz $USER@dev2.liip.ch:/home/liip/dev2/install/$TYPE/$NAME/
#ssh -l $USER dev2.liip.ch "ln -sf ../${TYPE}/${NAME}/${TYPE}-${NAME}-${REL}.tar.gz /home/liip/dev2/install/www/${TYPE}-${NAME}.tar.gz"

echo "done ..."
