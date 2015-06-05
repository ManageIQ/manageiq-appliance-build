export IMGFAC_SRC=/build/imagefactory

if [ ! -d $IMGFAC_SRC ]
then
  echo "Must Clone image factory in $IMGFAC_SRC"
  exit 1
fi

cd $IMGFAC_SRC
python ./setup.py sdist install

cd imagefactory-plugins
python ./setup.py sdist install
  
mkdir -p /etc/imagefactory/plugins.d
cd /etc/imagefactory/plugins.d
for PLUGIN in `ls /usr/lib/python2.7/site-packages/imagefactory_plugins |grep -v .py`
do
  ln -s -v /usr/lib/python2.7/site-packages/imagefactory_plugins/$PLUGIN/$PLUGIN.info ./$PLUGIN.info
done

cd $IMGFAC_SRC
scripts/imagefactory_dev_setup.sh
