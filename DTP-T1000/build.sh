set -e

SCRIPT_DIR=$(dirname $(realpath "$0"))

TARGET=mipsel-linux
PREFIX=/opt/dtp-t1000-cp-toolchain

BINUTILS_RPM=hhl-target-binutils-2.12.1-mvl3.0.0.14.3.src.rpm
GLIBC_RPM=hhl-target-glibc-2.2.5-mvl3.0.0.15.15.src.rpm
LINUX_TAR=DTP-T1000-linux-2.4.tar.gz

GCC_URL=https://ftp.gnu.org/pub/gnu/gcc/gcc-3.2.3/gcc-3.2.3.tar.bz2
MAKE_URL=https://ftp.gnu.org/gnu/make/make-3.81.tar.gz

MAKE_SRC_DIR="$SCRIPT_DIR/make-3.81"
BINUTILS_SRC_DIR="$SCRIPT_DIR/binutils-2.12.1"
BINUTILS_BUILD_DIR="$SCRIPT_DIR/binutils-2.12.1-build"
GLIBC_SRC_DIR="$SCRIPT_DIR/glibc-2.2.5"
GLIBC_BUILD_DIR="$SCRIPT_DIR/glibc-2.2.5-build"
GCC_SRC_DIR="$SCRIPT_DIR/gcc-3.2.3"
GCC_STAGE1_BUILD_DIR="$SCRIPT_DIR/gcc-3.2.3-stage1-build"
GCC_STAGE2_BUILD_DIR="$SCRIPT_DIR/gcc-3.2.3-stage2-build"
LINUX_SRC_DIR="$SCRIPT_DIR/linux"

export PATH="$MAKE_SRC_DIR/install/bin:$PREFIX/bin:$PATH"

archives=($BINUTILS_RPM $GLIBC_RPM $LINUX_TAR)

for i in "${!archives[@]}"; do
   if [ ! -f "${archives[$i]}" ]; then
      echo "Missing dependency ${archives[$i]}"
      exit 1
   fi
done

if [ ! -d "$PREFIX" ]; then
   if [ "$EUID" -eq 0 ]; then
      mkdir -p "$PREFIX/bin"
   else
      sudo mkdir -p "$PREFIX/bin"
      sudo chown -R $USER "$PREFIX"
   fi
fi

cd "$SCRIPT_DIR"

if [ ! -f "make-3.81.tar.gz" ]; then
   echo "Downloading make 3.81"
   wget $MAKE_URL
fi

if [ ! -f "$MAKE_SRC_DIR/extract.done" ]; then
   echo "Extracting make 3.81"
   tar xf make-3.81.tar.gz
   touch "$MAKE_SRC_DIR/extract.done"
fi

if [ ! -f "$MAKE_SRC_DIR/configure.done" ]; then
   echo "Configuring make 3.81"
   cd "$MAKE_SRC_DIR"
   "$MAKE_SRC_DIR/configure" \
      CFLAGS="-fcommon -D__alloca=alloca -D__stat=stat -Wno-implicit-function-declaration" \
      --prefix="$MAKE_SRC_DIR/install"
   touch "$MAKE_SRC_DIR/configure.done"
fi

if [ ! -f "$MAKE_SRC_DIR/build.done" ]; then
   echo "Compiling make 3.81"
   cd "$MAKE_SRC_DIR"
   make
   touch "$MAKE_SRC_DIR/build.done"
fi

if [ ! -f "$MAKE_SRC_DIR/install.done" ]; then
   echo "Installing make 3.81"
   cd "$MAKE_SRC_DIR"
   make install
   ln -s make "$MAKE_SRC_DIR/install/bin/gmake"
   touch "$MAKE_SRC_DIR/install.done"
fi

cd $SCRIPT_DIR

if [ ! -d "binutils-pkg-src" ]; then
   cpiofile="${BINUTILS_RPM%.*}.cpio"
   echo "Extracting $BINUTILS_RPM"
   if [ ! -f "$cpiofile" ]; then
      7z x "$BINUTILS_RPM"
   fi
   mkdir binutils-pkg-src
   cpio -idmv -D binutils-pkg-src < $cpiofile
fi

if [ ! -d "$BINUTILS_SRC_DIR" ]; then
   echo "Extracting binutils source"
   tar xf "binutils-pkg-src/binutils-2.12.1.tar.bz2" -C .

   echo "Patching binutils source"

   patch -N -d "$BINUTILS_SRC_DIR" -p1 < "binutils-pkg-src/binutils-nohoststrip.patch"
   patch -N -d "$BINUTILS_SRC_DIR" -p1 < "binutils-pkg-src/binutils-2.12.1-mips-dwarf.patch"
   patch -N -d "$BINUTILS_SRC_DIR" -p1 < "binutils-pkg-src/binutils-2.12.1-got-refcount.patch"
   patch -N -d "$BINUTILS_SRC_DIR" -p1 < "binutils-pkg-src/binutils-2.12.1-mips-merge.patch"
   patch -N -d "$BINUTILS_SRC_DIR" -p1 < "binutils-pkg-src/binutils-2.12.1-mips-hugestack.patch"
   patch -N -d "$BINUTILS_SRC_DIR" -p1 < "binutils-pkg-src/binutils-2.12.1-unified-constructors.patch"

   cd "$BINUTILS_SRC_DIR/gas" && autoconf
   cd "$BINUTILS_SRC_DIR/bfd" && autoconf
fi

if [ ! -d "$BINUTILS_BUILD_DIR" ]; then
   mkdir "$BINUTILS_BUILD_DIR"
fi

if [ ! -f "$BINUTILS_BUILD_DIR/configure.done" ]; then
   cd "$BINUTILS_BUILD_DIR"
   echo "Configuring binutils"
   CFLAGS="-Wno-implicit-int -Wno-implicit-function-declaration" \
   "$BINUTILS_SRC_DIR/configure" \
      --target=$TARGET \
      --prefix=$PREFIX \
      --enable-shared \
      --disable-nls
   touch configure.done
fi

if [ ! -f "$BINUTILS_BUILD_DIR/build.done" ]; then
   cd "$BINUTILS_BUILD_DIR"
   echo "Compiling binutils"
   make -j"$(nproc)"
   touch build.done
fi

if [ ! -f "$BINUTILS_BUILD_DIR/install.done" ]; then
   cd "$BINUTILS_BUILD_DIR"
   echo "Intalling binutils"
   make install MAKEINFO="$BINUTILS_SRC_DIR/missing makeinfo"
   touch install.done
fi

cd "$SCRIPT_DIR"

if [ ! -f "gcc-3.2.3.tar.bz2" ]; then
   echo "Downloading gcc 3.2.3 source tar"
   wget $GCC_URL
fi

if [ ! -d "$GCC_SRC_DIR" ]; then
   echo "Extracting gcc source"
   tar xf gcc-3.2.3.tar.bz2
   echo "Patching gcc source"
   patch -N -d "$GCC_SRC_DIR" -p1 < "gcc-3.2.3.patch"
fi

if [ ! -d "$GCC_STAGE1_BUILD_DIR" ]; then
   mkdir "$GCC_STAGE1_BUILD_DIR"
fi

if [ ! -f "$GCC_STAGE1_BUILD_DIR/configure.done" ]; then
   cd "$GCC_STAGE1_BUILD_DIR"
   echo "Configuring gcc stage 1"
   CFLAGS="-Wno-implicit-int -Wno-implicit-function-declaration" \
   "$GCC_SRC_DIR/configure" \
      --target=$TARGET\
      --prefix=$PREFIX \
      --enable-languages=c \
      --with-newlib \
      --without-headers \
      --disable-shared \
      --disable-threads \
      --disable-nls \
      --disable-multilib
   touch configure.done
fi

if [ ! -f "$GCC_STAGE1_BUILD_DIR/build.done" ]; then
   cd "$GCC_STAGE1_BUILD_DIR"
   echo "Compiling gcc stage 1"
   make -j"$(nproc)" HOST_CFLAGS="-Wno-error=incompatible-pointer-types"
   touch build.done
fi

if [ ! -f "$GCC_STAGE1_BUILD_DIR/install.done" ]; then
   cd "$GCC_STAGE1_BUILD_DIR"
   echo "Intalling gcc stage 1"
   make install
   touch install.done
fi

cd $SCRIPT_DIR

if [ ! -d "$LINUX_SRC_DIR" ]; then
   echo "Extracting linux source"
   tar xf "$LINUX_TAR"
fi

if [ ! -f "$LINUX_SRC_DIR/makeconfig.done" ]; then
   cd "$LINUX_SRC_DIR"
   cp -p arch/mips/configs/defconfig-snsc_mpu22x .config
   make ARCH=mips CROSS_COMPILE=mipsel-linux- oldconfig
   make ARCH=mips CROSS_COMPILE=mipsel-linux- dep
   touch makeconfig.done
fi

if [ ! -f "$LINUX_SRC_DIR/install.done" ]; then
   cd "$LINUX_SRC_DIR"
   include_dir="$PREFIX/$TARGET/include"
   mkdir -p "$include_dir"
   cp -rpL include/linux "$include_dir/"
   cp -rpL include/asm-mips "$include_dir/asm"
   touch install.done
fi

cd $SCRIPT_DIR

if [ ! -d "glibc-pkg-src" ]; then
   cpiofile="${GLIBC_RPM%.*}.cpio"
   echo "Extracting $GLIBC_RPM"
   if [ ! -f "$cpiofile" ]; then
      7z x "$GLIBC_RPM"
   fi
   mkdir glibc-pkg-src
   cpio -idmv -D glibc-pkg-src < $cpiofile
fi

if [ ! -f "$GLIBC_SRC_DIR/extract.done" ]; then
   echo "Extracting glibc source"
   tar xf "glibc-pkg-src/glibc-2.2.5.tar.bz2" -C .
   tar xf "glibc-pkg-src/glibc-linuxthreads-2.2.5.tar.bz2" -C "glibc-2.2.5/"
   touch "$GLIBC_SRC_DIR/extract.done"
fi

if [ ! -f "$GLIBC_SRC_DIR/patch.done" ]; then
   echo "Patching glibc source"
   zcat "glibc-pkg-src/glibc_2.2.3-9.diff.gz" | patch -N -p1 -d "$GLIBC_SRC_DIR"
   declare -a patches=(
      "glibc-2.2.5-cvs.patch"
      "glibc-2.2.5-cvs-po.patch"
      "glibc-2.2.5-procstat.patch"
      "glibc-2.2.5-cvs2.patch"
      "hhl-glibc-rpc-cross.patch"
      "hhl-glibc-rpc-cpp.patch"
      "hhl-glibc-2.2.5-save-lds.patch"
      "hhl-glibc-mips-atomic-op.patch"
      "glibc-2.2.5_mips_nfp.patch"
      "glibc-2.2.5-mips-regdump.patch"
      "glibc-affinity-syscalls-rml-2.2.5-1.patch"
      "glibc-2.2.5-mips-profile.patch"
      "hhl-glibc-mips-regsets.patch"
      "glibc-2.2.5-mips-vfork.patch"
      "hhl-glibc-libgcc-compat.patch"
      "glibc-2.2.5-lsb-nice.patch"
      "glibc-2.2.5-lsb-locale.patch"
      "glibc-2.2.5-xdrmem.patch"
      "hhl-glibc-ftw-lsb-compat.patch"
      "hhl-glibc-grantpt-lsb-compat.patch"
      "hhl-glibc-sysconf-lsb-compat.patch"
      "glibc-2.2.5-timers.patch"
      "glibc-2.2.5-resolvleak.patch"
      "glibc-2.2.4-getgrouplist.patch"
   )
   for p in "${patches[@]}"; do
      echo "Applying $p..."
      patch -N -d "$GLIBC_SRC_DIR" -p1 < "glibc-pkg-src/$p"
   done

   mkdir "$GLIBC_SRC_DIR/rpc"
   cp "$GLIBC_SRC_DIR/sunrpc/rpc/"*.h "$GLIBC_SRC_DIR/rpc"

   touch "$GLIBC_SRC_DIR/sysdeps/unix/sysv/linux/configure"
   
   touch "$GLIBC_SRC_DIR/patch.done"
fi

if [ ! -d "$GLIBC_BUILD_DIR" ]; then
   mkdir "$GLIBC_BUILD_DIR"
fi

if [ ! -f "$GLIBC_BUILD_DIR/configure.done" ]; then
   cd "$GLIBC_BUILD_DIR"
   echo "Configuring glibc"
   CFLAGS="-g -O2 -finline-limit-10000" \
   "$GLIBC_SRC_DIR/configure" \
      --build=x86_64-pc-linux-gnu \
      --host=mipsel-linux \
      --prefix=$PREFIX/$TARGET \
      --with-headers="$PREFIX/$TARGET/include" \
      --enable-add-ons \
      --without-cvs
   touch configure.done
fi

if [ ! -f "$GLIBC_BUILD_DIR/build.done" ]; then
   cd "$GLIBC_BUILD_DIR"
   echo "Compiling glibc"
   make
   touch build.done
fi

if [ ! -f "$GLIBC_BUILD_DIR/install.done" ]; then
   cd "$GLIBC_BUILD_DIR"
   echo "Intalling glibc"
   make install
   touch install.done
fi

cd $SCRIPT_DIR

if [ ! -d "$GCC_STAGE2_BUILD_DIR" ]; then
   mkdir "$GCC_STAGE2_BUILD_DIR"
fi

if [ ! -f "$GCC_STAGE2_BUILD_DIR/configure.done" ]; then
   cd "$GCC_STAGE2_BUILD_DIR"
   echo "Configuring gcc stage 2"
   CFLAGS="-Wno-implicit-int -Wno-implicit-function-declaration" \
   "$GCC_SRC_DIR/configure" \
      --target=$TARGET\
      --prefix=$PREFIX \
      --with-sysroot=$PREFIX/$TARGET \
      --enable-languages=c \
      --disable-multilib \
      --enable-shared \
      --enable-threads=posix
   touch configure.done
fi

if [ ! -f "$GCC_STAGE2_BUILD_DIR/build.done" ]; then
   cd "$GCC_STAGE2_BUILD_DIR"
   echo "Compiling gcc stage 2"
   make -j"$(nproc)" HOST_CFLAGS="-Wno-error=incompatible-pointer-types"
   touch build.done
fi

if [ ! -f "$GCC_STAGE2_BUILD_DIR/install.done" ]; then
   cd "$GCC_STAGE2_BUILD_DIR"
   echo "Intalling gcc stage 2"
   make install
   touch install.done
fi

echo "Done!"