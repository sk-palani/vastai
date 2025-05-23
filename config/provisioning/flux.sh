#!/bin/bash

# This file will be sourced in init.sh

# https://raw.githubusercontent.com/ai-dock/comfyui/main/config/provisioning/default.sh

# Packages are installed after nodes so we can fix them...

DEFAULT_WORKFLOW="https://raw.githubusercontent.com/ai-dock/comfyui/main/config/workflows/flux-comfyui-example.json"
mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/segm"
mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/bbox"

APT_PACKAGES=(
    #"package-1"
    #"package-2"
    "libmagickwand-dev"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
    "resynthesizer"
)

NODES=(
    "https://github.com/BlenderNeko/ComfyUI_Noise.git"
    "https://github.com/chrisgoringe/cg-use-everywhere.git"
    "https://github.com/city96/ComfyUI-GGUF.git"
    "https://github.com/Clybius/ComfyUI-Latent-Modifiers.git"
    "https://github.com/digitaljohn/comfyui-propost.git"
    "https://github.com/giriss/comfy-image-saver.git"
    "https://github.com/kijai/ComfyUI-Florence2.git"
    "https://github.com/kijai/ComfyUI-KJNodes.git"
    "https://github.com/kijai/ComfyUI-segment-anything-2.git"
    "https://github.com/KoreTeknology/ComfyUI-Universal-Styler.git"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
    "https://github.com/spacepxl/ComfyUI-Florence-2.git"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"
    "https://github.com/un-seen/comfyui-tensorops.git"
    "https://github.com/WASasquatch/was-node-suite-comfyui.git"
    "https://github.com/Xclbr7/ComfyUI-Merlin.git"
    "https://github.com/yolain/ComfyUI-Easy-Use.git"
    "https://github.com/Acly/comfyui-tooling-nodes.git"
    "https://github.com/alexopus/ComfyUI-Image-Saver"
    "https://github.com/BadCafeCode/masquerade-nodes-comfyui"
    "https://github.com/BobsBlazed/Bobs_Latent_Optimizer"
    "https://github.com/chflame163/ComfyUI_LayerStyle"
    "https://github.com/chibiace/ComfyUI-Chibi-Nodes"
    "https://github.com/chrisgoringe/cg-image-picker"
    "https://github.com/crystian/ComfyUI-Crystools"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/dagthomas/comfyui_dagthomas"
    "https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes"
    "https://github.com/evanspearman/ComfyMath"
    "https://github.com/Fannovel16/ComfyUI-MagickWand"
    "https://github.com/jamesWalker55/comfyui-various"
    "https://github.com/jjkramhoeft/ComfyUI-Jjk-Nodes"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/KoreTeknology/ComfyUI-Universal-Styler"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/ltdrdata/ComfyUI-Inspire-Pack"
    "https://github.com/melMass/comfy_mtb"
    "https://github.com/miaoshouai/ComfyUI-Miaoshouai-Tagger"
    "https://github.com/mirabarukaso/ComfyUI_Mira"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/SeargeDP/ComfyUI_Searge_LLM"
    "https://github.com/SeargeDP/SeargeSDXL"
    "https://github.com/sipherxyz/comfyui-art-venture"
    "https://github.com/Smirnov75/ComfyUI-mxToolkit"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes"
    "https://github.com/Tenney95/ComfyUI-NodeAligner"
    "https://github.com/TinyTerra/ComfyUI_tinyterraNodes"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/brayevalerien/ComfyUI-resynthesizer"
    "https://github.com/Jonseed/ComfyUI-Detail-Daemon"
    "https://github.com/jags111/efficiency-nodes-comfyui"
    "https://github.com/EllangoK/ComfyUI-post-processing-nodes"
    "https://github.com/digitaljohn/comfyui-propost"
    "https://github.com/EllangoK/ComfyUI-post-processing-nodes"
)

CHECKPOINT_MODELS=(
)

CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
)

UNET_MODELS=(
    "https://civitai.com/api/download/models/722620?type=Model&format=SafeTensor&size=pruned&fp=fp8"
)

VAE_MODELS=(

)

LORA_MODELS=(
    "https://huggingface.co/prithivMLmods/Canopus-LoRA-Flux-UltraRealism-2.0/resolve/main/Canopus-LoRA-Flux-UltraRealism.safetensors"
    "https://huggingface.co/XLabs-AI/flux-lora-collection/resolve/main/realism_lora_comfy_converted.safetensors"
    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-LoRA-AntiBlur/resolve/main/FLUX-dev-lora-AntiBlur.safetensors"
    "https://huggingface.co/neuroplus/skin-texture-style-v4d/resolve/main/skin%20texture%20style%20v4d.safetensors"
    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-LoRA-add-details/resolve/main/FLUX-dev-lora-add_details.safetensors"
)

ESRGAN_MODELS=(
    "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth"
    "https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth"
    "https://huggingface.co/Akumetsu971/SD_Anime_Futuristic_Armor/resolve/main/4x_NMKD-Siax_200k.pth"
)

CONTROLNET_MODELS=(
)


ULTRALYTICS_SEGS_MODELS=(
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8n_v2.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov9c.pt"
)

ULTRALYTICS_BBOX_MODELS=(
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
)




### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    # Get licensed models if HF_TOKEN set & valid
    if provisioning_has_valid_hf_token; then
        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors")
        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors")
    else
        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors")
        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors")
        sed -i 's/flux1-dev\.safetensors/flux1-schnell.safetensors/g' "${workflows_dir}/defaultGraph.js"
    fi

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_default_workflow
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/ckpt" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/clip" \
        "${CLIP_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/esrgan" \
        "${ESRGAN_MODELS[@]}"


    provisioning_print_end
    echo 'grep trycloud /var/log/supervisor/quicktunnel-*' > "${WORKSPACE}/l"
    chmod +x  "${WORKSPACE}/l"
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
            "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
        else
            micromamba run -n comfyui pip install --no-cache-dir "$@"
        fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
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

function provisioning_get_default_workflow() {
    if [[ -n $DEFAULT_WORKFLOW ]]; then
        workflow_json=$(curl -s "$DEFAULT_WORKFLOW")
        if [[ -n $workflow_json ]]; then
            echo "export const defaultGraph = $workflow_json;" > /opt/ComfyUI/web/scripts/defaultGraph.js
            echo "export const defaultGraph = $workflow_json;" > "${workflows_dir}/defaultGraph.js"
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
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif 
        [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]];then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

provisioning_start


