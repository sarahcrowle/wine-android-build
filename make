#!/bin/bash

# set up environment
export ANDROID_HOME=$(pwd)/android/
export NDK_ROOT=$(pwd)/android/android-ndk-r15c/

export TOOLCHAIN_VERSION="x86_64"
export TOOLCHAIN_TRIPLE="x86_64-linux-android"

mkdir android
cd android

echo "downloading and setting up sdks"

echo "downloading and extracting cmdline tools..."
wget -nc https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip
unzip -n commandlinetools-linux-7583922_latest.zip > /dev/null
    
echo "downloading and extracting ndk"
wget -nc https://dl.google.com/android/repository/android-ndk-r15c-linux-x86_64.zip
unzip -n android-ndk-r15c-linux-x86_64.zip > /dev/null
    
echo "installing packages and accepting licenses..."
chmod +x cmdline-tools/bin/sdkmanager
yes | cmdline-tools/bin/sdkmanager --sdk_root=$(pwd) --install "build-tools;27.0.3" "tools" "platforms;android-25" "platform-tools" > /dev/null
yes | cmdline-tools/bin/sdkmanager --sdk_root=$(pwd) --licenses > /dev/null

cd ..

echo "setting up dex2jar..."
wget -nc https://github.com/pxb1988/dex2jar/releases/download/v2.1/dex2jar-2.1.zip
unzip -n dex2jar-2.1.zip > /dev/null

echo "downloading vanilla wine for android..."
wget -nc https://dl.winehq.org/wine-builds/android/$2-x86.apk -O wine-vanilla.apk

#rm -rf build
mkdir build
cd build

echo setting up ndk...
$NDK_ROOT/build/tools/make-standalone-toolchain.sh --platform=android-26 --install-dir=android-toolchain --arch=$TOOLCHAIN_VERSION --verbose


if [ ! -d wine ]; then
    echo "downloading wine source..."
    wget -nc https://github.com/wine-mirror/wine/archive/$1.zip -O wine.zip

    echo "extracting..."
    unzip wine.zip
    mv wine-$1 wine

    echo "copying..."
    cp -r wine wine-native

    echo "patching..."
    patch -p1 -d wine < ../wine-android-configure.patch
    patch -p1 -d wine < ../wine-android-makefile-in.patch
    patch -p1 -d wine < ../wine-android-gradle.patch
    patch -p1 -d wine < ../wine-gradle-properties.patch
    #read -p "Press any key to resume ..."
fi

echo "building native wine"
cd wine-native
./configure --enable-win64 > /dev/null
make -j`nproc` > /dev/null

cd ..
export PATH=$(pwd)/android-toolchain/bin:$PATH

echo "downloading freetype..."
wget -nc https://download.savannah.gnu.org/releases/freetype/freetype-2.11.1.tar.xz

echo "extracting..."
tar xf freetype-2.11.1.tar.xz

echo "building freetype 2.11.1 for android"
cd freetype-2.11.1
./configure --host=$TOOLCHAIN_TRIPLE --prefix=`pwd`/output --without-zlib --with-png=no --with-brotli=no --with-harfbuzz=no CC=clang CXX=clang++ > /dev/null
make -j`nproc` > /dev/null && make install > /dev/null
export FREETYPE_CFLAGS="-I`pwd`/../freetype-2.11.1/output/include/freetype2"
export FREETYPE_LIBS="-L`pwd`/../freetype-2.11.1/output/lib"

echo "here we go! making wine for android!"
cd ../wine
./configure --host=$TOOLCHAIN_TRIPLE host_alias=$TOOLCHAIN_TRIPLE \
    --with-wine-tools=../wine-native --prefix=`pwd`/dlls/wineandroid.drv/assets --enable-win64 CC=clang CXX=clang++ > /dev/null
autoreconf
make -j`nproc` > /dev/null && make install > /dev/null

echo "fixing apk!"
cp ../freetype-2.11.1/output/lib/libfreetype.so dlls/wineandroid.drv/assets/x86_64/lib/
cd dlls/wineandroid.drv
make clean > /dev/null
make > /dev/null
cd ../../../../
echo `pwd`

echo "committing crimes..."
cp wine-vanilla.apk wine-patched.apk
bash gimmeapk .
unzip wine-debug.apk classes.dex > /dev/null                                           # extract the DEX from our new build
dex-tools-2.1/d2j-dex2jar.sh -f -o fresh-build.jar classes.dex > /dev/null             # convert it to a JAR
rm classes.dex                                                                         # don't need the DEX anymore
bash replaceclasses.sh wine-patched.apk fresh-build.jar org/winehq/wine > /dev/null    # patch the good, working build
rm fresh-build.jar wine-debug.apk                                                      # clean up

echo "all done! the build is in wine-patched.apk"
exit