#!/bin/bash

set -euo pipefail

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=10

### Mahsa Dadar & Yashar Zeighami - 2025-03-08  ###
#Input file format:
# id,visit,t1,t2,pd,flr
# Dependencies: minc-toolki, anaconda, and ANTs
# for use at the CIC, you can load the following modules (or similar versions)
# module load minc-toolkit-v2/1.9.18.2 ANTs/20220513 anaconda/2022.05

if [ $# -eq 3 ];then
    input_list=$1
    model_path=$2
    output_path=$3
    secondary_template_path=output_path
elif [ $# -eq 4 ];then
    input_list=$1
    model_path=$2
    output_path=$3
    secondary_template_path=$4
else
    echo "Usage $0 <input list> <model path> <output_path> <secondary template path>"
    echo "Outputs will be saved in <output_path> folder"
    exit 1
fi
if [ ! -f "$input_list" ]; then
    echo "Error: Input list file '$input_list' not found!"
    exit 1
fi

if [ ! -d "$model_path" ]; then
    echo "Error: Model path '$model_path' does not exist!"
    exit 1
fi
### Naming Conventions ###
# stx: stereotaxic space (i.e. registered to the standard template)
# lin: linear registration 
# nlin: nonlinear registration
# vbm: voxel based morphometry
# dbm: deformation based morphometry
# gm: gray matter
# wm: white matter
# cls: tissue classification
# qc: quality control
# tmp: temporary
# nlm: denoised file (Coupe et al. 2008)
# n3: non-uniformity corrected file (Sled et al. 1998)
# vp: acronym for volume_pol, intensity normalized file
# t1: T1 weighted image 
# t2: T2 weighted image
# pd: Proton Density image
# flr: FLuid Attenuated Inversion Recovery (FLAIR) image
# icbm: standard template
# beast: acronym for brain extraction based on nonlocal segmentation technique (Eskildsen et al. 2012)
# ANTs: Advanced normalization tools (Avants et al. 2009)
# BISON: Brain tissue segmentation (Dadar et al. 2020)

### Pre-processing the native data ###
echo "Pre-processing the native data"
for i in $(cat ${input_list});do
    id=$(echo ${i}|cut -d , -f 1)
    visit=$(echo ${i}|cut -d , -f 2)
    t1=$(echo ${i}|cut -d , -f 3)
    t2=$(echo ${i}|cut -d , -f 4)
    pd=$(echo ${i}|cut -d , -f 5)
    flr=$(echo ${i}|cut -d , -f 6)
    echo ${id} ${visit}
    ### Creating the directories for preprocessed outputs ###
    # native: where the preprocessed images (denoising, non-uniformity correction, intensity normalization) will be saved (before linear registration)
    # stx_lin: where the preprocessed and linearly registered images will be saved
    # stx_nlin: where nonlinear registration outputs (ANTs) will be saved
    # vbm: where deformation based morphometry (dbm) and voxel based morphometry (vbm, separately for gray and white matter) outputs will be saved
    # cls: where tissue classficiation outputs (BISON) will be saved 
    # template: where linear and nonlinear average template will be saved
    # qc: where quality control images will be saved
    # tmp: temporary files, will be deleted at the end

    mkdir -p ${output_path}/${id}/${visit}/native
    mkdir -p ${output_path}/${id}/${visit}/stx_lin
    mkdir -p ${output_path}/${id}/${visit}/stx_nlin
    mkdir -p ${output_path}/${id}/${visit}/vbm
    mkdir -p ${output_path}/${id}/${visit}/cls
    mkdir -p ${output_path}/${id}/template
    mkdir -p ${output_path}/${id}/qc/${visit}/
    mkdir -p ${output_path}/${id}/tmp

    path_t1_vp=${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc 
    path_t2_vp=${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc 
    path_pd_vp=${output_path}/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc 
    path_flr_vp=${output_path}/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc 

    path_t1_stx=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc  
    path_t2_stx=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin_vp.mnc 
    path_pd_stx=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_stx2_lin_vp.mnc 
    path_flr_stx=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin_vp.mnc 

    echo "Pre-processing T1w images"

    if [ ! -f ${path_t1_vp} ];then 
        minc_anlm --mt ${ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS} --beta 0.7 --clobber ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_anlm.mnc
        ### generating temporary masks for non-uniformity correction ###
        antsRegistration_affine_SyN.sh --clobber --skip-nonlinear --fixed-mask ${model_path}/Mask.mnc  ${t1} ${model_path}/Av_T1.mnc ${output_path}/${id}/tmp
        xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm
        mincresample  ${model_path}/Mask.mnc -like ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc -transform \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm -inv -nearest -clobber
        ### non-uniformity correction ###
        nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_anlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_n3.mnc \
        -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber
        ### intensity normalization ###
        volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_n3.mnc ${model_path}/Av_T1.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
        --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber
    fi
    
    if [ ! -f ${path_t2_vp} ] && [ ! -z ${t2} ];then 
        echo "Pre-processing T2w images"
        if [ ! -f ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm ];then
            cp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm
        fi
        minc_anlm --mt ${ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS} --beta 0.7 --clobber ${t2} ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_anlm.mnc
        antsRegistration_affine_SyN.sh --clobber --skip-nonlinear --linear-type lsq6 --close  ${t2} ${t1} ${output_path}/${id}/tmp
        xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm
        xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm -clobber
        mincresample  ${model_path}/Mask.mnc -like ${t2} ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc -transform \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm  -inv -nearest -clobber
        ### non-uniformity correction ###
        nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_anlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_n3.mnc \
        -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber
        ### intensity normalization ###
        volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_n3.mnc ${model_path}/Av_T2.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc \
        --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber
        echo "stx Registration"
        antsRegistration_affine_SyN.sh --clobber --skip-nonlinear --linear-type lsq6 --close \
        ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/tmp
        xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm
    fi

    if [ ! -f ${path_pd_vp} ] && [ ! -z ${pd} ];then 
        echo "Pre-processing PDw images"
        if [ ! -f ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm ];then
            cp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm
        fi
        minc_anlm --mt ${ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS} --beta 0.7 --clobber ${pd} ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_anlm.mnc
        antsRegistration_affine_SyN.sh --clobber --skip-nonlinear --linear-type lsq6 --close ${pd} ${t1} ${output_path}/${id}/tmp
        xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm
        xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx_tmp.xfm -clobber
        mincresample  ${model_path}/Mask.mnc -like ${pd} ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_mask_tmp.mnc -transform \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx_tmp.xfm  -inv -nearest -clobber
        ### non-uniformity correction ###
        nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_anlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_n3.mnc \
        -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber
        ### intensity normalization ###
        volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_n3.mnc ${model_path}/Av_PD.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc \
        --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber
        echo "stx Registration"
        antsRegistration_affine_SyN.sh --clobber --skip-nonlinear --linear-type lsq6 --close \
        ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/tmp
        xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm
    fi

    if [ ! -f ${path_flr_vp} ] && [ ! -z ${flr} ];then 
        echo "Pre-processing FLAIR images"
        if [ ! -f ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm ];then
            cp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm
        fi
        minc_anlm --mt ${ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS} --beta 0.7 --clobber ${flr} ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_anlm.mnc
        antsRegistration_affine_SyN.sh --clobber --skip-nonlinear --linear-type lsq6 --close ${flr} ${t1} ${output_path}/${id}/tmp
        xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm
        xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx_tmp.xfm -clobber
        mincresample  ${model_path}/Mask.mnc -like ${flr} ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_mask_tmp.mnc -transform \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx_tmp.xfm  -inv -nearest -clobber
        ### non-uniformity correction ###
        nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_anlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_n3.mnc \
        -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber
        ### intensity normalization ###
        volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_n3.mnc ${model_path}/Av_FLAIR.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc \
        --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber
        echo "stx Registration"
        antsRegistration_affine_SyN.sh --clobber --skip-nonlinear --linear-type lsq6 --close \
        ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/tmp
        xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm
    fi    
done
echo "Pre-processing the native data completed!"

tp=$(cat ${input_list}|wc -l)
t2=$(echo ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc)
pd=$(echo ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc)
flr=$(echo ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc)
### for just one timepoint; i.e. cross-sectional data ###
if [ ! -f ${path_t1_stx} ] && [ ${tp} = 1 ];then
    echo "cross-sectional data"
    echo "Linear stx registration"
    antsRegistration_affine_SyN.sh --clobber --skip-nonlinear \
        --fixed-mask ${model_path}/Mask.mnc \
        ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
        ${model_path}/Av_T1.mnc \
        ${output_path}/${id}/tmp
    xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_ants.xfm
    itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc \
    --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_ants.xfm --order 4 --clobber
    ### Brain Extraction ###
    mincbeast ${model_path}/ADNI_library ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc -fill -median -same_resolution \
    -configuration ${model_path}/ADNI_library/default.2mm.conf -clobber
    itk_resample ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_native_beast_mask.mnc \
    --like ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_ants.xfm --order  --clobber --invert_transform --label
    ### Registration with Brain Mask
    antsRegistration_affine_SyN.sh --clobber --skip-nonlinear \
        --moving-mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_native_beast_mask.mnc \
        --fixed-mask ${model_path}/Mask.mnc \
        ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
        ${model_path}/Av_T1.mnc \
        ${output_path}/${id}/tmp
    xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm
    itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc \
    --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm --order 4 --clobber
    volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc ${model_path}/Av_T1.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
    --target_mask ${model_path}/Mask.mnc --clobber
    echo "Nonlinear registration"
    src=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc
    trg=${model_path}/Av_T1.mnc
    src_mask=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc
    trg_mask=${model_path}/Mask.mnc
    outp=${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_
    if [ ! -z $trg_mask ];then
        mask="-x [${src_mask},${trg_mask}] "
    fi
    antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
    --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${mask} --minc
    echo "Deformation Based Morphometry"
    itk_resample ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_nlin.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
    grid_proc --det ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL_grid_0.mnc ${output_path}/${id}/${visit}/vbm/${id}_${visit}_dbm.mnc --clobber
    
    if [ -f ${secondary_template_path}/Av_T1.mnc ];then
        echo "Nonlinear registration to indirect template"
        src=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc
        trg=${secondary_template_path}/Av_T1.mnc
        src_mask=${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc
        trg_mask=${secondary_template_path}/Mask.mnc
        outp=${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_inv_nlin_
        if [ ! -z $trg_mask ];then
            mask="-x [${src_mask},${trg_mask}] "
        fi
    
        antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
        --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${mask} --minc

        itk_resample ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_nlin.mnc \
            --like ${secondary_template_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
        grid_proc --det ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_inv_nlin_0_inverse_NL_grid_0.mnc ${output_path}/${id}/${visit}/vbm/${id}_${visit}_secondary_template_dbm.mnc --clobber
        echo "Deformation Based Morphometry with indirect template"
        ### repeating DBM with seconday template as intermediate step
        xfmconcat ${secondary_template_path}/to_icbm_sym_0_inverse_NL.xfm ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_inv_nlin_0_inverse_NL.xfm \
            ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_three_inverse_NL.xfm -clobber
        xfm_normalize.pl ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_three_inverse_NL.xfm ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_3_inv_nlin_0_inverse_NL.xfm \
        --like ${secondary_template_path}/Av_T1.mnc --exact --clobber
        itk_resample ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_3_nlin.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_3_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
        grid_proc --det ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_secondary_template_3_inv_nlin_0_inverse_NL_grid_0.mnc ${output_path}/${id}/${visit}/vbm/${id}_${visit}_indirect_dbm.mnc --clobber
    fi
fi

### Generating input lists for BISON segmentation
echo Subjects,T1s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1.csv
echo Subjects,T1s,FLAIRs,Masks,XFMs >> ${output_path}/${id}/to_segment_t1_flair.csv
echo Subjects,T1s,T2s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1_t2.csv
echo ${id}_${visit}_t1,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc,\
${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc,\
${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1.csv 

    if [ ! -f ${path_t2_stx} ] && [ -f ${t2} ] && [ ${tp} = 1 ];then
        echo "Stx registration of T2w images"
        xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm  \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx2.xfm -clobber
        itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin.mnc \
        --like ${model_path}/Av_T2.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx2.xfm --order 4 --clobber
        ### Generating List for BISON Segmentation ###
        echo ${id}_${visit}_t1_t2,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc,\
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin.mnc,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc,\
        ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1_t2.csv
        volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin.mnc ${model_path}/Av_T2.mnc --order 1 --noclamp \
        --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
        --target_mask ${model_path}/Mask.mnc --clobber
    fi

    if [ ! -f ${path_pd_stx} ] && [ -f ${pd} ] && [ ${tp} = 1 ];then
        echo "Stx registration of PD images"
        xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm  \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx2.xfm -clobber
        itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_stx2_lin.mnc \
        --like ${model_path}/Av_PD.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx2.xfm --order 4 --clobber
        volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_stx2_lin.mnc ${model_path}/Av_PD.mnc --order 1 --noclamp \
        --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
        --target_mask ${model_path}/Mask.mnc --clobber
    fi

    if [ ! -f ${path_flr_stx} ] && [ -f ${flr} ] && [ ${tp} = 1 ];then
        echo "Stx registration of FLAIR images"
        xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm  \
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx2.xfm -clobber
        itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin.mnc \
        --like ${model_path}/Av_FLAIR.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx2.xfm --order 4 --clobber
        ### Generating List for BISON Segmentation ###
        echo ${id}_${visit}_t1_flr,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc,\
        ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin.mnc,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc,\
        ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1_flair.csv
        volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin.mnc ${model_path}/Av_FLAIR.mnc --order 1 --noclamp \
        --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
        --target_mask ${model_path}/Mask.mnc --clobber
    fi
    
tp=$(cat ${input_list}|wc -l)
### for longitudinal data: initial rigid registration of timepoints ###
if [ ${tp} -gt 1 ];then
    echo "longitudinal data: initial rigid registration"
    path_nlin_av=$(echo ${output_path}/${id}/template/${id}_nlin_av.mnc)
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        id=$(echo ${tmp}|cut -d , -f 1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        if [ ! -f ${path_nlin_av} ] && [ ${timepoint} = 1 ];then
            antsRegistration_affine_SyN.sh --clobber --skip-nonlinear \
                --fixed-mask ${model_path}/Mask.mnc \
                ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc \
                ${model_path}/Av_T1.mnc \
                ${output_path}/${id}/tmp
            xfminvert ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/template/${id}_baseline_to_icbm_stx_ants.xfm -clobber

            cp ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_baseline.mnc
            cp ${model_path}/i.xfm  ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_baseline_to_icbm_stx_ants.xfm --order 4 --clobber

            mincbeast ${model_path}/ADNI_library ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            ${output_path}/${id}/template/${id}_${visit_tp}_0_beast_mask.mnc -fill -median -same_resolution -configuration ${model_path}/ADNI_library/default.2mm.conf -clobber

            itk_resample ${output_path}/${id}/template/${id}_${visit_tp}_0_beast_mask.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0_beast_mask_native.mnc \
            --like ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc --transform ${output_path}/${id}/template/${id}_baseline_to_icbm_stx_ants.xfm --order 4  --clobber --invert_transform --label

            antsRegistration_affine_SyN.sh --clobber --skip-nonlinear \
                --fixed-mask ${model_path}/Mask.mnc \
                --moving-mask ${output_path}/${id}/template/${id}_${visit_tp}_0_beast_mask_native.mnc \
                ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc \
                ${model_path}/Av_T1.mnc \
                ${output_path}/${id}/tmp
            xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm

            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm --order 4 --clobber
        fi
        if [ ! -f ${path_nlin_av} ] && [ ${timepoint} -gt 1 ];then
            antsRegistration_affine_SyN.sh --clobber --skip-nonlinear  --linear-type lsq6 \
                ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc \
                ${output_path}/${id}/template/${id}_baseline.mnc \
                ${output_path}/${id}/tmp
            xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm

            xfmconcat ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm  ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm \
            ${output_path}/${id}/template/${id}_${visit_tp}_t1_to_icbm.xfm -clobber
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_t1_to_icbm.xfm --order 4 --clobber
        fi
    done
    if [ ! -f ${path_nlin_av} ];then mincaverage ${output_path}/${id}/template/${id}_*_0.mnc ${output_path}/${id}/template/${id}_lin_av.mnc -clobber;fi
fi
tp=$(cat ${input_list}|wc -l)
### for longitudinal data: linear average template ###
if [ ${tp} -gt 1 ];then
    if [ ! -f ${path_nlin_av} ];then
        echo "longitudinal data: linear average template"
        for iteration in {1..5};do
            for timepoint in $(seq 1 ${tp});do
                tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
                id=$(echo ${tmp}|cut -d , -f 1)
                visit_tp=$(echo ${tmp}|cut -d , -f 2)
                antsRegistration_affine_SyN.sh --clobber --skip-nonlinear  --linear-type lsq6 \
                    ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
                    ${output_path}/${id}/template/${id}_lin_av.mnc \
                    ${output_path}/${id}/tmp
                xfminvert -clobber ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/template/${id}_${visit_tp}.xfm

                xfmconcat ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm  ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm \
                ${output_path}/${id}/template/${id}_${visit_tp}.xfm ${output_path}/${id}/template/${id}_${visit_tp}_t1_to_icbm.xfm -clobber
                itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
                --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_t1_to_icbm.xfm --order 4 --clobber
            done
            mincaverage ${output_path}/${id}/template/${id}_*_0.mnc ${output_path}/${id}/template/${id}_lin_av.mnc -clobber
        done
    
        antsRegistration_affine_SyN.sh --clobber --skip-nonlinear \
            --fixed-mask ${model_path}/Mask.mnc \
            ${output_path}/${id}/template/${id}_lin_av.mnc \
            ${model_path}/Av_T1.mnc \
            ${output_path}/${id}/tmp
        xfminvert ${output_path}/${id}/tmp0_GenericAffine.xfm ${output_path}/${id}/template/${id}_lin_av_to_template.xfm -clobber
    fi
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        id=$(echo ${tmp}|cut -d , -f 1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        t2=$(echo ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_vp.mnc)
        pd=$(echo ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_pd_vp.mnc)
        flr=$(echo ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_flr_vp.mnc)

        path_t1_stx=${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc  
        path_t2_stx=${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc 
        path_pd_stx=${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin.mnc 
        path_flr_stx=${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc

        if [ ! -f ${path_t1_stx} ]; then
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_t1_to_icbm.xfm --order 4 --clobber
            cp ${output_path}/${id}/template/${id}_${visit_tp}_t1_to_icbm.xfm ${output_path}/${id}/${visit_tp}/stx_lin/
            ### BEaST brain mask + another round of intensity normalization with the BEaST mask### 
            mincbeast ${model_path}/ADNI_library ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc \
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc -fill -median -same_resolution -configuration \
            ${model_path}/ADNI_library/default.2mm.conf -clobber
            ### Second round of intensity normalization with the refined brain mask ###
            volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc ${model_path}/Av_T1.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber
        fi
        
        if [ ! -f ${path_t2_stx} ] && [ -f ${t2} ];then 
            xfmconcat ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_to_t1.xfm ${output_path}/${id}/template/${id}_${visit_tp}_t1_to_icbm.xfm \
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_to_icbm_stx.xfm -clobber
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc \
            --like ${model_path}/Av_T2.mnc --transform ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_to_icbm_stx.xfm --order 4 --clobber
            volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc ${model_path}/Av_T2.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber
        fi

        if [ ! -f ${path_pd_stx} ] && [ -f ${pd} ];then 
            xfmconcat ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_pd_to_t1.xfm ${output_path}/${id}/template/${id}_${visit_tp}_t1_to_icbm.xfm  \
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_to_icbm_stx.xfm -clobber
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_pd_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin.mnc \
            --like ${model_path}/Av_PD.mnc --transform ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_to_icbm_stx.xfm --order 4 --clobber
            volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin.mnc ${model_path}/Av_PD.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber
        fi

        if [ ! -f ${path_flr_stx} ] && [ -f ${flr} ];then  
            xfmconcat ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_flr_to_t1.xfm ${output_path}/${id}/template/${id}_${visit_tp}_t1_to_icbm.xfm \
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_to_icbm_stx.xfm -clobber
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_flr_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc \
            --like ${model_path}/Av_FLAIR.mnc --transform ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_to_icbm_stx.xfm --order 4 --clobber
            volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc ${model_path}/Av_FLAIR.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber
        fi
    done
fi

### for longitudinal data: nonlinear average template ###
tp=$(cat ${input_list}|wc -l)
if [ ${tp} -gt 1 ];then 
    echo "longitudinal data: nonlinear average template"
    path_nlin_av=$(echo ${output_path}/${id}/template/${id}_nlin_av.mnc) 
    if [ ! -f ${path_nlin_av} ];then  
        cp ${output_path}/${id}/template/${id}_lin_av.mnc  ${output_path}/${id}/template/${id}_nlin_av.mnc 
        mincbeast ${model_path}/ADNI_library ${output_path}/${id}/template/${id}_nlin_av.mnc ${output_path}/${id}/template/${id}_mask.mnc \
        -fill -median -same_resolution -configuration ${model_path}/ADNI_library/default.2mm.conf -clobber
        for iteration in {1..4};do
            for timepoint in $(seq 1 ${tp});do
                tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
                visit_tp=$(echo ${tmp}|cut -d , -f 2)
                src=${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc
                trg=${output_path}/${id}/template/${id}_nlin_av.mnc
                src_mask=${output_path}/${id}/template/${id}_mask.mnc
                trg_mask=${output_path}/${id}/template/${id}_mask.mnc
                outp=${output_path}/${id}/template/${id}_${visit_tp}_nl_ants_

                if [ ! -z $trg_mask ];then
                    mask="-x [${src_mask},${trg_mask}] "
                fi

                if [ ${iteration} = 1 ];then 
                    antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                    --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[500x500x300,1e-6,10]" --shrink-factors 32x16x8 --smoothing-sigmas 16x8x4vox ${mask} --minc
                fi
                if [ ${iteration} = 2 ];then 
                    antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                    --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[250x250x150,1e-6,10]" --shrink-factors 16x8x4 --smoothing-sigmas 8x4x2vox ${mask} --minc
                fi
                if [ ${iteration} = 3 ];then 
                    antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                    --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[100x100x50,1e-6,10]" --shrink-factors 8x4x2 --smoothing-sigmas 4x2x1vox ${mask} --minc
                fi
                if [ ${iteration} = 4 ];then 
                    antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                    --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${mask} --minc
                fi
                itk_resample ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_nlin.mnc \
                --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_nl_ants_0_inverse_NL.xfm --order 4 --clobber --invert_transform
            done
            mincaverage ${output_path}/${id}/template/*_nlin.mnc ${output_path}/${id}/template/${id}_nlin_av.mnc -clobber
        done
    fi

    ### nonlinear registration of nonlinear subject specific template to reference template###
    path_nlin_av_reg=$(echo ${output_path}/${id}/template/${id}_nlin_av_to_icbm.mnc) 
    if [ ! -f ${path_nlin_av_reg} ];then
        src=${output_path}/${id}/template/${id}_nlin_av.mnc
        trg=${model_path}/Av_T1.mnc
        src_mask=${output_path}/${id}/template/${id}_mask.mnc
        trg_mask=${model_path}/Mask.mnc
        outp=${output_path}/${id}/template/${id}_nlin_av_to_ref_nl_ants_
        if [ ! -z $trg_mask ];then
            mask="-x [${src_mask},${trg_mask}] "
        fi
        antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
        --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${mask} --minc
        itk_resample ${output_path}/${id}/template/${id}_nlin_av.mnc ${output_path}/${id}/template/${id}_nlin_av_to_icbm.mnc \
        --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm --order 4 --clobber --invert_transform
    fi
fi
### Deformation-Based Mprphometry (DBM) ###
tp=$(cat ${input_list}|wc -l)
if [ ${tp} -gt 1 ];then 
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        path_dbm=$(echo ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_dbm.mnc) 
        if [ ! -f ${path_dbm} ];then
            xfmconcat ${output_path}/${id}/template/${id}_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm ${output_path}/${id}/template/${id}_${visit_tp}_nl_ants_0_inverse_NL.xfm \
                ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_both_inverse_NL.xfm -clobber
            xfm_normalize.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_both_inverse_NL.xfm ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL.xfm \
            --like ${model_path}/Av_T1.mnc --exact --clobber
            itk_resample ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_nlin.mnc \
                --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
            grid_proc --det ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL_grid_0.mnc ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_dbm.mnc --clobber
        fi       
    done

    if [ -f ${secondary_template_path}/Av_T1.mnc ];then
        path_nlin_av_sec_reg=$(echo ${output_path}/${id}/template/${id}_secondary_template_nlin_av_to_icbm.mnc) 
        if [ ! -f ${path_nlin_av_sec_reg} ];then
            src=${output_path}/${id}/template/${id}_nlin_av.mnc
            trg=${secondary_template_path}/Av_T1.mnc
            src_mask=${output_path}/${id}/template/${id}_mask.mnc
            trg_mask=${secondary_template_path}/Mask.mnc
            outp=${output_path}/${id}/template/${id}_secondary_template_nlin_av_to_ref_nl_ants_
            if [ ! -z $trg_mask ];then
                mask="-x [${src_mask},${trg_mask}] "
            fi
            antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
            --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${mask} --minc
            itk_resample ${output_path}/${id}/template/${id}_nlin_av.mnc ${output_path}/${id}/template/${id}_secondary_template_nlin_av_to_icbm.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_secondary_template_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm --order 4 --clobber --invert_transform
        fi
        ### Deformation-Based Mprphometry (DBM) ###
        tp=$(cat ${input_list}|wc -l)
        if [ ${tp} -gt 1 ];then 
            for timepoint in $(seq 1 ${tp});do
                tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
                visit_tp=$(echo ${tmp}|cut -d , -f 2)
                path_secondary_template_dbm=$(echo ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_secondary_template_dbm.mnc)
                path_indirect_dbm=$(echo ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_indirect_dbm.mnc)
                if [ ! -f ${path_secondary_template_dbm} ];then
                    xfmconcat ${output_path}/${id}/template/${id}_secondary_template_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm ${output_path}/${id}/template/${id}_${visit_tp}_nl_ants_0_inverse_NL.xfm \
                        ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_both_inverse_NL.xfm -clobber
                    xfm_normalize.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_both_inverse_NL.xfm ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_inv_nlin_0_inverse_NL.xfm \
                    --like ${secondary_template_path}/Av_T1.mnc --exact --clobber
                    itk_resample ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_nlin.mnc \
                        --like ${secondary_template_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
                    grid_proc --det ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_inv_nlin_0_inverse_NL_grid_0.mnc ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_secondary_template_dbm.mnc
                fi
                ### repeating DBM with seconday template as intermediate step
                if [ ! -f ${path_indirect_dbm} ];then
                    xfmconcat ${secondary_template_path}/to_icbm_sym_0_inverse_NL.xfm ${output_path}/${id}/template/${id}_secondary_template_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm ${output_path}/${id}/template/${id}_${visit_tp}_nl_ants_0_inverse_NL.xfm \
                        ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_three_inverse_NL.xfm -clobber
                    xfm_normalize.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_three_inverse_NL.xfm ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_3_inv_nlin_0_inverse_NL.xfm \
                    --like ${secondary_template_path}/Av_T1.mnc --exact --clobber
                    itk_resample ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_3_nlin.mnc \
                        --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_3_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
                    grid_proc --det ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_3_inv_nlin_0_inverse_NL_grid_0.mnc ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_indirect_dbm.mnc --clobber
                fi
            done
        fi
    fi
fi
### Running BISON for tissue classification ###
if [ ${tp} -gt 1 ];then 
    if [ -f ${output_path}/${id}/to_segment_t1.csv ];then rm ${output_path}/${id}/to_segment_*.csv;fi
    echo Subjects,T1s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1.csv
    echo Subjects,T1s,T2s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1_t2.csv
    echo Subjects,T1s,FLAIRs,Masks,XFMs >> ${output_path}/${id}/to_segment_t1_flair.csv
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        id=$(echo ${tmp}|cut -d , -f 1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        t2=$(echo ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_vp.mnc)
        flr=$(echo ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_flr_vp.mnc)

        path_t1_bison=$(echo ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Labelr.mnc)
        path_t2_bison=$(echo ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_t2_Labelr.mnc)
        path_flr_bison=$(echo ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_flr_Labelr.mnc)
        if [ ! -f ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL.xfm ];then
            xfm_normalize.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_both_inverse_NL.xfm ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL.xfm \
            --like ${model_path}/Av_T1.mnc --exact --clobber
        fi

        if [ ! -f ${path_t1_bison} ];then
            echo ${id}_${visit_tp}_t1,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc,\
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc,\
            ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1.csv
        fi

        if [ ! -f ${path_t2_bison} ] && [ -f ${t2} ];then 
            echo ${id}_${visit_tp}_t1_t2,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc,\
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc,\
            ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1_t2.csv
        fi
        
        if [ ! -f ${path_flr_bison} ] && [ -f ${flr} ];then 
            echo ${id}_${visit_tp}_t1_flr,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc,\
            ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc,\
            ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1_flair.csv
        fi
    done
fi

echo "BISON"

t1f=$(cat ${output_path}/${id}/to_segment_t1.csv|wc -l)
if [ ${t1f} -gt 1 ];then  python ${model_path}/BISON.py -c RF0 -m ${model_path}/Pretrained_Library_ADNI_L9/ \
 -o  ${output_path}/${id}/tmp/ -t ${output_path}/${id}/tmp/ -e PT -n  ${output_path}/${id}/to_segment_t1.csv  -p  ${model_path}/Pretrained_Library_ADNI_L9/ -l 9;fi

t2f=$(cat ${output_path}/${id}/to_segment_t1_t2.csv|wc -l)
if [ ${t2f} -gt 1 ];then  python ${model_path}/BISON.py -c RF0 -m ${model_path}/Pretrained_Library_ADNI_T1_T2_L9/ \
 -o  ${output_path}/${id}/tmp/ -t ${output_path}/${id}/tmp/ -e PT -n  ${output_path}/${id}/to_segment_t1_t2.csv  -p  ${model_path}/Pretrained_Library_ADNI_T1_T2_L9/ -l 9; fi

flairf=$(cat ${output_path}/${id}/to_segment_t1_flair.csv|wc -l)
if [ ${flairf} -gt 1 ];then  python ${model_path}/BISON.py -c RF0 -m ${model_path}/Pretrained_Library_ADNI_T1_FLAIR_L9/ \
 -o  ${output_path}/${id}/tmp/ -t ${output_path}/${id}/tmp/ -e PT -n  ${output_path}/${id}/to_segment_t1_flair.csv  -p  ${model_path}/Pretrained_Library_ADNI_T1_FLAIR_L9/ -l 9; fi

### Moving Files ###
echo "BISON Done!"

for timepoint in $(seq 1 ${tp});do
    tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)

    if ls ${output_path}/${id}/tmp/*${id}*${visit_tp}*.mnc 1> /dev/null 2>&1; then
        mv ${output_path}/${id}/tmp/*${id}*${visit_tp}*.mnc ${output_path}/${id}/${visit_tp}/cls/
    fi

    if ls ${output_path}/${id}/tmp/*${id}*${visit_tp}*.jpg 1> /dev/null 2>&1; then
        mv ${output_path}/${id}/tmp/*${id}*${visit_tp}*.jpg ${output_path}/${id}/qc/${visit_tp}/
    fi
done

### Voxel-Based Mprphometry (VBM) ###
echo "Voxel-Based Mprphometry"

for timepoint in $(seq 1 ${tp});do
    tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)

    path_vbm=$(echo ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_gm.mnc)
    if [ ! -f ${path_vbm} ];then 
        minccalc -expression 'A[0]+A[1]+A[2]' ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_3.mnc \
        ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_6.mnc ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_7.mnc \
        ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_GM.mnc -clobber
        minccalc -expression 'A[0]+A[1]' ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_8.mnc \
        ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_9.mnc ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_WM.mnc -clobber
        itk_resample ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_GM.mnc ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_gm.mnc \
        --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
        itk_resample ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_WM.mnc ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_wm.mnc \
        --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
        minccalc -expression 'A[0]>0.5?A[0]:0' ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_gm.mnc ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_gmt.mnc -clobber
        minccalc -expression 'A[0]>0.5?A[0]:0' ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_wm.mnc ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_wmt.mnc -clobber
        minccalc -expression 'A[0]*A[1]' ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_gmt.mnc ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_dbm.mnc \
        ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_gm.mnc -clobber
        minccalc -expression 'A[0]*A[1]' ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_wmt.mnc ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_dbm.mnc \
        ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_wm.mnc -clobber
        mincblur -3dfwhm 4 4 4 ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_wm.mnc  ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_wm
        mincblur -3dfwhm 4 4 4 ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_gm.mnc  ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_gm
        mv  ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_wm_blur.mnc ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_wm.mnc 
        mv  ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_gm_blur.mnc ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_vbm_gm.mnc 
    fi
done

echo "Generating QC Files"

### generating QC files ###
for timepoint in $(seq 1 ${tp});do
    tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)
    t2=$(echo ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_vp.mnc)
    pd=$(echo ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_pd_vp.mnc)
    flr=$(echo ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_flr_vp.mnc) 

    path_qc=$(echo ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_stx2_nlin.jpg)
    if [ ! -f ${path_qc} ];then 
        minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_t1_stx2_lin_vp_light.jpg \
        --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100
        minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_t1_stx2_lin_vp.jpg \
        --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 250
        if [ -f ${t2} ];then minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin_vp.mnc ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_t2_stx2_lin_vp.jpg \
        --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100; fi
        if [ -f ${pd} ];then minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin_vp.mnc ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_pd_stx2_lin_vp.jpg \
        --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100; fi
        if [ -f ${flr} ];then  minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin_vp.mnc ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_flr_stx2_lin_vp.jpg \
        --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100; fi
        minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_t1_mask.jpg \
        --mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --big --clobber  --image-range 0 100 
        minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_nlin.mnc  ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_stx2_nlin_light.jpg \
        --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100   
        minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_nlin.mnc  ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_stx2_nlin.jpg \
        --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 250   

        if [ -f ${secondary_template_path}/Av_T1.mnc ];then
            minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_nlin.mnc  ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_stx2_secondary_template_nlin.jpg \
            --mask ${secondary_template_path}/outline.mnc --big --clobber  --image-range 0 250
            minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_secondary_template_3_nlin.mnc  ${output_path}/${id}/qc/${visit_tp}/${id}_${visit_tp}_stx2_indirect_nlin.jpg \
            --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 250
        fi
    fi
done
echo "Removing Redundant/Temporary Files"

### removing unnecessary intermediate files ###
if [ -d "${output_path}/${id}/tmp/" ]; then
    rm -rf "${output_path}/${id}/tmp/"
fi

for file in \
    "${output_path}/${id}/*/*/*tmp.xfm" \
    "${output_path}/${id}/*/*/*tmp.mnc" \
    "${output_path}/${id}/*/native/*anlm*" \
    "${output_path}/${id}/*/native/*n3*" \
    "${output_path}/${id}/*/cls/*Prob_Label*" \
    "${output_path}/${id}/*/cls/*l.mnc" \
    "${output_path}/${id}/*/stx_nlin/*0_NL*" \
    "${output_path}/${id}/*/stx_nlin/*secondary_template_3*" \
    "${output_path}/${id}/*/stx_nlin/*three*" \
    "${output_path}/${id}/template/*0_NL*" \
    "${output_path}/${id}/template/*0.mnc" \
    "${output_path}/${id}/template/*0_beast*.mnc" \
    "${output_path}/${id}/*.csv" \
    "${output_path}/${id}/*.xfm"
do
    if ls $file 1> /dev/null 2>&1; then
        rm $file
    fi
done

echo "Processing Successfully Finished!"

### generating QC report HTML ###
echo "Generating QC report HTML"
if [ -d "${output_path}/${id}/qc/" ]; then
    generate_qc_html.sh "${output_path}/${id}"
fi