#!/bin/bash

# Replaces classes in Android Package Files
# (c) Sebastian Fischer, CC-BY

# Can be used to rebuild an App with a modified version of a used library,
# as required for closed works that link to an LGPL library.

# Depends on: https://code.google.com/p/dex2jar/

APK=$1                        # target apk
JAR=$2                        # source jar
PKG=$3                        # example: PKG=org/mapsforge

unzip $APK classes.dex                           # extract original classes
dex-tools-2.1/d2j-dex2jar.sh -f -o classes.jar classes.dex     # and convert them to .jar
rm classes.dex
unzip $JAR $PKG/*                                # extract alternative classes
jar uvf classes.jar $PKG                         # and replace originals
rm -rf $PKG
dex-tools-2.1/d2j-jar2dex.sh -f -o classes.dex classes.jar     # convert back to .dex
rm classes.jar
jar uvf $APK classes.dex                         # replace .dex in .apk
rm classes.dex
mv $APK unsigned.apk
dex-tools-2.1/d2j-apk-sign.sh -f -o $APK unsigned.apk          # sign modified .apk
rm unsigned.apk
