#!/bin/bash

set -e

function show_help()
{
  if [ "$1" = "main" ] ; then
    echo "Script for automating the process of installing dependencies"
    echo "and compiling Worldforge in a self contained environment."
    echo ""
    echo "Usage: hammer.sh [<options>] <command> <target>"
    echo "Commands:"
    echo "  install-deps   -  install all 3rd party dependencies"
    echo "  checkout       -  fetch worldforge source (libraries, clients)"
    echo "  build          -  build the sources and install in environment"
    echo "  clean          -  delete build directory so a fresh build can be performed"
    echo "  release_ember  -  change ember to a specific release"
    echo ""
    echo "Options:"
    echo "  debug          -  Build for debuging instead of max performance"
    echo "  cross-compile  -  Compile to different platform: --cross_compile=android"
    echo "                    Can be android (=ARMv7), android-ARMv7 or android-x86"
    echo "  make_flags     -  Variable passed to every make call: --make_flags=\"-j4\""
    echo "  configure_flags-  Variable passed to every configure call"
    echo "  cmake_flags    -  Variable passed to every cmake call"
    echo "  compile_flags  -  Variable passed to the compiler"
    echo "  link_flags     -  Variable passed to the linker"
    echo "  force-autogen  -  Force autogen when it is already autogenerated"
    echo "  force-configure-  Force configure when it is already configured"
    echo ""
    echo "For more help, type: hammer.sh help <command>"
  elif [ "$1" = "install-deps" ] ; then
    echo "Install all 3rd party dependencies into build environment."
    echo ""
    echo "Usage: hammer.sh install-deps <dependency to install>"
    echo "Dependencies Available:"
    echo "  all      -  install all dependencies listed below"
    echo "  cegui    -  a free library providing windowing and widgets for "
    echo "              graphics APIs / engines"
    echo "  ogre     -  3D rendering engine"
    echo "  cg       -  interactive effects toolkit"
    echo "  basedir  -  implementation of the XDG Base Directory specifications"
    ,
    echo "Hint: build ogre first then cegui"
  elif [ "$1" = "checkout" ] ; then
    echo "Fetch latest source code for worldforge libraries and clients."
    echo "If you want Hammer to stash away any local changes, use the"
    echo "environment variable HAMMERALWAYSSTASH=yes."
    echo ""
    echo "Usage: hammer.sh checkout <target>"
    echo "Available targets:"
    echo "  all      - fetch everything"
    echo "  libs     - fetch libraries only"
    echo "  ember    - fetch ember only"
    echo "  webember - fetch ember and webember"
    echo "  cyphesis - fetch cyphesis server only"
    echo "  worlds   - fetch worlds only"
  elif [ "$1" = "build" ] ; then
    echo "Build the sources and install in environment."
    echo ""
    echo "Usage: hammer.sh build <target>"
    echo "Available targets:"
    echo "  all      - build everything"
    echo "  libs     - build libraries only"
    echo "  ember    - build ember only"
    echo "  webember - build webember only"
    echo "  cyphesis - build cyphesis server only"
    echo "  worlds   - build worlds only"
    echo ""
    echo "Hint: after a checkout use 'all'. To rebuild after changing code"
    echo "only in Ember, use 'ember'. Will build much quicker!"
  elif [ "$1" = "clean" ] ; then
    echo "Clean out build files of a project."
    echo ""
    echo "Usage: hammer.sh clean <target>"
    echo "Targets:"
    echo "  cegui, ogre, libs/<name>, clients/<name>, servers/<name>"
  elif [ "$1" = "release_ember" ] ; then
    echo "Build a specific release of Ember, including latest stable libraries."
    echo "Do not run this command as root, AppImage building will fail."
    echo ""
    echo "Usage: hammer.sh release_ember <version number> [<target>]"
    echo "Available targets [optional]:"
    echo "  dir        - build into a standard directory structure"
    echo "  image      - build an AppImage or AppBundle (Default)"
    echo ""
    echo "e.g. hammer.sh release_ember 0.7.1 dir"
  else
    echo "No help page found!"
  fi
}

if [ $# -eq 0 ] ; then
  show_help "main"
  exit 1
fi

#default flags, which can be changed with hammer.sh flags
#Change these for custom builds.
export DEBUG_BUILD=0 # Can be 0 (release build) or 1 (debug build). Only used if COMPILE_FLAGS is empty!

export MAKE_FLAGS="-j5"
export CONFIGURE_FLAGS=""
export CMAKE_FLAGS=""
export COMPILE_FLAGS=""
export LINK_FLAGS=""
export FORCE_AUTOGEN=0 # Can be 0 or 1.
export FORCE_CONFIGURE=0 # Can be 0 or 1.

export TARGET_OS="native" # Can be native or android.

# NOTE: These are only valid for non-native builds
export TARGET_ARCH="ARMv7" # Can be ARMv7 or x86. (ARMv6, ARMv8, ARM_NEON, MIPS may be added later)

if [[ $OSTYPE == *darwin* ]] ; then
  export HOST_ARCH="x86_64" # On OS X -p option returns i386, but in reality its 64 bit.
  export HOST_OS="$(uname -s)" # == "Darwin". On OS X -o option is unsupported.
else
  export HOST_ARCH="$(uname -p)" # Can be x86_64 or x86.
  if [[ $HOST_ARCH = i[3456]86 ]] ; then
    export HOST_ARCH=x86
  fi
  export HOST_OS="$(uname -o)" # Can be GNU/Linux.
fi

# Directory hierarchy base
export HAMMERDIR=$PWD # It should contain hammer.sh file only.
export WORKDIR=$HAMMERDIR/work # It should contain anything generated.
export SUPPORTDIR=$HAMMERDIR/support # It should contain any other script.


EMBER_VER="master"
WEBEMBER_VER="master"
VARCONF_VER="master"
ATLAS_CPP_VER="master"
SKSTREAM_VER="master"
WFMATH_VER="master"
ERIS_VER="master"
LIBWFUT_VER="master"
MERCATOR_VER="master"
WORLDS_VER="master"
CYPHESIS_VER="master"
FIREBREATH_VER="master"
MEDIA_VER="dev"

while :
do
  case $1 in
    help | -h | --help | -\?)
      if [ $# -eq 2 ] ; then
        show_help "$2"
      else
        show_help "main"
      fi
      exit 0
      ;;
    -t=* | --cross_compile=* | --cross-compile=*) # --cross-compile=android
      TARGET_NAME=${1#*=}
      if [ "$TARGET_NAME" = "android" ] || [ "$TARGET_NAME" = "android-ARMv7" ]; then
        export TARGET_OS="android"
        export TARGET_ARCH="ARMv7"
      elif [ "$TARGET_NAME" = "android-x86" ]; then
        export TARGET_OS="android"
        export TARGET_ARCH="x86"
      else
        echo "Unknown target '$TARGET_NAME'!"
        exit 1
      fi
      shift
      ;;
    -d | --debug)
      export DEBUG_BUILD=1
      shift
      ;;
    --make_flags=* | --make-flags=*) # --make_flags="-j4"
      export MAKE_FLAGS=${1#*=}
      shift
      ;;
    --configure_flags=* | --configure-flags=*) # --configure_flags="--static"
      export CONFIGURE_FLAGS=${1#*=}
      shift
      ;;
    --cmake_flags=* | --cmake-flags=*) # --cmake_flags="-DOGRE_UNITY_BUILD=true"
      export CMAKE_FLAGS=${1#*=}
      shift
      ;;
    --compile_flags=* | --compile-flags=*) # --compile_flags="-O0 -g"
      export COMPILE_FLAGS=${1#*=}
      shift
      ;;
    --link_flags=* | --compile-flags=*) # --link_flags="-L/usr/lib -lfoo"
      export LINK_FLAGS=${1#*=}
      shift
      ;;
    -a | --force-autogen | --force_autogen)
      export FORCE_AUTOGEN=1
      shift
      ;;
    -c | --force-configure | --force_configure)
      export FORCE_CONFIGURE=1
      shift
      ;;
    --use-release-ember=*)
      EMBER_VER="release-${1#*=}"
      shift
      ;;
    --use-release-media=*)
      MEDIA_VER="${1#*=}"
      shift
      ;;
    --use-release-libs)
      VARCONF_VER=1.0.1
      ATLAS_CPP_VER=0.6.3
      SKSTREAM_VER=0.3.9
      WFMATH_VER=1.0.2
      ERIS_VER=1.3.23
      LIBWFUT_VER=libwfut-0.2.3
      WORLDS_VER="master"
      CYPHESIS_VER=0.6.2
      MERCATOR_VER=0.3.3
      shift
      ;;
    -*)
      printf >&2 'Unknown option: %s\n' "$1"
      exit 1
      ;;
    *)  # end of options.
      break
      ;;
  esac
done

#+++++++++++++++++++++
#+ Setup environment +
#+++++++++++++++++++++

# It will use the settings from above to set up the environment.
# You can use pop_env to get back to system environment.
#$SUPPORTDIR/setup_env.sh push_env #Use this to debug setup_env.sh
eval $($SUPPORTDIR/setup_env.sh push_env)
echo "Building for $BUILDDIR!"

# Define component versions
CEGUI_VER=cegui-0.8.7
CEGUI_DOWNLOAD=cegui-0.8.7.tar.bz2
OGRE_VER=ogre_1_9_0
OGRE_DOWNLOAD=v1-9-0.tar.bz2
CG_VER=3.1
CG_FULLVER=${CG_VER}.0013
CG_DOWNLOAD=Cg-3.1_April2012
FREEALUT_VER=1.1.0
TOLUA_VER="tolua++-1.0.93"
BASEDIR_VER=1.2.0

# setup directories
mkdir -p "$PREFIX" "$DEPS_SOURCE" "$SOURCE" "$DEPS_BUILD" "$BUILD" "$LOGDIR"

# Output redirect logs
AUTOLOG=autogen.log     # Autogen output
CONFIGLOG=config.log    # Configure output
MAKELOG=build.log       # Make output
INSTALLLOG=install.log  # Install output

function buildwf()
{
    if [ x"$2" = x"" ]; then
      PRJNAME="$1"
    else
      PRJNAME="$2"
    fi

    mkdir -p "$LOGDIR/$PRJNAME"
    
    if [ ! -d "$SOURCE/$1" ] ; then
      echo "The source directory is missing!"
      echo "Try: ./hammer.sh help checkout"
      exit 1
    fi
    
    cd "$SOURCE/$1"
    if [ $FORCE_AUTOGEN -eq 1 ] || [ ! -f "configure" ] ; then
      echo "  Running autogen..."
      NOCONFIGURE=1 ./autogen.sh > "$LOGDIR/$PRJNAME/$AUTOLOG"
    fi

    mkdir -p "$BUILD/$1/$BUILDDIR"
    cd "$BUILD/$1/$BUILDDIR"
    if [ $FORCE_CONFIGURE -eq 1 ] || [ ! -f "Makefile" ] ; then
      echo "  Running configure..."
      "$SOURCE/$1/configure" $CONFIGURE_FLAGS > "$LOGDIR/$PRJNAME/$CONFIGLOG"
    fi

    echo "  Building..."
    make $MAKE_FLAGS > "$LOGDIR/$PRJNAME/$MAKELOG"
    echo "  Installing..."
    make install > "$LOGDIR/$PRJNAME/$INSTALLLOG"
    
    # Sometimes libtool installs some of our libs as relative, but with absolute path.
    # If a path in *.la file starts with =, then it is relative. Make them absolute.
	if [[ $OSTYPE == *darwin* ]] ; then
		find $PREFIX/lib/*.la -type f -print0 | xargs -0 sed -i '' -e 's,=/,/,g'
	else
		find $PREFIX/lib/*.la -type f -print0 | xargs -r -0 sed -i 's,=/,/,g'
		find $PREFIX/lib64/*.la -type f -print0 | xargs -r -0 sed -i 's,=/,/,g'
	fi
}

function checkoutwf()
{
  if [ x"$2" = x"" ]; then
    USER="worldforge"
  else
    USER="$2"
  fi
  if [ x"$3" = x"" ]; then
    # atlas-cpp ==> ATLAS_CPP
    BRANCH="$(echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_')_VER"
    # ATLAS_CPP ==> master
    BRANCH="${!BRANCH}"
  else
    BRANCH="$3"
  fi
  echo "Getting $1 $BRANCH"
  if [ ! -d "$1" ]; then
    git clone "https://github.com/$USER/$1.git" -b "$BRANCH"
  else
    cd "$1"
    if [ x"$HAMMERALWAYSSTASH" = x"yes" ]; then
      git stash save "Hammer stash"
    fi
    git remote set-url origin "https://github.com/$USER/$1.git" && git fetch && git rebase "origin/$BRANCH" && cd ..
  fi
}

function cyphesis_post_install()
{
  cd "$PREFIX/bin"

  # Rename real cyphesis binary to cyphesis.bin
  mv cyphesis cyphesis.bin

  # Install our cyphesis.in script as cyphesis
  cp "$SUPPORTDIR/cyphesis.in" cyphesis
  chmod +x cyphesis
}



function install_deps_cg()
{
    # Cg Toolkit
    echo "  Installing Cg Toolkit..."
    if [[ $OSTYPE == *darwin* ]] ; then
      CG_DOWNLOAD+=".dmg"
      CG_LIB_LOCATION="Library/Frameworks/Cg.framework/Versions/1.0/Cg"
    elif [[ $OSTYPE == linux-gnu ]] ; then
      if [[ $BUILDDIR == native-64 ]] ; then
        CG_DOWNLOAD+="_x86_64.tgz"
        CG_LIB_LOCATION="usr/lib64/libCg.so"
      elif [[ $BUILDDIR == native-32 ]] ; then
        CG_DOWNLOAD+="_x86.tgz"
        CG_LIB_LOCATION="usr/lib/libCg.so"
      fi
    fi
    mkdir -p "$LOGDIR/deps/cg"
    cd "$DEPS_SOURCE"
    if [ ! -d "Cg_$CG_FULLVER" ]; then
      echo "  Downloading..."
      curl -C - -OL "http://developer.download.nvidia.com/cg/Cg_$CG_VER/$CG_DOWNLOAD"
      if [[ $OSTYPE == *darwin* ]] ; then
        hdiutil mount "$CG_DOWNLOAD"
        cp "/Volumes/Cg-${CG_FULLVER}/Cg-${CG_FULLVER}.app/Contents/Resources/Installer Items/NVIDIA_Cg.tgz" .
        hdiutil unmount "/Volumes/Cg-$CG_FULLVER/"
        CG_DOWNLOAD="NVIDIA_Cg.tgz"
      fi
      mkdir -p "Cg_$CG_FULLVER"
      cd "Cg_$CG_FULLVER"
      tar -xf "../$CG_DOWNLOAD"
    fi
    mkdir -p "$PREFIX/lib"
    cp "$DEPS_SOURCE/Cg_${CG_FULLVER}/$CG_LIB_LOCATION" "$PREFIX/lib"
    echo "  Done."
}

function install_deps_ogre()
{
    # Ogre3D
    echo "  Installing Ogre..."
    mkdir -p "$LOGDIR/deps/ogre"
    cd "$DEPS_SOURCE"
    if [ ! -d $OGRE_VER ]; then
      echo "  Downloading..."
      curl -C - -OL "https://bitbucket.org/sinbad/ogre/get/$OGRE_DOWNLOAD"
      mkdir -p "$OGRE_VER"
      cd "$OGRE_VER"
      tar -xjf "../$OGRE_DOWNLOAD"
      OGRE_SOURCE="$DEPS_SOURCE/$OGRE_VER/$(ls "$DEPS_SOURCE/$OGRE_VER")"
      if [[ $OSTYPE == *darwin* ]] ; then
        cd "$OGRE_SOURCE"
        echo "  Patching..."
        patch -p1 < "$SUPPORTDIR/ogre_cocoa_currentGLContext_support.patch"
      fi
      cd "$OGRE_SOURCE"
      patch -p1 < "$SUPPORTDIR/ogre-1.9.0-03_move_stowed_template_func.patch"
    else
      OGRE_SOURCE="$DEPS_SOURCE/$OGRE_VER/$(ls "$DEPS_SOURCE/$OGRE_VER")"
    fi
    mkdir -p "$DEPS_BUILD/$OGRE_VER/$BUILDDIR"
    cd "$DEPS_BUILD/$OGRE_VER/$BUILDDIR"
    echo "  Configuring..."
    OGRE_EXTRA_FLAGS=""
    # Note: The -DOIS_INCLUDE_DIR flag is only set because of sample-related build failures
    #       which appear to be caused by Ogre 1.9.0. When fixed, this flag should be removed.
    cmake "$OGRE_SOURCE" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DOGRE_BUILD_SAMPLES="ON" -DOIS_FOUND="OFF" \
    -DOGRE_INSTALL_SAMPLES="OFF" -DOGRE_INSTALL_DOCS="OFF" -DOGRE_BUILD_TOOLS="OFF" -DOGRE_BUILD_PLUGIN_PCZ="OFF" \
    -DOGRE_BUILD_PLUGIN_BSP="OFF" $OGRE_EXTRA_FLAGS $CMAKE_FLAGS > "$LOGDIR/deps/ogre/$CONFIGLOG"
    if [[ $OSTYPE == *darwin* ]] ; then
      echo "  Building..."
        xcodebuild -configuration RelWithDebInfo > "$LOGDIR/deps/ogre/$MAKELOG"
        echo "  Installing..."
        xcodebuild -configuration RelWithDebInfo -target install > "$LOGDIR/deps/ogre/$INSTALLLOG"
        cp -r lib/RelWithDebInfo/* "$PREFIX/lib"
        #on mac, we have only Ogre.framework
        sed -i "" -e "s/-L\$[{]libdir[}]\ -lOgreMain/-F\${libdir} -framework Ogre/g" "$PREFIX/lib/pkgconfig/OGRE.pc"
        echo "  Done."
    else
        echo "  Building..."
        make $MAKE_FLAGS > "$LOGDIR/deps/ogre/$MAKELOG"
        echo "  Installing..."
        make install > "$LOGDIR/deps/ogre/$INSTALLLOG"
        echo "  Done."
    fi
}

function install_deps_freealut()
{
    # freealut
    echo "  Installing freealut..."
    mkdir -p "$LOGDIR/deps/freealut"
    cd "$DEPS_SOURCE"

    echo "  Downloading..."
	wget -c "http://pkgs.fedoraproject.org/repo/pkgs/freealut/freealut-${FREEALUT_VER}.tar.gz/e089b28a0267faabdb6c079ee173664a/freealut-${FREEALUT_VER}.tar.gz"
    tar -xzf "freealut-${FREEALUT_VER}.tar.gz"
    cd "freealut-${FREEALUT_VER}"
    if [[ $OSTYPE == *darwin* ]] ; then
      mkdir -p "$PREFIX/lib/pkgconfig"
      cp "$SUPPORTDIR/openal.pc" "$PREFIX/lib/pkgconfig/openal.pc"
    fi
    echo "  Running autogen..."
    autoreconf --install --force --warnings=all

    mkdir -p "$DEPS_BUILD/freealut-${FREEALUT_VER}-src/$BUILDDIR"
    cd "$DEPS_BUILD/freealut-${FREEALUT_VER}-src/$BUILDDIR"

    echo "  Running configure..."
    "$DEPS_SOURCE/freealut-${FREEALUT_VER}/configure" $CONFIGURE_FLAGS \
    CFLAGS="$CFLAGS $(pkg-config --cflags openal)" LDFLAGS="$LDFLAGS $(pkg-config --libs openal)" > "$LOGDIR/deps/freealut/$CONFIGLOG"

    echo "  Building..."
    make $MAKE_FLAGS > "$LOGDIR/deps/freealut/$MAKELOG"
    echo "  Installing..."
    make install > "$LOGDIR/deps/freealut/$INSTALLLOG"
}

function install_deps_basedir()
{
    # libxdg-basedir
    echo "  Installing libxdg-basedir..."
    mkdir -p "$LOGDIR/deps/libxdg-basedir"
    cd "$DEPS_SOURCE"

    echo "  Downloading..."
    curl -OL "http://nevill.ch/libxdg-basedir/downloads/libxdg-basedir-$BASEDIR_VER.tar.gz"
    tar -xf "libxdg-basedir-$BASEDIR_VER.tar.gz"
    cd "libxdg-basedir-$BASEDIR_VER"
    echo "  Running autogen..."
    #This library is currently not compatible with automake 1.12, the following line fixes this:
    sed -i 's/AC_PROG_CC/m4_ifdef([AM_PROG_AR], [AM_PROG_AR])\nAC_PROG_CC/' configure.ac
    autoreconf --install --force --warnings=all

    mkdir -p "$DEPS_BUILD/libxdg-basedir/$BUILDDIR"
    cd "$DEPS_BUILD/libxdg-basedir/$BUILDDIR"

    echo "  Running configure..."
    "$DEPS_SOURCE/libxdg-basedir-$BASEDIR_VER/configure" $CONFIGURE_FLAGS > "$LOGDIR/deps/libxdg-basedir/$CONFIGLOG"

    echo "  Building..."
    make $MAKE_FLAGS > "$LOGDIR/deps/libxdg-basedir/$MAKELOG"
    echo "  Installing..."
    make install > "$LOGDIR/deps/libxdg-basedir/$INSTALLLOG"
}

function install_deps_tolua++()
{
    # tolua++
	
	set +e # ‹== Do not kill script if pkg-config exits with error code
    for pkgname in lua5.1 lua-5.1 lua51 lua
    do
      echo "  Testing lua package '$pkgname'."
	  LUA_VERSION="$(pkg-config --modversion $pkgname 2> /dev/null)"
      if [[ $LUA_VERSION == 5.1* ]]; then
		echo "  Lua package '$pkgname' is suitable."
        LUA_CFLAGS="$(pkg-config --cflags $pkgname)"
        LUA_LDFLAGS="$(pkg-config --libs $pkgname)"
		break;
      fi
    done
	set -e
	
    if [ "x$LUA_VERSION" == "x" ] ; then
      if [ "x$LUA_LDFLAGS" == "x" ] ; then
        LUA_LDFLAGS="-llua"
      fi
      echo "  Failed to find suitable lua package, so we will just assume that '$LUA_LDFLAGS' will work."
    fi

    cd "$DEPS_SOURCE"
    if [ ! -d "$TOLUA_VER" ] ; then
        #curl -OL http://www.codenix.com/~tolua/${TOLUA_VER}.tar.bz2
		curl -OL "ftp://ftp.tw.freebsd.org/pub/ports/distfiles/${TOLUA_VER}.tar.bz2"
        tar -xjf "${TOLUA_VER}.tar.bz2"
    fi
	
    cd "$TOLUA_VER"
    mkdir -p "$PREFIX/include"
    cp include/tolua++.h "$PREFIX/include/tolua++.h"
    cd src/lib
    gcc $CFLAGS -c -fPIC -I"$PREFIX/include" ./*.c $LUA_CFLAGS
    mkdir -p "$PREFIX/lib"
    if [[ $OSTYPE == *darwin* ]] ; then
      ar cq libtolua++.a ./*.o
      cp libtolua++.a "$PREFIX/lib/libtolua++.a"
    else
      gcc -shared -Wl,-soname,libtolua++.so -o libtolua++.so  ./*.o
      cp libtolua++.so "$PREFIX/lib/libtolua++.so"
    fi
    cd ../bin
    gcc $CFLAGS $LDFLAGS -o tolua++ -I"$PREFIX/include" $LUA_CFLAGS $LUA_LDFLAGS -L"$PREFIX/lib" tolua.c toluabind.c -ltolua++
    mkdir -p "$PREFIX/bin"
    cp tolua++ "$PREFIX/bin/tolua++"
    cd ../../..
}

function install_deps_cegui()
{
    # CEGUI
    echo "  Installing CEGUI..."
    mkdir -p "$LOGDIR/deps/CEGUI"    # create CEGUI log directory
    cd "$DEPS_SOURCE"
    if [ ! -d "$CEGUI_VER" ] ; then
      echo "  Downloading..."
      curl -C - -OL "http://downloads.sourceforge.net/sourceforge/crayzedsgui/$CEGUI_DOWNLOAD"
      tar -xjf "$CEGUI_DOWNLOAD"
      if [[ $OSTYPE == *darwin* ]] ; then
        echo "  Patching..."
        cd "$DEPS_SOURCE/$CEGUI_VER"
        sed -i "" -e "s/\"macPlugins.h\"/\"implementations\/mac\/macPlugins.h\"/g" cegui/src/CEGUIDynamicModule.cpp
        sed -i "" -e '1i\#include<CoreFoundation\/CoreFoundation.h>' cegui/include/CEGUIDynamicModule.h
      fi
    fi
    
    mkdir -p "$DEPS_BUILD/$CEGUI_VER/$BUILDDIR"
    cd "$DEPS_BUILD/$CEGUI_VER/$BUILDDIR"
    echo "  Configuring..."
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -C "${SUPPORTDIR}/CEGUI_defaults.cmake" $CMAKE_FLAGS "$DEPS_SOURCE/$CEGUI_VER"  > "$LOGDIR/deps/CEGUI/$CONFIGLOG"
    echo "  Building..."
    make $MAKE_FLAGS > "$LOGDIR/deps/CEGUI/$MAKELOG"
    echo "  Installing..."
    make install > "$LOGDIR/deps/CEGUI/$INSTALLLOG"
    if [[ $OSTYPE == *darwin* ]] ; then
      #on mac we use -DCEGUI_STATIC, which will disable the plugin interface and we need to link the libraries manually.
      sed -i "" -e "s/-lCEGUIBase/-lCEfrGUIBase -lCEGUIFalagardWRBase -lCEGUIFreeImageImageCodec -lCEGUITinyXMLParser/g" "$PREFIX/lib/pkgconfig/CEGUI.pc"
    fi
    echo "  Done."
}
function install_deps_all()
{
    if [[ $OSTYPE == *darwin* ]] ; then
      install_deps_freealut
      install_deps_tolua++
    fi
    install_deps_ogre
    install_deps_cegui
    install_deps_basedir
}
function install_deps_AppImageKit()
{
  # AppImageKit
    echo "  Installing core AppImageKit functionality..."
    mkdir -p "$LOGDIR/deps/AppImageKit"    # create AppImageKit log directory
    cd "$DEPS_SOURCE"
    if [ ! -d "AppImageKit" ] ; then
      echo "  Downloading..."
      mkdir AppImageKit && cd AppImageKit
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/CMakeLists.txt
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/AppRun.c
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/fuseiso.c
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/isofs.c
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/isofs.h
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/md5.c
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/md5.h
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/runtime.c
      #AppImageKit isn't smart enough to find debian library locations, let's help it.
      sed -i 's|"/usr/lib64"|"/usr/lib" "/usr/lib64" "/usr/lib/i386-linux-gnu" "/usr/lib/x86_64-linux-gnu"|' CMakeLists.txt
      mkdir linux && cd linux
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/linux/iso_fs.h
      curl -OL https://raw.github.com/probonopd/AppImageKit/master/linux/rock.h
    fi
    mkdir -p "$DEPS_BUILD/AppImageKit"
    cd "$DEPS_BUILD/AppImageKit"
    curl -OL https://raw.github.com/probonopd/AppImageKit/master/AppImageAssistant.AppDir/package
    curl -OL https://raw.github.com/probonopd/AppImageKit/master/AppImageAssistant.AppDir/xdgappdir.py
    echo "  Configuring..."
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" $CMAKE_EXTRA_FLAGS "$DEPS_SOURCE/AppImageKit" &> "$LOGDIR/deps/AppImageKit/$CONFIGLOG"
    echo "  Building..."
    make $MAKEOPTS AppRun &> "$LOGDIR/deps/AppImageKit/${MAKELOG}_AppRun"
    make $MAKEOPTS runtime &> "$LOGDIR/deps/AppImageKit/${MAKELOG}_runtime"
    echo "  Installing..."
    echo "Installed." > "$LOGDIR/deps/AppImageKit/$INSTALLLOG"
    echo "  Done."
}

function ember_fetch_media()
{
  if [ x"$MEDIA_VER" = x"dev" ] ; then
    MEDIAURL="http://amber.worldforge.org/media/media-dev/"
    MEDIAVERSION="devmedia"
    MEDIA_PREFETCH="set +e"
    MEDIA_POSTFETCH="set -e"
  else
    MEDIAURL="http://downloads.sourceforge.net/worldforge/ember-media-${MEDIA_VER}.tar.bz2"
    MEDIAVERSION="releasemedia"
    MEDIA_PREFETCH=""
    MEDIA_POSTFETCH=""
  fi
  # Fetch Ember Media
    if command -v rsync &> /dev/null; then
      echo "Fetching media..."
      cd "$BUILD/clients/ember/$BUILDDIR"
      $MEDIA_PREFETCH
      make $MEDIAVERSION &> "$LOGDIR/clients/ember/media.log"
      if [ $? != 0 ] ; then
        echo "Could not fetch media. This may be caused by the media server being down, by the network being down, or by a firewall which prevents rsync from running. You need to get the media manually from $MEDIAURL"
      else
        echo "Media fetched."
      fi
      $MEDIA_POSTFETCH
    else
      echo "Rsync not found, skipping fetching of media. You will need to download and install it yourself from $MEDIAURL"
    fi
}

mkdir -p "$PREFIX" "$SOURCE" "$DEPS_SOURCE" "$BUILD" "$DEPS_BUILD"

# Dependencies install
if [ x"$1" = x"install-deps" ] ; then
  if [ x"$MSYSTEM" = x"MINGW32" ] ; then
    "$SUPPORTDIR/mingw_install_deps.sh" "$2"
    exit 0
  fi
  if [[ x"$TARGET_OS" = x"android" ]] ; then
    "$SUPPORTDIR/android_install_deps.sh" "$2"
    exit 0
  fi
  if [ $# -ne 2 ] ; then
    echo "Missing required parameter!"
    show_help "install-deps"
    exit 1
  fi

  echo "Installing 3rd party dependencies..."

  # Create deps log directory
  mkdir -p "$LOGDIR/deps"

  if [ "$2" = "all" ] || [ "$2" = "ogre" ] || [ "$2" = "cegui" ] ||
     [ "$2" = "cg" ] || [ "$2" = "tolua++" ] || [ "$2" = "freealut" ] ||
     [ "$2" = "basedir" ] ; then
    install_deps_$2
  else
    printf >&2 'Unknown target: %s\n' "$2"
    exit 1
  fi
  
  # AppImageKit
  if [ "$2" = "appimage" ] ; then
    install_deps_AppImageKit
  fi

  echo "Install of 3rd party dependencies is complete."

# Source checkout
elif [ "$1" = "checkout" ] ; then
  if [ $# -ne 2 ] ; then
    echo "Missing required parameter!"
    show_help "checkout"
    exit 1
  fi
  echo "Checking out sources..."

  if [ "$2" = "libs" ] || [ "$2" = "all" ] ; then

    mkdir -p "$SOURCE/libs"
    cd "$SOURCE/libs"

    # Varconf
    echo "  Varconf..."
    checkoutwf "varconf"
    echo "  Done."

    # Atlas-C++
    echo "  Atlas-C++..."
    checkoutwf "atlas-cpp"
    echo "  Done."

    # Wfmath
    echo "  Wfmath..."
    checkoutwf "wfmath"
    echo "  Done."

    # Eris
    echo "  Eris..."
    checkoutwf "eris"
    echo "  Done."

    # Libwfut
    echo "  Libwfut..."
    checkoutwf "libwfut"
    echo "  Done."

    # Mercator
    echo "  Mercator..."
    checkoutwf "mercator"
    echo "  Done."
  fi

  if [ "$2" = "worlds" ] || [ "$2" = "all" ] ; then
    # Worlds
    echo "  Worlds..."
    mkdir -p "$SOURCE"
    cd "$SOURCE"
    checkoutwf "worlds"
    echo "  Done."
  fi

  if [ "$2" = "ember" ] || [ "$2" = "webember" ] || [ "$2" = "all" ] ; then
    # Ember client
    echo "  Ember client..."
    mkdir -p "$SOURCE/clients"
    cd "$SOURCE/clients"
    checkoutwf "ember"
    echo "  Done."
  fi

  if [ "$2" = "cyphesis" ] || [ "$2" = "all" ] ; then
    # Cyphesis
    echo "  Cyphesis..."
    mkdir -p "$SOURCE/servers"
    cd "$SOURCE/servers"
    checkoutwf "cyphesis"
    echo "  Done."
  fi

  if [ "$2" = "metaserver-ng" ] ; then
    # Metaserver
    echo "  Metaserver-ng..."
    mkdir -p "$SOURCE/servers"
    cd "$SOURCE/servers"
    checkoutwf "metaserver-ng"
    echo "  Done."
  fi

  if [ "$2" = "webember" ] || [ "$2" = "all" ] ; then
    if [[ x$MSYSTEM != x"MINGW32" ]] ; then
      echo "  FireBreath..."
      mkdir -p "$SOURCE/clients/webember"
      cd "$SOURCE/clients/webember"
      checkoutwf "FireBreath" "sajty"
      echo "  Done."
      echo "  WebEmber..."
      checkoutwf "webember"
      echo "  Done."
    fi
  fi

  echo "Checkout complete."

# Build source
elif [ "$1" = "build" ] ; then
  if [ $# -lt 2 ] ; then
    echo "Missing required parameter!"
    show_help "build"
    exit 1
  fi

  # Check for make options
  if [ $# -ge 3 ] ; then
    export MAKE_FLAGS="$MAKE_FLAGS $3"
  fi

  echo "Building sources..."

  # Build libraries
  if [ "$2" = "libs" ] || [ "$2" = "all" ] ; then

    # Varconf
    echo "  Varconf..."
    buildwf "libs/varconf"
    echo "  Done."

    # Wfmath
    echo "  Wfmath..."
    buildwf "libs/wfmath"
    echo "  Done."

    # Atlas-C++
    echo "  Atlas-C++..."
    buildwf "libs/atlas-cpp"
    echo "  Done."

    # Mercator
    echo "  Mercator..."
    buildwf "libs/mercator"
    echo "  Done."

    # Eris
    echo "  Eris..."
    buildwf "libs/eris"
    echo "  Done."

    # Libwfut
    echo "  Libwfut..."
    buildwf "libs/libwfut"
    echo "  Done."

  fi

  if [ "$2" = "worlds" ] || [ "$2" = "all" ] ; then
    # Worlds
    echo "  Worlds..."
    buildwf "worlds"
    echo "  Done."
  fi

  if [ "$2" = "ember" ] || [ "$2" = "all" ] ; then
    # Ember client
    echo "  Ember client..."
    buildwf "clients/ember"
    echo "  Done."
    
    # Ember media
    ember_fetch_media
  fi

  if [ "$2" = "cyphesis" ] || [ "$2" = "all" ] ; then
    # Cyphesis
    echo "  Cyphesis..."
    buildwf "servers/cyphesis"
    cyphesis_post_install
    echo "  Done."
  fi

  if [ "$2" = "metaserver-ng" ] ; then

    # metaserver-ng
    # change sysconfdir in order to conform with the manner
    # of WF builds
    echo "  metaserver-ng..."
    CONFIGURE_FLAGS_SAVED="$CONFIGURE_FLAGS"
    export CONFIGURE_FLAGS="$CONFIGURE_FLAGS --sysconfdir=$PREFIX/etc/metaserver-ng"
    buildwf "servers/metaserver-ng"
    export CONFIGURE_FLAGS="$CONFIGURE_FLAGS_SAVED"
    echo "  Done."
  fi

  if [ "$2" = "webember" ] || [ "$2" = "all" ] ; then

    echo "  WebEmber..."
    export CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-webember"
    #we need to change the BUILDDIR to separate the ember and webember build directories.
    #the strange thing is that if BUILDDIR is 6+ character on win32, the build will fail with missing headers.
    export BUILDDIR="web${BUILDDIR}"
    buildwf "clients/ember" "webember"
    echo "  Done."

    # WebEmber media
    ember_fetch_media "dev"

    # WebEmber
    echo "  WebEmber plugin..."
    if [[ x$MSYSTEM = x"MINGW32" ]] ; then
      # Firebreath is not supporting mingw32 yet, we will use msvc prebuilt for webember.
      mkdir -p "$BUILD/clients/ember/$BUILDDIR"
      cd "$BUILD/clients/ember/$BUILDDIR"
      curl -C - -OL http://sajty.elementfx.com/npWebEmber.tar.gz
      tar -xzf npWebEmber.tar.gz
      cp npWebEmber.dll "$PREFIX/bin/npWebEmber.dll"
      regsvr32 -s "$PREFIX/bin/npWebEmber.dll"
      #To uninstall: regsvr32 -u $PREFIX/bin/npWebEmber.dll
    else
      mkdir -p "$LOGDIR/webember_plugin"
      mkdir -p "$BUILD/clients/webember/FireBreath/$BUILDDIR"
      cd "$BUILD/clients/webember/FireBreath/$BUILDDIR"

      cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DFB_PROJECTS_DIR="$SOURCE/clients/webember/webember/plugin" $CMAKE_FLAGS "$SOURCE/clients/webember/FireBreath" > "$LOGDIR/webember_plugin/cmake.log"
      if  [[ $OSTYPE == *darwin* ]] ; then
        echo "  Building..."
        xcodebuild -configuration RelWithDebInfo > "$LOGDIR/webember_plugin/$MAKELOG"
        echo "  Installing..."
        cp -r projects/WebEmber/RelWithDebInfo/webember.plugin "$PREFIX/lib"
      else
        echo "  Building..."
        make $MAKE_FLAGS > "$LOGDIR/webember_plugin/build.log"
        echo "  Installing..."
        mkdir -p ~/.mozilla/plugins
        cp bin/WebEmber/npWebEmber.so ~/.mozilla/plugins/npWebEmber.so
      fi
    fi
    export BUILDDIR="$(getconf LONG_BIT)"
    echo "  Done."
  fi
  if [ $TARGET_OS = "android" ] && [ "$2" = "ember_apk" ] ; then
    echo "  Bundling Ember into ember.apk..."
    "$SUPPORTDIR/AppBundler.sh"
    echo "  Done."
  fi
  echo "Build complete."

elif [ "$1" = "clean" ] ; then
  if [ $# -ne 2 ] ; then
    echo "Missing required parameter!"
    show_help "clean"
    exit 1
  fi

  # Delete build directory
  if [ "$2" = "cegui" ] ; then
    rm -rf "${DEPS_BUILD:?}/${CEGUI_VER:?}/${BUILDDIR:?}"
  elif [ "$2" = "ogre" ] ; then
    rm -rf "${DEPS_BUILD:?}/${OGRE_VER:?}/ogre/${BUILDDIR:?}"
  else
    rm -rf "${BUILD:?}/${2:?}/${BUILDDIR:?}"
  fi

elif [ "$1" = "release_ember" ] ; then
  # Set configuration for building a release
  if [[ $OSTYPE != *darwin* ]] ; then
    export CXXFLAGS="$CXXFLAGS -O3 -g0 -s"
    export CFLAGS="$CFLAGS -O3 -g0 -s"
  fi
  
  # Remove hammer environment
  eval $("$SUPPORTDIR/setup_env.sh" pop_env)
  CURDIR="$PWD"
  HAMMER="$0"
  
  # Install external dependencies
  echo "Installing 3rd party dependencies..."
  "$HAMMER" --compile_flags="$CXXFLAGS" install-deps all
  "$HAMMER" --compile_flags="$CXXFLAGS" install-deps cg
  HAMMER_EXTRA_FLAGS=""

  # Source checkout
  echo "Checking out sources..."
    
    if [ x"$2" != x"" ] && [ x"$2" != x"dev" ] ; then
	  # Push native build environment to checkout skstream
      eval $("$SUPPORTDIR/setup_env.sh" push_env)
        mkdir -p "$SOURCE/libs"
        cd "$SOURCE/libs"
        # skstream is deprecated, but we need it to build older ember releases!
        checkoutwf "skstream" "worldforge" $SKSTREAM_VER
      eval $("$SUPPORTDIR/setup_env.sh" pop_env)
      
      HAMMER_EXTRA_FLAGS="--use-release-libs --use-release-ember=$2"
      cd "$CURDIR"
    fi
    
    "$HAMMER" $HAMMER_EXTRA_FLAGS checkout libs
    "$HAMMER" $HAMMER_EXTRA_FLAGS checkout ember

  # Build source
  echo "Building sources..."
    "$HAMMER" --compile_flags="$CXXFLAGS" build libs
    
    if [ x"$2" != x"" ] && [ x"$2" != x"dev" ] ; then
      
      # skstream is deprecated, but we need it to build older ember releases!
      # Push native build environment to build skstream
	  eval $("$SUPPORTDIR/setup_env.sh" push_env)
        buildwf "libs/skstream"
      eval $("$SUPPORTDIR/setup_env.sh" pop_env)
      
      HAMMER_EXTRA_FLAGS="--use-release-media=$2"
      cd "$CURDIR"
    fi
    
    "$HAMMER" $HAMMER_EXTRA_FLAGS --compile_flags="$CXXFLAGS" build ember
  
  eval $("$SUPPORTDIR/setup_env.sh" push_env)
  # Check for Ember release target option
  if [ x"$3" = x"" ] || [ "$3" = "image" ] ; then
    # making an AppImage/AppBundle
    if [[ $OSTYPE == *darwin* ]] ; then
      echo "Creating AppBundle."
      source "$HAMMERDIR/support/AppBundler.sh"
      echo "AppBundle creation complete."
    else
      export APP_DIR_ROOT="$WORKDIR/Ember.AppDir"
      echo "Creating AppImage."
      install_deps_AppImageKit
      source "$HAMMERDIR/support/linux_AppDir_create.sh" &> "$LOGDIR/deps/AppImageKit/AppDir.log"
      echo "AppImage will be created from the AppDir at $APP_DIR_ROOT and placed into $WORKDIR."
      PACKAGE_FILE="$WORKDIR/ember-${2}-x86_$BUILDDIR"
      if [ -e "$PACKAGE_FILE" ] ; then
        echo "Removing existing artifact at '$PACKAGE_FILE'."
        rm "$PACKAGE_FILE" 
      fi
      python "$DEPS_BUILD/AppImageKit/package" "$APP_DIR_ROOT" "$PACKAGE_FILE" create new &> "$LOGDIR/deps/AppImageKit/AppImage.log"
      echo "AppImage creation complete."
    fi
  else 
    # making a standard directory
    echo "Creating release directory."
    cd "$HAMMERDIR"
    source "$HAMMERDIR/support/linux_release_bundle.sh"
    echo "Release directory created."
  fi
  eval $("$SUPPORTDIR/setup_env.sh" pop_env)
  
else
  echo "Invalid command!"
  show_help "main"
fi
