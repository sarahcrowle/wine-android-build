# wine-android-build
Automated tools to patch and build WINE for Android.

## How to build
- You're gonna need some prerequisites. Namely, Git, Gradle, Python (2), and whatever you need to build a normal version of Wine. On a Debian based system, you can get
  everything you need with:
  ```
  sudo apt install gradle python git
  sudo apt build-dep wine
  ```
- Now that you've got everything, IN THEORY, you should be able to clone this repo into a folder somewhere, then run `./make <wine commit hash> <compatible vanilla wine version>`. 
  Note the `./`. I don't know why I named it so ambiguously.
- By default, the script actually uses a vanilla build of Wine as a base that gets patched with the org.winehq.wine package that the build generates. This seems to make more compatible builds?
  If you want to use the full build that the script makes, use `wine-debug.apk`. Otherwise, you're mostly going to want `wine-patched.apk` instead.


## Interesting notes (aka the WTF section)

- At the moment, Wine must be built using a REALLY old NDK. (r15c to be exact). This is because of the new "unified headers" stuff that got deprecated not long
  after that version.
- You can't use an x86 build on an x86_64 device (this one is not REALLY all that bad, but it's annoying nonetheless)
- You can't build Wine with GCC 4.9.x anymore. GCC 4.9.x is also the default for this ancient NDK. Thank god `clang` is still here in this version.
- The `./configure` script is broken for Android. The build won't work because it looks for the APK in the wrong place. Then how do they build the Android version
  upstream!?
- The `build.gradle` script is also broken. The build won't work because jCenter doesn't exist. It also uses some super ancient versions of all the packages, which
  (believe it or not) don't work with modern versions of Gradle.
- Not broken (I guess), but Gradle's default config doesn't have nearly enough heap space allocated for packaging the assets in the APK. I just added a
  `gradle.properties` file to give it a few more gigs.
- Like all cross compilation thingies, these build steps are absurdly sensitive to the environment. That's why:
    * The script sucks. I'm way too dumb to get a better, less awful, hardcoded script working right now. I probably will eventually. You can see my pathetic failed
      attempt in `make.py` (which you shouldn't use lmao)
    * You should really build this in a Docker container or something. The cleaner the environment the better. I did all my testing in a Debian 11 VM. A container
      would have been easier. Seriously.
- Some versions after 6.5 hang on "Setting up Windows environment...". Reason unknown. Some change between 6.4 and 6.5?
- You may be familiar with the infamous "gray screen" bug in the Android port. This doesn't happen in Wine versions between (at least) 6.0 and 6.4... Why?
 
 ## License
 For reasons of not caring enough to look up if the LGPL has to spread to my script or not, due to the included Wine patches this repository is under the LGPL.
 See `LICENSE.md`.
