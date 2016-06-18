#!/bin/bash

# script is intended to run on Scaleway Arm32 Arch Linux machine

# builds non-standard NDK cross-toolchain with host=arm-eabi, target=arm-linux-androideabi

# prerequisites (run from root): pacman -S autoconf gcc make git binutils pkg-config automake patch flex bison zip

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
git clone https://android.googlesource.com/platform/ndk && cd ndk
export NDK=$(pwd)
repo init -u https://android.googlesource.com/platform/manifest -b master-ndk

# build binutils
repo sync toolchain/binutils
pushd toolchain/binutils/binutils-*
./configure --prefix=$NDK_TOOLCHAIN --target=arm-linux-androideabi --with-sysroot=$NDK_TOOLCHAIN --disable-multilib --disable-werror
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

# build libgcc
mkdir libgcc_place
pushd libgcc_place
$NDK/toolchain/gcc/gcc-4.9/configure --prefix=$NDK_TOOLCHAIN --target=arm-linux-androideabi --enable-languages=c,c++ --disable-multilib
make -j4 all-target-libgcc
make install-target-libgcc
popd
