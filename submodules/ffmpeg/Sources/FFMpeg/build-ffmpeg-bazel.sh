#!/bin/bash

set -x

RAW_ARCHS="$2"
ARCHS=""

for RAW_ARCH in $RAW_ARCHS; do
	ARCH_NAME="$RAW_ARCH"
	if [ "$ARCH_NAME" = "i386" -o "$ARCH_NAME" = "x86_64" -o "$ARCH_NAME" = "arm64" -o "$ARCH_NAME" = "armv7" -o "$ARCH_NAME" = "sim_arm64" -o "$ARCH_NAME" = "macos_arm64" -o "$ARCH_NAME" = "linux_arm64" -o "$ARCH_NAME" = "linux_x86_64" ]
	then
		ARCHS="$ARCHS $ARCH_NAME"
	else
		echo "Invalid architecture $ARCH"
		exit 1
	fi
done

BUILD_DIR=$3
SOURCE_DIR=$4

FF_VERSION="$5"
SOURCE="$SOURCE_DIR/ffmpeg-$FF_VERSION"

GAS_PREPROCESSOR_PATH="$SOURCE_DIR/gas-preprocessor.pl"

FAT="$BUILD_DIR/FFmpeg-iOS"

SCRATCH="$BUILD_DIR/scratch"
THIN="$BUILD_DIR/thin"

PKG_CONFIG="$SOURCE_DIR/pkg-config"

export PATH="$SOURCE_DIR:$PATH"

LIB_NAMES="libavcodec libavformat libavutil libswresample"

set -e

CONFIGURE_FLAGS="--enable-cross-compile --disable-programs \
                 --disable-armv5te --disable-armv6 --disable-armv6t2 \
                 --disable-doc --enable-pic --disable-all --disable-everything \
                 --enable-avcodec  \
                 --enable-swresample \
                 --enable-avformat \
                 --disable-xlib \
                 --enable-libopus \
                 --enable-libvpx \
                 --enable-libdav1d \
                 --enable-bsf=aac_adtstoasc,vp9_superframe,h264_mp4toannexb \
                 --enable-decoder=h264,libvpx_vp9,hevc,libopus,flac,pcm_s16le,pcm_s24le,pcm_f32le,libdav1d,av1,mp3 \
                 --enable-demuxer=aac,mov,m4v,mp3,ogg,libopus,flac,wav,aiff,matroska,mpegts, \
                 --enable-parser=aac,h264,mp3,libopus \
                 --enable-protocol=file \
                 --enable-muxer=mp4,matroska,ogg,mpegts \
                 "

#vorbis

EXTRA_CFLAGS="-DCONFIG_SAFE_BITSTREAM_READER=1"

if [ "$1" = "debug" ];
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-optimizations --disable-stripping"
elif [ "$1" = "release" ];
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-debug"
else
	echo "No configuration specified (debug / release)"
	exit 1
fi

COMPILE="y"

DEPLOYMENT_TARGET="13.0"

LIBS_HASH=""
for ARCH in $ARCHS
do
	for LIB_NAME in $LIB_NAMES
	do
		LIB="$THIN/$ARCH/lib/$LIB_NAME.a"
		if [ -f "$LIB" ]; then
			LIB_DATE=$(crc32 "$LIB" 2>/dev/null || cksum "$LIB" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
			LIBS_HASH="$LIBS_HASH $ARCH/$LIB:$LIB_DATE"
		fi
	done
done

if [ "$COMPILE" ]
then
	if [ ! `which pkg-config` ]; then
		echo 'pkg-config not found'
		exit 1
	else
		echo "PATH=$PATH"
		echo "pkg-config=$(which pkg-config)"
	fi
	IS_LINUX=false
	for A in $ARCHS; do
		case "$A" in linux_*) IS_LINUX=true ;; esac
	done
	if [ "$IS_LINUX" = "false" ] && [ ! `which "$GAS_PREPROCESSOR_PATH"` ]; then
		echo '$GAS_PREPROCESSOR_PATH not found.'
		exit 1
	fi

	if [ ! -r $SOURCE ]; then
		echo "FFmpeg source not found at $SOURCE"
		exit 1
	fi

	for RAW_ARCH in $ARCHS
	do
		ARCH="$RAW_ARCH"
		if [ "$RAW_ARCH" == "sim_arm64" ]; then
			ARCH="arm64"
		elif [ "$RAW_ARCH" == "macos_arm64" ]; then
			ARCH="arm64"
		fi

		echo "building $RAW_ARCH..."
		mkdir -p "$SCRATCH/$RAW_ARCH"
		pushd "$SCRATCH/$RAW_ARCH"

		LIBOPUS_PATH="$SOURCE_DIR/libopus"
		LIBVPX_PATH="$SOURCE_DIR/libvpx"
		LIBDAV1D_PATH="$SOURCE_DIR/libdav1d"

		if [ "$RAW_ARCH" = "linux_arm64" ]; then
			ARCH="aarch64"
			CFLAGS="$EXTRA_CFLAGS -fPIC"
			CC="gcc"
			AS="gcc"
			PLATFORM="linux"
		elif [ "$RAW_ARCH" = "linux_x86_64" ]; then
			ARCH="x86_64"
			CFLAGS="$EXTRA_CFLAGS -fPIC"
			CC="gcc"
			AS="nasm"
			PLATFORM="linux"
		else
		CFLAGS="$EXTRA_CFLAGS -arch $ARCH"
		if [ "$RAW_ARCH" = "sim_arm64" ]; then
			PLATFORM="iPhoneSimulator"
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET --target=arm64-apple-ios$DEPLOYMENT_TARGET-simulator"
		elif [ "$RAW_ARCH" = "macos_arm64" ]; then
			PLATFORM="MacOSX"
		    CFLAGS="$CFLAGS -mmacosx-version-min=14.0 --target=arm64-apple-macosx14.0"
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi
		fi
		fi

		if [ "$PLATFORM" != "linux" ]; then
			XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
			CC="xcrun -sdk $XCRUN_SDK clang"

			if [ "$RAW_ARCH" = "arm64" ] || [ "$RAW_ARCH" = "sim_arm64" ] || [ "$RAW_ARCH" = "macos_arm64" ]
			then
			    AS="$GAS_PREPROCESSOR_PATH -arch aarch64 -- $CC"
			else
			    AS="$GAS_PREPROCESSOR_PATH -- $CC"
			fi
		fi

		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CONFIGURED_MARKER="$THIN/$RAW_ARCH/configured_marker"
		CONFIGURED_MARKER_CONTENTS=""
		if [ -r "$CONFIGURED_MARKER" ]
		then
			CONFIGURED_MARKER_CONTENTS=`cat "$CONFIGURED_MARKER"`
		fi
		if [ "$CONFIGURED_MARKER_CONTENTS" = "$CONFIGURE_FLAGS" ]
		then
			echo "1" >/dev/null
		else
			mkdir -p "$THIN/$RAW_ARCH"
			if [ "$PLATFORM" = "linux" ]; then
				TMPDIR=${TMPDIR/%\/} "$SOURCE/configure" \
				    --target-os=linux \
				    --arch=$ARCH \
				    --cc="$CC" \
				    --as="$AS" \
				    $CONFIGURE_FLAGS \
				    --enable-encoder=libvpx_vp9 \
				    --extra-cflags="$CFLAGS" \
				    --extra-ldflags="$LDFLAGS" \
				    --prefix="$THIN/$RAW_ARCH" \
				    --pkg-config="$PKG_CONFIG" \
				    --pkg-config-flags="--libopus_path $LIBOPUS_PATH --libvpx_path $LIBVPX_PATH --libdav1d_path $LIBDAV1D_PATH" \
				|| exit 1
			else
				TMPDIR=${TMPDIR/%\/} "$SOURCE/configure" \
				    --target-os=darwin \
				    --arch=$ARCH \
				    --cc="$CC" \
				    --as="$AS" \
				    $CONFIGURE_FLAGS \
				    --enable-audiotoolbox \
				    --enable-decoder=alac_at,gsm_ms_at,aac_at \
				    --enable-encoder=libvpx_vp9,aac_at \
				    --enable-hwaccel=h264_videotoolbox,hevc_videotoolbox,av1_videotoolbox \
				    --extra-cflags="$CFLAGS" \
				    --extra-ldflags="$LDFLAGS" \
				    --prefix="$THIN/$RAW_ARCH" \
				    --pkg-config="$PKG_CONFIG" \
				    --pkg-config-flags="--libopus_path $LIBOPUS_PATH --libvpx_path $LIBVPX_PATH --libdav1d_path $LIBDAV1D_PATH" \
				|| exit 1
			fi
			echo "$CONFIGURE_FLAGS" > "$CONFIGURED_MARKER"
		fi

		CORE_COUNT=$(nproc 2>/dev/null || PATH="$PATH:/usr/sbin" sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
		make -j$CORE_COUNT install $EXPORT || exit 1

		popd
	done
fi

UPDATED_LIBS_HASH=""
for ARCH in $ARCHS
do
	for LIB_NAME in $LIB_NAMES
	do
		LIB="$THIN/$ARCH/lib/$LIB_NAME.a"
		if [ -f "$LIB" ]; then
			LIB_DATE=$(crc32 "$LIB" 2>/dev/null || cksum "$LIB" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
			UPDATED_LIBS_HASH="$UPDATED_LIBS_HASH $ARCH/$LIB:$LIB_DATE"
		fi
	done
done

if [ "$UPDATED_LIBS_HASH" = "$LIBS_HASH" ]
then
	echo "Libs aren't changed, skipping lipo"
else
	echo "UPDATED_LIBS_HASH=$UPDATED_LIBS_HASH"
	echo "LIBS_HASH=$LIBS_HASH"
	LIPO="y"
fi

if [ "$LIPO" ]
then
	echo "building fat binaries in $FAT"
	mkdir -p "$FAT"/lib
	set - $ARCHS
	for LIB in "$THIN/$1/lib/"*.a
	do
		LIB_NAME="$(basename $LIB)"
		echo "LIPO_INPUT command find \"$THIN\" -name \"$LIB_NAME\""
		LIPO_INPUT=`find "$THIN" -name "$LIB_NAME"`
		if command -v lipo >/dev/null 2>&1; then
			lipo -create $LIPO_INPUT -output "$FAT/lib/$LIB_NAME" || exit 1
		else
			cp $LIPO_INPUT "$FAT/lib/$LIB_NAME" || exit 1
		fi
	done

	cp -rf "$THIN/$1/include" "$FAT"
fi

echo Done
