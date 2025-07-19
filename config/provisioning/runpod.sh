#!/bin/bash

# This file will be sourced in init.sh

# https://github.com/MushroomFleet/Runpod-init
COMFYUI_DIR=${WORKSPACE}/ComfyUI

mkdir -p "${WORKSPACE}environments/python/"
cd "${WORKSPACE}environments/python/"
/usr/bin/python3 -m venv comfyui
COMFYUI_VENV_DIR=${WORKSPACE}environments/python/comfyui
mkdir -p "${COMFYUI_VENV_DIR}"
source "${COMFYUI_VENV_DIR}/bin/activate"

# Packages are installed after nodes so we can fix them...

DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/flux-comfyui-example.json"

mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/segm"
mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/bbox"

APT_PACKAGES=(
    "libmagickwand-dev"
    "axel"
    "screen"
    "tree"
)

PIP_PACKAGES=(
    "resynthesizer"
)

CHECKPOINT_MODELS=(
)

NODES=(
    "https://github.com/yorkane/ComfyUI-KYNode"
    "https://github.com/Acly/comfyui-tooling-nodes.git"
    "https://github.com/BadCafeCode/masquerade-nodes-comfyui.git"
    "https://github.com/BlenderNeko/ComfyUI_Noise.git"
    "https://github.com/BobsBlazed/Bobs_Latent_Optimizer.git"
    "https://github.com/Clybius/ComfyUI-Latent-Modifiers.git"
    "https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes.git"
    "https://github.com/EllangoK/ComfyUI-post-processing-nodes"
    "https://github.com/Fannovel16/ComfyUI-MagickWand.git"
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/Jonseed/ComfyUI-Detail-Daemon.git"
    "https://github.com/KoreTeknology/ComfyUI-Universal-Styler.git"
    "https://github.com/Layer-norm/comfyui-lama-remover"
    "https://github.com/SeargeDP/ComfyUI_Searge_LLM.git"
    "https://github.com/SeargeDP/SeargeSDXL.git"
    "https://github.com/Smirnov75/ComfyUI-mxToolkit.git"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"
    "https://github.com/Tenney95/ComfyUI-NodeAligner.git"
    "https://github.com/TinyTerra/ComfyUI_tinyterraNodes.git"
    "https://github.com/WASasquatch/was-node-suite-comfyui.git"
    "https://github.com/Xclbr7/ComfyUI-Merlin.git"
    "https://github.com/alexopus/ComfyUI-Image-Saver.git"
    "https://github.com/brayevalerien/ComfyUI-resynthesizer.git"
    "https://github.com/chflame163/ComfyUI_LayerStyle.git"
    "https://github.com/chrisgoringe/cg-image-picker.git"
    "https://github.com/chrisgoringe/cg-use-everywhere.git"
    "https://github.com/city96/ComfyUI-GGUF.git"
    "https://github.com/crystian/ComfyUI-Crystools.git"
    "https://github.com/cubiq/ComfyUI_essentials.git"
    "https://github.com/dagthomas/comfyui_dagthomas.git"
    "https://github.com/daxcay/ComfyUI-JDCN"
    "https://github.com/digitaljohn/comfyui-propost.git"
    "https://github.com/djbielejeski/a-person-mask-generator"
    "https://github.com/evanspearman/ComfyMath.git"
    "https://github.com/giriss/comfy-image-saver.git"
    "https://github.com/jags111/efficiency-nodes-comfyui"
    "https://github.com/jamesWalker55/comfyui-various.git"
    "https://github.com/jjkramhoeft/ComfyUI-Jjk-Nodes.git"
    "https://github.com/kijai/ComfyUI-Florence2.git"
    "https://github.com/kijai/ComfyUI-KJNodes.git"
    "https://github.com/kijai/ComfyUI-segment-anything-2.git"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/ltdrdata/ComfyUI-Impact-Subpack"
    "https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git"
    "https://github.com/melMass/comfy_mtb.git"
    "https://github.com/miaoshouai/ComfyUI-Miaoshouai-Tagger.git"
    "https://github.com/mirabarukaso/ComfyUI_Mira.git"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
    "https://github.com/rgthree/rgthree-comfy.git"
    "https://github.com/sipherxyz/comfyui-art-venture.git"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
    "https://github.com/thezveroboy/comfyui-random-image-loader"
    "https://github.com/un-seen/comfyui-tensorops.git"
    "https://github.com/yolain/ComfyUI-Easy-Use.git"
    "https://github.com/za-wa-n-go/ComfyUI_Zwng_Nodes"
    "https://github.com/LevelPixel/ComfyUI-LevelPixel"
    "https://github.com/shiimizu/ComfyUI-TiledDiffusion"
    "https://github.com/MieMieeeee/ComfyUI-CaptionThis"
    "https://github.com/kk8bit/kaytool"
)

#    "https://github.com/yolain/ComfyUI-Easy-Use.git"
#    "https://github.com/LevelPixel/ComfyUI-LevelPixel"

WORKFLOWS=(
    "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/flux_dev_example.json"
)

CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
    "https://huggingface.co/zer0int/CLIP-GmP-ViT-L-14/resolve/main/ViT-L-14-TEXT-detail-improved-hiT-GmP-TE-only-HF.safetensors"
    "https://civitai.com/api/download/models/2019009?type=Model&format=SafeTensor&size=pruned&fp=fp32&token=${CIVITAI_TOKEN}"
)

CLIPVISION_MODELS=(
    "https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors"
)

STYLE_MODELS=(
  "https://huggingface.co/black-forest-labs/FLUX.1-Redux-dev/resolve/main/flux1-redux-dev.safetensors"
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
#    "https://civitai.com/api/download/models/722620?type=Model&format=SafeTensor&size=pruned&fp=fp8&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1756326?type=Model&format=SafeTensor&size=pruned&fp=fp8&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1769925?type=Model&format=SafeTensor&size=pruned&fp=fp8&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1479339?type=Model&format=SafeTensor&size=full&fp=fp16&token=${CIVITAI_TOKEN}"
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
)

LORA_MODELS=(
    "https://huggingface.co/prithivMLmods/Canopus-LoRA-Flux-UltraRealism-2.0/resolve/main/Canopus-LoRA-Flux-UltraRealism.safetensors?&token=${HF_TOKEN}"
    "https://huggingface.co/XLabs-AI/flux-lora-collection/resolve/main/realism_lora_comfy_converted.safetensors?&token=${HF_TOKEN}"
    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-LoRA-AntiBlur/resolve/main/FLUX-dev-lora-AntiBlur.safetensors?&token=${HF_TOKEN}"
    "https://huggingface.co/neuroplus/skin-texture-style-v4d/resolve/main/skin%20texture%20style%20v4d.safetensors?&token=${HF_TOKEN}"
    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-LoRA-add-details/resolve/main/FLUX-dev-lora-add_details.safetensors?&token=${HF_TOKEN}"
    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-LoRA-add-details/resolve/main/FLUX-dev-lora-add_details.safetensors?&token=${HF_TOKEN}"
    "https://huggingface.co/XLabs-AI/flux-RealismLora/resolve/main/lora.safetensors?&token=${HF_TOKEN}"
    "https://huggingface.co/Fantasyworld/Skin_tone_slider_Flux1.d/resolve/main/Skin_Tone_Slider_flux_v1.safetensors?&token=${HF_TOKEN}"
    "https://civitai.com/api/download/models/1301668?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/706528?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/712589?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/737992?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/824319?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/825288?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/893799?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/910095?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/932482?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1751485?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/984672?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1115050?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1188438?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1875852?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/857446?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1633249?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1885706?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1885663?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/824514?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/936132?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/735960?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1909850?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1969712?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1956947?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/827325?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://huggingface.co/comfyanonymous/flux_RealismLora_converted_comfyui/resolve/main/flux_realism_lora.safetensors"
)


ESRGAN_MODELS=(
    "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth"
)


UPSCALE_MODELS=(
    "https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth"
    "https://huggingface.co/Akumetsu971/SD_Anime_Futuristic_Armor/resolve/main/4x_NMKD-Siax_200k.pth"
    "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Superscale-SP_178000_G.pth"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro/resolve/main/diffusion_pytorch_model.safetensors"
    "https://civitai.com/api/download/models/1307407?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
)


ULTRALYTICS_SEGS_MODELS=(
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8n_v2.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov9c.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
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

    if provisioning_has_valid_hf_token; then
        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors")
        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors")
    else
        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors")
        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors")
        sed -i 's/flux1-dev\.safetensors/flux1-schnell.safetensors/g' /opt/ComfyUI/web/scripts/defaultGraph.js
    fi

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
            pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
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

  URL="$1"
  DEST="$2"
  DOTBYTES="${3:-4M}"
  AUTH_HEADER=""

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
provisioning_get_nodes
provisioning_get_pip_packages
#provisioning_start

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /workspace/.noprovisioning ]]; then
    provisioning_start
    pip install -r "${WORKSPACE}/ComfyUI/requirements.txt"
fi

/opt/environments/python/comfyui/bin/python -m pip install -r /workspace/ComfyUI/requirements.txt
