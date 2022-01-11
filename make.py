#!/usr/bin/env python3

import os
import urllib.request
import tarfile
import shutil
import multiprocessing
import sys
import zipfile

BOLD_CYAN = "\033[1;36m"
COLOR_OFF = "\033[0m"

OG_CWD = os.getcwd()

def print_banner_message(msg):
    print(f"{BOLD_CYAN}{msg}{COLOR_OFF}")

environ_clean = {}
def save_environment():
    global environ_clean
    environ_clean = os.environ

def reset_environment():
    os.environ = environ_clean

def make_dir_if_not_exist(dir):
    if not os.path.exists(dir):
        os.mkdir(dir)
        return True
    else:
        return False

def download_no_clobber(url):
    filename = os.path.basename(url)
    if not os.path.exists(filename):
        urllib.request.urlretrieve(url, filename)
        return True
    else:
        print("already existed!")
        return False

WINE_VER = "wine-6.22"
WINE_SERIES = "6.x"
def download_and_patch_wine():
    print_banner_message("SETTING UP WINE SOURCE TREES")
    print_banner_message("    downloading...")
    download_no_clobber(f"https://dl.winehq.org/wine/source/{WINE_SERIES}/{WINE_VER}.tar.xz")
    
    print_banner_message("    extracting...")
    with tarfile.open(f"{WINE_VER}.tar.xz", 'r:xz') as tar:
        tar.extractall()
    
    print_banner_message("    copying...")
    shutil.copytree(f"{WINE_VER}", f"{WINE_VER}-native", dirs_exist_ok=True)

    print_banner_message("    patching...")
    os.system(f"patch -p1 -d {WINE_VER} < ../wine-android-configure.patch")
    os.system(f"patch -p1 -d {WINE_VER} < ../wine-android-gradle.patch")
    os.system(f"patch -p1 -d {WINE_VER} < ../wine-gradle-properties.patch")

FREETYPE_VER = "freetype-2.11.1"
def build_wine_for_android(jobs):
    save_environment()

    ## set up initial environment
    os.environ["ANDROID_HOME"] = f"{os.getcwd()}/android/"
    os.environ["NDK_ROOT"] = f"{os.getcwd()}/android-ndk-r15c/"
    os.environ["TOOLCHAIN_VERSION"] = "x86"
    os.environ["TOOLCHAIN_TRIPLE"] = "i686-linux-android"

    ## create and enter the build dir
    make_dir_if_not_exist("build")
    os.chdir("build")

    print_banner_message("setting up NDK")
    os.system("$NDK_ROOT/build/tools/make-standalone-toolchain.sh --platform=android-26 --install-dir=android-toolchain --arch=$TOOLCHAIN_VERSION --verbose ")
    
    if not os.path.exists(WINE_VER):
        download_and_patch_wine()
    
    print_banner_message(f"building native {WINE_VER}")
    os.chdir(f"{WINE_VER}-native")
    os.system("./configure --enable-win64 > /dev/null")
    os.system(f"make -j{jobs}  > /dev/null")

    os.chdir("..")
    os.environ["PATH"] = f"{os.getcwd()}/android_toolchain/bin" + os.pathsep + os.environ["PATH"]
    os.system("echo $PATH")

    print_banner_message("downloading and extracting freetype...")
    download_no_clobber(f"https://download.savannah.gnu.org/releases/freetype/{FREETYPE_VER}.tar.xz")
    with tarfile.open(f"{FREETYPE_VER}.tar.xz", 'r:xz') as tar:
        tar.extractall()
    
    print_banner_message(f"building {FREETYPE_VER} for android")
    os.chdir(FREETYPE_VER)
    os.system(f"./configure --host=$TOOLCHAIN_TRIPLE --prefix={os.getcwd()}/output --without-zlib --with-png=no --with-brotli=no --with-harfbuzz=no CC=clang CXX=clang++ ")
    os.system(f"make -j{jobs}  > /dev/null && make install > /dev/null")
    os.environ["FREETYPE_CFLAGS"] = f"-I{os.getcwd()}/../freetype-2.11.1/output/include/freetype2"
    os.environ["FREETYPE_LIBS"] = f"-L{os.getcwd()}/../freetype-2.11.1/output/lib"

    print_banner_message(f"here we go! building {WINE_VER} for android!")
    os.chdir(f"../{WINE_VER}")
    os.system(f"./configure --host=$TOOLCHAIN_TRIPLE host_alias=$TOOLCHAIN_TRIPLE --with-wine-tools=../{WINE_VER}-native --prefix={os.getcwd()}/dlls/wineandroid.drv/assets CC=clang CXX=clang++ > /dev/null")
    os.system("autoreconf")
    os.system(f"make -j{jobs} > /dev/null && make install > /dev/null")

    print_banner_message("fixing apk")
    shutil.copyfile(f"../{FREETYPE_VER}/output/lib/libfreetype.so dlls/wineandroid.drv/assets/x86/lib")
    os.chdir("dlls/wineandroid.drv")
    os.system("make clean > /dev/null && make > /dev/null")

    reset_environment()
    os.chdir(OG_CWD)

NDK_VERSION = "r15c"
CMDLINE_TOOLS_VERSION = "7583922_latest"
def download_android_sdks():
    make_dir_if_not_exist("android")
    os.chdir("android")

    print_banner_message("downloading and extracting cmdline tools...")
    download_no_clobber(f"https://dl.google.com/android/repository/commandlinetools-linux-{CMDLINE_TOOLS_VERSION}.zip")
    with zipfile.ZipFile(f"commandlinetools-linux-{CMDLINE_TOOLS_VERSION}.zip", "r") as zip:
        zip.extractall(".")
    
    print_banner_message("downloading and extracting NDK...")
    download_no_clobber(f"https://dl.google.com/android/repository/android-ndk-{NDK_VERSION}-linux-x86_64.zip")
    with zipfile.ZipFile(f"android-ndk-{NDK_VERSION}-linux-x86_64.zip", "r") as zip:
        zip.extractall(".")
    
    print_banner_message("installing packages and accepting licenses...")
    os.system("chmod +x cmdline-tools/bin/sdkmanager")
    os.system(f'yes | cmdline-tools/bin/sdkmanager --sdk_root={os.getcwd()} --install "build-tools;27.0.3" "tools" "platforms;android-25" "platform-tools" > /dev/null')
    os.system(f"yes | cmdline-tools/bin/sdkmanager --sdk_root={os.getcwd()} --licenses > /dev/null")

    os.chdir(OG_CWD)


def print_help():
    print("Builds WINE for Android.\n")
    print("Specify either 'build', 'clean', 'totallyclean', 'ndk', or 'auto'.")
    sys.exit()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print_help()

    if sys.argv[1] == "clean":
        if os.path.exists("build"):
            shutil.rmtree("build")
        sys.exit()
    
    if sys.argv[1] == "totallyclean":
        if os.path.exists("build"):
            shutil.rmtree("build")
        if os.path.exists("android"):
            shutil.rmtree("android")
        sys.exit()
    
    if sys.argv[1] == "ndk" or sys.argv[1] == "auto":
        download_android_sdks()
        if not sys.argv[1] == "auto":
            sys.exit()

    if sys.argv[1] == "build" or sys.argv[1] == "auto":
        build_wine_for_android(multiprocessing.cpu_count())
        sys.exit()


    print_help()
