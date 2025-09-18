#!/bin/bash
# Define variables
#results_dir="./6000030_hcp"
results_dir="$1"
qc_dir=${results_dir}"/qc"

# Extract participant ID from one of the filenames
participant_id=$(basename "$results_dir" | grep -oP '(sub-\d+|\d+)')

output_html=${results_dir}/${participant_id}_QC_report.html

# Find all session folders (e.g., ses-01, ses-02)
#sessions=($(ls -d "$qc_dir"/ses-* 2>/dev/null | sort -V))
sessions=($(find "$qc_dir" -mindepth 1 -maxdepth 1 -type d | sort -V))

# Get number of sessions
num_sessions=${#sessions[@]}

# Start HTML file
cat <<EOF > "$output_html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>QC Report for $participant_id</title>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js" integrity="sha256-/xUj+3OJU5yExlq6GSYGSHk7tPXikynS7ogEvDej/m4=" crossorigin="anonymous"></script>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-rbsA2VBKQhggwzxH7pPCaAqO46MgnOM80zW1RWuH61DGLwZJEdK2Kadq2F9CUG65" crossorigin="anonymous">
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/js/bootstrap.bundle.min.js" integrity="sha384-kenU1KFdBIe4zVF0s0G1M5b4hcpxyD9F7jL+jjXkk+Q2h455rYXK/7HAuoJl+0I4" crossorigin="anonymous"></script>
    <style>
        body { font-family: Helvetica, sans-serif; }
        img { max-width: 95%; height: auto; margin: 10px; border: 2px solid #000; }
        .container { max-width: 900px; margin: auto; }
        .common-margin { margin-left: 1.5rem; margin-top: 1rem; }
        .common-padding { padding-top: 1rem; padding-left: 1rem; }
        .tight-spacing { margin-top: 0.5rem; margin-bottom: 0.5rem; margin-left: 1.5rem;}
    </style>
</head>
<body>
<nav class="navbar fixed-top navbar-expand-lg bg-light">
    <div class="container-fluid">
        <div class="collapse navbar-collapse" id="navbarSupportedContent">
            <ul class="navbar-nav me-auto mb-2 mb-lg-0">
                <li class="nav-item"><a class="nav-link" href="#Summary">Summary</a></li>
                <li class="nav-item"><a class="nav-link" href="#QC">Processing</a></li>
                <li class="nav-item dropdown">
                    <a class="nav-link dropdown-toggle" id="navbarAbout" role="button" data-bs-toggle="dropdown" aria-expanded="false" href="#About">About</a>
                    <ul class="dropdown-menu">
                        <li><a class="dropdown-item" href="#pelican">PELICAN</a></li>
                        <li><a class="dropdown-item" href="#qc_protocols">QC Protocols</a></li>
                        <li><a class="dropdown-item" href="#templates">Average templates</a></li>
                    </ul>
                </li>
            </ul>
        </div>
    </div>
</nav>
<noscript>
    <h1 class="text-danger">The navigation menu uses Javascript. Without it, this report might not work as expected.</h1>
</noscript>

<div id="main-body">
    <div id="Summary" class="mt-5">
        <h1 class="sub-report-title common-padding">Summary</h1>
        <div id="datatype-figures_desc-summary_participant-$participant_id" class="ps-3 pe-4 mb-2">
            <ul class="elem-desc">
                <li>Participant ID: ${participant_id}</li>
                <li>Number of Sessions: $num_sessions</li>
            </ul>
        </div>
    </div>

    <div id="QC" class="mt-4">
        <h1 class="sub-report-title common-padding">QC images</h1>
EOF

# Define descriptions for mandatory and optional images
declare -A descriptions=(
    ["t1_stx2_lin_vp"]="Linear registration"
    ["t1_mask"]="Brain mask"
    ["stx2_nlin"]="Nonlinear registration"
    ["stx2_indirect_nlin"]="Indirect Nonlinear registration"
    ["t1_t1"]="Preprocessed T1-weighted image"
    ["t1_Label"]="T1-based BISON segmentation"
    ["t1_flr_FLAIR"]="Preprocessed FLAIR image"
    ["t1_flr_Label"]="FLAIR-based BISON segmentation"
    ["t1_t2"]="Preprocessed T2-weighted image"
    ["t1_t2_Label"]="T2-based BISON segmentation"
)

# Define captions for images (if any)
declare -A captions=(
    ["t1_stx2_lin_vp"]="The images show contours of the MNI-ICBM152 average template overlaid on the linearly registered T1w image. MNI-ICBM152 contours of the main sulci should align with the contours of the participant brain, but not necessarily the ventricles."
    ["t1_mask"]="The following images show BEaST brain masks overlaid on preprocessed and linearly registered T1w images in the stereotaxic space. The masks should capture the entirety of the brain, but not include non-brain skull or dura. Note that brain masks are used in downstream DBM and VBM analyses, and BISON segmentations. "
    ["stx2_nlin"]="The images show contours of the MNI-ICBM152 average template overlaid on the nonlinearly registered T1w image. MNI-ICBM152 contours of the main sulci should align well with the contours of the participant brain and ventricles."
    ["stx2_indirect_nlin"]="The images show contours of the MNI-ICBM152 average template overlaid on the T1w image nonlinearly registered using an intermediate template. MNI-ICBM152 contours of the main sulci should align well with the contours of the participant brain and ventricles. "
    ["t1_t1"]="Preprocessed T1w images (denoised, non-uniformity corrected, and intensity normalized) in the stereotaxic space. Images should be free of extensive noise, intensity inhomogeneity, and the brightness level should be consistent across different participants."
    ["t1_Label"]="BISON segmentation labels based only on T1-weighted images in the stereotaxic space overlaid on the preprocessed T1-weighted image. "
    ["t1_flr_FLAIR"]="Preprocessed FLAIR  images (denoised, non-uniformity corrected, and intensity normalized) in the stereotaxic space. Images should be free of extensive noise, intensity inhomogeneity, and the brightness level should be consistent across different participants."
    ["t1_flr_Label"]="BISON segmentation labels based on FLAIR and T1-weighted images in the stereotaxic space overlaid on the preprocessed T1-weighted image. "
    ["t1_t2"]="Preprocessed T2-weighted  images (denoised, non-uniformity corrected, and intensity normalized) in the stereotaxic space. Images should be free of extensive noise, intensity inhomogeneity, and the brightness level should be consistent across different participants."
    ["t1_t2_Label"]="BISON segmentation labels based on FLAIR and T1-weighted images in the stereotaxic space overlaid on the preprocessed T1-weighted image. "
)

# Loop through each session
for session in "${sessions[@]}"; do
    session_name=$(basename "$session")
    echo "        <div class=\"qc-block common-margin\">" >> "$output_html"
    echo "            <h2 class=\"sub-report-group common-margin\">Session: $session_name</h2>" >> "$output_html"

    # Add mandatory images first
    for key in "t1_stx2_lin_vp" "t1_mask" "stx2_nlin" "stx2_indirect_nlin" "t1_t1" "t1_Label" "t1_flr_FLAIR" "t1_flr_Label" "t1_t2" "t1_t2_Label"; do
        img=$(find "$session" -type f -name "*${key}.jpg" | head -n 1)
        if [[ -f "$img" ]]; then
            img_rel=$(realpath --relative-to="$(dirname "$output_html")" "$img")
            img_name=$(basename "$img")
            echo "            <h3 class=\"run-title tight-spacing pt-1\">${descriptions[$key]}</h3>" >> "$output_html"
            if [[ -n "${captions[$key]}" ]]; then
                echo "            <p class=\"elem-caption tight-spacing\">${captions[$key]}</p>" >> "$output_html"
            fi
            echo "            <img class=\"jpg-fig tight-spacing\" src=\"$img_rel\" alt=\"$img_name\">" >> "$output_html"
            echo "            <div>" >> "$output_html"
            echo "                <small class=\"elem-caption tight-spacing\">Get figure file: <a href=\"$img_rel\" target=\"_blank\">$img_name</a></small>" >> "$output_html"
            echo "            </div>" >> "$output_html"
        fi
    done
    echo "        </div>" >> "$output_html"
done

# Citation section
cat <<EOF >> "$output_html"
    </div>

    <div id="About" class="mt-4">
        <h1 class="sub-report-title common-padding">About</h1>
        <div id="pelican">
            <h2 class="sub-report-group common-margin">PELICAN</h2>
            <p class="description common-margin">For more details on PELICAN pipeline, please refer to:<br>Dadar, Mahsa, et al. "PELICAN: a Longitudinal Image Processing Pipeline for Analyzing Structural Magnetic Resonance Images in Aging and Neurodegenerative Disease Populations." <i>medRxiv</i> (2025).</p>
        </div>
        <div id="qc_protocols">
            <h2 class="sub-report-group common-margin">QC Protocols</h2>
            <p class="description common-margin">For more information on quality control protocols, please refer to:<br><a href="https://www.sciencedirect.com/science/article/pii/S1053811918302350?via%3Dihub" target="_blank">Dadar, Mahsa, et al. "A comparison of publicly available linear MRI stereotaxic registration techniques." <i>Neuroimage</i> 174 (2018): 191-200.</a></p>
        </div>
        <div id="templates">
            <h2 class="sub-report-group common-margin">Average templates</h2>
            <p class="description common-margin">For more details on average templates, please refer to:</p>
            <ul class="common-margin">
            <li><a href="https://www.nature.com/articles/s41597-021-01007-5" target="_blank">Dadar, Mahsa, et al. "MNI-FTD templates, unbiased average templates of frontotemporal dementia variants." <i>Scientific Data</i> 8.1 (2021): 222.</a></li>
            <li><a href="https://www.nature.com/articles/s41597-022-01341-2" target="_blank">Dadar, Mahsa, Richard Camicioli, and Simon Duchesne. "Multi sequence average templates for aging and neurodegenerative disease populations." <i>Scientific Data</i> 9.1 (2022): 238.</a></li>
            </ul>
        </div>
</p>
        </div>
    </div>
</div>
</body>
</html>
EOF

echo "HTML report generated: $output_html"