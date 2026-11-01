#!/usr/bin/env bash
# Standalone ComfyUI model/assets downloader.
# Separate from provisioning: it does NOT install custom nodes, modify Python,
# change Torch/xFormers, restart ComfyUI, or write the provider provisioning marker.
#
# Required environment (only for gated/private downloads):
#   HF_TOKEN            Hugging Face access token, if required by a repository.
#   CIVITAI_TOKEN       Civitai API token (required for the Civitai model URLs below).
# Optional environment:
#   WORKSPACE           Default: /opt
#   COMFYUI_DIR         Default: /opt/ComfyUI
#   MAX_PARALLEL_DOWNLOADS  Default: 2
#   FORCE_MODEL_DOWNLOADS   Default: false; set true or pass --force to redownload.
#   HF_HOME             Default: $WORKSPACE/.cache/huggingface
#   HF_BIN              Existing hf CLI path (optional).
#   CIVITAI_BIN         Existing Civitai CLI path (optional).
#   MODEL_DOWNLOAD_ONLY Comma-separated categories to download; default all.
#
# Usage:
#   bash comfyui-model-downloader.sh             # all model/assets
#   bash comfyui-model-downloader.sh --list      # show categories/counts
#   bash comfyui-model-downloader.sh --only loras,text_encoders
#   bash comfyui-model-downloader.sh --force     # redownload all selected assets
#
# Safe to rerun. Existing non-empty files are skipped by default. Failed partial
# downloads are retained as .part and resumed on the next run where supported.

set -Eeuo pipefail

BUILD_ID="2026-11-01-model-downloader-r2"
# BASH_SOURCE[0] is unset when this script is streamed to `bash -s` (curl | bash).
# Use a safe stdin label in that mode instead of failing under `set -u`.
SCRIPT_PATH="${BASH_SOURCE[0]:-<stdin>}"
WORKSPACE="${WORKSPACE:-/opt}"
COMFYUI_DIR="${COMFYUI_DIR:-/opt/ComfyUI}"
TOOLS_DIR="${TOOLS_DIR:-${WORKSPACE}/.tools}"
TOOLS_BIN="${TOOLS_BIN:-${TOOLS_DIR}/bin}"
HF_TOOL_VENV="${HF_TOOL_VENV:-${TOOLS_DIR}/hf-download-venv}"
HF_BIN="${HF_BIN:-${HF_TOOL_VENV}/bin/hf}"
CIVITAI_BIN="${CIVITAI_BIN:-${TOOLS_BIN}/civitai}"
HF_HOME="${HF_HOME:-${WORKSPACE}/.cache/huggingface}"
CIVITAI_NO_UPDATE_CHECK=1
HF_HUB_DISABLE_UPDATE_CHECK=1
HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-60}"
HF_HUB_ETAG_TIMEOUT="${HF_HUB_ETAG_TIMEOUT:-30}"
HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-0}"
MAX_PARALLEL_DOWNLOADS="${MAX_PARALLEL_DOWNLOADS:-2}"
FORCE_MODEL_DOWNLOADS="${FORCE_MODEL_DOWNLOADS:-false}"
MODEL_DOWNLOAD_ONLY="${MODEL_DOWNLOAD_ONLY:-all}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
STATUS_DIR="${WORKSPACE}/.provisioning/model-downloads/${RUN_ID}"
LOG_FILE="${WORKSPACE}/model-downloads.log"

export HF_HOME CIVITAI_NO_UPDATE_CHECK HF_HUB_DISABLE_UPDATE_CHECK
export HF_HUB_DOWNLOAD_TIMEOUT HF_HUB_ETAG_TIMEOUT HF_XET_HIGH_PERFORMANCE

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
die() { echo "FATAL: $*" >&2; exit 1; }

echo "MODEL_DOWNLOADER_BUILD_ID=${BUILD_ID}"
echo "MODEL_DOWNLOADER_SCRIPT=${SCRIPT_PATH}"
if command -v md5sum >/dev/null 2>&1; then
    if [[ -f "$SCRIPT_PATH" ]]; then
        md5sum -- "$SCRIPT_PATH"
    else
        echo "MODEL_DOWNLOADER_MD5=unavailable (script is being read from stdin)"
    fi
fi

usage() {
    cat <<'USAGE'
Standalone ComfyUI model/assets downloader

Options:
  --list                 List categories and asset counts.
  --only CATEGORIES      Comma-separated categories, e.g. loras,text_encoders.
  --force                Redownload selected files even if they already exist.
  --help                 Show this help.

Categories:
  clip, text_encoders, clip_vision, style_models, luts, fonts, audio,
  unet, diffusion_models, vae, loras, upscalers, controlnet,
  ultralytics_segm, ultralytics_bbox, sam

Environment:
  WORKSPACE=/opt COMFYUI_DIR=/opt/ComfyUI
  HF_TOKEN=... CIVITAI_TOKEN=...
  MAX_PARALLEL_DOWNLOADS=2 FORCE_MODEL_DOWNLOADS=true
USAGE
}

LIST_ONLY=0
while (($#)); do
    case "$1" in
        --list) LIST_ONLY=1 ;;
        --force) FORCE_MODEL_DOWNLOADS=true ;;
        --only)
            (($# >= 2)) || die "--only requires a comma-separated category list"
            MODEL_DOWNLOAD_ONLY="$2"; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown argument: $1 (use --help)" ;;
    esac
    shift
done

[[ "$MAX_PARALLEL_DOWNLOADS" =~ ^[1-9][0-9]*$ ]] || die "MAX_PARALLEL_DOWNLOADS must be a positive integer"

# ---- Model manifest: copied from the main provisioning model asset lists. ----
# Format is category|destination|URL. Paths are relative to COMFYUI_DIR.
MODEL_CATEGORIES=(
  clip text_encoders clip_vision style_models luts fonts audio unet
  diffusion_models vae loras upscalers controlnet ultralytics_segm
  ultralytics_bbox sam
)

CHECKPOINT_MODELS=()
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
  "https://civitai.com/api/download/models/3349249?format=SafeTensor"
  "https://civitai.com/api/download/models/3323867?format=SafeTensor"
  "https://huggingface.co/inlineresearch/skin-lora-krea-2-raw/resolve/main/inline-skin-lora-krea-2-raw.safetensors"
  "https://civitai.com/api/download/models/2998669?format=SafeTensor"
  "https://civitai.com/api/download/models/3110766?format=SafeTensor"
  "https://civitai.com/api/download/models/3328996?fileId=3215019"
  "https://civitai.com/api/download/models/1943855?format=SafeTensor"
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

# ---- Category selection and manifest ----
selected_category() {
    local cat="$1" item
    [[ "$MODEL_DOWNLOAD_ONLY" == "all" ]] && return 0
    IFS=',' read -ra requested <<< "$MODEL_DOWNLOAD_ONLY"
    for item in "${requested[@]}"; do
        item="${item//[[:space:]]/}"
        [[ "${item,,}" == "$cat" ]] && return 0
    done
    return 1
}

declare -a JOB_CATEGORIES=() JOB_URLS=() JOB_DESTS=()
declare -A JOB_SEEN=()
queue_urls() {
    local category="$1" dest="$2" url key
    shift 2
    selected_category "$category" || return 0
    for url in "$@"; do
        [[ -n "$url" ]] || continue
        key="${dest}|${url}"
        [[ -n "${JOB_SEEN[$key]+yes}" ]] && continue
        JOB_SEEN[$key]=1
        JOB_CATEGORIES+=("$category")
        JOB_URLS+=("$url")
        JOB_DESTS+=("$dest")
    done
}

queue_urls clip "${COMFYUI_DIR}/models/clip" "${CLIP_MODELS[@]}"
queue_urls text_encoders "${COMFYUI_DIR}/models/text_encoders" "${TEXT_ENCODER_MODELS[@]}"
queue_urls clip_vision "${COMFYUI_DIR}/models/clip_vision" "${CLIPVISION_MODELS[@]}"
queue_urls style_models "${COMFYUI_DIR}/models/style_models" "${STYLE_MODELS[@]}"
queue_urls luts "${COMFYUI_DIR}/models/luts" "${LUTS[@]}"
queue_urls fonts "${COMFYUI_DIR}/custom_nodes/comfyui_essentials/fonts" "${FONTS[@]}"
queue_urls audio "${COMFYUI_DIR}/custom_nodes/comfyui_custom_scripts/web/js/assets" "${MP3[@]}"
queue_urls unet "${COMFYUI_DIR}/models/unet" "${UNET_MODELS[@]}"
queue_urls diffusion_models "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}"
queue_urls vae "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
queue_urls loras "${COMFYUI_DIR}/models/loras" "${LORA_MODELS[@]}"
queue_urls upscalers "${COMFYUI_DIR}/models/upscale_models" "${UPSCALE_MODELS[@]}"
queue_urls controlnet "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}"
queue_urls ultralytics_segm "${COMFYUI_DIR}/models/ultralytics/segm" "${ULTRALYTICS_SEGS_MODELS[@]}"
queue_urls ultralytics_bbox "${COMFYUI_DIR}/models/ultralytics/bbox" "${ULTRALYTICS_BBOX_MODELS[@]}"
queue_urls sam "${COMFYUI_DIR}/models/sams" "${SAM_MODELS[@]}"

if (( LIST_ONLY )); then
    printf 'Build: %s\nComfyUI: %s\n' "$BUILD_ID" "$COMFYUI_DIR"
    for cat in "${MODEL_CATEGORIES[@]}"; do
        count=0
        for idx in "${!JOB_CATEGORIES[@]}"; do [[ "${JOB_CATEGORIES[$idx]}" == "$cat" ]] && ((count+=1)); done
        printf '%-20s %d\n' "$cat" "$count"
    done
    printf '%-20s %d\n' TOTAL "${#JOB_URLS[@]}"
    exit 0
fi

[[ -d "$COMFYUI_DIR" ]] || die "ComfyUI directory not found: $COMFYUI_DIR (set COMFYUI_DIR correctly)"
mkdir -p "$WORKSPACE" "$STATUS_DIR" "$TOOLS_DIR" "$TOOLS_BIN" "${WORKSPACE}/.cache/civitai"
for cmd in curl jq tar sha256sum grep sed awk find install; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done
SYSTEM_PYTHON="${SYSTEM_PYTHON:-$(command -v python3 || true)}"
[[ -n "$SYSTEM_PYTHON" && -x "$SYSTEM_PYTHON" ]] || die "python3 is required to install/use the isolated Hugging Face CLI"
(( ${#JOB_URLS[@]} > 0 )) || die "No model assets selected. Check MODEL_DOWNLOAD_ONLY."

# ---- Downloader tools kept outside ComfyUI's Python environment ----
HF_READY=0
CIVITAI_READY=0

install_hf_cli() {
    if [[ -x "$HF_BIN" ]]; then HF_READY=1; return 0; fi
    if command -v hf >/dev/null 2>&1; then HF_BIN="$(command -v hf)"; HF_READY=1; return 0; fi
    log "Installing Hugging Face CLI in isolated environment: $HF_TOOL_VENV"
    mkdir -p "$(dirname "$HF_TOOL_VENV")"
    if ! "$SYSTEM_PYTHON" -m venv "$HF_TOOL_VENV"; then
        echo "Could not create downloader venv. Install python3-venv or set HF_BIN." >&2
        return 1
    fi
    if ! PIP_DISABLE_PIP_VERSION_CHECK=1 "$HF_TOOL_VENV/bin/python" -m pip install --upgrade "huggingface_hub[hf_xet]"; then
        echo "Could not install Hugging Face CLI; Hugging Face model jobs will fail, other downloads will continue." >&2
        return 1
    fi
    [[ -x "$HF_BIN" ]] || { echo "hf CLI missing after installation: $HF_BIN" >&2; return 1; }
    HF_READY=1
}

install_civitai_cli() {
    if [[ -x "$CIVITAI_BIN" ]]; then CIVITAI_READY=1; return 0; fi
    if command -v civitai >/dev/null 2>&1; then CIVITAI_BIN="$(command -v civitai)"; CIVITAI_READY=1; return 0; fi
    local arch release_json asset_url archive_name checksums_url tmpdir binary
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) echo "Unsupported architecture for Civitai CLI: $(uname -m)" >&2; return 1 ;;
    esac
    log "Installing official Civitai CLI in $TOOLS_BIN"
    release_json="$(curl -fsSL --retry 4 --retry-all-errors https://api.github.com/repos/civitai/cli/releases/latest)" || return 1
    asset_url="$(jq -r --arg suffix "_linux_${arch}.tar.gz" '.assets[] | select(.name | endswith($suffix)) | .browser_download_url' <<< "$release_json" | head -n 1)"
    checksums_url="$(jq -r '.assets[] | select(.name == "checksums.txt") | .browser_download_url' <<< "$release_json" | head -n 1)"
    [[ -n "$asset_url" && -n "$checksums_url" ]] || { echo "Could not locate Civitai CLI release archive/checksums." >&2; return 1; }
    archive_name="${asset_url##*/}"
    tmpdir="$(mktemp -d)"
    if ! curl -fL --retry 4 --retry-all-errors "$asset_url" -o "$tmpdir/$archive_name" || \
       ! curl -fsSL --retry 4 --retry-all-errors "$checksums_url" -o "$tmpdir/checksums.txt"; then
        rm -rf "$tmpdir"; return 1
    fi
    if ! (cd "$tmpdir" && grep -E "[[:space:]]\\*?${archive_name//./\\.}$" checksums.txt | sha256sum -c -); then
        echo "Civitai CLI checksum verification failed." >&2; rm -rf "$tmpdir"; return 1
    fi
    if ! tar -xzf "$tmpdir/$archive_name" -C "$tmpdir"; then rm -rf "$tmpdir"; return 1; fi
    binary="$(find "$tmpdir" -type f -name civitai -print -quit)"
    if [[ -z "$binary" ]]; then echo "Civitai archive contains no civitai binary." >&2; rm -rf "$tmpdir"; return 1; fi
    install -m 0755 "$binary" "$CIVITAI_BIN"
    rm -rf "$tmpdir"
    CIVITAI_READY=1
}

need_hf=0 need_civitai=0
for url in "${JOB_URLS[@]}"; do
    case "$url" in
        https://huggingface.co/*) need_hf=1 ;;
        https://civitai.com/api/download/models/*|https://civitai.red/api/download/models/*) need_civitai=1 ;;
    esac
done
if (( need_hf )); then install_hf_cli || true; fi
if (( need_civitai )); then install_civitai_cli || true; fi

# ---- Download implementations ----
download_huggingface() {
    local url="$1" dest="$2" rest repo_type="model" owner repo revision file_path target source local_dir
    (( HF_READY == 1 )) || { echo "Hugging Face CLI unavailable." >&2; return 1; }
    rest="${url#https://huggingface.co/}"
    if [[ "$rest" == datasets/* ]]; then repo_type="dataset"; rest="${rest#datasets/}"; fi
    owner="${rest%%/*}"; rest="${rest#*/}"
    repo="${rest%%/*}"; rest="${rest#*/}"
    [[ "$rest" == resolve/* ]] || { echo "Unsupported Hugging Face URL: ${url%%\?*}" >&2; return 1; }
    rest="${rest#resolve/}"
    revision="${rest%%/*}"; file_path="${rest#*/}"
    [[ -n "$owner" && -n "$repo" && -n "$revision" && -n "$file_path" ]] || { echo "Could not parse Hugging Face URL: ${url%%\?*}" >&2; return 1; }
    mkdir -p "$dest"
    target="$dest/${file_path##*/}"
    if [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$target" ]]; then
        log "Already present: $target"; return 0
    fi
    local_dir="${HF_HOME}/local/${repo_type}/${owner}/${repo}/${revision}"
    source="$local_dir/$file_path"
    mkdir -p "$local_dir"
    if [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$target" && ! -L "$target" ]]; then
        log "Preserving existing Hugging Face file: $target"; return 0
    elif [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$source" ]]; then
        log "Reusing Hugging Face cache: $source"
    else
        log "Hugging Face download: ${owner}/${repo}/${file_path}"
        local -a args=(download "${owner}/${repo}" "$file_path" --repo-type "$repo_type" --revision "$revision" --local-dir "$local_dir")
        [[ -n "${HF_TOKEN:-}" ]] && export HF_TOKEN
        [[ "${FORCE_MODEL_DOWNLOADS,,}" == "true" ]] && args+=(--force-download)
        "$HF_BIN" "${args[@]}" || { echo "Hugging Face download failed: ${url%%\?*}" >&2; return 1; }
    fi
    [[ -s "$source" ]] || { echo "Hugging Face CLI finished but expected file is absent: $source" >&2; return 1; }
    ln -sfn "$source" "$target"
}

download_civitai() {
    local url="$1" dest="$2" version_id query file_id="" format="" metadata_dir metadata_path metadata selected_file filename target
    (( CIVITAI_READY == 1 )) || { echo "Civitai CLI unavailable." >&2; return 1; }
    [[ -n "${CIVITAI_TOKEN:-}" ]] || { echo "CIVITAI_TOKEN is required for this Civitai file." >&2; return 1; }
    version_id="$(sed -nE 's#^https://civitai\.com/api/download/models/([0-9]+)(\?.*)?$#\1#p' <<< "${url/civitai.red/civitai.com}")"
    [[ -n "$version_id" ]] || { echo "Could not parse Civitai model version from URL." >&2; return 1; }
    query="${url#*\?}"; [[ "$query" == "$url" ]] && query=""
    file_id="$(sed -nE 's#(^|.*&)fileId=([0-9]+).*#\2#p' <<< "$query")"
    [[ "$query" == *"format=PickleTensor"* ]] && format="pickletensor"
    [[ "$query" == *"format=SafeTensor"* || "$query" == *"format=safetensors"* ]] && format="safetensor"
    metadata_dir="${WORKSPACE}/.cache/civitai"; mkdir -p "$metadata_dir"
    metadata_path="${metadata_dir}/version-${version_id}.json"
    if [[ ! -s "$metadata_path" || "${FORCE_MODEL_DOWNLOADS,,}" == "true" ]]; then
        metadata="$(CIVITAI_TOKEN="$CIVITAI_TOKEN" "$CIVITAI_BIN" model-versions get "$version_id" --json)" || { echo "Civitai metadata request failed for version $version_id." >&2; return 1; }
        jq -e '.files | type == "array"' <<< "$metadata" >/dev/null || { echo "Invalid Civitai metadata for version $version_id." >&2; return 1; }
        printf '%s\n' "$metadata" > "${metadata_path}.part" && mv -f "${metadata_path}.part" "$metadata_path"
    else
        metadata="$(cat "$metadata_path")"
    fi
    if [[ -n "$file_id" ]]; then
        selected_file="$(jq -c --arg id "$file_id" '[.files[] | select((.id | tostring) == $id)][0] // empty' <<< "$metadata")"
    elif [[ -n "$format" ]]; then
        selected_file="$(jq -c --arg fmt "$format" '([.files[] | select(((.metadata.format // .format // "") | ascii_downcase) == $fmt)] | (map(select(.primary == true))[0] // .[0])) // empty' <<< "$metadata")"
    else
        selected_file="$(jq -c '([.files[] | select(.primary == true)][0] // .files[0] // empty)' <<< "$metadata")"
    fi
    [[ -n "$selected_file" && "$selected_file" != "null" ]] || { echo "Requested Civitai file not found for version $version_id." >&2; jq -r '.files[]? | "id=\(.id) primary=\(.primary // false) format=\(.metadata.format // .format // "unknown") name=\(.name // "unknown")"' <<< "$metadata" >&2; return 1; }
    filename="$(jq -r '.name // empty' <<< "$selected_file")"
    [[ -n "$filename" && "$filename" != "null" ]] || { echo "Civitai metadata has no filename for version $version_id." >&2; return 1; }
    mkdir -p "$dest"; target="$dest/$filename"
    if [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$target" ]]; then log "Already present: $target"; return 0; fi
    log "Civitai download: version $version_id, file $filename -> $target"
    local -a args=(download "$version_id" --file "$filename" --out-dir "$dest")
    [[ "${FORCE_MODEL_DOWNLOADS,,}" == "true" ]] && args+=(--force)
    CIVITAI_TOKEN="$CIVITAI_TOKEN" "$CIVITAI_BIN" "${args[@]}"
}

download_one() {
    local category="$1" url="$2" dest="$3" name target part
    mkdir -p "$dest"
    case "$url" in
        https://huggingface.co/*) download_huggingface "$url" "$dest"; return $? ;;
        https://civitai.com/api/download/models/*|https://civitai.red/api/download/models/*)
            download_civitai "${url/civitai.red/civitai.com}" "$dest"; return $? ;;
    esac
    name="$(python3 -c 'from urllib.parse import urlsplit, unquote; import sys; print(unquote(urlsplit(sys.argv[1]).path.rsplit("/", 1)[-1]))' "$url")"
    [[ -n "$name" ]] || { echo "Could not determine filename for ${url%%\?*}" >&2; return 1; }
    target="$dest/$name"; part="$target.part"
    if [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$target" ]]; then log "Already present: $target"; return 0; fi
    log "Downloading [$category]: $name"
    if ! curl -fL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 30 \
        --continue-at - --output "$part" "$url"; then
        echo "Download failed: ${url%%\?*}; partial retained at $part" >&2; return 1
    fi
    [[ -s "$part" ]] || { echo "Downloaded file is empty: $url" >&2; return 1; }
    mv -f "$part" "$target"
}

# ---- Execute all selected assets, continuing after individual failures ----
log "Starting standalone model download run: $BUILD_ID"
log "ComfyUI directory: $COMFYUI_DIR"
log "Workspace: $WORKSPACE"
log "Selected assets: ${#JOB_URLS[@]} | parallel downloads: ${MAX_PARALLEL_DOWNLOADS} | force: ${FORCE_MODEL_DOWNLOADS}"
log "Results: $STATUS_DIR"

wait_for_any_download() {
    local completed="" rc=0 pid
    local -a remaining=()
    if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
        wait -n -p completed "${pids[@]}" || rc=$?
        [[ -n "$completed" ]] || { echo "Unable to identify completed download process." >&2; return 1; }
    else
        completed="${pids[0]}"; wait "$completed" || rc=$?
    fi
    local removed=0
    for pid in "${pids[@]}"; do
        if [[ "$pid" == "$completed" && $removed == 0 ]]; then removed=1; else remaining+=("$pid"); fi
    done
    pids=("${remaining[@]}")
    return "$rc"
}

failed=0
pids=()
for i in "${!JOB_URLS[@]}"; do
    while (( ${#pids[@]} >= MAX_PARALLEL_DOWNLOADS )); do wait_for_any_download || failed=1; done
    (
        started="$(date +%s)"; rc=0
        download_one "${JOB_CATEGORIES[$i]}" "${JOB_URLS[$i]}" "${JOB_DESTS[$i]}" || rc=$?
        elapsed=$(( $(date +%s) - started ))
        safe_url="${JOB_URLS[$i]%%\?*}"
        printf '%s\t%s\t%s\t%s\n' "$rc" "$elapsed" "${JOB_CATEGORIES[$i]}" "${JOB_DESTS[$i]}" > "${STATUS_DIR}/${i}.status"
        if (( rc == 0 )); then log "DONE [$((i+1))/${#JOB_URLS[@]}] ${JOB_CATEGORIES[$i]}: ${safe_url##*/} (${elapsed}s)"; else log "FAILED [$((i+1))/${#JOB_URLS[@]}] ${JOB_CATEGORIES[$i]}: ${safe_url}" >&2; fi
        exit "$rc"
    ) >> "$LOG_FILE" 2>&1 &
    pids+=("$!")
done
while (( ${#pids[@]} > 0 )); do wait_for_any_download || failed=1; done

# ---- Final report ----
SUCCESS_COUNT=0
FAILURE_COUNT=0
: > "${STATUS_DIR}/FAILED.txt"
for i in "${!JOB_URLS[@]}"; do
    status_file="${STATUS_DIR}/${i}.status"
    if [[ ! -s "$status_file" ]]; then
        printf 'No completion record | %s | %s\n' "${JOB_CATEGORIES[$i]}" "${JOB_URLS[$i]%%\?*}" >> "${STATUS_DIR}/FAILED.txt"
        ((FAILURE_COUNT+=1)); continue
    fi
    IFS=$'\t' read -r rc elapsed category dest < "$status_file"
    if [[ "$rc" == "0" ]]; then
        ((SUCCESS_COUNT+=1))
    else
        printf 'Exit %s | %s | %s | %s\n' "$rc" "$category" "$dest" "${JOB_URLS[$i]%%\?*}" >> "${STATUS_DIR}/FAILED.txt"
        ((FAILURE_COUNT+=1))
    fi
done

log "Model download summary: ${SUCCESS_COUNT} succeeded, ${FAILURE_COUNT} failed."
log "Detailed output log: $LOG_FILE"
log "Per-run results: $STATUS_DIR"
if (( FAILURE_COUNT > 0 )); then
    echo "Some assets failed. They will be retried on the next run; existing successful files are retained." >&2
    cat "${STATUS_DIR}/FAILED.txt" >&2
    exit 1
fi
rm -f "${STATUS_DIR}/FAILED.txt"
log "All selected model/assets are present."
