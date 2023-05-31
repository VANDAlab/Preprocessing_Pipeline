### Mahsa & Yashar - 2023-03-08  ###
#Input file format:
# id,visit,t1,t2,pd,flr
# Dependencies: minc-toolki, anaconda, and ANTs
# for use at the CIC, you can load the following modules (or similar versions)
# module load minc-toolkit-v2/1.9.18.2 ANTs/20220513 anaconda/2022.05

if [ $# -eq 3 ];then
    input_list=$1
    model_path=$2
    output_path=$3
else
 echo "Usage $0 <input list> <model path> <output_path>"
 echo "Outputs will be saved in <output_path> folder"
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
    mkdir -p ${output_path}/${id}/qc
    mkdir -p ${output_path}/${id}/tmp

    ### denoising ###
    mincnlm ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_nlm.mnc -mt 1 -beta 0.7 -clobber
    if [ ! -z ${t2} ];then mincnlm ${t2} ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_nlm.mnc -mt 1 -beta 0.7 -clobber; fi
    if [ ! -z ${pd} ];then mincnlm ${pd} ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_nlm.mnc -mt 1 -beta 0.7 -clobber; fi
    if [ ! -z ${flr} ];then mincnlm ${flr} ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_nlm.mnc -mt 1 -beta 0.7 -clobber; fi

    ### co-registration of different modalities to t1 ###
    if [ ! -z ${t2} ];then bestlinreg_s2 -lsq6 ${t2} ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm -clobber -mi; fi
    if [ ! -z ${pd} ];then bestlinreg_s2 -lsq6 ${pd} ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm -clobber -mi; fi
    if [ ! -z ${flr} ];then bestlinreg_s2 -lsq6 ${flr} ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm -clobber -mi; fi

    ### generating temporary masks for non-uniformity correction ###
    ${model_path}/bestlinreg_claude ${t1} ${model_path}/Av_T1.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm -clobber
    if [ ! -z ${t2} ];then xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm; fi
    if [ ! -z ${pd} ];then xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx_tmp.xfm; fi
    if [ ! -z ${flr} ];then  xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx_tmp.xfm; fi

    mincresample  ${model_path}/Mask.mnc -like ${t1} ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc -transform \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm -inv -nearest -clobber
    if [ ! -z ${t2} ];then mincresample  ${model_path}/Mask.mnc -like ${t2} ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc -transform \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm  -inv -nearest -clobber; fi
    if [ ! -z ${pd} ];then mincresample  ${model_path}/Mask.mnc -like ${pd} ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_mask_tmp.mnc -transform \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx_tmp.xfm  -inv -nearest -clobber; fi
    if [ ! -z ${flr} ];then  mincresample  ${model_path}/Mask.mnc -like ${flr} ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_mask_tmp.mnc -transform \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx_tmp.xfm  -inv -nearest -clobber; fi

    ### non-uniformity correction ###
    nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_nlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_n3.mnc \
     -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber
    if [ ! -z ${t2} ];then nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_nlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_n3.mnc \
    -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber; fi
    if [ ! -z ${pd} ];then nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_nlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_n3.mnc \
    -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber; fi
    if [ ! -z ${flr} ];then  nu_correct ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_nlm.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_n3.mnc \
    -mask ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber; fi

    ### intensity normalization ###
    volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_n3.mnc ${model_path}/Av_T1.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
     --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber
    if [ ! -z ${t2} ];then volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_n3.mnc ${model_path}/Av_T2.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc \
     --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber; fi
    if [ ! -z ${pd} ];then volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_n3.mnc ${model_path}/Av_PD.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc \
     --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber; fi
    if [ ! -z ${flr} ];then volume_pol ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_n3.mnc ${model_path}/Av_FLAIR.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc \
     --source_mask ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_mask_tmp.mnc --target_mask ${model_path}/Mask.mnc  --clobber; fi

    ### registering everything to stx space ###
    if [ ! -z ${t2} ];then bestlinreg_s2 -lsq6 ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
    ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm -clobber; fi
    if [ ! -z ${pd} ];then bestlinreg_s2 -lsq6 ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
    ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm -clobber; fi
    if [ ! -z ${flr} ];then bestlinreg_s2 -lsq6 ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
    ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm -clobber; fi
done

tp=$(cat ${input_list}|wc -l)
### for just one timepoint; i.e. cross-sectional data ###
if [ ${tp} = 1 ];then 
    ${model_path}/bestlinreg_claude ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${model_path}/Av_T1.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm -clobber
    if [ ! -z ${t2} ];then xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm  \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx2.xfm; fi
    if [ ! -z ${pd} ];then xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm  \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx2.xfm; fi
    if [ ! -z ${flr} ];then xfmconcat ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm  \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx2.xfm; fi

    itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc \
    --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm --order 4 --clobber
    if [ ! -z ${t2} ];then itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin.mnc \
    --like ${model_path}/Av_T2.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx2.xfm --order 4 --clobber; fi
    if [ ! -z ${pd} ];then itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_stx2_lin.mnc \
    --like ${model_path}/Av_PD.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx2.xfm --order 4 --clobber; fi
    if [ ! -z ${flr} ];then itk_resample ${output_path}/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin.mnc \
    --like ${model_path}/Av_FLAIR.mnc --transform ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx2.xfm --order 4 --clobber; fi

    mincbeast ${model_path}/ADNI_library ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc -fill -median -same_resolution \
    -configuration ${model_path}/ADNI_library/default.2mm.conf -clobber

    volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc ${model_path}/Av_T1.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
    --target_mask ${model_path}/Mask.mnc --clobber
    if [ ! -z ${t2} ];then volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin.mnc ${model_path}/Av_T2.mnc --order 1 --noclamp \
    --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
    --target_mask ${model_path}/Mask.mnc --clobber; fi
    if [ ! -z ${pd} ];then volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_stx2_lin.mnc ${model_path}/Av_PD.mnc --order 1 --noclamp \
    --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_pd_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
    --target_mask ${model_path}/Mask.mnc --clobber; fi
    if [ ! -z ${flr} ];then volume_pol ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin.mnc ${model_path}/Av_FLAIR.mnc --order 1 --noclamp \
    --expfile ${output_path}/${id}/tmp/tmp ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc \
    --target_mask ${model_path}/Mask.mnc --clobber; fi

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

    itk_resample ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_nlin.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm --order 4 --clobber --invert_transform
    grid_proc --det ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL_grid_0.mnc ${output_path}/${id}/${visit}/vbm/${id}_${visit}_dbm.mnc
    
    echo Subjects,T1s,FLAIRs,Masks,XFMs >> ${output_path}/${id}/to_segment_t1_flair.csv
    echo Subjects,T1s,T2s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1_t2.csv
    echo Subjects,T1s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1.csv

    echo ${id}_${visit}_t1,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc,\
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc,\
    ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1.csv 
    if [ ! -z ${flr} ];then echo ${id}_${visit}_t1_flair,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc,\
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin.mnc,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc,\
    ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1_flair.csv; fi
    if [ ! -z ${t2} ];then echo ${id}_${visit}_t1_t2,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc,\
    ${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin.mnc,${output_path}/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc,\
    ${output_path}/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_inverse_NL.xfm >> ${output_path}/${id}/to_segment_t1_t2.csv; fi
fi
tp=$(cat ${input_list}|wc -l)
### for longitudinal data: initial rigid registration of timepoints ###
if [ ${tp} -gt 1 ];then
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        id=$(echo ${tmp}|cut -d , -f 1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        if [ ${timepoint} = 1 ];then 
            ${model_path}/bestlinreg_claude ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${model_path}/Av_T1.mnc ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm -clobber 
            cp ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_baseline.mnc
            cp ${model_path}/i.xfm  ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm --order 4 --clobber
        fi
        if [ ${timepoint} -gt 1 ];then 
            ${model_path}/bestlinreg_claude -lsq6 ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_baseline.mnc \
            ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm -clobber
            xfmconcat ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm  ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm \
            ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm --order 4 --clobber
        fi
    done
    mincaverage ${output_path}/${id}/template/${id}_*_0.mnc ${output_path}/${id}/template/${id}_lin_av.mnc -clobber
fi
tp=$(cat ${input_list}|wc -l)
### for longitudinal data: linear average template ###
if [ ${tp} -gt 1 ];then
    for iteration in {1..5};do
        for timepoint in $(seq 1 ${tp});do
            tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
            id=$(echo ${tmp}|cut -d , -f 1)
            visit_tp=$(echo ${tmp}|cut -d , -f 2)
            ${model_path}/bestlinreg_claude ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc ${output_path}/${id}/template/${id}_lin_av.mnc ${output_path}/${id}/template/${id}_${visit_tp}.xfm -lsq6 -clobber
            xfmconcat ${output_path}/${id}/template/${id}_${visit_tp}_to_baseline.xfm  ${output_path}/${id}/template/${id}_baseline_to_icbm_stx.xfm \
            ${output_path}/${id}/template/${id}_${visit_tp}.xfm ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm -clobber
            itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/template/${id}_${visit_tp}_0.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm --order 4 --clobber
        done
        mincaverage ${output_path}/${id}/template/${id}_*_0.mnc ${output_path}/${id}/template/${id}_lin_av.mnc -clobber
    done

    ${model_path}/bestlinreg_claude ${output_path}/${id}/template/${id}_lin_av.mnc ${model_path}/Av_T1.mnc ${output_path}/${id}/template/${id}_lin_av_to_template.xfm  -clobber
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        id=$(echo ${tmp}|cut -d , -f 1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc \
        --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm --order 4 --clobber
        cp ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm ${output_path}/${id}/${visit_tp}/stx_lin/
        if [ ! -z ${t2} ];then xfmconcat ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_to_t1.xfm ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm \
         ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_to_icbm_stx.xfm; fi
        if [ ! -z ${pd} ];then xfmconcat ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_pd_to_t1.xfm ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm  \
        ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_to_icbm_stx.xfm; fi
       if [ ! -z ${flr} ];then  xfmconcat ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_flr_to_t1.xfm ${output_path}/${id}/template/${id}_${visit_tp}_to_icbm.xfm \
         ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_to_icbm_stx.xfm; fi

        if [ ! -z ${t2} ];then itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc \
        --like ${model_path}/Av_T2.mnc --transform ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_to_icbm_stx.xfm --order 4 --clobber; fi
        if [ ! -z ${pd} ];then itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_pd_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin.mnc \
        --like ${model_path}/Av_PD.mnc --transform ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_to_icbm_stx.xfm --order 4 --clobber; fi
        if [ ! -z ${flr} ];then  itk_resample ${output_path}/${id}/${visit_tp}/native/${id}_${visit_tp}_flr_vp.mnc ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc \
        --like ${model_path}/Av_FLAIR.mnc --transform ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_to_icbm_stx.xfm --order 4 --clobber; fi

        ### BEaST brain mask + another round of intensity normalization with the BEaST mask### 
        mincbeast ${model_path}/ADNI_library ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc \
        ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc -fill -median -same_resolution -configuration \
        ${model_path}/ADNI_library/default.2mm.conf -clobber
        ### Second round of intensity normalization with the refined brain mask ###
        volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc ${model_path}/Av_T1.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
        ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber
        if [ ! -z ${t2} ];then volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc ${model_path}/Av_T2.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
        ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber; fi
        if [ ! -z ${pd} ];then volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin.mnc ${model_path}/Av_PD.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
        ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber; fi
        if [ ! -z ${flr} ];then volume_pol ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc ${model_path}/Av_FLAIR.mnc --order 1 --noclamp --expfile ${output_path}/${id}/tmp/tmp \
        ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin_vp.mnc  --source_mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --target_mask ${model_path}/Mask.mnc --clobber; fi
    done
fi

### for longitudinal data: nonlinear average template ###
tp=$(cat ${input_list}|wc -l)
if [ ${tp} -gt 1 ];then 
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

### nonlinear registration of nonlinear subject specific template to reference template###
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
### Deformation-Based Mprphometry (DBM) ###
tp=$(cat ${input_list}|wc -l)
if [ ${tp} -gt 1 ];then 
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        xfmconcat ${output_path}/${id}/template/${id}_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm ${output_path}/${id}/template/${id}_${visit_tp}_nl_ants_0_inverse_NL.xfm \
            ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_both_inverse_NL.xfm -clobber
        xfm_normalize.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_both_inverse_NL.xfm ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm \
        --like ${model_path}/Av_T1.mnc --exact --clobber
        itk_resample ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_nlin.mnc \
            --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm --order 4 --clobber --invert_transform
        grid_proc --det ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL_grid_0.mnc ${output_path}/${id}/${visit_tp}/vbm/${id}_${visit_tp}_dbm.mnc
    done
fi

### Running BISON for tissue classification ###

if [ ${tp} -gt 1 ];then 
echo Subjects,T1s,FLAIRs,Masks,XFMs >> ${output_path}/${id}/to_segment_t1_flair.csv
echo Subjects,T1s,T2s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1_t2.csv
echo Subjects,T1s,Masks,XFMs >> ${output_path}/${id}/to_segment_t1.csv
for timepoint in $(seq 1 ${tp});do
    tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)
    echo ${id}_${visit_tp}_t1,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc,\
    ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc,\
    ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm >> ${output_path}/${id}/to_segment_t1.csv 
    if [ ! -z ${flr} ];then echo ${id}_${visit_tp}_t1_flair,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc,\
    ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc,\
    ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm >> ${output_path}/${id}/to_segment_t1_flair.csv; fi
    if [ ! -z ${t2} ];then echo ${id}_${visit_tp}_t1_t2,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc,\
    ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc,${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc,\
    ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm >> ${output_path}/${id}/to_segment_t1_t2.csv; fi
done
fi
python ${model_path}/BISON.py -c RF0 -m ${model_path}/Pretrained_Library_ADNI_L9/ \
 -o  ${output_path}/${id}/tmp/ -t ${output_path}/${id}/tmp/ -e PT -n  ${output_path}/${id}/to_segment_t1.csv  -p  ${model_path}/Pretrained_Library_ADNI_L9/ -l 9
if [ ! -z ${t2} ];then  python ${model_path}/BISON.py -c RF0 -m ${model_path}/Pretrained_Library_ADNI_T1_T2_L9/ \
 -o  ${output_path}/${id}/tmp/ -t ${output_path}/${id}/tmp/ -e PT -n  ${output_path}/${id}/to_segment_t1_t2.csv  -p  ${model_path}/Pretrained_Library_ADNI_T1_T2_L9/ -l 9; fi
if [ ! -z ${flr} ];then  python ${model_path}/BISON.py -c RF0 -m ${model_path}/Pretrained_Library_ADNI_T1_FLAIR_L9/ \
 -o  ${output_path}/${id}/tmp/ -t ${output_path}/${id}/tmp/ -e PT -n  ${output_path}/${id}/to_segment_t1_flair.csv  -p  ${model_path}/Pretrained_Library_ADNI_T1_FLAIR_L9/ -l 9; fi

### Voxel-Based Mprphometry (VBM) ###
for timepoint in $(seq 1 ${tp});do
    tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)
    mv ${output_path}/${id}/tmp/*${id}*${visit_tp}*.mnc ${output_path}/${id}/${visit_tp}/cls/
    mv ${output_path}/${id}/tmp/*${id}*${visit_tp}*.jpg ${output_path}/${id}/qc/
    minccalc -expression 'A[0]+A[1]+A[2]' ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_3.mnc \
    ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_6.mnc ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_7.mnc \
    ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_GM.mnc -clobber
    minccalc -expression 'A[0]+A[1]' ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_8.mnc \
    ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_Label_9.mnc ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_WM.mnc -clobber
    itk_resample ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_GM.mnc ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_gm.mnc \
    --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm --order 4 --clobber --invert_transform
    itk_resample ${output_path}/${id}/${visit_tp}/cls/RF0_${id}_${visit_tp}_t1_Prob_WM.mnc ${output_path}/${id}/tmp/${id}_${visit_tp}_nl_prob_wm.mnc \
    --like ${model_path}/Av_T1.mnc --transform ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_0_NL.xfm --order 4 --clobber --invert_transform
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
done

### generating QC files ###
for timepoint in $(seq 1 ${tp});do
    tmp=$(cat ${input_list} | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)
    minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/qc/${id}_${visit_tp}_t1_stx2_lin_vp.jpg \
     --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100
    if [ ! -z ${t2} ];then minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin_vp.mnc ${output_path}/${id}/qc/${id}_${visit_tp}_t2_stx2_lin_vp.jpg \
     --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100; fi
    if [ ! -z ${pd} ];then minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin_vp.mnc ${output_path}/${id}/qc/${id}_${visit_tp}_pd_stx2_lin_vp.jpg \
     --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100; fi
    if [ ! -z ${flr} ];then  minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin_vp.mnc ${output_path}/${id}/qc/${id}_${visit_tp}_flr_stx2_lin_vp.jpg \
     --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100; fi
    minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc ${output_path}/${id}/qc/${id}_${visit_tp}_t1_mask.jpg \
     --mask ${output_path}/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --big --clobber  --image-range 0 100 
    minc_qc.pl ${output_path}/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_nlin.mnc  ${output_path}/${id}/qc/${id}_${visit_tp}_stx2_nlin.jpg \
     --mask ${model_path}/outline.mnc --big --clobber  --image-range 0 100     
done

### removing unnecessary intermediate files ###
rm -rf ${output_path}/${id}/tmp/
rm ${output_path}/${id}/*/*/*tmp.xfm
rm ${output_path}/${id}/*/*/*tmp.mnc
rm ${output_path}/${id}/*/*/*tmp
rm ${output_path}/${id}/*/native/*nlm*
rm ${output_path}/${id}/*/native/*n3*
rm ${output_path}/${id}/*/cls/*Prob_Label*
rm ${output_path}/${id}/*.csv
