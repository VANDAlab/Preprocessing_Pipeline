The general command to the pipeline is formatted as:  
./PELICAN.sh single_participant_input_file.csv model_folder/ output_folder_all_participants/ {optional indirect_template_folder}

Model path to be used as model_folder:  
* will be uploaded to zenodo in future

example 1:  
./PELICAN.sh Participant_Inputs_File.csv /data/dadmah/tools/cicLngPipelineModels/ Outputs/ 

example 2:  
./PELICAN.sh Participant_Inputs_File.csv /data/dadmah/tools/cicLngPipelineModels/ Outputs/ Indirect_Template/


Participant_Inputs_File.csv format:  
ParticipantID, ParticipantVisit, Path to T1w MRI,Path to T2w MRI, Path to PDw MRI, Path to FLAIR MRI 

example 1: single visit with all 4 constrasts  
Subject_1,Visit_1, Data/Subject_1_Visit_1_T1w.mnc,Data/Subject_1_Visit_1_T2w.mnc,Data/Subject_1_Visit_1_PDw.mnc,Data/Subject_1_Visit_1_FLAIR.mnc

example 2: single visit with only T1w and FLAIR  
Subject_1,Visit_1, Data/Subject_1_Visit_1_T1w.mnc,,,Data/Subject_1_Visit_1_FLAIR.mnc

example 3: 4 visits, each with different combinations of contrasts  
Subject_1,Visit_1, Data/Subject_1_Visit_1_T1w.mnc,Data/Subject_1_Visit_1_T2w.mnc,Data/Subject_1_Visit_1_PDw.mnc,Data/Subject_1_Visit_1_FLAIR.mnc
Subject_1,Visit_2, Data/Subject_1_Visit_2_T1w.mnc,,,
Subject_1,Visit_3, Data/Subject_1_Visit_3_T1w.mnc,Data/Subject_1_Visit_3_T2w.mnc,,Data/Subject_1_Visit_3_FLAIR.mnc
Subject_1,Visit_5, Data/Subject_1_Visit_5_T1w.mnc,,,Data/Subject_1_Visit_5_FLAIR.mnc

Notes
* The lines in Participant_Inputs_File.csv correspond to different visits from the same participant; <u>**do not include data from different participants in the same csv file**</u>
* In case of missing modalities leave the column empty, similar to the examples provided above
* Do not mismatch contrasts when some are not available **(i.e. if inputs are Subject_1,Visit_2, Data/Subject_1_Visit_2_T1w.mnc,Data/Subject_1_Visit_1_FLAIR.mnc, it will assume Data/Subject_1_Visit_1_FLAIR.mnc is a path to a T2w image.**
* Use of Indirect_Template is <u>**optional**</u> and not necessary in healthy populations or those with subtle atrophy, but it is recommended in Alzheimer's disease and frontotemporal dementia populations.
* It is possible to use other indirect templates if appropriate files are provided: model averages, corresponding masks, brain contour, and nonlinear transformation to ICBM
* It is also possible to replace ICBM with other templates by changing the template files (e.g. Av_T1.mnc) in the Models folder.

