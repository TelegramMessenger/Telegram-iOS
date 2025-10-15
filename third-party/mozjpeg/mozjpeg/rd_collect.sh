#!/bin/bash
set -e

if [ $# == 0 ]; then
  echo "usage: DAALA_ROOT=<daala_root> MOZJPEG_ROOT=<mozjpeg_root> $0 *.y4m"
  exit 1
fi

if [ -z $MOZJPEG_ROOT ]; then
  MOZJPEG_ROOT=.
fi

if [ -z $DAALA_ROOT ]; then
  echo "DAALA_ROOT not set."
  exit 1
fi

if [ -z "$PLANE" ]; then
  export PLANE=0
fi

if [ $PLANE != 0 ] && [ $PLANE != 1 ] && [ $PLANE != 2 ]; then
  echo "Invalid plane $PLANE. Must be 0, 1 or 2."
  exit 1
fi

if [ -z "$YUVJPEG" ]; then
  export YUVJPEG=$MOZJPEG_ROOT/yuvjpeg
fi

if [ -z "$JPEGYUV" ]; then
  export JPEGYUV=$MOZJPEG_ROOT/jpegyuv
fi

if [ ! -x "$YUVJPEG" ]; then
  echo "Executable not found YUVJPEG=$YUVJPEG"
  echo "Do you have the right MOZJPEG_ROOT=$MOZJPEG_ROOT"
  exit 1
fi

if [ ! -x "$JPEGYUV" ]; then
  echo "Executable not found JPEGYUV=$JPEGYUV"
  echo "Do you have the right MOZJPEG_ROOT=$MOZJPEG_ROOT"
  exit 1
fi

# TODO refactor these out of the daala project into a metrics project

if [ -z "$YUV2YUV4MPEG" ]; then
  export YUV2YUV4MPEG=$DAALA_ROOT/tools/yuv2yuv4mpeg
fi

if [ -z "$DUMP_PSNR" ]; then
  export DUMP_PSNR=$DAALA_ROOT/tools/dump_psnr
fi

if [ -z "$DUMP_PSNRHVS" ]; then
  export DUMP_PSNRHVS=$DAALA_ROOT/tools/dump_psnrhvs
fi

if [ -z "$DUMP_SSIM" ]; then
  export DUMP_SSIM=$DAALA_ROOT/tools/dump_ssim
fi

if [ -z "$DUMP_FASTSSIM" ]; then
  export DUMP_FASTSSIM=$DAALA_ROOT/tools/dump_fastssim
fi

if [ ! -x "$YUV2YUV4MPEG" ]; then
  echo "Executable not found YUV2YUV4MPEG=$YUV2YUV4MPEG"
  echo "Do you have the right DAALA_ROOT=$DAALA_ROOT"
  exit 1
fi

if [ ! -x "$DUMP_PSNR" ]; then
  echo "Executable not found DUMP_PSNR=$DUMP_PSNR"
  echo "Do you have the right DAALA_ROOT=$DAALA_ROOT"
  exit 1
fi

if [ ! -x "$DUMP_PSNRHVS" ]; then
  echo "Executable not found DUMP_PSNRHVS=$DUMP_PSNRHVS"
  echo "Do you have the right DAALA_ROOT=$DAALA_ROOT"
  exit 1
fi

if [ ! -x "$DUMP_SSIM" ]; then
  echo "Executable not found DUMP_SSIM=$DUMP_SSIM"
  echo "Do you have the right DAALA_ROOT=$DAALA_ROOT"
  exit 1
fi

if [ ! -x "$DUMP_FASTSSIM" ]; then
  echo "Executable not found DUMP_FASTSSIM=$DUMP_FASTSSIM"
  echo "Do you have the right DAALA_ROOT=$DAALA_ROOT"
  exit 1
fi

RD_COLLECT_SUB=$(dirname "$0")/rd_collect_sub.sh

if [ -z "$CORES" ]; then
  CORES=`grep -i processor /proc/cpuinfo | wc -l`
  #echo "CORES not set, using $CORES"
fi

find $@ -type f -name "*.y4m" -print0 | xargs -0 -n1 -P$CORES $RD_COLLECT_SUB
