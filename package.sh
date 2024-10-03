#!/bin/bash

rm -rf ItemRollTracker-v*.zip

rm -rf package
mkdir package
rsync -av --exclude='package' . package

rm -rf ./package/Readme.md ./package/License.md ./package/Acknowledgements.md ./package/.gitattributes ./gitignore
version=$(cat ./package/ItemRollTracker.toc | grep -oP '(?<=## Version: ).+')
echo $version

cd package
zip -rv ../ItemRollTracker-v$version.zip ./*
cd ..
rm -rf package