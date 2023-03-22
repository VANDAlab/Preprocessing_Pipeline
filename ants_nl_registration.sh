#! /bin/bash

if [ $# -eq 3 ];then
    src=$1
    trg=$2
    outp=$3
elif [ $# -eq 5 ];then
    src=$1
    trg=$2
    src_mask=$3
    trg_mask=$4
    outp=$5
else
 echo "Usage $0 <source> <target> [source mask] [target mask] <output_prefix>"
 echo "Output will be <output_prefix>0_NL.xfm and <output_prefix>0NL_inverse.xfm with corresponding grid files"
 exit 1
fi

if [ ! -z $trg_mask ];then
mask="-x [${src_mask},${trg_mask}] "
fi


antsRegistration -v -d 3 --float 1 \
    --output "[${outp}]" \
    --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
    --transform "SyN[0.7,3,0]" \
        --metric "CC[${src},${trg},1,4]" \
        --convergence "[50x50x30,1e-6,10]" \
        --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox \
        ${mask} --minc
