#!/usr/bin/env bash

# Sourced by the provider init script. Keep secrets in container environment variables.
# Environment variables:
#   HF_TOKEN                 Hugging Face token for gated/licensed repositories.
#   CIVITAI_TOKEN            Required for Civitai model downloads.
#   TAILSCALE_AUTHKEY        Optional; when set, auto-joins this container to your tailnet.
#   TS_HOSTNAME              Optional Tailscale device name.
#   MAX_PARALLEL_DOWNLOADS   Global model-download concurrency (default 2; try 3 if bandwidth allows).
#   HF_XET_HIGH_PERFORMANCE  Set to 1 only when you want hf-xet to use more system resources.
#   FORCE_PROVISIONING=1     Recheck/update nodes and refresh Civitai metadata/workflows.
#   FORCE_MODEL_DOWNLOADS=true  Force all model files to be downloaded again.
# https://github.com/MushroomFleet/Runpod-init
: "${WORKSPACE:?WORKSPACE must be set by the container provider}"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
workflows_dir="${COMFYUI_DIR}/user/default/workflows"
COMFYUI_VENV_DIR="${WORKSPACE}/environments/python/comfyui"
TOOLS_DIR="${WORKSPACE}/.tools"
TOOLS_BIN="${TOOLS_DIR}/bin"
HF_TOOL_VENV="${TOOLS_DIR}/hf-download-venv"
HF_BIN="${HF_TOOL_VENV}/bin/hf"
CIVITAI_BIN="${TOOLS_BIN}/civitai"

mkdir -p \
    "$workflows_dir" \
    "${COMFYUI_DIR}/Inputs/Downloaded/Parked" \
    "${COMFYUI_DIR}/Inputs/Next/Best" \
    "${COMFYUI_DIR}/Inputs/Next/Park" \
    "${COMFYUI_DIR}/Inputs/Processed" \
    "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/segm" \
    "${WORKSPACE}/storage/stable_diffusion/models/ultralytics/bbox" \
    "${WORKSPACE}/storage/stable_diffusion/models/sams" \
    "$TOOLS_BIN"

# Packages are installed after nodes so we can fix them...

DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/Workflow_API.json"
CRON_SCRIPT="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/submit_prompt.sh"

APT_PACKAGES=(
    "ca-certificates"
    "curl"
    "git"
    "jq"
    "python3.12"
    "python3.12-venv"
    "netcat-openbsd"
    "libmagickwand-dev"
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

PIP_PACKAGES=(
    "resynthesizer==1.2"
    "OpenEXR==3.4.4"
    "soundfile==0.13.1"
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
  "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev.safetensors"
  "https://civitai.com/api/download/models/2287992?fileId=2181185"

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
    "https://civitai.com/api/download/models/3349249?format=SafeTensor"

    # skin_detail_slider_krea2_ZT-V1.safetensors
    "https://civitai.com/api/download/models/3323867?format=SafeTensor"

    # inline-skin-lora-krea-2-raw.safetensors
    "https://huggingface.co/inlineresearch/skin-lora-krea-2-raw/resolve/main/inline-skin-lora-krea-2-raw.safetensors"

    # ------------------------------
    # Flux2.Klein
    # ------------------------------

    "https://civitai.com/api/download/models/2998669?format=SafeTensor"

    #Purple_Grainy_Kr2_AM.safetensors
    "https://civitai.com/api/download/models/3110766?format=SafeTensor"
    # Purple_Grainy_KR2_V2_D.safetensors
    "https://civitai.com/api/download/models/3328996?fileId=3215019"

    # ------------------------------
    # Flux1.Dev
    # ------------------------------
    # Pandora-RAWr.safetensors
    "https://civitai.com/api/download/models/1943855?format=SafeTensor"


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
  "https://civitai.com/api/download/models/1324778?format=PickleTensor"
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




### Provisioning and download helpers ###

MAX_PARALLEL_DOWNLOADS="${MAX_PARALLEL_DOWNLOADS:-2}"
HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-60}"
HF_HUB_ETAG_TIMEOUT="${HF_HUB_ETAG_TIMEOUT:-30}"
PORT_WAIT_TIMEOUT="${PORT_WAIT_TIMEOUT:-180}"
FORCE_MODEL_DOWNLOADS="${FORCE_MODEL_DOWNLOADS:-false}"
APT_PACKAGES_READY=0

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n# Model downloads use resumable clients      #\n#                                            #\n##############################################\n\n"
    if [[ -n "${DISK_GB_ALLOCATED:-}" && -n "${DISK_GB_REQUIRED:-}" ]] && \
       (( DISK_GB_ALLOCATED < DISK_GB_REQUIRED )); then
        echo "WARNING: allocated disk (${DISK_GB_ALLOCATED}GB) is below recommended ${DISK_GB_REQUIRED}GB."
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete: Web UI will start now\n\n"
}

function provisioning_get_apt_packages() {
    (( APT_PACKAGES_READY == 1 )) && return 0
    local package
    local -a missing=()
    for package in "${APT_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
            missing+=("$package")
        fi
    done
    if (( ${#missing[@]} == 0 )); then
        echo "Base OS packages are already installed; skipping apt update."
        APT_PACKAGES_READY=1
        return 0
    fi
    echo "Installing ${#missing[@]} missing OS package(s) in one apt transaction..."
    sudo apt-get update || return 1
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}" || return 1
    APT_PACKAGES_READY=1
}

function pip_install() {
    if [[ -n "${MAMBA_BASE:-}" ]]; then
        micromamba run -n comfyui pip install --no-cache-dir "$@"
    elif [[ -n "${COMFYUI_VENV_PIP:-}" && -x "${COMFYUI_VENV_PIP}" ]]; then
        "${COMFYUI_VENV_PIP}" install --no-cache-dir "$@"
    elif [[ -x "${COMFYUI_VENV_DIR}/bin/python" ]]; then
        "${COMFYUI_VENV_DIR}/bin/python" -m pip install --no-cache-dir "$@"
    else
        python3 -m pip install --no-cache-dir "$@"
    fi
}

function provisioning_get_pip_packages() {
    if (( ${#PIP_PACKAGES[@]} )); then
        echo "Installing pinned utility Python packages in one pip transaction..."
        pip_install "${PIP_PACKAGES[@]}"
    fi
}

function install_downloader_tools() {
    # Keep Hugging Face's downloader dependencies out of ComfyUI's Python env.
    if [[ ! -x "$HF_BIN" ]]; then
        echo "Creating isolated Hugging Face CLI environment..."
        mkdir -p "$TOOLS_DIR"
        /usr/bin/python3.12 -m venv "$HF_TOOL_VENV"
        PIP_DISABLE_PIP_VERSION_CHECK=1 "$HF_TOOL_VENV/bin/python" -m pip install --upgrade "huggingface_hub[hf_xet]"
    fi

    # Install the official Civitai CLI from its signed-by-checksum release bundle.
    if [[ ! -x "$CIVITAI_BIN" ]]; then
        local arch release_json asset_url archive_name checksums_url tmpdir
        case "$(uname -m)" in
            x86_64) arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
            *) echo "Unsupported architecture for the Civitai CLI: $(uname -m)" >&2; return 1 ;;
        esac
        echo "Installing official Civitai CLI..."
        release_json="$(curl -fsSL --retry 4 --retry-all-errors https://api.github.com/repos/civitai/cli/releases/latest)" || return 1
        asset_url="$(jq -r --arg suffix "_linux_${arch}.tar.gz" '.assets[] | select(.name | endswith($suffix)) | .browser_download_url' <<< "$release_json" | head -n 1)"
        checksums_url="$(jq -r '.assets[] | select(.name == "checksums.txt") | .browser_download_url' <<< "$release_json" | head -n 1)"
        [[ -n "$asset_url" && -n "$checksums_url" ]] || { echo "Could not locate the Civitai Linux archive/checksums in the latest release." >&2; return 1; }
        archive_name="${asset_url##*/}"
        tmpdir="$(mktemp -d)"
        if ! curl -fL --retry 4 --retry-all-errors "$asset_url" -o "$tmpdir/$archive_name" || \
           ! curl -fsSL --retry 4 --retry-all-errors "$checksums_url" -o "$tmpdir/checksums.txt"; then
            rm -rf "$tmpdir"
            return 1
        fi
        if ! (cd "$tmpdir" && grep -E "[[:space:]]\\*?${archive_name//./\\.}$" checksums.txt | sha256sum -c -); then
            echo "Civitai CLI checksum verification failed." >&2
            rm -rf "$tmpdir"
            return 1
        fi
        if ! tar -xzf "$tmpdir/$archive_name" -C "$tmpdir"; then
            rm -rf "$tmpdir"
            return 1
        fi
        local binary
        binary="$(find "$tmpdir" -type f -name civitai -print -quit)"
        if [[ -z "$binary" ]]; then
            echo "The Civitai CLI archive did not contain a civitai executable." >&2
            rm -rf "$tmpdir"
            return 1
        fi
        install -m 0755 "$binary" "$CIVITAI_BIN"
        rm -rf "$tmpdir"
    fi

    export HF_HUB_DOWNLOAD_TIMEOUT HF_HUB_ETAG_TIMEOUT
    export HF_HUB_DISABLE_UPDATE_CHECK=1
    export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-0}"
    export HF_HOME="${HF_HOME:-${WORKSPACE}/.cache/huggingface}"
    export CIVITAI_NO_UPDATE_CHECK=1
    export PATH="${TOOLS_BIN}:${HF_TOOL_VENV}/bin:${PATH}"
}

function setup_tailscale() {
    # Optional until TAILSCALE_AUTHKEY is configured in the provider's env.
    if [[ -z "${TAILSCALE_AUTHKEY:-}" ]]; then
        echo "Tailscale: skipped (set TAILSCALE_AUTHKEY in the container environment to enable auto-join)."
        return 0
    fi

    if ! command -v tailscale >/dev/null 2>&1 || ! command -v tailscaled >/dev/null 2>&1; then
        echo "Installing Tailscale package..."
        curl -fsSL https://tailscale.com/install.sh | sh || return 1
    fi

    local ts_dir="${WORKSPACE}/.tailscale"
    local ts_state="${ts_dir}/tailscaled.state"
    local ts_socket="/tmp/tailscaled.sock"
    local ts_log="/tmp/tailscaled.log"
    local i
    local previous_umask
    previous_umask="$(umask)"
    umask 077
    mkdir -p "$ts_dir"
    chmod 700 "$ts_dir"
    umask "$previous_umask"

    if ! tailscale --socket="$ts_socket" status >/dev/null 2>&1; then
        rm -f "$ts_socket"
        echo "Starting Tailscale userspace daemon..."
        nohup tailscaled --tun=userspace-networking --state="$ts_state" --socket="$ts_socket" \
            >"$ts_log" 2>&1 </dev/null &
        for i in $(seq 1 30); do
            if tailscale --socket="$ts_socket" status >/dev/null 2>&1; then break; fi
            sleep 1
        done
    fi

    if ! tailscale --socket="$ts_socket" status --json 2>/dev/null | jq -e '.BackendState == "Running"' >/dev/null; then
        echo "Joining Tailscale tailnet..."
        tailscale --socket="$ts_socket" up \
            --auth-key="$TAILSCALE_AUTHKEY" \
            --hostname="${TS_HOSTNAME:-comfyui-${HOSTNAME:0:12}}" \
            --ssh || return 1
    else
        tailscale --socket="$ts_socket" set --ssh || return 1
    fi

    echo "Tailscale connected:"
    tailscale --socket="$ts_socket" status
    tailscale --socket="$ts_socket" ip -4 || true
}

function provisioning_download_huggingface() {
    local url="$1" dest="$2" rest repo_type="model" owner repo revision file_path target source local_dir
    rest="${url#https://huggingface.co/}"
    if [[ "$rest" == datasets/* ]]; then
        repo_type="dataset"
        rest="${rest#datasets/}"
    fi
    owner="${rest%%/*}"; rest="${rest#*/}"
    repo="${rest%%/*}"; rest="${rest#*/}"
    [[ "$rest" == resolve/* ]] || { echo "Unsupported Hugging Face URL form: $url" >&2; return 1; }
    rest="${rest#resolve/}"
    revision="${rest%%/*}"
    file_path="${rest#*/}"
    [[ -n "$owner" && -n "$repo" && -n "$revision" && -n "$file_path" ]] || { echo "Could not parse Hugging Face URL: $url" >&2; return 1; }

    mkdir -p "$dest"
    target="$dest/${file_path##*/}"
    if [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$target" ]]; then
        echo "Already present: $target"
        return 0
    fi

    # Keep each repository outside ComfyUI's model tree. A local-dir download
    # preserves subdirectories; placing that tree directly in models/ can make
    # ComfyUI discover the same weight twice. Expose only a flat symlink below.
    local_dir="${WORKSPACE}/.cache/huggingface/local/${repo_type}/${owner}/${repo}/${revision}"
    source="$local_dir/$file_path"
    mkdir -p "$local_dir"

    if [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$source" ]]; then
        echo "Reusing cached Hugging Face file: $source"
    else
        echo "Hugging Face: ${owner}/${repo}/${file_path} -> ${target}"
        export HF_TOKEN
        local -a hf_args=(download "${owner}/${repo}" "$file_path" --repo-type "$repo_type" --revision "$revision" --local-dir "$local_dir")
        [[ "${FORCE_MODEL_DOWNLOADS,,}" == "true" ]] && hf_args+=(--force-download)
        if ! "$HF_BIN" "${hf_args[@]}"; then
            echo "Hugging Face download failed: $url (check HF_TOKEN and repository access)." >&2
            return 1
        fi
    fi

    if [[ ! -s "$source" ]]; then
        echo "Hugging Face CLI reported success but the file is missing: $source" >&2
        return 1
    fi
    ln -sfn "$source" "$target"
}

function provisioning_download_civitai() {
    local url="$1" dest="$2" version_id query file_id="" format="" metadata filename target metadata_path metadata_dir
    version_id="$(sed -nE 's#^https://civitai\.com/api/download/models/([0-9]+)(\?.*)?$#\1#p' <<< "$url")"
    [[ -n "$version_id" ]] || { echo "Could not parse Civitai model-version ID from URL: ${url%%\?*}" >&2; return 1; }
    query="${url#*\?}"
    if [[ "$query" == "$url" ]]; then query=""; fi
    file_id="$(sed -nE 's#(^|.*&)fileId=([0-9]+).*#\2#p' <<< "$query")"
    if [[ "$query" == *"format=PickleTensor"* ]]; then format="pickletensor"; fi
    if [[ "$query" == *"format=SafeTensor"* || "$query" == *"format=safetensors"* ]]; then format="safetensor"; fi

    # Version metadata is stable and public. Cache it in persistent workspace so
    # ordinary container restarts don't make another API call per Civitai asset.
    metadata_dir="${WORKSPACE}/.cache/civitai"
    metadata_path="${metadata_dir}/version-${version_id}.json"
    mkdir -p "$metadata_dir"
    if [[ ! -s "$metadata_path" || "${FORCE_PROVISIONING:-0}" == "1" || "${FORCE_MODEL_DOWNLOADS,,}" == "true" ]]; then
        export CIVITAI_TOKEN CIVITAI_NO_UPDATE_CHECK
        metadata="$("$CIVITAI_BIN" model-versions get "$version_id" --json)" || {
            echo "Could not query Civitai version ${version_id}." >&2; return 1;
        }
        if ! jq -e '.files | type == "array"' <<< "$metadata" >/dev/null; then
            echo "Civitai returned invalid file metadata for version ${version_id}." >&2
            return 1
        fi
        printf '%s\n' "$metadata" > "${metadata_path}.part" && mv -f "${metadata_path}.part" "$metadata_path" || return 1
    else
        metadata="$(cat "$metadata_path")" || return 1
    fi
    if [[ -z "$file_id" && -n "$format" ]]; then
        file_id="$(jq -r --arg fmt "$format" '([.files[] | select(.primary == true and ((.format // "" | ascii_downcase) == $fmt))][0] // [.files[] | select((.format // "" | ascii_downcase) == $fmt)][0] // {}).id // empty' <<< "$metadata")"
    fi
    if [[ -z "$file_id" ]]; then
        file_id="$(jq -r '([.files[] | select(.primary == true)][0] // .files[0] // {}).id // empty' <<< "$metadata")"
    fi
    filename="$(jq -r --arg id "$file_id" '[.files[] | select((.id | tostring) == $id)][0].name // empty' <<< "$metadata")"
    if [[ -z "$file_id" || -z "$filename" || "$filename" == "null" ]]; then
        echo "Could not resolve the selected Civitai file for version ${version_id}." >&2
        return 1
    fi

    mkdir -p "$dest"
    target="$dest/$filename"
    if [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$target" ]]; then
        echo "Already present: $target"
        return 0
    fi

    if [[ -z "${CIVITAI_TOKEN:-}" ]]; then
        echo "Civitai downloads require CIVITAI_TOKEN; set it in the container environment to download: ${filename}" >&2
        return 1
    fi
    export CIVITAI_TOKEN CIVITAI_NO_UPDATE_CHECK
    echo "Civitai: version ${version_id}, file ${file_id} -> ${target}"
    local -a args=(download "$version_id" --file "$file_id" --out-dir "$dest")
    [[ "${FORCE_MODEL_DOWNLOADS,,}" == "true" ]] && args+=(--force)
    "$CIVITAI_BIN" "${args[@]}"
}

function provisioning_download() {
    local url="$1" dest="$2" name target part
    mkdir -p "$dest"
    case "$url" in
        https://huggingface.co/*)
            provisioning_download_huggingface "$url" "$dest"
            return $? ;;
        https://civitai.com/api/download/models/*|https://civitai.red/api/download/models/*)
            url="${url/civitai.red/civitai.com}"
            provisioning_download_civitai "$url" "$dest"
            return $? ;;
    esac

    name="$(python3.12 -c 'from urllib.parse import urlsplit, unquote; import sys; print(unquote(urlsplit(sys.argv[1]).path.rsplit("/", 1)[-1]))' "$url")" || return 1
    [[ -n "$name" ]] || { echo "Could not determine download filename: $url" >&2; return 1; }
    target="$dest/$name"
    part="$target.part"
    if [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$target" ]]; then
        echo "Already present: $target"
        return 0
    fi
    echo "Downloading: $name"
    if ! curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 30 \
        --continue-at - --output "$part" "$url"; then
        echo "Download failed: $url (partial file retained for resume)." >&2
        return 1
    fi
    [[ -s "$part" ]] || { echo "Downloaded file is empty: $url" >&2; return 1; }
    mv -f "$part" "$target"
}

# Build one global queue so large files in different model folders can download
# concurrently. The previous per-folder loop serialized the largest model groups.
MODEL_JOB_URLS=()
MODEL_JOB_DESTS=()
function queue_model_urls() {
    local dest="$1" url key
    shift
    local -A seen=()
    # Deduplicate URLs per destination, not globally: the same model can
    # intentionally be installed into more than one ComfyUI folder.
    for url in "$@"; do
        [[ -n "$url" ]] || continue
        key="${dest}"$'\t'"${url}"
        if [[ -n "${seen[$key]+yes}" ]]; then continue; fi
        seen["$key"]=1
        MODEL_JOB_DESTS+=("$dest")
        MODEL_JOB_URLS+=("$url")
    done
}

function provisioning_get_model_assets() {
    local failed=0 max="${MAX_PARALLEL_DOWNLOADS:-2}" pid i
    [[ "$max" =~ ^[1-9][0-9]*$ ]] || max=2
    MODEL_JOB_URLS=()
    MODEL_JOB_DESTS=()

    queue_model_urls "${WORKSPACE}/ComfyUI/models/ckpt" "${CHECKPOINT_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/loras" "${LORA_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/luts" "${LUTS[@]}"
    queue_model_urls "${COMFYUI_DIR}/custom_nodes/comfyui_essentials/fonts/" "${FONTS[@]}"
    queue_model_urls "${COMFYUI_DIR}/custom_nodes/comfyui_custom_scripts/web/js/assets/" "${MP3[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/text_encoders" "${TEXT_ENCODER_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/clip_vision" "${CLIPVISION_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/style_models" "${STYLE_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/esrgan" "${ESRGAN_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/upscale_models" "${UPSCALE_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/sams" "${SAM_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/ultralytics/segm" "${ULTRALYTICS_SEGS_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/ultralytics/bbox" "${ULTRALYTICS_BBOX_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/unet" "${UNET_MODELS[@]}"
    queue_model_urls "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}"

    echo "Preparing ${#MODEL_JOB_URLS[@]} unique asset/destination jobs (global parallelism: ${max})."
    local -a pids=()
    for i in "${!MODEL_JOB_URLS[@]}"; do
        while (( ${#pids[@]} >= max )); do
            pid="${pids[0]}"
            wait "$pid" || failed=1
            pids=("${pids[@]:1}")
        done
        ( provisioning_download "${MODEL_JOB_URLS[$i]}" "${MODEL_JOB_DESTS[$i]}" ) &
        pids+=("$!")
    done
    for pid in "${pids[@]}"; do wait "$pid" || failed=1; done
    return "$failed"
}

function provisioning_get_nodes() {
    source "${COMFYUI_VENV_DIR}/bin/activate"
    local repo dir path requirements failed=0
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"; dir="${dir,,}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d "$path" ]]; then
            if [[ "${AUTO_UPDATE,,}" != "false" ]]; then
                printf "Updating node: %s...\\n" "$repo"
                git -C "$path" pull --ff-only || { echo "Warning: could not update $repo" >&2; failed=1; }
            fi
        else
            printf "Cloning node: %s...\\n" "$repo"
            git clone --recursive "$repo" "$path" || { echo "Failed cloning $repo" >&2; failed=1; continue; }
        fi
        if [[ -f "$requirements" ]]; then
            pip_install -r "$requirements" || { echo "Failed installing requirements for $repo" >&2; failed=1; }
        fi
    done
    return "$failed"
}

function provisioning_get_workflows() {
    local url filename target part failed=0
    mkdir -p "$workflows_dir"
    for url in "${WORKFLOWS[@]}"; do
        filename="$(python3.12 -c 'from urllib.parse import urlsplit, unquote; import sys; print(unquote(urlsplit(sys.argv[1]).path.rsplit("/", 1)[-1]))' "$url")"
        target="$workflows_dir/$filename"; part="$target.part"
        if [[ "${FORCE_PROVISIONING:-0}" != "1" && -s "$target" ]]; then
            echo "Workflow already present: $target"; continue
        fi
        echo "Downloading workflow: $filename"
        if curl -fL --retry 4 --retry-all-errors --retry-delay 2 --continue-at - -o "$part" "$url" && jq -e . "$part" >/dev/null; then
            mv -f "$part" "$target"
        else
            echo "Failed to download/validate workflow: $url" >&2
            failed=1
        fi
    done
    return "$failed"
}

function provisioning_get_default_workflow() {
    local script_path="${WORKSPACE}/scripts/submit_prompt.sh"
    local downloaded_workflow="${WORKSPACE}/scripts/Workflow_API.json"
    local graph_source graph_json target
    mkdir -p "${WORKSPACE}/scripts" "$workflows_dir" "${COMFYUI_DIR}/web/scripts" /opt/ComfyUI/web/scripts

    if [[ "${FORCE_PROVISIONING:-0}" == "1" || ! -s "$script_path" ]]; then
        curl -fL --retry 4 --retry-all-errors --retry-delay 2 "$CRON_SCRIPT" -o "$script_path" || return 1
    fi
    chmod +x "$script_path"

    if [[ "${FORCE_PROVISIONING:-0}" == "1" || ! -s "$downloaded_workflow" ]]; then
        curl -fL --retry 4 --retry-all-errors --retry-delay 2 "$DEFAULT_WORKFLOW" -o "$downloaded_workflow.part" || return 1
        jq -e . "$downloaded_workflow.part" >/dev/null || { rm -f "$downloaded_workflow.part"; echo "Default workflow is not valid JSON." >&2; return 1; }
        mv -f "$downloaded_workflow.part" "$downloaded_workflow"
    fi

    graph_source="$downloaded_workflow"
    [[ -s "${workflows_dir}/latest.json" ]] && graph_source="${workflows_dir}/latest.json"
    graph_json="$(jq -c . "$graph_source")" || return 1
    for target in /opt/ComfyUI/web/scripts/defaultGraph.js "${COMFYUI_DIR}/web/scripts/defaultGraph.js" "${workflows_dir}/defaultGraph.js"; do
        printf 'export const defaultGraph = %s;\n' "$graph_json" > "$target"
    done
}

function provisioning_start() {
    local failed=0
    if [[ ! -d /opt/environments/python ]]; then export MAMBA_BASE=true; fi
    source /opt/ai-dock/etc/environment.sh || return 1
    source /opt/ai-dock/bin/venv-set.sh comfyui || return 1
    provisioning_print_header
    provisioning_get_apt_packages || return 1
    provisioning_get_pip_packages || return 1
    provisioning_get_nodes || failed=1
    provisioning_get_model_assets || failed=1

    if (( failed != 0 )); then
        echo "Provisioning had failures. The .noprovisioning marker was NOT written; fix errors and restart." >&2
        return 1
    fi

    provisioning_get_workflows || return 1
    # Install ComfyUI requirements only once per successful provision (not twice per startup).
    pip_install -r "${COMFYUI_DIR}/requirements.txt" || return 1
    touch "${WORKSPACE}/.noprovisioning"
    provisioning_print_end
}

function wait_for_port() {
    local port="$1" deadline=$((SECONDS + PORT_WAIT_TIMEOUT))
    while ! nc -z -w 2 127.0.0.1 "$port"; do
        if (( SECONDS >= deadline )); then
            echo "Timed out waiting for localhost:${port}; related proxy will be skipped." >&2
            return 1
        fi
        sleep 1
    done
}

function start_socat_proxy() {
    local listen_port="$1" target_port="$2"
    if pgrep -f "[s]ocat TCP-LISTEN:${listen_port}," >/dev/null 2>&1; then
        echo "socat proxy ${listen_port} already running."
        return 0
    fi
    nohup socat "TCP-LISTEN:${listen_port},fork,reuseaddr" "TCP:127.0.0.1:${target_port}" \
        >>"/tmp/socat-${listen_port}.log" 2>&1 </dev/null &
}

### Execute setup ###

provisioning_get_apt_packages || { echo "Base package installation failed." >&2; exit 1; }

# Load provider-defined credentials and connect Tailscale as early as practical,
# before the downloader tool installs or any large model transfers.
if [[ -f /opt/ai-dock/etc/environment.sh ]]; then
    source /opt/ai-dock/etc/environment.sh || true
fi
setup_tailscale || { echo "Tailscale startup/authentication failed. See /tmp/tailscaled.log." >&2; exit 1; }

# Reuse the workspace venv if it already exists; rebuilding it on every start is unnecessary.
mkdir -p "${WORKSPACE}/environments/python"
if [[ ! -x "${COMFYUI_VENV_DIR}/bin/python" ]]; then
    /usr/bin/python3.12 -m venv "$COMFYUI_VENV_DIR" || { echo "Could not create ComfyUI venv." >&2; exit 1; }
fi

install_downloader_tools || { echo "Downloader tool installation failed." >&2; exit 1; }

# .noprovisioning is kept for compatibility with the original init design.
# Set FORCE_PROVISIONING=1 to recheck nodes/models/workflows on a future start.
if [[ ! -f "${WORKSPACE}/.noprovisioning" || "${FORCE_PROVISIONING:-0}" == "1" ]]; then
    provisioning_start || { echo "Provisioning failed; ComfyUI requirements may be incomplete." >&2; exit 1; }
else
    echo "Provisioning marker exists; checking for any missing model/workflow assets only."
    source /opt/ai-dock/etc/environment.sh || true
    provisioning_get_model_assets || { echo "One or more model assets are still missing; fix the errors and restart." >&2; exit 1; }
    provisioning_get_workflows || { echo "Workflow download failed." >&2; exit 1; }
fi

provisioning_get_default_workflow || echo "Warning: default workflow setup failed." >&2

# Install/update the submit-prompt cron job without a second pip requirements install.
if [[ -s "${WORKSPACE}/scripts/submit_prompt.sh" ]]; then
    chmod +x "${WORKSPACE}/scripts/submit_prompt.sh"
    cron_tmp="$(mktemp)"
    printf 'WORKSPACE=%s\n* * * * * %s/scripts/submit_prompt.sh >> %s/crontab.log 2>&1\n' \
        "$WORKSPACE" "$WORKSPACE" "$WORKSPACE" > "$cron_tmp"
    crontab "$cron_tmp"
    rm -f "$cron_tmp"
    sudo service cron start || service cron start || true
fi

# These services are provider-specific; tolerate absent supervisor groups.
for service_name in \
    'cf_quicktunnel:="cf_quicktunnel_0"' \
    'cf_quicktunnel:="cf_quicktunnel_1"' \
    'cf_quicktunnel:="cf_quicktunnel_2"' \
    'cf_quicktunnel:="cf_quicktunnel_3"' \
    'jupyter'; do
    sudo supervisorctl stop "$service_name" >/dev/null 2>&1 || true
done

# Keep existing provider port mappings, but avoid hanging forever if a service never appears.
start_socat_proxy 18000 1111
if wait_for_port 18188; then
    start_socat_proxy 19000 18188
    start_socat_proxy 8188 18188
fi
if wait_for_port 18384; then
    start_socat_proxy 20000 18384
fi
