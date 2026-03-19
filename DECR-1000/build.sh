set -e

SCRIPT_DIR=$(dirname $(realpath "$0"))

TARGET=mipsel-linux
PREFIX=/opt/decr-1000-cp-toolchain

BINUTILS_RPM=hhl-target-binutils-2.12.1-mvl3.0.0.14.3.src.rpm
GLIBC_RPM=hhl-target-glibc-2.2.5-mvl3.0.0.15.14.src.rpm
GCC_RPM=hhl-target-gcc-3.2.1-mvl3.0.0.5.20.src.rpm
LINUX_TAR=DECR-1000-linux-2.4.tar.gz

LINUX_TAR_URL=https://web.archive.org/web/20141118200137/http://oss.sony.net/Products/Linux/Others/Download/DECR-1000/DECR-1000-linux-2.4.tar.gz
BINUTILS_RPM_URL=https://web.archive.org/web/20141118200137/http://oss.sony.net/Products/Linux/Others/Download/common/retCGKc_WAe_ax_UbA4peA/hhl-target-binutils-2.12.1-mvl3.0.0.14.3.src.rpm
GLIBC_RPM_URL=https://web.archive.org/web/20141118200137/http://oss.sony.net/Products/Linux/Others/Download/DECR-1000/hhl-target-glibc-2.2.5-mvl3.0.0.15.14.src.rpm
GCC_URL=https://web.archive.org/web/20141118200137/http://oss.sony.net/Products/Linux/Others/Download/DECR-1000/hhl-target-gcc-3.2.1-mvl3.0.0.5.20.src.rpm
MAKE_URL=https://ftp.gnu.org/gnu/make/make-3.81.tar.gz
BISON_URL=https://ftp.gnu.org/gnu/bison/bison-1.28.tar.gz

MAKE_SRC_DIR="$SCRIPT_DIR/make-3.81"
BISON_SRC_DIR="$SCRIPT_DIR/bison-1.28"
BINUTILS_SRC_DIR="$SCRIPT_DIR/binutils-2.12.1"
BINUTILS_BUILD_DIR="$SCRIPT_DIR/binutils-2.12.1-build"
GLIBC_SRC_DIR="$SCRIPT_DIR/glibc-2.2.5"
GLIBC_BUILD_DIR="$SCRIPT_DIR/glibc-2.2.5-build"
GCC_SRC_DIR="$SCRIPT_DIR/gcc-3.2"
GCC_STAGE1_BUILD_DIR="$SCRIPT_DIR/gcc-3.2-stage1-build"
GCC_STAGE2_BUILD_DIR="$SCRIPT_DIR/gcc-3.2-stage2-build"
LINUX_SRC_DIR="$SCRIPT_DIR/linux"

export PATH="$BISON_SRC_DIR/install/bin:$MAKE_SRC_DIR/install/bin:$PREFIX/bin:$PATH"

urls=($LINUX_TAR_URL $BINUTILS_RPM_URL $GLIBC_RPM_URL $GCC_URL $MAKE_URL)

for i in "${!urls[@]}"; do
   file="${urls[$i]##*/}"
   url=${urls[$i]}
   if [ ! -f "$file" ]; then
      echo "Downloading $file"
      wget $url
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

cd "$SCRIPT_DIR"

if [ ! -f "bison-1.28.tar.gz" ]; then
   echo "Downloading bison 1.28"
   wget $BISON_URL
fi

if [ ! -f "$BISON_SRC_DIR/extract.done" ]; then
   echo "Extracting bison 1.28"
   tar xf bison-1.28.tar.gz
   touch "$BISON_SRC_DIR/extract.done"
fi

if [ ! -f "$BISON_SRC_DIR/configure.done" ]; then
   echo "Configuring bison 1.28"
   cd "$BISON_SRC_DIR"
   CFLAGS="-Wno-implicit-int -Wno-implicit-function-declaration" \
   "$BISON_SRC_DIR/configure" \
      --prefix="$BISON_SRC_DIR/install"
   touch "$BISON_SRC_DIR/configure.done"
fi

if [ ! -f "$BISON_SRC_DIR/build.done" ]; then
   echo "Compiling bison 1.28"
   cd "$BISON_SRC_DIR"
   make
   touch "$BISON_SRC_DIR/build.done"
fi

if [ ! -f "$BISON_SRC_DIR/install.done" ]; then
   echo "Installing bison 1.28"
   cd "$BISON_SRC_DIR"
   make install
   touch "$BISON_SRC_DIR/install.done"
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

if [ ! -d "gcc-pkg-src" ]; then
   cpiofile="${GCC_RPM%.*}.cpio"
   echo "Extracting $GCC_RPM"
   if [ ! -f "$cpiofile" ]; then
      7z x "$GCC_RPM"
   fi
   mkdir gcc-pkg-src
   cpio -idmv -D gcc-pkg-src < $cpiofile
fi

if [ ! -f "$GCC_SRC_DIR/extract.done" ]; then
   echo "Extracting gcc source"
   tar xf "gcc-pkg-src/gcc-3.2.tar.gz" -C .
   touch "$GCC_SRC_DIR/extract.done"
fi

if [ ! -f "$GCC_SRC_DIR/patch.done" ]; then
   echo "Patching gcc source"
   declare -a patches=(
      "gcc-3.2-cvs.patch"
      "libstdc-include-dir.patch"
      "gcc-3.1-libstdcxx-incdir.patch"
      "hhl-gcc3.1-target-nls.patch"
      "gcc-3.1-visibility.patch"
#      "gcc-3.1-with-default-cpu.patch"
      "hhl-gcc3.2-version.patch"
      "gcc-3.2-softfloat.patch"
      "hhl-gcc3.2-cross-profile.patch"
      "gcc-3.2-stack-temps.patch"
      "gcc-3.2-relocation-dirsep.patch"
      "gcc-3.2-relocation-symlink.patch"
      "gcc-3.2_mempcpy.patch"
      "gcc-3.2.2-declone-apple.patch"
      "gcc-3.2.2-declone-mvista.patch"
      "gcc-3.2-compoundlit.patch"
      "gcc-3.2-dwarf-current.patch"
      "gcc-3.2-lifetimes.patch"
      "gcc-3.2-ifcvt.patch"
      "gcc-3.2-libstdc-mips.patch"
      "gcc-3.1-mips_nfp.patch"
      "hhl-gcc3.2-sb1.patch"
   )
   for p in "${patches[@]}"; do
      echo "Applying $p..."
      patch -N -d "$GCC_SRC_DIR" -p1 < "gcc-pkg-src/$p"
   done

   patch -N -d "$GCC_SRC_DIR" -p1 < "gcc-3.2.patch"
   
   touch "$GCC_SRC_DIR/patch.done"
fi

if [ ! -d "$GCC_STAGE1_BUILD_DIR" ]; then
   mkdir "$GCC_STAGE1_BUILD_DIR"
fi

if [ ! -f "$GCC_STAGE1_BUILD_DIR/configure.done" ]; then
   cd "$GCC_STAGE1_BUILD_DIR"
   echo "Configuring gcc stage 1"
   ac_cv_type_uintptr_t=yes \
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
   cp -p arch/mips/configs/defconfig-snsc_tcp5xx .config
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
   ac_cv_type_uintptr_t=yes \
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