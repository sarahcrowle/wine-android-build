#!/usr/bin/env ruby

require 'optparse'
require 'set'
require 'fileutils'
require 'etc'
require 'yaml'

class String
    def black;          "\e[30m#{self}\e[0m" end
    def red;            "\e[31m#{self}\e[0m" end
    def green;          "\e[32m#{self}\e[0m" end
    def brown;          "\e[33m#{self}\e[0m" end
    def blue;           "\e[34m#{self}\e[0m" end
    def magenta;        "\e[35m#{self}\e[0m" end
    def cyan;           "\e[36m#{self}\e[0m" end
    def gray;           "\e[37m#{self}\e[0m" end
    
    def bg_black;       "\e[40m#{self}\e[0m" end
    def bg_red;         "\e[41m#{self}\e[0m" end
    def bg_green;       "\e[42m#{self}\e[0m" end
    def bg_brown;       "\e[43m#{self}\e[0m" end
    def bg_blue;        "\e[44m#{self}\e[0m" end
    def bg_magenta;     "\e[45m#{self}\e[0m" end
    def bg_cyan;        "\e[46m#{self}\e[0m" end
    def bg_gray;        "\e[47m#{self}\e[0m" end
    
    def bold;           "\e[1m#{self}\e[22m" end
    def italic;         "\e[3m#{self}\e[23m" end
    def underline;      "\e[4m#{self}\e[24m" end
    def blink;          "\e[5m#{self}\e[25m" end
    def reverse_color;  "\e[7m#{self}\e[27m" end
end

def ignore_exception
    begin
      yield  
    rescue Exception
    end
 end 


# Parse arguments
options = {}
option_parser = OptionParser.new do |opts|
    opts.banner = "Usage: make.rb -h <COMMIT HASH> -w <WINE VERSION> [options] OR make.rb --[totally]clean OR make.rb -p <PROJECT DIR> [options]"

    opts.on("-c", "--ccompiler=C", "C compiler name for NDK build") do |name|
        options[:cc] = name
    end

    opts.on("-x", "--cxxcompiler=CXX", "C++ compiler name for NDK build") do |name|
        options[:cxx] = name
    end

    opts.on("-h", "--commithash=HASH", "Wine commit hash to clone") do |hash|
        options[:commithash] = hash
    end

    opts.on("-w", "--wineversion=VER", "Wine version to patch") do |ver|
        options[:wineversion] = ver
    end

    opts.on("-f", "--freetypeversion=VER", "Freetype version to build") do |ver|
        options[:freetypeversion] = ver
    end

    opts.on("-n", "--newpackagename=NAME", "New package name for the app") do |name|
        options[:newpackagename] = name
    end

    opts.on("-N", "--newappname=NAME", "New name for the app's activity in launcher") do |name|
        options[:newappname] = name
    end

    opts.on("-i", "--icon=PNG", "Path to a PNG icon to use for the app") do |filename|
        options[:iconfile] = filename
    end

    opts.on("-p", "--project=DIR", "Path to a project dir containing a wine-package.yml") do |dir|
        options[:project] = dir
    end

    opts.on("--clean", "Clean out build/ directory") do |x|
        options[:clean] = true
    end

    opts.on("--totallyclean", "Totally clean everything") do |x|
        options[:totallyclean] = true
    end

    opts.on("--tools", "Set up tooling") do |x|
        options[:tools] = true
    end

    opts.on("--dlwine", "Download, copy, and patch Wine source") do |x|
        options[:dlwine] = true
    end

    opts.on("--nativewine", "Build native Wine") do |x|
        options[:nativewine] = true
    end

    opts.on("--dlfreetype", "Download and extract freetype") do |x|
        options[:dlfreetype] = true
    end

    opts.on("--freetype", "Build freetype for Android") do |x|
        options[:freetype] = true
    end

    opts.on("--androidwine", "Build Wine for Android") do |x|
        options[:androidwine] = true
    end

    opts.on("--dlvwine", "Download vanilla Wine") do |x|
        options[:dlvwine] = true
    end

    opts.on("--crimes", "Patch vanilla Wine") do |x|
        options[:crimes] = true
    end
end
option_parser.parse!


unless options[:project].nil?
    all_option_types = [:cc, :cxx, :commithash, :wineversion, :freetypeversion, \
                    :newpackagename, :newappname, :iconfile, :clean, :totallyclean, \
                    :tools, :dlwine, :nativewine, :dlfreetype, :freetype, :androidwine, \
                    :dlvwine, :crimes, :injectedsoftwaredir, :injectedsoftwaremain]
    
    project = YAML.load(File.read(options[:project] + "/wine-package.yml").gsub! "$PROJECTDIR", File.expand_path(options[:project]))
    
    for option in all_option_types
        unless options.key?(option)
            if project.key?(option)
                puts "setting option from project: %s = %s" % [option.to_s, project[option]]
                options[option] = project[option]
            end
        end
    end
end

# require wine version and commit hash to be specified
if options[:commithash].nil? or options[:wineversion].nil?
    unless options[:totallyclean] or options[:clean]
        puts option_parser.help
        exit 1
    else
        options[:commithash] = "INVALID"
        options[:wineversion] = "INVALID"
    end
end

# establish defaults for missing params
options[:cc] ||= "clang"
options[:cxx] ||= "clang++"
options[:freetypeversion] ||= "2.11.1"

targets = [:clean, :totallyclean, :tools, :dlwine, :nativewine,\
 :dlfreetype, :freetype, :androidwine, :dlvwine, :crimes]

 # if there are no targets specified
unless (options.keys & targets).any?
    puts "No targets specified. Making all"

    options[:tools] = true
    options[:dlwine] = true
    options[:nativewine] = true
    options[:dlfreetype] = true
    options[:freetype] = true
    options[:androidwine] = true
    options[:dlvwine] = true
    options[:crimes] = true
end

for target in targets
    if options[target].nil?
        options[target] = false  # we don't want ANY nils, set nonexistent targets to false
    end
end

puts options

if options[:totallyclean] or options[:clean]
    delete_directory = -> (dir) { FileUtils.remove_dir(dir) if File.directory?(dir) }
    delete_directory.call("build")

    if options[:totallyclean]
        delete_directory.call("dex-tools-2.1")
        delete_directory.call("apktool")
        delete_directory.call("android")
        delete_directory.call("org")
        Dir.glob('*.zip').each { |file| File.delete(file)}
    end
end

if options[:commithash] == "INVALID" or options[:wineversion] == "INVALID"
    exit 1
end

if options[:tools]
    puts " -> Downloading and setting up tools...".blue.reverse_color

    FileUtils.mkdir_p "android"
    Dir.chdir("android") do
        puts "    -> cmdline-tools".green.reverse_color
        `wget -nc https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip > /dev/null`
        `unzip -n commandlinetools-linux-7583922_latest.zip > /dev/null`

        puts "    -> NDK".green.reverse_color
        `wget -nc https://dl.google.com/android/repository/android-ndk-r17c-linux-x86_64.zip  > /dev/null`
        `unzip -n android-ndk-r17c-linux-x86_64.zip > /dev/null`

        puts "    -> Installing required packages/accepting licenses".green.reverse_color
        `chmod +x cmdline-tools/bin/sdkmanager`
        `yes | cmdline-tools/bin/sdkmanager --sdk_root=$(pwd) --install "build-tools;27.0.3" "tools" "platforms;android-25" "platform-tools" > /dev/null`
        `yes | cmdline-tools/bin/sdkmanager --sdk_root=$(pwd) --licenses > /dev/null`
    end

    puts "    -> dex2jar".green.reverse_color
    `wget -nc https://github.com/pxb1988/dex2jar/releases/download/v2.1/dex2jar-2.1.zip  > /dev/null`
    `unzip -n dex2jar-2.1.zip > /dev/null`

    FileUtils.mkdir_p "apktool"
    Dir.chdir("apktool") do
        puts "    -> apktool".green.reverse_color
        `wget -nc https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.6.0.jar -O apktool.jar > /dev/null`
        `wget -nc https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool -O apktool  > /dev/null`
        `chmod +x apktool`
    end
end

# initial env setup
ENV["ANDROID_HOME"] = "%s/android/" % [Dir.pwd]
ENV["NDK_ROOT"] = "%s/android/android-ndk-r17c/" % [Dir.pwd]
ENV["TOOLCHAIN_VERSION"] = "x86_64"
ENV["TOOLCHAIN_TRIPLE"] = "x86_64-linux-android"

FileUtils.mkdir_p "build"

Dir.chdir("build") do
    if options[:androidwine] or options[:freetype]
        `$NDK_ROOT/build/tools/make-standalone-toolchain.sh --platform=android-26 --install-dir=android-toolchain --arch=$TOOLCHAIN_VERSION --verbose`
    end

    if options[:dlwine]
        puts " -> Downloading Wine source...".blue.reverse_color
        system("wget -nc https://github.com/wine-mirror/wine/archive/%s.zip -O wine.zip > /dev/null" % [options[:commithash]])
        
        puts "    -> Extracting!".green.reverse_color
        `unzip -n wine.zip`

        puts "    -> Copying!".green.reverse_color
        FileUtils.mv("wine-%s" % [options[:commithash]], "wine", :force => true)
        FileUtils.cp_r("wine", "wine-native", :remove_destination => true)

        puts "    -> Patching!".green.reverse_color
        `patch -p1 -d wine < ../wine-android-configure.patch`
        `patch -p1 -d wine < ../wine-android-makefile-in.patch`
        `patch -p1 -d wine < ../wine-android-gradle.patch`
        `patch -p1 -d wine < ../wine-gradle-properties.patch`
    end

    if options[:nativewine]
        puts " -> Building native wine".blue.reverse_color
        Dir.chdir("wine-native") do
            `./configure --enable-win64 > /dev/null`
            system("make -j%d > /dev/null" % [Etc.nprocessors])
        end
    end

    ENV["PATH"] = "%s/android-toolchain/bin:" % [Dir.pwd] + ENV["PATH"]
    
    if options[:dlfreetype]
        puts " -> Downloading freetype source...".blue.reverse_color
        system("wget -nc https://download.savannah.gnu.org/releases/freetype/freetype-%s.tar.xz" % [options[:freetypeversion]])
        system("tar xf freetype-%s.tar.xz" % [options[:freetypeversion]])
    end

    if options[:freetype]
        puts " -> Building freetype for Android...".blue.reverse_color

        Dir.chdir("freetype-%s" % [options[:freetypeversion]]) do
            system("./configure --host=$TOOLCHAIN_TRIPLE --prefix=%s/output --without-zlib \
                --with-png=no --with-brotli=no --with-harfbuzz=no CC=%s CXX=%s > /dev/null" % [Dir.pwd, options[:cc], options[:cxx]])
            system("make -j%d > /dev/null && make install > /dev/null" % [Etc.nprocessors])
        end

        ENV["FREETYPE_CFLAGS"] = "-I%s/freetype-2.11.1/output/include/freetype2" % [Dir.pwd]
        ENV["FREETYPE_LIBS"] = "-L%s/freetype-2.11.1/output/lib" % [Dir.pwd]
    end
    
    if options[:androidwine]
        puts " -> Building Wine for Android!".blue.reverse_color

        Dir.chdir("wine") do
            # FIXME: hax
            if options[:injectedsoftwaremain]
                puts "    -> Patching the Wine activity!".green.reverse_color

                if File.file?("dlls/wineandroid.drv/WineActivity.java.old")
                    FileUtils.rm("dlls/wineandroid.drv/WineActivity.java")
                    FileUtils.cp("dlls/wineandroid.drv/WineActivity.java.old", "dlls/wineandroid.drv/WineActivity.java")
                    FileUtils.rm("dlls/wineandroid.drv/WineActivity.java.old")
                end

                FileUtils.cp("dlls/wineandroid.drv/WineActivity.java", "dlls/wineandroid.drv/WineActivity.java.old")
                FileUtils.rm("dlls/wineandroid.drv/WineActivity.java")

                patch_text = File.read("dlls/wineandroid.drv/WineActivity.java.old")
                patch_new = patch_text.sub "cmdline };", "\"%s\%s\" };" % ["Z:\\\\data\\\\user\\\\0\\\\%s\\\\files\\\\x86\\\\lib\\\\wine\\\\" % [options[:newpackagename]], options[:injectedsoftwaremain]]
                File.open("dlls/wineandroid.drv/WineActivity.java", "w") {|file| file.puts(patch_new)}
            end

            puts "    -> Doing build!".green.reverse_color
            system("./configure --host=$TOOLCHAIN_TRIPLE host_alias=$TOOLCHAIN_TRIPLE \
                --with-wine-tools=../wine-native \
                --prefix=%s/dlls/wineandroid.drv/assets --enable-win64 CFLAGS=-O3 CXXFLAGS=-O3 \
                CC=%s CXX=%s > /dev/null" % [Dir.pwd, options[:cc], options[:cxx]])
            system("autoreconf")
            system("make -j%d > /dev/null && make install > /dev/null" % [Etc.nprocessors])
        
            puts "    -> Fixing APK".green.reverse_color
            ignore_exception { FileUtils.cp("../freetype-2.11.1/output/lib/libfreetype.so", "dlls/wineandroid.drv/assets/x86_64/lib64/") }
            ignore_exception { FileUtils.cp("../freetype-2.11.1/output/lib/libfreetype.so", "dlls/wineandroid.drv/assets/x86_64/lib/") }
            Dir.chdir("dlls/wineandroid.drv") do
                `make clean > /dev/null`
                `make > /dev/null`
            end
        end
    end
end

if options[:crimes]
    puts " -> Committing crimes...".blue.reverse_color
    FileUtils.cp("wine-vanilla.apk", "wine-patched.apk")
    `bash gimmeapk .`
    `unzip wine-debug.apk classes.dex > /dev/null`
    `dex-tools-2.1/d2j-dex2jar.sh -f -o fresh-build.jar classes.dex > /dev/null`
    FileUtils.rm("classes.dex")
    `bash replaceclasses.sh wine-patched.apk fresh-build.jar org/winehq/wine > /dev/null`
    FileUtils.rm("fresh-build.jar")
    FileUtils.rm_rf("wine-patched")
end

if options[:newpackagename] or options[:newappname]
    # set defaults if nothing was specified
    options[:newpackagename] ||= "org.winehq.wine"
    options[:newappname] ||= "Wine"

    puts " -> Replacing package/app name...".blue.reverse_color
    puts "    -> New package name is %s, new app name is %s".green.reverse_color % [options[:newpackagename], options[:newappname]]
    system("bash replacenames %s %s wine-patched.apk" % [options[:newpackagename], options[:newappname]])
end

if options[:iconfile]
    puts " -> Replacing icon files...".blue.reverse_color
    options[:iconfile] = File.expand_path(options[:iconfile])
    puts "    -> New icon file path is %s".green.reverse_color % [options[:iconfile]]
    system("bash replaceicons %s wine-patched.apk" % [options[:iconfile]])
end

if options[:injectedsoftwaredir]
    puts " -> Injecting software files...".blue.reverse_color
    system("bash injectsoftware %s wine-patched.apk" % [options[:injectedsoftwaredir]])
end

puts "########## BUILD COMPLETE! ##########".reverse_color