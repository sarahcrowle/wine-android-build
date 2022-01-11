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

#rm -rf build
mkdir build
cd build

echo setting up ndk...
$NDK_ROOT/build/tools/make-standalone-toolchain.sh --platform=android-26 --install-dir=android-toolchain --arch=$TOOLCHAIN_VERSION --verbose


if [ ! -d wine-6.22 ]; then
    echo "downloading wine..."
    wget -nc https://dl.winehq.org/wine/source/6.x/wine-6.22.tar.xz

    echo "extracting..."
    tar xf wine-6.22.tar.xz

    echo "copying..."
    cp -r wine-6.22 wine-6.22-native

    echo "patching..."
    patch -p1 -d wine-6.22 < ../wine-android-configure.patch
    patch -p1 -d wine-6.22 < ../wine-android-gradle.patch
    patch -p1 -d wine-6.22 < ../wine-gradle-properties.patch
    #read -p "Press any key to resume ..."
fi

echo "building native wine 6.22"
cd wine-6.22-native
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

echo "here we go! making wine 6.22 for android!"
cd ../wine-6.22
./configure --host=$TOOLCHAIN_TRIPLE host_alias=$TOOLCHAIN_TRIPLE \
    --with-wine-tools=../wine-6.22-native --prefix=`pwd`/dlls/wineandroid.drv/assets --enable-win64 CC=clang CXX=clang++ > /dev/null
autoreconf
make -j`nproc` > /dev/null && make install > /dev/null

echo "fixing apk!"
cp ../freetype-2.11.1/output/lib/libfreetype.so dlls/wineandroid.drv/assets/x86_64/lib/
cd dlls/wineandroid.drv
make clean > /dev/null
make > /dev/null

echo "all done!"
exit