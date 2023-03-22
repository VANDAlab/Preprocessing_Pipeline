### Mahsa & Yashar - 2023-03-08  ###
#Input file format:
# id,visit,t1,t2,pd,flr

### Pre-processing the native data ###
for i in $(cat LP_List.csv);do
    id=$(echo ${i}|cut -d , -f 1)
    visit=$(echo ${i}|cut -d , -f 2)
    t1=$(echo ${i}|cut -d , -f 3)
    t2=$(echo ${i}|cut -d , -f 4)
    pd=$(echo ${i}|cut -d , -f 5)
    flr=$(echo ${i}|cut -d , -f 6)
    echo ${id} ${visit}
    mkdir -p Preprocessing/${id}/${visit}/native
    mkdir -p Preprocessing/${id}/${visit}/stx_lin
    mkdir -p Preprocessing/${id}/${visit}/stx_nlin
    mkdir -p Preprocessing/${id}/${visit}/vbm
    mkdir -p Preprocessing/${id}/template
    mkdir -p Preprocessing/${id}/qc
    mkdir -p Preprocessing/${id}/cls


    ### denoising ###
    mincnlm ${t1} Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_nlm.mnc -mt 1 -beta 0.7 -clobber
    mincnlm ${t2} Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_nlm.mnc -mt 1 -beta 0.7 -clobber
    mincnlm ${pd} Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_nlm.mnc -mt 1 -beta 0.7 -clobber
    mincnlm ${flr} Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_nlm.mnc -mt 1 -beta 0.7 -clobber

    ### co-registration of different modalities to t1 ###
    bestlinreg_s2 -lsq6 ${t2} ${t1} Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm -clobber -mi
    bestlinreg_s2 -lsq6 ${pd} ${t1} Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm -clobber -mi
    bestlinreg_s2 -lsq6 ${flr} ${t1} Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm -clobber -mi

    ### generating temporary masks for non-uniformity correction ###
    bestlinreg_g ${t1} Av_T1.mnc Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm -clobber
    xfmconcat Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm
    xfmconcat Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx_tmp.xfm
    xfmconcat Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx_tmp.xfm

    mincresample  Mask.mnc -like ${t1} Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc -transform \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm_stx_tmp.xfm -inv -nearest -clobber
    mincresample  Mask.mnc -like ${t2} Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc -transform \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx_tmp.xfm  -inv -nearest -clobber
    mincresample  Mask.mnc -like ${pd} Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_mask_tmp.mnc -transform \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx_tmp.xfm  -inv -nearest -clobber
    mincresample  Mask.mnc -like ${flr} Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_mask_tmp.mnc -transform \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx_tmp.xfm  -inv -nearest -clobber

    ### non-uniformity correction ###
    nu_correct Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_nlm.mnc Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_n3.mnc \
     -mask Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber
    nu_correct Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_nlm.mnc Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_n3.mnc \
    -mask Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber
    nu_correct Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_nlm.mnc Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_n3.mnc \
    -mask Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber
    nu_correct Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_nlm.mnc Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_n3.mnc \
    -mask Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_mask_tmp.mnc -iter 200 -distance 200 -stop 0.000001 -normalize_field  -clobber

    ### intensity normalization ###
    volume_pol Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_n3.mnc Av_T1.mnc --order 1 --noclamp --expfile tmp Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
     --source_mask Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_mask_tmp.mnc --target_mask Mask.mnc  --clobber
    volume_pol Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_n3.mnc Av_T2.mnc --order 1 --noclamp --expfile tmp Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc \
     --source_mask Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_mask_tmp.mnc --target_mask Mask.mnc  --clobber
    volume_pol Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_n3.mnc Av_PD.mnc --order 1 --noclamp --expfile tmp Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc \
     --source_mask Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_mask_tmp.mnc --target_mask Mask.mnc  --clobber
    volume_pol Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_n3.mnc Av_FLAIR.mnc --order 1 --noclamp --expfile tmp Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc \
     --source_mask Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_mask_tmp.mnc --target_mask Mask.mnc  --clobber

    ### registering everything to stx space ###
    bestlinreg_g -lsq6 Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
    Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm -clobber
    bestlinreg_g -lsq6 Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
    Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm -clobber
    bestlinreg_g -lsq6 Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc \
    Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm -clobber
done

tp=$(cat LP_List.csv|wc -l)
### for just one timepoint; i.e. cross-sectional data ###
if [ ${tp} = 1 ];then 
    bestlinreg_g Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc Av_T1.mnc Preprocessing/${id}/template/${id}_${visit_tp}.xfm  \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_to_icbm.xfm -clobber
    xfmconcat Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_to_t1.xfm Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm  \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx.xfm
    xfmconcat Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_to_t1.xfm Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm  \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx.xfm
    xfmconcat Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_to_t1.xfm Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm  \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx.xfm

    itk_resample Preprocessing/${id}/${visit}/native/${id}_${visit}_t1_vp.mnc Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc \
    --like Av_T1.mnc --transform Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm --order 4
    itk_resample Preprocessing/${id}/${visit}/native/${id}_${visit}_t2_vp.mnc Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t2_stx2_lin.mnc \
    --like Av_T2.mnc --transform Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t2_to_icbm_stx2.xfm --order 4
    itk_resample Preprocessing/${id}/${visit}/native/${id}_${visit}_pd_vp.mnc Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_pd_stx2_lin.mnc \
    --like Av_PD.mnc --transform Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_pd_to_icbm_stx2.xfm --order 4
    itk_resample Preprocessing/${id}/${visit}/native/${id}_${visit}_flr_vp.mnc Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_flr_stx2_lin.mnc \
    --like Av_FLAIR.mnc --transform Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_flr_to_icbm_stx2.xfm --order 4

    mincbeast /opt/quarantine/resources/BEaST_libraries/ADNI_library Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc \
    Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc -fill -median -same_resolution \
    -configuration /opt/quarantine/resources/BEaST_libraries/ADNI_library/default.2mm.conf -clobber

    src=Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_lin.mnc
    trg=Av_T1.mnc
    src_mask=Preprocessing/${id}/${visit}/stx_lin/${id}_${visit}_t1_stx2_beast_mask.mnc
    trg_mask=Mask.mnc
    outp=Preprocessing/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_
    antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
    --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${mask} --minc

    grid_proc --det Preprocessing/${id}/${visit}/stx_nlin/${id}_${visit}_inv_nlin_0_NL_grid_0.mnc Preprocessing/${id}/${visit}/vbm/${id}_${visit}_dbm.mnc

fi

### for longitudinal data: initial rigid registration of timepoints ###
if [ ${tp} > 1 ];then
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat LP_List.csv | head -${timepoint} | tail -1)
        id=$(echo ${tmp}|cut -d , -f 1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        if [ ${timepoint} = 1 ];then 
            bestlinreg_g Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc Av_T1.mnc Preprocessing/${id}/template/${id}_baseline_to_icbm_stx.xfm -clobber 
            cp Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc Preprocessing/${id}/template/${id}_baseline.mnc 
            itk_resample Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc Preprocessing/${id}/template/${id}_${visit_tp}_0.mnc \
            --like Av_T1.mnc --transform Preprocessing/${id}/template/${id}_baseline_to_icbm_stx.xfm --order 4 --clobber
        fi
        if [ ${timepoint} > 1 ];then 
            bestlinreg_g -lsq6 Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc Preprocessing/${id}/template/${id}_baseline.mnc \
            Preprocessing/${id}/template/${id}_${visit_tp}_to_baseline.xfm -clobber
            xfmconcat Preprocessing/${id}/template/${id}_${visit_tp}_to_baseline.xfm  Preprocessing/${id}/template/${id}_baseline_to_icbm_stx.xfm \
            Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm
            itk_resample Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc Preprocessing/${id}/template/${id}_${visit_tp}_0.mnc \
            --like Av_T1.mnc --transform Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm --order 4 --clobber
        fi
    done
    mincaverage Preprocessing/${id}/template/${id}_*_0.mnc Preprocessing/${id}/template/${id}_lin_av.mnc -clobber
fi

### for longitudinal data: linear average template ###
if [ ${tp} > 1 ];then
    for iteration in {1..5};do
        for timepoint in $(seq 1 ${tp});do
            tmp=$(cat LP_List.csv | head -${timepoint} | tail -1)
            id=$(echo ${tmp}|cut -d , -f 1)
            visit_tp=$(echo ${tmp}|cut -d , -f 2)
            bestlinreg_g Preprocessing/${id}/template/${id}_${visit_tp}_0.mnc Preprocessing/${id}/template/${id}_lin_av.mnc Preprocessing/${id}/template/${id}_${visit_tp}.xfm -lsq6 -clobber
            xfmconcat Preprocessing/${id}/template/${id}_${visit_tp}_to_baseline.xfm  Preprocessing/${id}/template/${id}_baseline_to_icbm_stx.xfm \
            Preprocessing/${id}/template/${id}_${visit_tp}.xfm Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm -clobber
            itk_resample Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc Preprocessing/${id}/template/${id}_${visit_tp}.mnc \
            --like Av_T1.mnc --transform Preprocessing/${id}/template/${id}_${visit_tp}_0.mnc --order 4 --clobber
        done
        mincaverage Preprocessing/${id}/template/${id}_*_0.mnc Preprocessing/${id}/template/${id}_lin_av.mnc -clobber
    done

    bestlinreg_g Preprocessing/${id}/template/${id}_lin_av.mnc Av_T1.mnc Preprocessing/${id}/template/${id}_lin_av_to_template.xfm  -clobber
    for timepoint in $(seq 1 ${tp});do
        tmp=$(cat LP_List.csv | head -${timepoint} | tail -1)
        id=$(echo ${tmp}|cut -d , -f 1)
        visit_tp=$(echo ${tmp}|cut -d , -f 2)
        itk_resample Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_t1_vp.mnc Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc \
        --like Av_T1.mnc --transform Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm --order 4

        xfmconcat Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_to_t1.xfm Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm \
         Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_to_icbm_stx.xfm
        xfmconcat Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_pd_to_t1.xfm Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm  \
        Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_to_icbm_stx.xfm
        xfmconcat Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_flr_to_t1.xfm Preprocessing/${id}/template/${id}_${visit_tp}_to_icbm.xfm \
         Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_to_icbm_stx.xfm

        itk_resample Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_t2_vp.mnc Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc \
        --like Av_T2.mnc --transform Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_to_icbm_stx.xfm --order 4
        itk_resample Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_pd_vp.mnc Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin.mnc \
        --like Av_PD.mnc --transform Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_to_icbm_stx.xfm --order 4
        itk_resample Preprocessing/${id}/${visit_tp}/native/${id}_${visit_tp}_flr_vp.mnc Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc \
        --like Av_FLAIR.mnc --transform Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_to_icbm_stx.xfm --order 4

        ### BEaST brain mask + another round of intensity normalization with the BEaST mask### 
        mincbeast /opt/quarantine/resources/BEaST_libraries/ADNI_library Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc \
        Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc -fill -median -same_resolution -configuration /opt/quarantine/resources/BEaST_libraries/ADNI_library/default.2mm.conf -clobber
        ### Second round of intensity normalization with the refined brain mask ###
        volume_pol Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc Av_T1.mnc --order 1 --noclamp --expfile tmp \
        Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc  --source_mask Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc \
        --target_mask Mask.mnc  --clobber
        volume_pol Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin.mnc Av_T2.mnc --order 1 --noclamp --expfile tmp \
        Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin_vp.mnc  --source_mask Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc \
        --target_mask Mask.mnc  --clobber
        volume_pol Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin.mnc Av_PD.mnc --order 1 --noclamp --expfile tmp \
        Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin_vp.mnc  --source_mask Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc \
        --target_mask Mask.mnc  --clobber
        volume_pol Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc Av_FLAIR.mnc --order 1 --noclamp --expfile tmp \
        Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin_vp.mnc  --source_mask Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc \
        --target_mask Mask.mnc  --clobber
    done
fi

### for longitudinal data: nonlinear average template ###
cp Preprocessing/${id}/template/${id}_lin_av.mnc  Preprocessing/${id}/template/${id}_nlin_av.mnc 
mincbeast /opt/quarantine/resources/BEaST_libraries/ADNI_library Preprocessing/${id}/template/${id}_nlin_av.mnc Preprocessing/${id}/template/${id}_mask.mnc \
-fill -median -same_resolution -configuration /opt/quarantine/resources/BEaST_libraries/ADNI_library/default.2mm.conf -clobber

if [ ${tp} > 1 ];then 
    for iteration in {1..4};do
        for timepoint in $(seq 1 ${tp});do
            tmp=$(cat LP_List.csv | head -${timepoint} | tail -1)
            visit_tp=$(echo ${tmp}|cut -d , -f 2)
            src=Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc
            trg=Preprocessing/${id}/template/${id}_nlin_av.mnc
            src_mask=Preprocessing/${id}/template/${id}_mask.mnc
            trg_mask=Preprocessing/${id}/template/${id}_mask.mnc
            outp=Preprocessing/${id}/template/${id}_${visit_tp}_nl_ants_
            if [ ${iteration} = 1 ];then 
                antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[500x500x300,1e-6,10]" --shrink-factors 32x16x8 --smoothing-sigmas 16x8x4vox ${src_mask} ${trg_mask} --minc
            fi
            if [ ${iteration} = 2 ];then 
                antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[250x250x150,1e-6,10]" --shrink-factors 16x8x4 --smoothing-sigmas 8x4x2vox ${src_mask} ${trg_mask} --minc
            fi
            if [ ${iteration} = 3 ];then 
                antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[100x100x50,1e-6,10]" --shrink-factors 8x4x2 --smoothing-sigmas 4x2x1vox ${src_mask} ${trg_mask} --minc
            fi
            if [ ${iteration} = 4 ];then 
                antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
                --transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${src_mask} ${trg_mask} --minc
            fi
            itk_resample Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc Preprocessing/${id}/template/${id}_${visit_tp}_nlin.mnc \
            --like Av_T1.mnc --transform Preprocessing/${id}/template/${id}_${visit_tp}_nl_ants_0_inverse_NL.xfm --order 4 --clobber --invert_transform
        done
        mincaverage Preprocessing/${id}/template/*_nlin.mnc Preprocessing/${id}/template/${id}_nlin_av.mnc -clobber
    done
fi
### nonlinear registration of nonlinear subject specific template to reference template###
src=Preprocessing/${id}/template/${id}_nlin_av.mnc
trg=Av_T1.mnc
src_mask=Preprocessing/${id}/template/${id}_mask.mnc
trg_mask=Mask.mnc
outp=Preprocessing/${id}/template/${id}_nlin_av_to_ref_nl_ants_
antsRegistration -v -d 3 --float 1  --output "[${outp}]"  --use-histogram-matching 0 --winsorize-image-intensities "[0.005,0.995]" \
--transform "SyN[0.7,3,0]" --metric "CC[${src},${trg},1,4]" --convergence "[50x50x30,1e-6,10]" --shrink-factors 4x2x1 --smoothing-sigmas 2x1x0vox ${src_mask} ${trg_mask} --minc
itk_resample Preprocessing/${id}/template/${id}_nlin_av.mnc Preprocessing/${id}/template/${id}_nlin_av_to_icbm.mnc \
--like Av_T1.mnc --transform Preprocessing/${id}/template/${id}_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm --order 4 --clobber --invert_transform

### Running BISON using the av template nonlinear transform ###
for timepoint in $(seq 1 ${tp});do
    tmp=$(cat LP_List.csv | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)
    echo Subjects,T1s,FLAIRs,Masks,XFMs >> Preprocessing/${id}/to_segment_t1_flair.csv
    echo ${id}_${visit_tp}_t1_flair,Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc,\
    Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin.mnc,Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc,\
    Preprocessing/${id}/template/${id}_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm >> Preprocessing/${id}/to_segment_t1_flair.csv 

    echo Subjects,T1s,Masks,XFMs >> Preprocessing/${id}/to_segment_t1.csv
    echo ${id}_${visit_tp}_t1,Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin.mnc,\
    Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc,\
    Preprocessing/${id}/template/${id}_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm >> Preprocessing/${id}/to_segment_t1.csv 
done
python ./data/dadmah/in_vivo_Preprocessing/Prep_Pipeline//BISON.py -c RF0 -m /data/dadmah/in_vivo_Preprocessing/Prep_Pipeline/Pretrained_Library_ADNI_T1_L9/ \
 -o  Preprocessing/${id}/cls/ -t Temp_Files/ -e PT -n  Preprocessing/${id}/to_segment_t1.csv  -p  /data/dadmah/in_vivo_Preprocessing/Prep_Pipeline/Pretrained_Library_ADNI_T1_L9/ -l 9
python ./data/dadmah/in_vivo_Preprocessing/Prep_Pipeline//BISON.py -c RF0 -m /data/dadmah/in_vivo_Preprocessing/Prep_Pipeline/Pretrained_Library_ADNI_T1_FLAIR_L9/ \
 -o  Preprocessing/${id}/cls/ -t Temp_Files/ -e PT -n  Preprocessing/${id}/to_segment_t1_flair.csv  -p  /data/dadmah/in_vivo_Preprocessing/Prep_Pipeline/Pretrained_Library_ADNI_T1_FLAIR_L9/ -l 9

### generating QC files ###
for timepoint in $(seq 1 ${tp});do
    tmp=$(cat LP_List.csv | head -${timepoint} | tail -1)
    id=$(echo ${tmp}|cut -d , -f 1)
    visit_tp=$(echo ${tmp}|cut -d , -f 2)
    minc_qc.pl Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc Preprocessing/${id}/qc/${id}_${visit_tp}_t1_stx2_lin_vp.jpg \
     --mask /opt/quarantine/resources/mni_icbm152_nlin_sym_09c_minc2/mni_icbm152_t1_tal_nlin_sym_09c_outline.mnc --big --clobber  --image-range 0 100
    minc_qc.pl Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t2_stx2_lin_vp.mnc Preprocessing/${id}/qc/${id}_${visit_tp}_t2_stx2_lin_vp.jpg \
     --mask /opt/quarantine/resources/mni_icbm152_nlin_sym_09c_minc2/mni_icbm152_t1_tal_nlin_sym_09c_outline.mnc --big --clobber  --image-range 0 100
    minc_qc.pl Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_pd_stx2_lin_vp.mnc Preprocessing/${id}/qc/${id}_${visit_tp}_pd_stx2_lin_vp.jpg \
     --mask /opt/quarantine/resources/mni_icbm152_nlin_sym_09c_minc2/mni_icbm152_t1_tal_nlin_sym_09c_outline.mnc --big --clobber  --image-range 0 100
     minc_qc.pl Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_flr_stx2_lin_vp.mnc Preprocessing/${id}/qc/${id}_${visit_tp}_flr_stx2_lin_vp.jpg \
     --mask /opt/quarantine/resources/mni_icbm152_nlin_sym_09c_minc2/mni_icbm152_t1_tal_nlin_sym_09c_outline.mnc --big --clobber  --image-range 0 100
    minc_qc.pl Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_lin_vp.mnc Preprocessing/${id}/qc/${id}_${visit_tp}_t1_mask.jpg \
     --mask Preprocessing/${id}/${visit_tp}/stx_lin/${id}_${visit_tp}_t1_stx2_beast_mask.mnc --big --clobber  --image-range 0 100 

    minc_qc.pl Preprocessing/${id}/template/${id}_nlin_av_to_icbm.mnc Preprocessing/${id}/qc/${id}_${visit_tp}_av_stx2_nlin.jpg \
     --mask /opt/quarantine/resources/mni_icbm152_nlin_sym_09c_minc2/mni_icbm152_t1_tal_nlin_sym_09c_outline.mnc --big --clobber  --image-range 0 100     
    mv Preprocessing/${id}/cls/*.jpg Preprocessing/${id}/qc/
done

tp=$(cat LP_List.csv|wc -l)
if [ ${tp} -gt 1 ];then 
for timepoint in $(seq 1 ${tp});do
tmp=$(cat LP_List.csv | head -${timepoint} | tail -1)
visit_tp=$(echo ${tmp}|cut -d , -f 2)
xfmconcat Preprocessing/${id}/template/${id}_nlin_av_to_ref_nl_ants_0_inverse_NL.xfm Preprocessing/${id}/template/${id}_${visit_tp}_nl_ants_0_inverse_NL.xfm \
    Preprocessing/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_both_inverse_NL.xfm -clobber
xfm_normalize.pl Preprocessing/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_both_inverse_NL.xfm Preprocessing/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin.xfm
grid_proc --det Preprocessing/${id}/${visit_tp}/stx_nlin/${id}_${visit_tp}_inv_nlin_grid.mnc Preprocessing/${id}/${visit_tp}/vbm/${id}_${visit_tp}_dbm.mnc

done
fi