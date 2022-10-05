#!/bin/bash

list="x86_64-linux-gnu-gcc x86-linux-gnu-gcc arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc sparc64-linux-gnu-gcc mips-linux-gnu-gcc powerpc-linux-gnu-gcc"
declare -A alias=( [x86-linux-gnu-gcc]=i686-linux-gnu-gcc )
declare -A cppflags=( [sparc64-linux-gnu-gcc]="-mcpu=v7" [mips-linux-gnu-gcc]="-march=mips32" [powerpc-linux-gnu-gcc]="-m32")
declare -a compilers

IFS= read -ra candidates <<< "$list"

# first select platforms/compilers
for cc in ${candidates[@]}
do
	# check compiler first
	if ! command -v ${alias[$cc]:-$cc} &> /dev/null; then
		continue
	fi
	
	if [[ $# == 0 ]]; then
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

# then iterate selected platforms/compilers
for cc in ${compilers[@]}
do
	IFS=- read -r platform host dummy <<< $cc
	
	cd jansson
	export CPPFLAGS=${cppflags[$cc]}
	export CC=${alias[$cc]:-$cc} 
	export CXX=${CC/gcc/g++}
	./configure --enable-static --disable-shared --host=$platform-$host 
	make clean && make
		
	mkdir -p ../targets/$host/$platform
	cp src/.libs/lib*.a $_
	mkdir -p ../targets/$host/$platform/include
	cp src/jansson.h $_
	cp src/jansson_config.h $_
done
