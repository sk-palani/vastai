#!/bin/bash

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
items=(
  "https://civitai.com/api/download/models/1301668?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN};models/loras/aidmaRealisticSkin-FLUX-v0.1.safetensors;2ed123e3f004076ecd2a35ec847a8828"
  "https://civitai.com/api/download/models/857446?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN};models/loras/SameFace_Fix.safetensors;27a435104a39d7a0606439aab323a1ad"
  "https://civitai.com/api/download/models/706528?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN};models/loras/flux_realism_lora.safetensors;300d6ec19df568f13a747f5aeb6b3214"
  "https://civitai.com/api/download/models/737992?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN};models/loras/Add_More_details_Flux.safetensors;d82d5667a572c3f4dd89a79e0680039f"
  "https://civitai.com/api/download/models/824319?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN};models/loras/BreastShaper_splendid_droplets_Flux_v3.0-000009.safetensors;e5f7e5df98f5e8ded1d21e0109c5d305"
  "https://civitai.com/api/download/models/825288?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN};models/loras/zavy-fnrt-flx.safetensors;3bcc62c91b55beb6cd463793784d60aa"
  "https://civitai.com/api/download/models/893799?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN};models/loras/skin%20tone%20style%20v2-step00001500.safetensors;f1c0fbd070c9b3043bd19ae58f8f452d"
  "https://civitai.com/api/download/models/910095?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN};models/loras/zavy-drkcnmtc-flx-v2.safetensors;c26c6602931fefc3120315cb4fc77da4"
  "https://civitai.com/api/download/models/932482?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN};models/loras/breast-size2.safetensors;0408f8b989fc6fecafe4ef646f38c519"
  "https://huggingface.co/prithivMLmods/Canopus-LoRA-Flux-UltraRealism-2.0/resolve/main/Canopus-LoRA-Flux-UltraRealism.safetensors?token=${HF_TOKEN};Canopus-LoRA-Flux-UltraRealism.safetensors;has"

  "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors;models/unet/flux1-dev.safetensors;ed3246c590d00ae6f1bcf3f77b0e276e"
)

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors;ae.safetensors;18a7ef7436ed08700d85c408b6809538"
)

function provisioning_start() {
    provisioning_get_models \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
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

  if [[ -f "${filename}" ]]; then
    echo "File [${filename}] exists. Verifying checksum..."
    LOCAL_MD5=$(calc_last_mb_md5 "${filename}")
    if [[ "${LOCAL_MD5}" == "${checksum}" ]]; then
      echo "File [${filename}] is up to date. No download needed."
      continue
    else
      rm -rv "${filename}"
      echo "File [${filename}] differs. Re-downloading..."
    fi
  else
    echo "File [${filename}] does not exist. Downloading..."

#    curl -L -I -v  --create-dirs -O --output-dir "${dir}" -J "$url"
#    LOCAL_MD5=$(calc_last_mb_md5 "${filename}")

  fi


  remote_filename=$(get_remote_filename "${URL}")


  echo "----------"
  echo "Filename  : ${filename}      Remote    :${remote_filename}"
  echo "Checksum  : ${checksum}      LOCAL_MD5 : ${LOCAL_MD5}"
  echo "URL       : ${URL}"
  echo "----------"

  # Download using axel

  if [[ $URL =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
    AUTH_HEADER="Authorization: Bearer $HF_TOKEN"
    echo ${AUTH_HEADER}
    axel -n 8 -H "${AUTH_HEADER}" -o "$filename" "${URL}"
  elif [[ $URL =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
    axel -a -n 8 -o "$filename" "${URL}"
  else
    axel -a -n 8 -o "$filename" "${URL}"
  fi
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



provisioning_start