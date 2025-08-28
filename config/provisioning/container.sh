#!/bin/bash

COMFYUI_DIR=${WORKSPACE}/ComfyUI
workflows_dir=${WORKSPACE}/ComfyUI/user/default/workflows

mkdir -p "${WORKSPACE}environments/python/comfyui"
cd "${WORKSPACE}environments/python/"
/usr/bin/python3 -m venv comfyui

COMFYUI_VENV_DIR=${WORKSPACE}environments/python/comfyui
mkdir -p "${COMFYUI_VENV_DIR}"
source "${COMFYUI_VENV_DIR}/bin/activate"

DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/flux-comfyui-example.json"

mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/segm"
mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/bbox"
mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/sams"

APT_PACKAGES=(
    "libmagickwand-dev"
    "axel"
    "screen"
    "tree"
)

PIP_PACKAGES=(
    "resynthesizer"
    "uvicorn==0.30.6"
    "fastapi==0.115.0"
    "torchsde==0.2.6"
)

CHECKPOINT_MODELS=(
)

NODES=(
    "https://github.com/yorkane/ComfyUI-KYNode"
)

#    "https://github.com/yolain/ComfyUI-Easy-Use.git"
#    "https://github.com/LevelPixel/ComfyUI-LevelPixel"

WORKFLOWS=(
    "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/flux_dev_example.json"
)

CLIP_MODELS=(

)

CLIPVISION_MODELS=(

)

STYLE_MODELS=(

)

LUTS=(
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20%20-%20Gold%20200.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20%20-%20Kodacrome%2064.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Agfa%20Optima.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Agfa%20Ultra%20100.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Cinematic.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Fuji%20Astia.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Hollywood.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Kodachrome.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Moody%20Aqua.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Moody%20Stock.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Polaroid%20Color.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Reversal.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Stylish.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Velvia%20100.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Vibe.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Emulation.cube"
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/Presetpro%20-%20Fuji%20Film.cube"
)

UNET_MODELS=(
)

VAE_MODELS=(
)

LORA_MODELS=(

)


ESRGAN_MODELS=(

)


UPSCALE_MODELS=(

)

CONTROLNET_MODELS=(

)


ULTRALYTICS_SEGS_MODELS=(

)

ULTRALYTICS_BBOX_MODELS=(

)

SAM_MODELS=(

)


### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    if provisioning_has_valid_hf_token; then
        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors")
        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors")
    else
        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors")
        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors")
        sed -i 's/flux1-dev\.safetensors/flux1-schnell.safetensors/g' /opt/ComfyUI/web/scripts/defaultGraph.js
    fi

    provisioning_print_header
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
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/clip" \
        "${CLIP_MODELS[@]}"
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
    provisioning_print_end
    echo 'grep trycloud /var/log/supervisor/quicktunnel-*' > "${WORKSPACE}/l"
    chmod +x  "${WORKSPACE}/l"
    provisioning_get_workflows
    provisioning_print_end
    touch /workspace/.noprovisioning
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
            "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
        else
            micromamba run -n comfyui pip install --no-cache-dir "$@"
        fi
}

function provisioning_get_apt_packages() {
    sudo apt-get update
    if [[ -n $APT_PACKAGES ]]; then
            sudo apt install -y  ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        source "${COMFYUI_VENV_DIR}/bin/activate"
        pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    source "${COMFYUI_VENV_DIR}/bin/activate"
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
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
    mkdir -p "${COMFYUI_DIR}/web/scripts"
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

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /workspace/.noprovisioning ]]; then
    provisioning_start
    pip install -r "${WORKSPACE}/ComfyUI/requirements.txt"
fi

${WORKSPACE}/environments/python/comfyui/bin/python -m pip install -r "${WORKSPACE}/ComfyUI/requirements.txt"
