#!/bin/bash

list="x86_64-linux-gnu-gcc x86-linux-gnu-gcc arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc \
      sparc64-linux-gnu-gcc mips-linux-gnu-gcc mipsel-linux-gnu-gcc powerpc-linux-gnu-gcc x86_64-macos-darwin-gcc \
      arm64-macos-darwin-cc x86_64-freebsd-gnu-gcc x86_64-solaris-gnu-gcc armv6-linux-gnueabi-gcc \
	  armv5-linux-gnueabi-gcc"

declare -A alias=( [x86-linux-gnu-gcc]=i686-stretch-linux-gnu-gcc \
                   [x86_64-linux-gnu-gcc]=x86_64-stretch-linux-gnu-gcc \
                   [arm-linux-gnueabi-gcc]=armv7-stretch-linux-gnueabi-gcc \
                   [armv5-linux-gnueabi-gcc]=armv6-stretch-linux-gnueabi-gcc \
                   [armv6-linux-gnueabi-gcc]=armv6-stretch-linux-gnueabi-gcc \
                   [aarch64-linux-gnu-gcc]=aarch64-stretch-linux-gnu-gcc \
                   [sparc64-linux-gnu-gcc]=sparc64-stretch-linux-gnu-gcc \
                   [mips-linux-gnu-gcc]=mips64-stretch-linux-gnu-gcc \
				   [mipsel-linux-gnu-gcc]=mips64el-stretch-linux-gnu-gcc \
                   [powerpc-linux-gnu-gcc]=powerpc64-stretch-linux-gnu-gcc \
                   [x86_64-macos-darwin-gcc]=x86_64-apple-darwin19-gcc \
                   [arm64-macos-darwin-cc]=arm64-apple-darwin20.4-cc \
                   [x86_64-freebsd-gnu-gcc]=x86_64-cross-freebsd12.3-gcc \
                   [x86_64-solaris-gnu-gcc]=x86_64-cross-solaris2.x-gcc )

declare -A cflags=( [sparc64-linux-gnu-gcc]="-mcpu=v7" \
                    [mips-linux-gnu-gcc]="-march=mips32" \
					[mipsel-linux-gnu-gcc]="-march=mips32" \
                    [armv5-linux-gnueabi-gcc]="-march=armv5t -mfloat-abi=soft" \
                    [powerpc-linux-gnu-gcc]="-m32" )
					
declare -a compilers					

IFS= read -ra candidates <<< "$list"

# do we have "clean" somewhere in parameters (assuming no compiler has "clean" in it...
if [[ $@[*]} =~ clean ]]; then
	clean="clean"
fi	

# first select platforms/compilers
for cc in ${candidates[@]}; do
	# check compiler first
	if ! command -v ${alias[$cc]:-$cc} &> /dev/null; then
		if command -v $cc &> /dev/null; then
			unset alias[$cc]
		else	
			continue
		fi	
	fi

	if [[ $# == 0 || ($# == 1 && -n $clean) ]]; then
		compilers+=($cc)
		continue
	fi

	for arg in $@
	do
		if [[ $cc =~ $arg ]]; then 
			compilers+=($cc)
		fi
	done
done

item=jansson
library=lib$item.a
pwd=$(pwd)

# bootstrap environment if needed
if [[ ! -f $item/configure && -f $item/configure.ac ]]; then
	cd $item
	if [[ -f autogen.sh ]]; then
		./autogen.sh --no-symlinks
	else 	
		autoreconf -if
	fi	
	cd $pwd
fi	

# then iterate selected platforms/compilers
for cc in ${compilers[@]}
do
	IFS=- read -r platform host dummy <<< $cc

	target=targets/$host/$platform
	
	if [ -f $target/$library ] && [[ -z $clean ]]; then
		continue
	fi
	
	export CFLAGS=${cflags[$cc]}
	export CC=${alias[$cc]:-$cc} 
	export CXX=${CC/gcc/g++}
	export AR=${CC%-*}-ar
	export RANLIB=${CC%-*}-ranlib
	
	# don't let clang create temp files
	if [[ $CC =~ -cc ]]; then
		CFLAGS+="-fno-temp-file"
	else 
		CFLAGS+=" -fPIC"		
	fi		
	
	cd $item
	./configure --enable-static --disable-shared --host=$platform-$host 
	make clean && make
	cd $pwd

	mkdir -p $target		
	cp -u $item/src/.libs/$library $_
	mkdir -p $_/include
	cp -u $item/src/$item.h $_
	cp -u $item/src/"$item"_config.h $_
done
