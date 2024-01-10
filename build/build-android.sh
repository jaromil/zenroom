#!/usr/bin/env bash

# export ANDROID_HOME="${ANDROID_HOME:-${HOME}/Android/Sdk}"
export NDK_HOME="$1"

export LIB_SRC_PATH=${LIB_SRC_PATH:=${PWD}/src}
export LIB_DST_PATH=${LIB_DST_PATH:=${PWD}/build/target/android/jniLibs}

build () {

	echo "${0}: Building Android ${2} libs ..."
	make clean
	make android-$1
	mkdir -p ${LIB_DST_PATH}/${3}
	cp ${LIB_SRC_PATH}/zenroom.so ${LIB_DST_PATH}/${3}/libzenroom.so
}

if [ ! -d "$NDK_HOME" ]; then
  echo "NDK_HOME environment variable not set"
  exit 1
fi

build "x86" "i686-linux-android" "x86"
build "arm" "arm-linux-androideabi" "armeabi-v7a"
build "aarch64" "aarch64-linux-android" "arm64-v8a"
echo "Built Android libs placed under ${LIB_DST_PATH}"
