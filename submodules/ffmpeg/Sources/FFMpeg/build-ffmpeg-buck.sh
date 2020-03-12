#!/bin/sh

RAW_ARCHS="$2"
ARCHS=""

for RAW_ARCH in $RAW_ARCHS; do
	ARCH_NAME="$RAW_ARCH"
	if [ "$ARCH_NAME" == "iphoneos-arm64" ]; then
		ARCH_NAME="arm64"
	elif [ "$ARCH_NAME" == "iphoneos-armv7" ]; then
		ARCH_NAME="armv7"
	elif [ "$ARCH_NAME" == "iphonesimulator-x86_64" ]; then
		ARCH_NAME="x86_64"
	elif [ "$ARCH_NAME" == "iphonesimulator-i386" ]; then
		ARCH_NAME="i386"
	fi

	if [ "$ARCH_NAME" = "i386" -o "$ARCH_NAME" = "x86_64" -o "$ARCH_NAME" = "arm64" -o "$ARCH_NAME" = "armv7" ]
	then
		ARCHS="$ARCHS $ARCH_NAME"
	else
		echo "Invalid architecture $ARCH"
		exit 1
	fi
done

BUILD_DIR=$3
SOURCE_DIR=$4

FF_VERSION="4.1"
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
                 --enable-audiotoolbox \
                 --enable-bsf=aac_adtstoasc \
                 --enable-decoder=h264,hevc,libopus,mp3_at,aac,flac,alac_at,pcm_s16le,pcm_s24le,gsm_ms_at \
                 --enable-demuxer=aac,mov,m4v,mp3,ogg,libopus,flac,wav,aiff,matroska \
                 --enable-parser=aac,h264,mp3,libopus \
                 --enable-protocol=file \
                 --enable-muxer=mp4 \
                 "


#--enable-hwaccel=h264_videotoolbox,hevc_videotoolbox \

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

DEPLOYMENT_TARGET="8.0"

LIBS_HASH=""
for ARCH in $ARCHS
do
	for LIB_NAME in $LIB_NAMES
	do
		LIB="$SCRATCH/$ARCH/$LIB_NAME/$LIB_NAME.a"
		if [ -e "$LIB" ]
		then
			LIB_DATE=`crc32 "$LIB"`
			LIBS_HASH="$LIBS_HASH $ARCH/$LIB:$LIB_DATE"
		fi
	done
done

if [ "$COMPILE" ]
then
	if [ ! `which yasm` ]; then
		echo 'Yasm not found'
		exit 1
	fi
	if [ ! `which pkg-config` ]; then
		echo 'pkg-config not found'
		exit 1
	else
		echo "PATH=$PATH"
		echo "pkg-config=$(which pkg-config)"
	fi
	if [ ! `which "$GAS_PREPROCESSOR_PATH"` ]; then
		echo '$GAS_PREPROCESSOR_PATH not found.'
		exit 1
	fi

	if [ ! -r $SOURCE ]; then
		echo "FFmpeg source not found at $SOURCE"
		exit 1
	fi

	CWD="$BUILD_DIR"
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		LIBOPUS_PATH="$SOURCE_DIR/libopus"

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"

		if [ "$ARCH" = "arm64" ]
		then
		    AS="$GAS_PREPROCESSOR_PATH -arch aarch64 -- $CC"
		else
		    AS="$GAS_PREPROCESSOR_PATH -- $CC"
		fi

		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CONFIGURED_MARKER="$THIN/$ARCH/configured_marker"
		CONFIGURED_MARKER_CONTENTS=""
		if [ -r "$CONFIGURED_MARKER" ]
		then
			CONFIGURED_MARKER_CONTENTS=`cat "$CONFIGURED_MARKER"`
		fi
		if [ "$CONFIGURED_MARKER_CONTENTS" = "$CONFIGURE_FLAGS" ]
		then
			echo "1" >/dev/null
		else
			mkdir -p "$THIN/$ARCH"
			TMPDIR=${TMPDIR/%\/} "$SOURCE/configure" \
			    --target-os=darwin \
			    --arch=$ARCH \
			    --cc="$CC" \
			    --as="$AS" \
			    $CONFIGURE_FLAGS \
			    --extra-cflags="$CFLAGS" \
			    --extra-ldflags="$LDFLAGS" \
			    --prefix="$THIN/$ARCH" \
			    --pkg-config="$PKG_CONFIG" \
			    --pkg-config-flags="--libopus_path $LIBOPUS_PATH" \
			|| exit 1
			echo "$CONFIGURE_FLAGS" > "$CONFIGURED_MARKER"
		fi

		CORE_COUNT=`sysctl -n hw.logicalcpu`
		make -j$CORE_COUNT install $EXPORT || exit 1
		cd "$CWD"
	done
fi

UPDATED_LIBS_HASH=""
for ARCH in $ARCHS
do
	for LIB_NAME in $LIB_NAMES
	do
		LIB="$SCRATCH/$ARCH/$LIB_NAME/$LIB_NAME.a"
		if [ -e "$LIB" ]
		then
			LIB_DATE=`crc32 "$LIB"`
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
	echo "building fat binaries..."
	mkdir -p "$FAT"/lib
	set - $ARCHS
	CWD="$BUILD_DIR"
	cd "$THIN/$1/lib"
	for LIB in *.a
	do
		cd "$CWD"
		echo lipo -create `find "$THIN" -name "$LIB"` -output "$FAT/lib/$LIB" 1>&2
		LIPO_INPUT=`find "$THIN" -name "$LIB"`
		lipo -create $LIPO_INPUT -output "$FAT/lib/$LIB" || exit 1
	done

	cd "$CWD"
	cp -rf "$THIN/$1/include" "$FAT"
fi

echo Done
