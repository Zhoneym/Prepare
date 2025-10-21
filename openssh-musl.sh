#!/bin/bash
dnf install wget -y
wget https://musl.cc/x86_64-linux-musl-cross.tgz
dnf install tar -y
tar -xvf x86_64-linux-musl-cross.tgz
mv x86_64-linux-musl-cross /
ls -l /x86_64-linux-musl-cross/bin/
wget -q https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.2p1.tar.gz
dnf install gzip
tar -xf openssh-10.2p1.tar.gz
mkdir -p /openssh-10.2p1
dnf install make -y
export CC=/x86_64-linux-musl-cross/bin/x86_64-linux-musl-gcc
export CXX=/x86_64-linux-musl-cross/bin/x86_64-linux-musl-g++
export AR=/x86_64-linux-musl-cross/bin/x86_64-linux-musl-ar
export RANLIB=/x86_64-linux-musl-cross/bin/x86_64-linux-musl-ranlib
export LD=/x86_64-linux-musl-cross/bin/x86_64-linux-musl-ld
export CFLAGS="-Os -static"
export LDFLAGS="-static"
wget https://zlib.net/zlib-1.3.1.tar.gz
tar -xvf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --static
make -j$(nproc)
cd ..
wget https://github.com/openssl/openssl/releases/download/openssl-3.6.0/openssl-3.6.0.tar.gz
tar -xvf openssl-3.6.0.tar.gz
cd openssl-3.6.0
export CFLAGS="-Os -static -I$HOME/zlib-1.3.1"
export LDFLAGS="-static -L$HOME/zlib-1.3.1"
dnf install perl -y
./Configure --static
make -j$(nproc)
cd ..
cd openssh-10.2p1
export CFLAGS="-static -I$HOME/openssl-3.6.0/include -I$HOME/zlib-1.3.1"
export LDFLAGS="-static -L$HOME/openssl-3.6.0 -L$HOME/zlib-1.3.1"
./configure --prefix=/openssh-10.2p1
make -j$(nproc)
ln -sr /x86_64-linux-musl-cross/bin/x86_64-linux-musl-strip /usr/bin/strip
make install
# sed -i 's/-oGSSAPIKexAlgorithms[^ ]* //g' /etc/crypto-policies/back-ends/opensshserver.config
# sed -i 's/^GSSAPIKexAlgorithms.*//g' /etc/crypto-policies/back-ends/openssh.config
