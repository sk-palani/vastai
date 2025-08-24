#!/bin/bash

COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Constants
ONE_HUNDRED_MB=$((100 * 1024 * 1024))

# Function to calculate MD5 of last 1MB
calc_last_mb_md5() {
  local file=$1
  tail -c ${ONE_HUNDRED_MB} "$file" | md5sum | awk '{print $1}'
}

# Function to check and install axel
ensure_axel_installed() {
  if ! command -v axel &> /dev/null; then
    echo "axel not found. Attempting to install..."

    if command -v apt &> /dev/null; then
      sudo apt update && sudo apt install -y axel
    elif command -v dnf &> /dev/null; then
      sudo dnf install -y axel
    elif command -v brew &> /dev/null; then
      brew install axel
    else
      echo "Cannot install axel: no supported package manager found."
      exit 1
    fi
  fi
}

get_remote_filename() {
  local url=$1
  curl -sI "$url" | \
    awk -F'filename=' '/Content-Disposition/ {
      gsub(/"/, "", $2); print $2
    }'
}

# Ensure axel is installed
ensure_axel_installed


# Define items: url;filename;checksum

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors;ae.safetensors;18a7ef7436ed08700d85c408b6809538"
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
#    "https://civitai.com/api/download/models/1479339?type=Model&format=SafeTensor&size=full&fp=fp16&token=${CIVITAI_TOKEN}"
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
    "https://huggingface.co/comfyanonymous/flux_RealismLora_converted_comfyui/resolve/main/flux_realism_lora.safetensors?&token=${HF_TOKEN}"
    "https://civitai.com/api/download/models/1115050?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1188438?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1301668?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1633249?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1751485?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1875852?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1885663?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1885706?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1909850?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1956947?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1969712?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/706528?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/712589?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/735960?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/737992?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/824319?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/824514?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/825288?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/827325?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/857446?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/893799?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/910095?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/932482?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/936132?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/984672?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
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


function provisioning_start() {
    provisioning_get_models \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS[@]}"
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
        provisioning_check_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_check_download() {

  item="$1"
  DEST="$2"
  DOTBYTES="${3:-4M}"
  AUTH_HEADER=""
  IFS=';' read -r URL FILE checksum <<< "$item"

  # Ensure target directory exists
  mkdir -p "$DEST"
  filename="${DEST}/${FILE}"

  local need_download=true
  if [[ -f "${filename}" ]]; then
    echo "File [${filename}] exists. Verifying checksum..."
    LOCAL_MD5=$(calc_last_mb_md5 "${filename}")
    if [[ "${LOCAL_MD5}" == "${checksum}" ]]; then
      echo "File [${filename}] is up to date. No download needed."
      need_download=false
    else
      rm -rv "${filename}"
      echo "File [${filename}] differs. Re-downloading..."
    fi
  else
    echo "File [${filename}] does not exist. Downloading..."
  fi

  if [[ $need_download == true ]]; then
    if [[ $URL =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
       [[ -n $HF_TOKEN ]] && AUTH_HEADER="Authorization: Bearer $HF_TOKEN"
       wget ${AUTH_HEADER:+--header="$AUTH_HEADER"} -qnc --content-disposition --show-progress -e dotbytes="$DOTBYTES" -P "$DEST" "$URL"
    elif [[ $URL =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
      axel -a -n 8 -o "$filename" "${URL}"
    else
      axel -a -n 8 -o "$filename" "${URL}"
    fi
  fi

  if [[ $need_download == true ]]; then
      LOCAL_MD5=$(calc_last_mb_md5 "${filename}")
      echo "${filename};${FILE};${LOCAL_MD5}" >> output.txt
  fi


  remote_filename=$(get_remote_filename "${URL}")


  echo "----------"
  echo "Filename  : ${filename}      Remote    :${remote_filename}"
  echo "Checksum  : ${checksum}      LOCAL_MD5 : ${LOCAL_MD5}"
  echo "URL       : ${URL}"
  echo "----------"

  # Download using axel


#  curl -L -I -v  -O -J "$url"


}



#    "https://civitai.com/api/download/models/1301668?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/706528?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/712589?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/737992?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/824319?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/825288?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/893799?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/910095?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/932482?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"



#provisioning_start
TARGET_DIR="${1:-.}"  # Use current directory if none specified
# Constants
ONE_HUNDRED_MB=$((100 * 1024 * 1024))

# Function to calculate MD5 of last 1MB
calc_last_mb_md5() {
  local file=$1
  tail -c ${ONE_HUNDRED_MB} "$file" | md5sum | awk '{print $1}'
}
find "$TARGET_DIR" -type f | while read -r file; do
  echo "$(basename $file);$(calc_last_mb_md5 "$file" | awk '{print $1}')"
  echo "----------------------------------------"
done