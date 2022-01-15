# Packaging tools for Wine Android
Automated tools to patch and build Wine for Android.

## How to build
- You're gonna need some prerequisites. Namely, Git, Gradle, rsync, Python (2), Ruby, and whatever you need to build a normal version of Wine. On a Debian based system, you can get
  everything you need with:
  ```
  sudo apt install gradle python ruby git rsync
  sudo apt build-dep wine
  ```
- Now that you've got everything, IN THEORY, you should be able to clone this repo into a folder somewhere, then run `./make <wine commit hash> <compatible vanilla wine version>`. 
  Note the `./`. I don't know why I named it so ambiguously.
- By default, the script actually uses a vanilla build of Wine as a base that gets patched with the org.winehq.wine package that the build generates. This seems to make more compatible builds?
  If you want to use the full build that the script makes, use `wine-debug.apk`. Otherwise, you're mostly going to want `wine-patched.apk` instead.

### Recommended (known working) Wine commit hash/version combos
- "4336ed0b84b3dd3097bbbbf8e4b9de2e4d444ad7 6.4" - Wine 6.4 release version **(THIS IS THE MOST COMPATIBLE VERSION I'VE FOUND)**
    * You can safely ignore the wine-android-configure patch failure. That part of configure.ac is irrelevant in this old version, since the Makefile.in patch covers that change.
- "86eaf7eeb2603d1b13d18e3fe71a615e1ee14cee 7.0-rc5" - Wine 7.0-rc5 release candidate
    * You can safely ignore the wine-android-makefile-in patch failure. That part of Makefile.in is irrelevant in this old version, since the configure.ac patch covers that change.

### Automating the process (injecting software into the build)
Recently, support was added for "projects". This feature (as well as making builds more repeatable) lets you inject arbitrary software into the APK that runs at Wine startup. 
Essentially, this lets you package Windows software for Android!

A basic project consists of a directory with a `wine-package.yml` inside. Any option that can be supplied on the command line can be specified in here (plus more). There are also additional, 
exclusive options. There's a full list of options below. A basic `wine-package.yml` looks like this (pulled from the sample project located in `sample-project/`):

```yaml
---
:commithash: "4336ed0b84b3dd3097bbbbf8e4b9de2e4d444ad7"
:wineversion: "6.4"
:iconfile: $PROJECTDIR/bread-icon.png
:newpackagename: com.picsofbread.wine
:newappname: PicsOfWine
:injectedsoftwaredir: $PROJECTDIR/bread-hello/
:injectedsoftwaremain: bread-hello\\bread-hello-vc2008.exe
```

`$PROJECTDIR` gets replaced with the full path to the project directory.

Note the options `:injectedsoftwaredir` and `:injectedsoftwaremain` above. These specify both the directory where the software lives, and the relative path within the install dir that Wine needs 
to execute it. As long as these options are specified correctly, software injection *should* work.

To build using a project, run `./make -p <project dir>`. Any options not specified in the `wine-package.yml` will be replaced with (somewhat) sane defaults.

#### Full list of project options, and what they do
- `:cc`
  * Specify a different C compiler for building the Android stuff (default: clang)
- `:cxx`
  * Specify a different C++ compiler for building the Android stuff (default: clang++)
- `:commithash`
  * Specify a Wine Git commit hash to build from (required, no default)
- `:wineversion`
  * Specify a Wine vanilla version to patch (required, no default)
- `:freetypeversion`
  * Specify a version of Freetype to build for Android (default: 2.11.1)
- `:newpackagename`
  * Specify a new name for the patched Wine app (default: n/a)
- `:newappname`
  * Specify a new app title for the patched Wine app (default: n/a)
- `:iconfile`
  * Specify a PNG app icon for the patched Wine app (default: n/a)
- `:injectedsoftwaredir`
  * Specify a directory to inject into the patched Wine app (default: n/a)
- `:injectedsoftwaremain`
  * Specify what executable/command Wine should run to execute your injected software (default: n/a)

#### Full list of project target options, and what they do
- `:clean`
  * Set to true to clean out the `build/` directory
- `:totallyclean`
  * Set to true to clean out the `build/` directory AND the tools directories
- `:tools`
  * Set to true to download and set up tools
- `:dlwine`
  * Set to true to download, extract, and patch the Wine source directories
- `:nativewine`
  * Set to true to build native Wine
- `:dlfreetype`
  * Set to true to download/extract Freetype
- `:freetype`
  * Set to true to build Freetype for Android
- `:androidwine`
  * Set to true to build Wine for Android
- `:dlvwine`
  * Set to true to download vanilla Wine APK
- `:crimes`
  * Set to true to commit crimes (apply patches to vanilla Wine)

## Interesting notes (aka the WTF section)

- ~~At the moment, Wine must be built using a REALLY old NDK. (r15c to be exact). This is because of the new "unified headers" stuff that got deprecated not long
  after that version.~~ **Fixed 2022/01/13**
- ~~You can't use an x86 build on an x86_64 device (this one is not REALLY all that bad, but it's annoying nonetheless)~~ **Was never a problem lol**
- ~~You can't build Wine with GCC 4.9.x anymore. GCC 4.9.x is also the default for this ancient NDK. Thank god `clang` is still here in this version.~~ **Fixed 2022/01/13**
- The `./configure` script is broken for Android. The build won't work because it looks for the APK in the wrong place. Then how do they build the Android version
  upstream!?
- The `build.gradle` script is also broken. The build won't work because jCenter doesn't exist. It also uses some super ancient versions of all the packages, which
  (believe it or not) don't work with modern versions of Gradle.
- Not broken (I guess), but Gradle's default config doesn't have nearly enough heap space allocated for packaging the assets in the APK. I just added a
  `gradle.properties` file to give it a few more gigs.
- Like all cross compilation thingies, these build steps are absurdly sensitive to the environment. That's why:
    * ~~The script sucks. I'm way too dumb to get a better, less awful, hardcoded script working right now. I probably will eventually. You can see my pathetic failed
      attempt in `make.py` (which you shouldn't use lmao)~~ **2022/01/13 - the script's been rewritten in Ruby. much cleaner.**
    * You should really build this in a Docker container or something. The cleaner the environment the better. I did all my testing in a Debian 11 VM. A container
      would have been easier. Seriously.
- Some versions after 6.5 hang on "Setting up Windows environment...". Reason unknown. Some change between 6.4 and 6.5?
- You may be familiar with the infamous "gray screen" bug in the Android port. This doesn't happen in Wine versions between (at least) 6.0 and 6.4... Why?
 
 ## License
 For reasons of not caring enough to look up if the LGPL has to spread to my script or not, due to the included Wine patches this repository is under the LGPL.
 See `LICENSE.md`.
