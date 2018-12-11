# FFmpeg iOS build script

[![Build Status](https://travis-ci.org/kewlbear/FFmpeg-iOS-build-script.svg?branch=master)](https://travis-ci.org/kewlbear/FFmpeg-iOS-build-script)

This is a shell script to build FFmpeg libraries for iOS and tvOS apps.

Tested with:

* FFmpeg 4.0.3
* Xcode 10.1

## Requirements

* https://github.com/libav/gas-preprocessor
* yasm 1.2.0

## Usage

Use build-ffmpeg-tvos.sh for tvOS.

* To build everything:

        ./build-ffmpeg.sh

* To build arm64 libraries:

        ./build-ffmpeg.sh arm64

* To build fat libraries for armv7 and x86_64 (64-bit simulator):

        ./build-ffmpeg.sh armv7 x86_64

* To build fat libraries from separately built thin libraries:

        ./build-ffmpeg.sh lipo

## Download

You can download a binary for FFmpeg 4.0.3 release at https://downloads.sourceforge.net/project/ffmpeg-ios/ffmpeg-ios-master.tar.bz2

## External libraries

You should link your app with

* libz.dylib
* libbz2.dylib
* libiconv.dylib
