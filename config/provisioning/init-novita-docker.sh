#!/bin/bash

# This file will be sourced in init.sh




# https://github.com/MushroomFleet/Runpod-init
COMFYUI_DIR=${WORKSPACE}/ComfyUI
workflows_dir=${WORKSPACE}/ComfyUI/user/default/workflows

mkdir -p "${WORKSPACE}/ComfyUI/user/default/workflows"
mkdir -p "${WORKSPACE}/ComfyUI/Inputs/Downloaded/Parked"
mkdir -p "${WORKSPACE}/ComfyUI/Inputs/Next/Best"
mkdir -p "${WORKSPACE}/ComfyUI/Inputs/Next/Park"
mkdir -p "${WORKSPACE}/ComfyUI/Inputs/Processed"

mkdir -p "${WORKSPACE}/environments/python/comfyui"
cd "${WORKSPACE}/environments/python/"

# Check and install python3.12 python3.12-venv
# Check if python3.12 and python3.12-venv are installed
if ! dpkg -l | grep -qw python3.12 || ! dpkg -l | grep -qw python3.12-venv; then
    echo "python3.12 or python3.12-venv is not installed. Installing now..."
    sudo apt update && sudo apt install -y python3.12 python3.12-venv
else
    echo "python3.12 and python3.12-venv are already installed."
fi


/usr/bin/python3.12 -m venv comfyui

#/usr/bin/python3 -m venv serviceportal
#/usr/bin/python3 -m venv api
COMFYUI_VENV_DIR=${WORKSPACE}environments/python/comfyui
mkdir -p "${COMFYUI_VENV_DIR}"
source "${COMFYUI_VENV_DIR}/bin/activate"

# Packages are installed after nodes so we can fix them...

DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/flux-comfyui-example.json"
  DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/Workflow_API.json"
CRON_SCRIPT="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/submit_prompt.sh"

mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/segm"
mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/bbox"
mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/sams"

APT_PACKAGES=(
    "netcat"
    "libmagickwand-dev"
    "axel"
    "screen"
    "tree"
    "ncdu"
    "socat"
    "cron"
    "libgl1"
    "libegl1"
    "libgles2"
    "libglib2.0-0"
    "libsm6"
    "libxext6"
    "libxrender1"
    "ffmpeg"
)

#apt-get update --fix-missing &&  apt install -y   libmagickwand-dev axel tree screen socat  cron   libgl1 libegl1 libgles2 libglib2.0-0 libsm6 libxext6 libxrender1 ffmpeg


PIP_PACKAGES=(
    "resynthesizer=1.2"
    "OpenEXR=3.4.4"
    "soundfile=0.13.1"
    "uvicorn==0.30.6"
    "fastapi==0.115.0"
    "torchsde==0.2.6"
)

CHECKPOINT_MODELS=(
)
NODES=(
    "https://github.com/sk-palani/ComfyUI_Simpler"
    "https://github.com/ClownsharkBatwing/RES4LYF"
)


WORKFLOWS=(
    "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/flux_dev_example.json"
)



CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"

)

TEXT_ENCODER_MODELS=(
    "https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors"
    "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/text_encoders/qwen3vl_4b_fp8_scaled.safetensors"
)





CLIPVISION_MODELS=(
    "https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors"
    "https://huggingface.co/ostris/ComfyUI-Advanced-Vision/resolve/main/clip_vision/siglip2_so400m_patch16_512.safetensors"
)

STYLE_MODELS=(
  "https://huggingface.co/black-forest-labs/FLUX.1-Redux-dev/resolve/main/flux1-redux-dev.safetensors"
  "https://huggingface.co/ostris/Flex.1-alpha-Redux/resolve/main/flex1_redux_siglip2_512.safetensors"
)

LUTS=(
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20%20-%20Gold%20200.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20%20-%20Kodacrome%2064.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Agfa%20Optima.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Agfa%20Ultra%20100.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Cinematic.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Fuji%20Astia.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Hollywood.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Kodachrome.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Moody%20Aqua.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Moody%20Stock.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Polaroid%20Color.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Reversal.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Stylish.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Velvia%20100.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Vibe.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Emulation.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Presetpro%20-%20Fuji%20Film.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Monochrome_Safe_Gentle_Contrast_33.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/luts/Neutral_Identity_33.cube"
)



FONTS=(
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/fonts/SevenSegment.ttf"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/fonts/DSEG14Classic-Bold.ttf"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/fonts/DSEG14Classic-BoldItalic.ttf"
)


MP3=(
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/sound/finish.mp3"
)


UNET_MODELS=(
  "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors"
  "https://civitai.red/api/download/models/2287992?fileId=2181185&token=${CIVITAI_TOKEN}"

)

DIFFUSION_MODELS=(
  "https://huggingface.co/black-forest-labs/FLUX.2-klein-9B/resolve/main/flux-2-klein-9b.safetensors"
  "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/diffusion_models/krea2_turbo_fp8_scaled.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
    "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors"
    "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/vae/qwen_image_vae.safetensors"

)

LORA_MODELS=(
    # ------------------------------
    # Flux Krea 2
    # ------------------------------

    # expression_slider_0ts-krea2-V1.safetensors
    "https://civitai.com/api/download/models/3349249?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"

    # skin_detail_slider_krea2_ZT-V1.safetensors
    "https://civitai.com/api/download/models/3323867?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"

    # inline-skin-lora-krea-2-raw.safetensors
    "https://huggingface.co/inlineresearch/skin-lora-krea-2-raw/resolve/main/inline-skin-lora-krea-2-raw.safetensors"

    # ------------------------------
    # Flux2.Klein
    # ------------------------------

    "https://civitai.com/api/download/models/2998669?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"

    #Purple_Grainy_Kr2_AM.safetensors
    "https://civitai.com/api/download/models/3110766?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    # Purple_Grainy_KR2_V2_D.safetensors
    "https://civitai.com/api/download/models/3328996?fileId=3215019&token=${CIVITAI_TOKEN}"

    # ------------------------------
    # Flux1.Dev
    # ------------------------------
    # Pandora-RAWr.safetensors
    "https://civitai.com/api/download/models/1943855?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"


)


ESRGAN_MODELS=(
#    "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth"
)


UPSCALE_MODELS=(
    "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Superscale-SP_178000_G.pth"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/Kijai/flux-fp8/resolve/main/flux_shakker_labs_union_pro-fp8_e4m3fn.safetensors"
    "https://huggingface.co/jasperai/Flux.1-dev-Controlnet-Upscaler/resolve/main/diffusion_pytorch_model.safetensors"
)

ULTRALYTICS_SEGS_MODELS=(
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8n_v2.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov9c.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
  "https://huggingface.co/jags/yolov8_model_segmentation-set/resolve/main/skin_yolov8m-seg_400.pt"
  "https://civitai.com/api/download/models/1324778?type=Model&format=PickleTensor"
  "https://huggingface.co/ashllay/YOLO_Models/resolve/main/segm/unwanted-3x.pt"

)

ULTRALYTICS_BBOX_MODELS=(
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
  "https://huggingface.co/ashllay/YOLO_Models/resolve/main/bbox/Eyeful_v2-Paired.pt"
  "https://huggingface.co/ashllay/YOLO_Models/resolve/main/bbox/face_yolov8m.pt"
)

SAM_MODELS=(
  "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/sams/sam_vit_b_01ec64.pth"
)



### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_pip_packages
    provisioning_get_nodes
    provisioning_get_models \
        "${WORKSPACE}/ComfyUI/models/ckpt" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/luts" \
        "${LUTS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/custom_nodes/comfyui_essentials/fonts/" \
        "${FONTS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/custom_nodes/comfyui_custom_scripts/web/js/assets/" \
        "${MP3[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/clip" \
        "${CLIP_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/text_encoders" \
        "${TEXT_ENCODER_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/clip_vision" \
        "${CLIPVISION_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/style_models" \
        "${STYLE_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/upscale_models" \
        "${UPSCALE_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/sams" \
        "${SAM_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/ultralytics/segm" \
        "${ULTRALYTICS_SEGS_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/ultralytics/bbox" \
        "${ULTRALYTICS_BBOX_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/diffusion_models" \
        "${DIFFUSION_MODELS[@]}"
    provisioning_print_end
    echo 'grep trycloud /var/log/supervisor/quicktunnel-*' > "${WORKSPACE}/l"
    chmod +x  "${WORKSPACE}/l"
    provisioning_get_workflows
    provisioning_print_end
    touch "${WORKSPACE}/.noprovisioning"
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
            "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
        else
            micromamba run -n comfyui pip install --no-cache-dir "$@"
        fi
}

function provisioning_get_apt_packages() {
    sudo apt-get update --fix-missing
    if [[ -n $APT_PACKAGES ]]; then
        for package in "${APT_PACKAGES[@]}"; do
            if ! dpkg -l | grep -qw "$package"; then
                echo "$package is not installed. Installing now..."
                sudo apt-get install -y "$package"
            else
                echo "$package is already installed."
            fi
        done
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        source "${COMFYUI_VENV_DIR}/bin/activate"
        for package in "${PIP_PACKAGES[@]}"; do
            if ! pip show "$package" > /dev/null 2>&1; then
                echo "$package is not installed. Installing now..."
                pip install "$package"
            else
                echo "$package is already installed."
            fi
        done
    fi
}

function provisioning_get_nodes() {
    source "${COMFYUI_VENV_DIR}/bin/activate"
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        dir="${dir,,}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_workflows() {
    for repo in "${WORKFLOWS[@]}"; do
        dir=$(basename "$repo" .git)
        path="${COMFYUI_DIR}/user/default/workflows/${dir}"
        if [[ -d "$path" ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating workflows: %s...\n" "${repo}"
                ( cd "$path" && git pull )
            fi
        else
            printf "Cloning workflows: %s...\n" "${repo}"
            git clone "$repo" "$path"
        fi
    done
}

function provisioning_get_default_workflow() {
    mkdir -p "${WORKSPACE}/web/scripts"
    mkdir -p "${WORKSPACE}/scripts"
    curl -L -o "${WORKSPACE}/scripts/submit_prompt.sh" "${CRON_SCRIPT}"
    curl -L -o "${WORKSPACE}/scripts/Workflow_API.json" "${DEFAULT_WORKFLOW}"

    if [[ -n $DEFAULT_WORKFLOW ]]; then
        workflow_json=$(curl -s "$DEFAULT_WORKFLOW")
        if [[ -n $workflow_json ]]; then
            echo "export const defaultGraph = $workflow_json;" > /opt/ComfyUI/web/scripts/defaultGraph.js
            echo "export const defaultGraph = $workflow_json;" > "${workflows_dir}/defaultGraph.js"
            echo "export const defaultGraph = $workflow_json;" > "${COMFYUI_DIR}/web/scripts/defaultGraph.js"
        fi
    fi
    if [[ -f "${workflows_dir}/latest.json" ]]; then
        workflow_json=$(cat "${workflows_dir}/latest.json")
        if [[ -n $workflow_json ]]; then
            echo "export const defaultGraph = $workflow_json;" > /opt/ComfyUI/web/scripts/defaultGraph.js
            echo "export const defaultGraph = $workflow_json;" > "${workflows_dir}/defaultGraph.js"
            echo "export const defaultGraph = $workflow_json;" > "${COMFYUI_DIR}/web/scripts/defaultGraph.js"
        fi
    fi
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi

    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
function provisioning_download() {

  URL="$1"
  DEST="$2"
  DOTBYTES="${3:-4M}"
  AUTH_HEADER=""
  mkdir -p "${DEST}"
  if [[ $URL =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
    [[ -n $HF_TOKEN ]] && AUTH_HEADER="Authorization: Bearer $HF_TOKEN"
    wget ${AUTH_HEADER:+--header="$AUTH_HEADER"} -qnc --content-disposition --show-progress -e dotbytes="$DOTBYTES" -P "$DEST" "$URL"
  elif [[ $URL =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
    if [[ -n $CIVITAI_TOKEN ]]; then
        cd "$DEST"
        axel "$URL"
        cd - > /dev/null
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="$DOTBYTES" -P "$DEST" "$URL"
    fi

  else
    wget -qnc --content-disposition --show-progress -e dotbytes="$DOTBYTES" -P "$DEST" "$URL"
  fi

}

provisioning_get_apt_packages
#provisioning_get_nodes
#provisioning_get_pip_packages
#provisioning_start
#pip install -r "${WORKSPACE}/ComfyUI/requirements.txt"

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f "${WORKSPACE}/.noprovisioning" ]]; then
    provisioning_start
    pip install -r "${WORKSPACE}/ComfyUI/requirements.txt"
fi


${WORKSPACE}/environments/python/comfyui/bin/python -m pip install -r "${WORKSPACE}/ComfyUI/requirements.txt"
#opencv-contrib-python
provisioning_get_default_workflow

#WORKSPACE=/workspace/
# * * * * * /workspace/scripts/submit_prompt.sh >> /workspace/crontab.log
# * * * * * /workspace/submit_prompt.sh >> /workspace/crontab.log
chmod +x "${WORKSPACE}scripts/submit_prompt.sh"

set -f
JOB="* * * * * ${WORKSPACE}scripts/submit_prompt.sh >> ${WORKSPACE}crontab.log 2>&1"

sudo bash -c "cat > /tmp/workspace.cron <<EOF
WORKSPACE=${WORKSPACE}
${JOB}
EOF

crontab /tmp/workspace.cron
rm /tmp/workspace.cron"

set +f

sudo service cron start

sudo supervisorctl stop 'cf_quicktunnel:="cf_quicktunnel_0"'
sudo supervisorctl stop 'cf_quicktunnel:="cf_quicktunnel_1"'
sudo supervisorctl stop 'cf_quicktunnel:="cf_quicktunnel_2"'
sudo supervisorctl stop 'cf_quicktunnel:="cf_quicktunnel_3"'
sudo supervisorctl stop 'jupyter'



# supervisorctl restart 'cf_quicktunnel:="cf_quicktunnel_0"'
# supervisorctl restart 'cf_quicktunnel:="cf_quicktunnel_1"'
# supervisorctl restart 'cf_quicktunnel:="cf_quicktunnel_2"'
# supervisorctl restart 'cf_quicktunnel:="cf_quicktunnel_3"'

## wait for port to be available
# wait for port 18188 and 18384 to be available
while ! nc -z localhost 18188; do
    sleep 1
done
while ! nc -z localhost 18384; do
    sleep 1
done

nohup  socat TCP-LISTEN:18000,fork,reuseaddr TCP:127.0.0.1:1111 &
sleep 2
nohup  socat TCP-LISTEN:19000,fork,reuseaddr TCP:127.0.0.1:18188 &
sleep 2
nohup  socat TCP-LISTEN:8188,fork,reuseaddr TCP:127.0.0.1:18188 &
sleep 2
nohup  socat TCP-LISTEN:20000,fork,reuseaddr TCP:127.0.0.1:18384 &
sleep 2
