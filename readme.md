This page describes PELICAN pipeline, a longitudinal multi-contrast MRI processing pipeline developed by Mahsa Dadar and Yashar Zeighami. 
The general command to run the pipeline should be formatted as:  
./PELICAN.sh single_participant_input_file.csv model_folder/ output_folder_all_participants/ {optional indirect_template_folder}

Model path <ins>**necessary**</ins> to be used as model_folder as well as a singularity build for the necessary tools (ANTs, MINC, and Anaconda) are available at: https://zenodo.org/records/17168419. 
For more details, please refer to: https://www.biorxiv.org/content/10.1101/2025.09.20.677546v1.abstract

**example 1:**  
./PELICAN.sh Participant_Inputs_File.csv Models_Folder/ Outputs/ 

**example 2:**  
./PELICAN.sh Participant_Inputs_File.csv Models_Folder/ Outputs/ Indirect_Template/


Participant_Inputs_File.csv format:  
ParticipantID, ParticipantVisit, Path to T1w MRI,Path to T2w MRI, Path to PDw MRI, Path to FLAIR MRI 

**example 1:** single visit with all 4 constrasts  
Subject_1,Visit_1, Data/Subject_1_Visit_1_T1w.mnc,Data/Subject_1_Visit_1_T2w.mnc,Data/Subject_1_Visit_1_PDw.mnc,Data/Subject_1_Visit_1_FLAIR.mnc

**example 2:** single visit with only T1w and FLAIR  
Subject_1,Visit_1, Data/Subject_1_Visit_1_T1w.mnc,,,Data/Subject_1_Visit_1_FLAIR.mnc

**example 3:** 4 visits, each with different combinations of contrasts  
Subject_1,Visit_1, Data/Subject_1_Visit_1_T1w.mnc,Data/Subject_1_Visit_1_T2w.mnc,Data/Subject_1_Visit_1_PDw.mnc,Data/Subject_1_Visit_1_FLAIR.mnc
Subject_1,Visit_2, Data/Subject_1_Visit_2_T1w.mnc,,,
Subject_1,Visit_3, Data/Subject_1_Visit_3_T1w.mnc,Data/Subject_1_Visit_3_T2w.mnc,,Data/Subject_1_Visit_3_FLAIR.mnc
Subject_1,Visit_5, Data/Subject_1_Visit_5_T1w.mnc,,,Data/Subject_1_Visit_5_FLAIR.mnc

**Notes**
* The lines in Participant_Inputs_File.csv correspond to different visits from the same participant; <ins>**do not include data from different participants in the same csv file**</ins>
* In case of missing modalities, leave the column empty, similar to the examples provided above.
* Do not mismatch contrasts when some are not available **(i.e. if inputs are Subject_1,Visit_2, Data/Subject_1_Visit_2_T1w.mnc,Data/Subject_1_Visit_1_FLAIR.mnc, it will assume Data/Subject_1_Visit_1_FLAIR.mnc is a path to a T2w image).**
* Use of Indirect_Template is <u>**optional**</u> and not necessary in healthy populations or those with subtle atrophy, but it is recommended in Alzheimer's disease and frontotemporal dementia populations.
* It is possible to use other indirect templates if appropriate files are provided: model averages, corresponding masks, brain contour, and nonlinear transformation to ICBM
* It is also possible to replace ICBM with other templates by changing the template files (e.g. Av_T1.mnc) in the Models folder.
* BISON labels include:
    1. Ventricles
    2. CSF
    3. cerebellar GM
    4. cerebellar WM
    5. brainstem
    6. deep GM
    7. cortical GM
    8. WM
    9. WMHs


