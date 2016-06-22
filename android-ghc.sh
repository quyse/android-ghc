#!/bin/sh

# on x64

# remember our directory
export MY_SCRIPT_DIR=$(pwd)

# position-independent executables are required for Android 5.0, but crashes system linker prior to 4.1
# see http://stackoverflow.com/a/30547603/960629

# select platform
### android-9
export ANDROID_PLATFORM=9
export ANDROID_TOOLCHAIN_FLAGS=

### android-24
# export ANDROID_PLATFORM=24
# export ANDROID_TOOLCHAIN_FLAGS="CFLAGS=-fPIE LDFLAGS=-pie"

# make ndk toolchain
export NDK_TOOLCHAIN=$(pwd)/ndk-toolchain-$ANDROID_PLATFORM
/opt/android-ndk/build/tools/make-standalone-toolchain.sh --arch=arm --platform=android-$ANDROID_PLATFORM --install-dir=$NDK_TOOLCHAIN
export PATH=$NDK_TOOLCHAIN/bin:$PATH
# fake pthread
ln -rs $NDK_TOOLCHAIN/sysroot/usr/lib/{libc.a,libpthread.a}
# make some links for files in non-standard location
ln -rs $NDK_TOOLCHAIN/sysroot/usr/include/{fcntl.h,sys/}

# make android toolchain dir
export ANDROID_TOOLCHAIN=$(pwd)/android-toolchain-$ANDROID_PLATFORM
mkdir $ANDROID_TOOLCHAIN
ln -rs $ANDROID_TOOLCHAIN{,/usr}

# clone NDK
git clone https://android.googlesource.com/platform/ndk
pushd ndk
export NDK=$(pwd)
repo init -u https://android.googlesource.com/platform/manifest -b master-ndk

# build binutils
repo sync toolchain/binutils
pushd toolchain/binutils/binutils-*
./configure --prefix=$ANDROID_TOOLCHAIN --host=arm-linux-androideabi --target=arm-linux-androideabi --enable-ld --enable-gold --enable-plugins --disable-multilib --disable-nls --disable-werror $ANDROID_TOOLCHAIN_FLAGS
make -j8
make install
popd

# build GMP
repo sync toolchain/gmp
pushd toolchain/gmp
tar xf gmp-5.0.5.tar.bz2
pushd gmp-5.0.5
./configure --prefix=$ANDROID_TOOLCHAIN --host=arm-linux-androideabi
make -j8
make install
popd
popd

# build MPFR
repo sync toolchain/mpfr
pushd toolchain/mpfr
tar xf mpfr-3.1.1.tar.bz2
pushd mpfr-3.1.1
./configure --prefix=$ANDROID_TOOLCHAIN --host=arm-linux-androideabi --with-gmp=$ANDROID_TOOLCHAIN
make -j8
make install
popd
popd

# build MPC
repo sync toolchain/mpc
pushd toolchain/mpc
tar xf mpc-1.0.1.tar.gz
pushd mpc-1.0.1
./configure --prefix=$ANDROID_TOOLCHAIN --host=arm-linux-androideabi --with-gmp=$ANDROID_TOOLCHAIN
make -j8
make install
popd
popd

# build gcc
repo sync toolchain/gcc
pushd toolchain/gcc/gcc-4.9
patch -p1 -i $MY_SCRIPT_DIR/android-$ANDROID_PLATFORM-patches/gcc.patch
popd
mkdir gcc_place
pushd gcc_place
$NDK/toolchain/gcc/gcc-4.9/configure --prefix=$ANDROID_TOOLCHAIN --with-gmp=$ANDROID_TOOLCHAIN --host=arm-linux-androideabi --target=arm-linux-androideabi --enable-languages=c,c++ --disable-multilib $ANDROID_TOOLCHAIN_FLAGS
make -j8
make install
popd

popd # ndk

# add sysroot over toolchain
cp -rn $NDK_TOOLCHAIN/sysroot/usr/* $ANDROID_TOOLCHAIN/
