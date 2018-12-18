#!/bin/sh

ARCHS="$2"

for ARCH in $ARCHS
do
	if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" -o "$ARCH" = "arm64" -o "$ARCH" = "armv7" ]
	then
		echo "1" >/dev/null
	else
		echo "Invalid architecture $ARCH"
		exit 1
	fi
done

BUILD_DIR=$3
SOURCE_DIR=$4

FF_VERSION="4.1"
SOURCE="$SOURCE_DIR/ffmpeg-$FF_VERSION"

FAT="$BUILD_DIR/FFmpeg-iOS"

SCRATCH="$BUILD_DIR/scratch"
THIN="$BUILD_DIR/thin"

PKG_CONFIG="$SOURCE_DIR/pkg-config-wrapper.sh"

LIB_NAMES="libavcodec libavformat libavutil libswresample"

set -e

CONFIGURE_FLAGS="--enable-cross-compile --disable-programs \
                 --disable-doc --enable-pic --disable-all --disable-everything \
                 --disable-videotoolbox \
                 --enable-avcodec  \
                 --enable-swresample \
                 --enable-avformat \
                 --disable-xlib \
                 --enable-audiotoolbox \
                 --enable-libopus \
                 --enable-bsf=aac_adtstoasc \
                 --enable-decoder=h264,libopus,mp3_at,aac_at,flac,alac_at,pcm_s16le,pcm_s24le,gsm_ms_at \
                 --enable-demuxer=aac,mov,m4v,mp3,ogg,libopus,flac,wav \
                 --enable-parser=aac,h264,mp3,libopus \
                 "


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

#CONFIGURE_FLAGS="$CONFIGURE_FLAGS --pkg-config=$PKG_CONFIG"

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
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
                        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
				|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi
	if [ ! `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			-o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
	fi

	if [ ! -r $SOURCE ]
	then
		echo "FFmpeg source not found at $SOURCE"
		exit 1
	fi

	CWD="$BUILD_DIR"
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		LIBOPUS_TARGET_PATH="$SCRATCH/$ARCH"
		LIBOPUS_PATH="$LIBOPUS_TARGET_PATH/libopus"

		VANILLA_OPUS_PC=`cat $SOURCE_DIR/libopus/opus.pc`
		OPUS_PC="prefix=\"$LIBOPUS_PATH\"\n$VANILLA_OPUS_PC"

		if [ ! -e "$LIBOPUS_PATH/opus.pc" ]
		then
			echo "Generating opus.pc"
			rm -rf "$LIBOPUS_PATH"
			cp -R "$SOURCE_DIR/libopus" "$LIBOPUS_TARGET_PATH"

			echo "$OPUS_PC" > "$LIBOPUS_PATH/opus.pc"
		fi

		export PKG_CONFIG_PATH="$LIBOPUS_PATH"

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"

		# force "configure" to use "gas-preprocessor.pl" (FFmpeg 3.3)
		if [ "$ARCH" = "arm64" ]
		then
		    AS="gas-preprocessor.pl -arch aarch64 -- $CC"
		else
		    AS="gas-preprocessor.pl -- $CC"
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
