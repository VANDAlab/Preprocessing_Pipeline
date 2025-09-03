#!/bin/bash
# Define variables
#results_dir="./6000030_hcp"
results_dir="$1"
qc_dir=${results_dir}"/qc"

# Extract subject ID from one of the filenames
subject_id=$(basename "$results_dir" | grep -oP '(sub-\d+|\d+)')

output_html=${results_dir}/${subject_id}_QC_report.html

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
    <title>QC Report for $subject_id</title>
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
                        <li><a class="dropdown-item" href="#methods">Methods</a></li>
                        <li><a class="dropdown-item" href="#references">References</a></li>
                        <li><a class="dropdown-item" href="#citations">Citations</a></li>
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
        <div id="datatype-figures_desc-summary_subject-$subject_id" class="ps-3 pe-4 mb-2">
            <ul class="elem-desc">
                <li>Subject ID: ${subject_id}</li>
                <li>Number of Sessions: $num_sessions</li>
            </ul>
        </div>
    </div>

    <div id="QC" class="mt-4">
        <h1 class="sub-report-title common-padding">QC images</h1>
EOF

# Define descriptions for mandatory and optional images
declare -A descriptions=(
    ["t1_mask"]="Brain mask"
    ["t1_stx2_lin_vp"]="Linear registration of T1-weighted image"
    ["stx2_nlin"]="Non-linear registration alignment"
    ["t1_t1"]="T1 preprocessed image"
    ["t1_Label"]="T1 image with BISON segmentation labels"
    ["t1_t2"]="T2 preprocessed image"
    ["t1_t2_Label"]="T2 image with BISON segmentation labels"
    ["t1_flr_FLAIR"]="FLAIR preprocessed image"
    ["t1_flr_Label"]="FLAIR image with BISON segmentation labels"
)

# Define captions for images (if any)
declare -A captions=(
    ["t1_mask"]="This is the brain mask used for analysis. Check ..."
    ["t1_stx2_lin_vp"]="Linear registration of T1-weighted image."
    ["stx2_nlin"]="Alignment using non-linear registration."
    ["t1_t1"]="t1 preprocessed"
    ["t1_Label"]="Segmentation labels on T1 image."
    ["t1_t2"]="t2 preprocessed"
    ["t1_t2_Label"]="Segmentation labels on T2 image."
    ["t1_flr_FLAIR"]="FLAIR preprocessed"
    ["t1_flr_Label"]="Segmentation labels on FLAIR image."
)

# Loop through each session
for session in "${sessions[@]}"; do
    session_name=$(basename "$session")
    echo "        <div class=\"qc-block common-margin\">" >> "$output_html"
    echo "            <h2 class=\"sub-report-group common-margin\">Session: $session_name</h2>" >> "$output_html"

    # Add mandatory images first
    #session_rel=$(realpath --relative-to="$(dirname "$output_html")" "$session")
    for key in "t1_mask" "t1_stx2_lin_vp" "stx2_nlin" "t1_t1" "t1_Label" "t1_t2" "t1_t2_Label" "t1_flr_FLAIR" "t1_flr_Label"; do
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
        <div id="methods">
            <h2 class="sub-report-group common-margin">Methods</h2>
            <p class="description common-margin"><b>We can copy some methods from the paper</b></p>
        </div>
        <div id="references">
            <h2 class="sub-report-group common-margin">References</h2>
            <p class="description common-margin"><b>We can add relevant lit</b></p>
        </div>
        <div id="citations">
            <h2 class="sub-report-group common-margin">Citations</h2>
            <p class="description common-margin">Don't forget to cite our <a href="https://www.w3schools.com/">paper</a></p>
        </div>
    </div>
</div>
</body>
</html>
EOF

echo "HTML report generated: $output_html"