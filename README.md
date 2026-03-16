# CP Toolchain

This repo builds cross compilers targeting the Communications Processor found in the DECR-1000 and DTP-T1000.

## Building

For Debian and Ubuntu install ```build-essential autoconf cpio p7zip-full wget```

### DECR-1000

```bash
cd DECR-1000 && ./build.sh
```

### DTP-T1000

The following packages must be supplied:

 - hhl-target-binutils-2.12.1-mvl3.0.0.14.3.src.rpm
 - hhl-target-glibc-2.2.5-mvl3.0.0.15.15.src.rpm
 - DTP-T1000-linux-2.4.tar.gz

```bash
cd DTP-T1000 && ./build.sh
```

## DECR-1000 Cross Compiler

Installs in /opt/decr-1000-cp-toolchain/

Built with:

 - GCC 3.2.1-mvl3.0.0.5.20
 - Binutils 2.12.1-mvl3.0.0.14.3
 - Glibc 2.2.5-mvl3.0.0.15.14

## DTP-T1000 Cross Compiler

Installs in /opt/dtp-t1000-cp-toolchain/

Built with:

 - GCC 3.2.3
 - Binutils 2.12.1-mvl3.0.0.14.3
 - Glibc 2.2.5-mvl3.0.0.15.15

## Notes

Binaries compiled using the DECR-1000 cross compiler should work on the DTP-T1000 though it is not thoroughly tested.