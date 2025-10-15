#!/bin/bash
set -e

# Use this to average data from multiple runs
#awk '{size[FNR]+=$2;bytes[FNR]+=$3;psnr[FNR]+=$2*$4;psnrhvs[FNR]+=$2*$5;ssim[FNR]+=$2*$6;fastssim[FNR]+=$2*$7;}END{for(i=1;i<=FNR;i++)print i+1,size[i],bytes[i],psnr[i]/size[i],psnrhvs[i]/size[i],ssim[i]/size[i],fastssim[i]/size[i];}' *.out > total.out

if [ -n "$IMAGE" ]; then
  IMAGE="$IMAGE-"
fi

if [ $# == 0 ]; then
  echo "usage: IMAGE=<prefix> $0 *.out"
  exit 1
fi

if [ -z "$GNUPLOT" -a -n "`type -p gnuplot`" ]; then
  GNUPLOT=`type -p gnuplot`
fi
if [ ! -x "$GNUPLOT" ]; then
  echo "Executable not found GNUPLOT=$GNUPLOT"
  echo "Please install it or set GNUPLOT to point to an installed copy"
  exit 1
fi

CMDS="$CMDS set term pngcairo dashed size 1024,768;"
CMDS="$CMDS set log x;"
CMDS="$CMDS set xlabel 'Bits/Pixel';"
CMDS="$CMDS set ylabel 'dB';"
CMDS="$CMDS set key bot right;"

for FILE in "$@"; do
  BASENAME=$(basename $FILE)
  PSNR="$PSNR $PREFIX '$FILE' using (\$3*8/\$2):4 with lines title '${BASENAME%.*} (PSNR)'"
  PSNRHVS="$PSNRHVS $PREFIX '$FILE' using (\$3*8/\$2):5 with lines title '${BASENAME%.*} (PSNR-HVS)'"
  SSIM="$SSIM $PREFIX '$FILE' using (\$3*8/\$2):6 with lines title '${BASENAME%.*} (SSIM)'"
  FASTSSIM="$FASTSSIM $PREFIX '$FILE' using (\$3*8/\$2):7 with lines title '${BASENAME%.*} (FAST SSIM)'"
  PREFIX=","
done

SUFFIX="psnr.png"
$GNUPLOT -e "$CMDS set output \"$IMAGE$SUFFIX\"; plot $PSNR;"     2> /dev/null
SUFFIX="psnrhvs.png"
$GNUPLOT -e "$CMDS set output \"$IMAGE$SUFFIX\"; plot $PSNRHVS;"  2> /dev/null
SUFFIX="ssim.png"
$GNUPLOT -e "$CMDS set output \"$IMAGE$SUFFIX\"; plot $SSIM;"     2> /dev/null
SUFFIX="fastssim.png"
$GNUPLOT -e "$CMDS set output \"$IMAGE$SUFFIX\"; plot $FASTSSIM;" 2> /dev/null
