#!/bin/bash
set -e

if [ $# == 0 ]; then
  echo "usage: OUTPUT=<label> $0 *.out"
  exit 1
fi

TOTAL=total.out

if [ -n "$OUTPUT" ]; then
  TOTAL="$OUTPUT.out"
fi

awk '{size[FNR]+=$2;bytes[FNR]+=$3;psnr[FNR]+=$2*$4;psnrhvs[FNR]+=$2*$5;ssim[FNR]+=$2*$6;fastssim[FNR]+=$2*$7;}END{for(i=1;i<=FNR;i++)print i-1,size[i],bytes[i],psnr[i]/size[i],psnrhvs[i]/size[i],ssim[i]/size[i],fastssim[i]/size[i];}' $@ > $TOTAL
