export IMGFAC_SRC="/build/imagefactory"
export ETC_IMGFAC_PLUGINS="/etc/imagefactory/plugins.d"
export PYTHON_IMGFAC_PLUGINS="/usr/lib/python2.7/site-packages/imagefactory_plugins"

if [ ! -d $IMGFAC_SRC ]
then
  echo "Must Clone image factory in $IMGFAC_SRC"
  exit 1
fi

cd $IMGFAC_SRC
python ./setup.py sdist install

cd imagefactory-plugins
python ./setup.py sdist install
  
mkdir -p $ETC_IMGFAC_PLUGINS
mkdir -p $PYTHON_IMGFAC_PLUGINS

cd $ETC_IMGFAC_PLUGINS
for PLUGIN in `ls $PYTHON_IMGFAC_PLUGINS | grep -v .py`
do
  ln -s -v $PYTHON_IMGFAC_PLUGINS/$PLUGIN/$PLUGIN.info ./$PLUGIN.info
done

cd $IMGFAC_SRC
scripts/imagefactory_dev_setup.sh
