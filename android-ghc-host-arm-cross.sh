#!/bin/bash

# script is intended to run on Scaleway Arm32 Arch Linux machine

# builds non-standard NDK cross-toolchain with host=arm-eabi, target=arm-linux-androideabi

# prerequisites (run from root): pacman -S autoconf gcc make git binutils pkg-config automake patch flex bison zip alex happy ghc

# run the following with normal user

# remember our directory
export MY_SCRIPT_DIR=$(pwd)

mkdir -p $HOME/.local/bin
export PATH=$HOME/.local/bin:$PATH
curl -o $HOME/.local/bin/repo -L https://storage.googleapis.com/git-repo-downloads/repo
chmod +x $HOME/.local/bin/repo
# patch script to use python2 on Arch Linux
sed -ie '0,/python/s/python/python2/' $HOME/.local/bin/repo

# make working directory
mkdir $HOME/thirdparty && cd $HOME/thirdparty
# setup git, otherwise repo doesn't work
git config --global user.name runner
git config --global user.email runner

# make directory for NDK toolchain
mkdir ndk-toolchain
export NDK_TOOLCHAIN=$(pwd)/ndk-toolchain
export PATH=$NDK_TOOLCHAIN/bin:$PATH
mkdir $NDK_TOOLCHAIN/include
ln -rs $NDK_TOOLCHAIN{,/usr}

# copy files from android-9

# clone NDK
git clone https://android.googlesource.com/platform/ndk
pushd ndk
export NDK=$(pwd)
repo init -u https://android.googlesource.com/platform/manifest -b master-ndk

# build binutils
repo sync toolchain/binutils
pushd toolchain/binutils/binutils-*
patch -p1 -i $MY_SCRIPT_DIR/patches/binutils.patch
./configure --prefix=$NDK_TOOLCHAIN --target=arm-linux-androideabi --with-sysroot=$NDK_TOOLCHAIN --enable-ld --enable-gold --enable-plugins --disable-multilib --disable-werror
make -j4
make install
popd

# apply patches to gcc
repo sync toolchain/gcc
pushd toolchain/gcc/gcc-4.9
# from https://gcc.gnu.org/viewcvs/gcc?view=revision&revision=233720, see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=69959
# from https://gcc.gnu.org/viewcvs/gcc?view=revision&revision=221326, see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=25672
find $MY_SCRIPT_DIR/patches/gcc -name '*.patch' -exec patch -p2 -i '{}' \;
popd

# build gcc out-of-place
mkdir gcc_place
pushd gcc_place
$NDK/toolchain/gcc/gcc-4.9/configure --prefix=$NDK_TOOLCHAIN --target=arm-linux-androideabi --with-sysroot=$NDK_TOOLCHAIN --enable-languages=c,c++ --disable-multilib
make -j4 all-gcc all-target-libgcc
make install-gcc install-target-libgcc
popd

popd # ndk

# path for updating automake scripts
export CONFIG_SUB_SRC=/usr/share/automake-1.15

# install iconv
git clone https://github.com/ironsteel/iconv-android.git
pushd iconv-android
# Update config.sub and config.guess
cp $CONFIG_SUB_SRC/config.sub build-aux
cp $CONFIG_SUB_SRC/config.guess build-aux
cp $CONFIG_SUB_SRC/config.sub libcharset/build-aux
cp $CONFIG_SUB_SRC/config.guess libcharset/build-aux
./configure --prefix=$NDK_TOOLCHAIN --host=arm-linux-androideabi --with-sysroot=$NDK_TOOLCHAIN --enable-static --disable-shared
make -j4
make install
popd

# install ncurses
curl -LO http://ftp.gnu.org/pub/gnu/ncurses/ncurses-5.9.tar.gz
tar xf ncurses-5.9.tar.gz
pushd ncurses-5.9
# ac_cv_header_locale_h=no is to work around error
ac_cv_header_locale_h=no ./configure --prefix=$NDK_TOOLCHAIN --host=arm-linux-androideabi --with-sysroot=$NDK_TOOLCHAIN --enable-static --disable-shared --without-manpages --includedir=$NDK_TOOLCHAIN/include
make -j4
make install
popd

# now build ghc

# use github
git config --global url."git://github.com/ghc/packages-".insteadOf     git://github.com/ghc/packages/
git config --global url."http://github.com/ghc/packages-".insteadOf    http://github.com/ghc/packages/
git config --global url."https://github.com/ghc/packages-".insteadOf   https://github.com/ghc/packages/
git config --global url."ssh://git@github.com/ghc/packages-".insteadOf ssh://git@github.com/ghc/packages/
git config --global url."git@github.com:/ghc/packages-".insteadOf      git@github.com:/ghc/packages/

# get ghc source
git clone --recursive https://github.com/ghc/ghc.git -b ghc-8.0.1-release
pushd ghc

# setup build.mk and config.mk.in
cp mk/build.mk{.sample,}
patch -p1 -i $MY_SCRIPT_DIR/patches/ghc.patch

# boot and configure
./boot
./configure --prefix=$NDK_TOOLCHAIN --target=arm-linux-androideabi --with-gcc=$NDK_TOOLCHAIN/bin/arm-linux-androideabi-gcc
make -j4

popd
