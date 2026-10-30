#!/usr/bin/env bash

# Sourced by the provider init script. Keep secrets in container environment variables.
# Environment variables:
#   HF_TOKEN                 Hugging Face token for gated/licensed repositories.
#   SYNCTHING_ENABLE         Enable Syncthing daemon (default true; set false to disable).
#   SYNCTHING_GUI_ADDRESS    GUI bind address (default 127.0.0.1:8384; keep loopback unless secured).
#   SYNCTHING_GUI_USER/PASSWORD  Optional GUI login; required when Tailscale Serve is enabled.
#   SYNCTHING_TAILSCALE_SERVE   Set true to expose the authenticated GUI privately over Tailscale HTTPS.
#   CIVITAI_TOKEN            Required for Civitai model downloads.
#   TAILSCALE_AUTHKEY        Optional; when set, auto-joins this container to your tailnet.
#   TS_HOSTNAME              Optional Tailscale device name.
#   MAX_PARALLEL_DOWNLOADS   Global model-download concurrency (default 2; try 3 if bandwidth allows).
#   HF_XET_HIGH_PERFORMANCE  Set to 1 only when you want hf-xet to use more system resources.
#   FORCE_PROVISIONING=1     Recheck/update nodes and refresh Civitai metadata/workflows.
#   FORCE_MODEL_DOWNLOADS=true  Force all model files to be downloaded again.
#   COMFYUI_PYTHON_VERSION     Optional Python target. Defaults to the image's existing runtime Python.
#   COMFYUI_BOOTSTRAP_PYTHON   Interpreter path for an explicit Python migration, if needed.
#   COMFYUI_REF                ComfyUI branch/tag/commit, or latest stable release (default latest).
#   COMFYUI_AUTO_UPDATE        Update ComfyUI core at startup (default true).
#   COMFYUI_TORCH_INDEX_URL    Explicit PyTorch wheel index for a deliberate Torch upgrade.
#   COMFYUI_UPGRADE_TORCH      Set true only when intentionally upgrading Torch during Python migration.
#   ALLOW_NODE_TORCH_REQUIREMENTS Set true to allow node/core requirements to replace the image's Torch packages.
#   COMFYUI_MIN_TORCH_VERSION     Minimum Torch required by this ComfyUI checkout (default 2.7.0).
#   COMFYUI_TORCH_INDEX_URL      Optional explicit PyTorch wheel index; otherwise selected from NVIDIA driver.
#   COMFYUI_AUTO_FIX_TORCH       Automatically upgrade an older Torch to a compatible 2.7.1 build (default true).
# https://github.com/MushroomFleet/Runpod-init
: "${WORKSPACE:?WORKSPACE must be set by the container provider}"

# Container images commonly run as root but set no-new-privileges, which makes
# sudo fail even for UID 0. Run privileged commands directly when already root.
# Non-root execution falls back to passwordless sudo when it is available.
function as_root() {
    if (( EUID == 0 )); then
        "$@"
        return $?
    fi
    if command -v sudo >/dev/null 2>&1; then
        sudo -n "$@"
        return $?
    fi
    echo "This provisioning step requires root privileges (effective UID=${EUID})." >&2
    return 1
}

echo "Provisioning identity: uid=$(id -u) user=$(id -un 2>/dev/null || echo unknown) no-new-privileges may be enabled; privileged commands use direct root execution when possible."

# Load AI-Dock's runtime paths before selecting the ComfyUI code and venv paths.
# The provider's ComfyUI service normally runs /opt/ComfyUI with
# /opt/environments/python/comfyui; installing dependencies elsewhere is ineffective.
if [[ -f /opt/ai-dock/etc/environment.sh ]]; then
    source /opt/ai-dock/etc/environment.sh || true
fi
if [[ -f /opt/ai-dock/bin/venv-set.sh ]]; then
    source /opt/ai-dock/bin/venv-set.sh comfyui || true
fi

COMFYUI_DIR="${COMFYUI_DIR:-}"
if [[ -z "$COMFYUI_DIR" ]]; then
    if [[ -d /opt/ComfyUI/.git ]]; then
        COMFYUI_DIR="/opt/ComfyUI"
    else
        COMFYUI_DIR="${WORKSPACE}/ComfyUI"
    fi
fi
COMFYUI_VENV_DIR="${COMFYUI_VENV:-/opt/environments/python/comfyui}"
COMFYUI_PYTHON="${COMFYUI_VENV_PYTHON:-${COMFYUI_VENV_DIR}/bin/python}"
if [[ ! -x "$COMFYUI_PYTHON" ]]; then
    echo "AI-Dock ComfyUI Python environment not found: $COMFYUI_PYTHON" >&2
    echo "Expected the image-provided environment at /opt/environments/python/comfyui." >&2
    exit 1
fi
COMFYUI_IMAGE_PYTHON_VERSION="$("$COMFYUI_PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')" || exit 1
# AI-Dock's published image defaults to Python 3.10. Preserve the interpreter
# bundled with the image unless a different installed interpreter is requested.
COMFYUI_PYTHON_VERSION="${COMFYUI_PYTHON_VERSION:-$COMFYUI_IMAGE_PYTHON_VERSION}"
if [[ "$COMFYUI_PYTHON_VERSION" == "$COMFYUI_IMAGE_PYTHON_VERSION" ]]; then
    COMFYUI_BOOTSTRAP_PYTHON="$COMFYUI_PYTHON"
else
    COMFYUI_BOOTSTRAP_PYTHON="${COMFYUI_BOOTSTRAP_PYTHON:-$(command -v "python${COMFYUI_PYTHON_VERSION}" 2>/dev/null || true)}"
    if [[ -z "$COMFYUI_BOOTSTRAP_PYTHON" || ! -x "$COMFYUI_BOOTSTRAP_PYTHON" ]]; then
        echo "Requested Python ${COMFYUI_PYTHON_VERSION} is not installed in this container." >&2
        echo "The AI-Dock :latest image is built around its bundled Python environment; do not assume apt has python${COMFYUI_PYTHON_VERSION}." >&2
        echo "Use a matching AI-Dock image build or provide COMFYUI_BOOTSTRAP_PYTHON pointing to an installed Python ${COMFYUI_PYTHON_VERSION} interpreter." >&2
        exit 1
    fi
fi
SYSTEM_PYTHON="$(command -v python3 2>/dev/null || true)"
[[ -x "$SYSTEM_PYTHON" ]] || SYSTEM_PYTHON="$COMFYUI_PYTHON"
COMFYUI_REPO_URL="${COMFYUI_REPO_URL:-https://github.com/Comfy-Org/ComfyUI.git}"
COMFYUI_REF="${COMFYUI_REF:-latest}"
COMFYUI_AUTO_UPDATE="${COMFYUI_AUTO_UPDATE:-true}"
AUTO_UPDATE="${NODES_AUTO_UPDATE:-${AUTO_UPDATE:-false}}"
COMFYUI_UPGRADE_TORCH="${COMFYUI_UPGRADE_TORCH:-false}"
COMFYUI_TORCH_INDEX_URL="${COMFYUI_TORCH_INDEX_URL:-}"
COMFYUI_MIN_TORCH_VERSION="${COMFYUI_MIN_TORCH_VERSION:-2.7.0}"
COMFYUI_AUTO_FIX_TORCH="${COMFYUI_AUTO_FIX_TORCH:-true}"
COMFYUI_PYTHON_STAGE=""
COMFYUI_PYTHON_BACKUP=""
COMFYUI_RUNTIME_VENV_DIR="$COMFYUI_VENV_DIR"
COMFYUI_CORE_CHANGED=0
COMFYUI_PYTHON_REBUILT=0
workflows_dir="${COMFYUI_DIR}/user/default/workflows"
TOOLS_DIR="${WORKSPACE}/.tools"
TOOLS_BIN="${TOOLS_DIR}/bin"
HF_TOOL_VENV="${TOOLS_DIR}/hf-download-venv"
HF_BIN="${HF_TOOL_VENV}/bin/hf"
CIVITAI_BIN="${TOOLS_BIN}/civitai"
SYNCTHING_ENABLE="${SYNCTHING_ENABLE:-true}"
SYNCTHING_HOME="${SYNCTHING_HOME:-${WORKSPACE}/.syncthing}"
SYNCTHING_GUI_ADDRESS="${SYNCTHING_GUI_ADDRESS:-127.0.0.1:8384}"
SYNCTHING_GUI_PORT="${SYNCTHING_GUI_ADDRESS##*:}"
SYNCTHING_TAILSCALE_SERVE="${SYNCTHING_TAILSCALE_SERVE:-false}"
SYNCTHING_REPO_CHANGED=0
TIMING_LOG="${WORKSPACE}/provisioning-timings.log"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
SCRIPT_START_EPOCH="$(date +%s)"
ORIGINAL_EXIT_TRAP="$(trap -p EXIT)"

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

if [[ "${SYNCTHING_ENABLE,,}" != "false" && "${SYNCTHING_ENABLE,,}" != "0" ]]; then
    APT_PACKAGES+=("syncthing")
fi

# Only add-ons not owned by ComfyUI's core requirements. Avoid pinning FastAPI,
# Uvicorn, torchsde, or Torch here: the core requirements and existing CUDA build
# should determine those versions.
PIP_PACKAGES=(
    "resynthesizer==1.2"
    "OpenEXR==3.4.4"
    "soundfile==0.13.1"
)

CHECKPOINT_MODELS=(
)
# Only these two repositories are managed by this script. Other folders already
# present in custom_nodes are supplied by the AI-Dock image or installed separately;
# leave them untouched.
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




### Provisioning, timing, and download helpers ###

# Append-only timing log; per-download entries are written by concurrent jobs too.
# Format: run-id<TAB>timestamp<TAB>duration-seconds<TAB>status<TAB>stage
mkdir -p "$(dirname "$TIMING_LOG")"
{
    printf '\n=== Provisioning run %s started %s ===\n' "$RUN_ID" "$(date --iso-8601=seconds 2>/dev/null || date)"
    printf 'run-id\ttimestamp\tduration-seconds\tstatus\tstage\n'
} >> "$TIMING_LOG"

function duration_hms() {
    local total="$1"
    printf '%02d:%02d:%02d' "$((total / 3600))" "$(((total % 3600) / 60))" "$((total % 60))"
}

function run_timed() {
    local label="$1" start end elapsed rc status
    shift
    start="$(date +%s)"
    printf '[TIME] START %s\n' "$label"
    if "$@"; then
        rc=0; status="OK"
    else
        rc=$?; status="FAIL"
    fi
    end="$(date +%s)"
    elapsed=$((end - start))
    printf '[TIME] END   %s | %s | %s\n' "$label" "$(duration_hms "$elapsed")" "$status"
    printf '%s\t%s\t%s\t%s\t%s\n' "$RUN_ID" "$(date --iso-8601=seconds 2>/dev/null || date)" "$elapsed" "$status" "$label" >> "$TIMING_LOG"
    return "$rc"
}

function finish_timing_summary() {
    local exit_rc="$?" end elapsed status
    trap - EXIT
    end="$(date +%s)"
    elapsed=$((end - SCRIPT_START_EPOCH))
    status="OK"
    (( exit_rc == 0 )) || status="FAIL(exit=${exit_rc})"
    if (( exit_rc != 0 )) && [[ -n "${COMFYUI_PYTHON_STAGE:-}" && -d "$COMFYUI_PYTHON_STAGE" ]]; then
        echo "Removing incomplete staged ComfyUI Python environment: $COMFYUI_PYTHON_STAGE" >&2
        rm -rf "$COMFYUI_PYTHON_STAGE"
    fi
    printf '\n[TIME] TOTAL script elapsed: %s | %s\n' "$(duration_hms "$elapsed")" "$status"
    printf '%s\t%s\t%s\t%s\t%s\n' "$RUN_ID" "$(date --iso-8601=seconds 2>/dev/null || date)" "$elapsed" "$status" "TOTAL_SCRIPT_ELAPSED" >> "$TIMING_LOG"
    echo "Timing log: $TIMING_LOG"
    echo "Slowest timed steps in this run:"
    awk -F '\t' -v run="$RUN_ID" '$1 == run && $3 ~ /^[0-9]+$/ && $5 != "TOTAL_SCRIPT_ELAPSED" { print $3 " sec\t" $4 "\t" $5 }' "$TIMING_LOG" \
        | sort -nr -k1,1 | head -n 10 || true
    if [[ -n "$ORIGINAL_EXIT_TRAP" ]]; then eval "$ORIGINAL_EXIT_TRAP"; fi
}
trap finish_timing_summary EXIT

function setup_syncthing_repository() {
    [[ "${SYNCTHING_ENABLE,,}" == "false" || "${SYNCTHING_ENABLE,,}" == "0" ]] && return 0
    local keyring=/etc/apt/keyrings/syncthing-archive-keyring.gpg
    local source=/etc/apt/sources.list.d/syncthing.list
    if (( EUID != 0 )) && ! command -v sudo >/dev/null 2>&1; then
        echo "Syncthing repository setup requires root; current effective UID is ${EUID}." >&2
        return 1
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "Bootstrapping curl and CA certificates before configuring Syncthing..."
        as_root apt-get update || { echo "APT update failed while bootstrapping curl." >&2; return 1; }
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ca-certificates || { echo "Could not install curl/ca-certificates." >&2; return 1; }
    fi
    if [[ ! -s "$keyring" ]]; then
        echo "Adding the official Syncthing APT signing key..."
        as_root mkdir -p /etc/apt/keyrings || return 1
        as_root curl -fL --retry 4 --retry-all-errors https://syncthing.net/release-key.gpg -o "${keyring}.tmp" || return 1
        as_root install -m 0644 "${keyring}.tmp" "$keyring" || return 1
        as_root rm -f "${keyring}.tmp"
    fi
    if ! grep -qF 'https://apt.syncthing.net/ syncthing stable-v2' "$source" 2>/dev/null; then
        echo "Enabling the official Syncthing stable-v2 repository..."
        printf '%s\n' "deb [signed-by=${keyring}] https://apt.syncthing.net/ syncthing stable-v2" | as_root tee "$source" >/dev/null || return 1
        SYNCTHING_REPO_CHANGED=1
    fi
    if ! grep -qF 'Pin: origin apt.syncthing.net' /etc/apt/preferences.d/syncthing.pref 2>/dev/null; then
        printf '%s\n' 'Package: *' 'Pin: origin apt.syncthing.net' 'Pin-Priority: 990' | as_root tee /etc/apt/preferences.d/syncthing.pref >/dev/null || return 1
        SYNCTHING_REPO_CHANGED=1
    fi
}

function syncthing_gui_auth_configured() {
    "$SYSTEM_PYTHON" - "$SYNCTHING_HOME/config.xml" <<'PYXML'
import sys
import xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
    gui = root.find("gui")
    user = gui.findtext("user", default="").strip() if gui is not None else ""
    password = gui.findtext("password", default="").strip() if gui is not None else ""
    raise SystemExit(0 if user and password else 1)
except (OSError, ET.ParseError):
    raise SystemExit(1)
PYXML
}

function setup_syncthing() {
    [[ "${SYNCTHING_ENABLE,,}" == "false" || "${SYNCTHING_ENABLE,,}" == "0" ]] && {
        echo "Syncthing: disabled (SYNCTHING_ENABLE=${SYNCTHING_ENABLE})."
        return 0
    }
    local syncthing_bin pid i ts_socket ts_name
    syncthing_bin="$(command -v syncthing)" || { echo "Syncthing package is not installed." >&2; return 1; }
    ts_socket="/tmp/tailscaled.sock"
    mkdir -p "$SYNCTHING_HOME" "${WORKSPACE}/Sync"
    chmod 700 "$SYNCTHING_HOME"

    # Don't reconfigure credentials while an existing daemon is running.
    if pgrep -f "[s]yncthing.*--home=${SYNCTHING_HOME}" >/dev/null 2>&1; then
        echo "Syncthing already appears to be running from $SYNCTHING_HOME."
    else
        if [[ -n "${SYNCTHING_GUI_USER:-}" || -n "${SYNCTHING_GUI_PASSWORD:-}" ]]; then
            if [[ -z "${SYNCTHING_GUI_USER:-}" || -z "${SYNCTHING_GUI_PASSWORD:-}" ]]; then
                echo "Set both SYNCTHING_GUI_USER and SYNCTHING_GUI_PASSWORD, or leave both unset." >&2
                return 1
            fi
            echo "Configuring Syncthing GUI authentication without placing the password in process arguments..."
            if ! printf '%s' "$SYNCTHING_GUI_PASSWORD" | HOME="$WORKSPACE" "$syncthing_bin" generate \
                --home="$SYNCTHING_HOME" --gui-user="$SYNCTHING_GUI_USER" --gui-password=-; then
                echo "Failed to set Syncthing GUI credentials." >&2
                return 1
            fi
        fi

        echo "Starting Syncthing with persistent config: $SYNCTHING_HOME"
        # HOME is set to WORKSPACE so the default Sync folder is persistent.
        HOME="$WORKSPACE" nohup "$syncthing_bin" \
            --home="$SYNCTHING_HOME" \
            --no-browser --no-console \
            --gui-address="$SYNCTHING_GUI_ADDRESS" \
            >>"${WORKSPACE}/syncthing.log" 2>&1 </dev/null &
        pid=$!
        for i in $(seq 1 20); do
            if ! kill -0 "$pid" 2>/dev/null; then
                echo "Syncthing exited during startup; inspect ${WORKSPACE}/syncthing.log." >&2
                tail -n 60 "${WORKSPACE}/syncthing.log" >&2 || true
                return 1
            fi
            if nc -z -w 1 127.0.0.1 "$SYNCTHING_GUI_PORT" 2>/dev/null; then break; fi
            sleep 1
        done
        if ! nc -z -w 1 127.0.0.1 "$SYNCTHING_GUI_PORT" 2>/dev/null; then
            echo "Syncthing process started but GUI did not become ready on port ${SYNCTHING_GUI_PORT}; inspect ${WORKSPACE}/syncthing.log." >&2
            tail -n 60 "${WORKSPACE}/syncthing.log" >&2 || true
            return 1
        fi
        echo "Syncthing process started (PID ${pid})."
    fi

    echo "Syncthing log: ${WORKSPACE}/syncthing.log"
    echo "Persistent Sync folder: ${WORKSPACE}/Sync"
    local device_id
    device_id="$("$syncthing_bin" device-id --home="$SYNCTHING_HOME" 2>/dev/null || true)"
    [[ -n "$device_id" ]] && echo "Syncthing Device ID: ${device_id}"
    if [[ "$SYNCTHING_GUI_ADDRESS" == 127.0.0.1:* || "$SYNCTHING_GUI_ADDRESS" == localhost:* ]]; then
        echo "Syncthing GUI is loopback-only and is not exposed publicly."
    else
        echo "WARNING: Syncthing GUI is listening on a non-loopback address. Configure GUI authentication and HTTPS before exposing this port."
    fi

    if [[ "${SYNCTHING_TAILSCALE_SERVE,,}" == "true" || "${SYNCTHING_TAILSCALE_SERVE,,}" == "1" ]]; then
        if [[ -z "${SYNCTHING_GUI_USER:-}" || -z "${SYNCTHING_GUI_PASSWORD:-}" ]]; then
            echo "SYNCTHING_TAILSCALE_SERVE requires both SYNCTHING_GUI_USER and SYNCTHING_GUI_PASSWORD." >&2
            return 1
        fi
        if ! syncthing_gui_auth_configured; then
            echo "Refusing to publish Syncthing GUI: GUI username/password are not present in ${SYNCTHING_HOME}/config.xml." >&2
            echo "Restart with SYNCTHING_GUI_USER and SYNCTHING_GUI_PASSWORD set so credentials can be written before Syncthing starts." >&2
            return 1
        fi
        if ! tailscale --socket="$ts_socket" status >/dev/null 2>&1; then
            echo "Tailscale is not connected; cannot publish the Syncthing GUI over Tailscale Serve." >&2
            return 1
        fi
        echo "Publishing Syncthing GUI privately to the tailnet via Tailscale Serve..."
        tailscale --socket="$ts_socket" serve --bg "http://127.0.0.1:${SYNCTHING_GUI_PORT}" || return 1
        ts_name="$(tailscale --socket="$ts_socket" status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//')"
        if [[ -n "$ts_name" ]]; then
            echo "Syncthing GUI URL (tailnet only): https://${ts_name}/"
        else
            tailscale --socket="$ts_socket" serve status || true
        fi
    else
        echo "To reach the GUI remotely, use a secured Tailscale Serve option; the default GUI remains local-only."
    fi
    echo "Complete device pairing and folder sharing once in the Syncthing GUI."
}

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
        if (( SYNCTHING_REPO_CHANGED == 1 )); then
            echo "Refreshing APT metadata for the newly added Syncthing repository..."
            as_root apt-get update || return 1
            as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends syncthing || return 1
        else
            echo "Base OS packages are already installed; skipping apt update."
        fi
        APT_PACKAGES_READY=1
        return 0
    fi
    echo "Installing ${#missing[@]} missing OS package(s) in one apt transaction..."
    as_root apt-get update || return 1
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}" || return 1
    APT_PACKAGES_READY=1
}

function update_comfyui_core() {
    [[ "${COMFYUI_AUTO_UPDATE,,}" == "false" || "${COMFYUI_AUTO_UPDATE,,}" == "0" ]] && {
        echo "ComfyUI core auto-update disabled (COMFYUI_AUTO_UPDATE=${COMFYUI_AUTO_UPDATE})."
        return 0
    }

    local ref="$COMFYUI_REF" old_head new_head latest_json
    mkdir -p "$(dirname "$COMFYUI_DIR")"
    if [[ ! -d "$COMFYUI_DIR/.git" ]]; then
        if [[ -d "$COMFYUI_DIR" && -n "$(find "$COMFYUI_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
            echo "$COMFYUI_DIR exists but is not a Git checkout; refusing to replace it." >&2
            return 1
        fi
        echo "Cloning ComfyUI core into $COMFYUI_DIR..."
        git clone "$COMFYUI_REPO_URL" "$COMFYUI_DIR" || return 1
    fi

    if ! git -C "$COMFYUI_DIR" diff --quiet || ! git -C "$COMFYUI_DIR" diff --cached --quiet; then
        echo "ComfyUI has local tracked changes. Commit/stash them before automatic core updates." >&2
        return 1
    fi

    if [[ "$ref" == "latest" || -z "$ref" ]]; then
        echo "Resolving latest stable ComfyUI release..."
        latest_json="$(curl -fsSL --retry 4 --retry-all-errors https://api.github.com/repos/Comfy-Org/ComfyUI/releases/latest)" || return 1
        ref="$(jq -r '.tag_name // empty' <<< "$latest_json")"
        [[ -n "$ref" ]] || { echo "GitHub did not return a latest release tag." >&2; return 1; }
    fi

    old_head="$(git -C "$COMFYUI_DIR" rev-parse HEAD 2>/dev/null || true)"
    run_timed "ComfyUI git fetch" git -C "$COMFYUI_DIR" fetch --tags --prune origin || return 1

    # Prefer the fetched remote branch when REF names a branch; otherwise use tag/commit.
    if git -C "$COMFYUI_DIR" show-ref --verify --quiet "refs/remotes/origin/${ref}"; then
        git -C "$COMFYUI_DIR" checkout --detach "refs/remotes/origin/${ref}" || return 1
    else
        git -C "$COMFYUI_DIR" checkout --detach "$ref" || {
            echo "Could not check out COMFYUI_REF=$ref" >&2
            return 1
        }
    fi
    git -C "$COMFYUI_DIR" submodule update --init --recursive || return 1
    new_head="$(git -C "$COMFYUI_DIR" rev-parse HEAD)"
    if [[ "$old_head" != "$new_head" ]]; then
        COMFYUI_CORE_CHANGED=1
        echo "ComfyUI updated: ${old_head:-new checkout} -> ${new_head} (${ref})"
    else
        echo "ComfyUI already at requested revision ${new_head} (${ref})."
    fi
}

function get_old_torch_metadata() {
    local python_path="$1"
    [[ -x "$python_path" ]] || return 0
    "$python_path" - <<'PYTORCH_META' 2>/dev/null || true
import importlib.metadata as md
try:
    import torch
    values = [md.version("torch"), "", "", torch.version.cuda or "", torch.__version__]
    for i, package in ((1, "torchvision"), (2, "torchaudio")):
        try:
            values[i] = md.version(package)
        except md.PackageNotFoundError:
            pass
    print("|".join(values))
except Exception:
    print("||||")
PYTORCH_META
}

function ensure_comfyui_python() {
    local current_version="" old_python="$COMFYUI_VENV_DIR/bin/python"
    local torch_meta="" old_torch="" old_vision="" old_audio="" old_cuda="" index_url=""
    local stage="${COMFYUI_RUNTIME_VENV_DIR}.staging.${RUN_ID}"

    [[ -x "$COMFYUI_BOOTSTRAP_PYTHON" ]] || {
        echo "Requested Python ${COMFYUI_PYTHON_VERSION} is not installed at ${COMFYUI_BOOTSTRAP_PYTHON}." >&2
        echo "Install python${COMFYUI_PYTHON_VERSION} and python${COMFYUI_PYTHON_VERSION}-venv, or choose an available COMFYUI_PYTHON_VERSION." >&2
        return 1
    }

    if [[ -x "$old_python" ]]; then
        current_version="$("$old_python" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || true)"
    fi

    if [[ "$current_version" == "$COMFYUI_PYTHON_VERSION" ]]; then
        COMFYUI_VENV_DIR="$COMFYUI_RUNTIME_VENV_DIR"
        COMFYUI_PYTHON="$COMFYUI_VENV_DIR/bin/python"
        export COMFYUI_VENV="$COMFYUI_VENV_DIR" COMFYUI_VENV_PYTHON="$COMFYUI_PYTHON" COMFYUI_VENV_PIP="$COMFYUI_VENV_DIR/bin/pip"
        echo "ComfyUI runtime already uses Python ${current_version}; reusing ${COMFYUI_VENV_DIR}."
        return 0
    fi

    echo "Preparing the actual ComfyUI runtime venv with Python ${COMFYUI_PYTHON_VERSION} (existing: ${current_version:-none})."
    torch_meta="$(get_old_torch_metadata "$old_python")"
    IFS='|' read -r old_torch old_vision old_audio old_cuda old_torch_full <<< "$torch_meta"

    rm -rf "$stage"
    mkdir -p "$(dirname "$COMFYUI_RUNTIME_VENV_DIR")"
    "$COMFYUI_BOOTSTRAP_PYTHON" -m venv "$stage" || return 1
    COMFYUI_PYTHON_STAGE="$stage"
    COMFYUI_VENV_DIR="$stage"
    COMFYUI_PYTHON="$stage/bin/python"
    export COMFYUI_VENV="$COMFYUI_VENV_DIR" COMFYUI_VENV_PYTHON="$COMFYUI_PYTHON" COMFYUI_VENV_PIP="$COMFYUI_VENV_DIR/bin/pip"

    "$COMFYUI_PYTHON" -m pip install --upgrade pip setuptools wheel || return 1

    if [[ -n "$old_torch" ]]; then
        if [[ -n "$COMFYUI_TORCH_INDEX_URL" ]]; then
            index_url="$COMFYUI_TORCH_INDEX_URL"
        elif [[ "$old_cuda" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
            index_url="https://download.pytorch.org/whl/cu${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
        elif [[ "$old_torch" == *"+cpu"* ]]; then
            index_url="https://download.pytorch.org/whl/cpu"
        elif [[ "$old_torch" =~ \+rocm([0-9]+\.[0-9]+) ]]; then
            index_url="https://download.pytorch.org/whl/rocm${BASH_REMATCH[1]}"
        else
            echo "Could not identify the existing PyTorch wheel channel (${old_torch}; CUDA=${old_cuda:-unknown})." >&2
            echo "Set COMFYUI_TORCH_INDEX_URL explicitly before upgrading the Python venv." >&2
            return 1
        fi

        local -a torch_specs=("torch==${old_torch}")
        [[ -n "$old_vision" ]] && torch_specs+=("torchvision==${old_vision}")
        [[ -n "$old_audio" ]] && torch_specs+=("torchaudio==${old_audio}")
        if [[ "${COMFYUI_UPGRADE_TORCH,,}" == "true" || "${COMFYUI_UPGRADE_TORCH,,}" == "1" ]]; then
            [[ -n "$COMFYUI_TORCH_INDEX_URL" ]] || {
                echo "COMFYUI_UPGRADE_TORCH requires COMFYUI_TORCH_INDEX_URL (choose the wheel channel for this GPU/driver)." >&2
                return 1
            }
            index_url="$COMFYUI_TORCH_INDEX_URL"
            torch_specs=(torch torchvision torchaudio)
            echo "Upgrading PyTorch packages from ${index_url}."
        else
            echo "Preserving the existing PyTorch build in the new Python venv from ${index_url}."
            if [[ "$old_torch" =~ ^([0-9]+)\.([0-9]+) ]]; then
                if (( BASH_REMATCH[1] == 2 && BASH_REMATCH[2] < 7 )); then
                    echo "WARNING: existing Torch ${old_torch} is older than ComfyUI's current stated minimum (2.7)." >&2
                    echo "It is preserved to avoid silently switching your CUDA build. Set COMFYUI_UPGRADE_TORCH=true and COMFYUI_TORCH_INDEX_URL to upgrade it." >&2
                fi
            fi
        fi
        "$COMFYUI_PYTHON" -m pip install --index-url "$index_url" "${torch_specs[@]}" || {
            echo "Could not install/migrate the selected PyTorch packages for Python ${COMFYUI_PYTHON_VERSION}." >&2
            echo "The original venv remains intact. Check the chosen wheel index and GPU/driver compatibility." >&2
            return 1
        }
    else
        if [[ "${COMFYUI_UPGRADE_TORCH,,}" == "true" || "${COMFYUI_UPGRADE_TORCH,,}" == "1" ]]; then
            [[ -n "$COMFYUI_TORCH_INDEX_URL" ]] || {
                echo "COMFYUI_UPGRADE_TORCH requires COMFYUI_TORCH_INDEX_URL (choose the wheel channel for this GPU/driver)." >&2
                return 1
            }
            "$COMFYUI_PYTHON" -m pip install --index-url "$COMFYUI_TORCH_INDEX_URL" torch torchvision torchaudio || return 1
        else
            echo "No existing PyTorch installation was detected. Set COMFYUI_UPGRADE_TORCH=true and COMFYUI_TORCH_INDEX_URL to install a GPU-matched Torch build."
        fi
    fi

    COMFYUI_PYTHON_REBUILT=1
    COMFYUI_PYTHON_STAGE="$stage"
    echo "New ComfyUI Python environment staged at ${stage}; original environment has not been replaced yet."
}

function finalize_comfyui_python() {
    [[ -n "$COMFYUI_PYTHON_STAGE" ]] || return 0
    local backup="${COMFYUI_RUNTIME_VENV_DIR}.backup-${RUN_ID}"

    if [[ -d "$COMFYUI_RUNTIME_VENV_DIR" ]]; then
        mv "$COMFYUI_RUNTIME_VENV_DIR" "$backup" || return 1
        COMFYUI_PYTHON_BACKUP="$backup"
    fi
    if ! mv "$COMFYUI_PYTHON_STAGE" "$COMFYUI_RUNTIME_VENV_DIR"; then
        [[ -n "$COMFYUI_PYTHON_BACKUP" && -d "$COMFYUI_PYTHON_BACKUP" ]] && mv "$COMFYUI_PYTHON_BACKUP" "$COMFYUI_RUNTIME_VENV_DIR"
        return 1
    fi

    COMFYUI_VENV_DIR="$COMFYUI_RUNTIME_VENV_DIR"
    COMFYUI_PYTHON="$COMFYUI_VENV_DIR/bin/python"
    export COMFYUI_VENV="$COMFYUI_VENV_DIR" COMFYUI_VENV_PYTHON="$COMFYUI_PYTHON" COMFYUI_VENV_PIP="$COMFYUI_VENV_DIR/bin/pip"
    echo "Activated Python ${COMFYUI_PYTHON_VERSION} as the AI-Dock ComfyUI runtime interpreter."
    if [[ -n "$COMFYUI_PYTHON_BACKUP" ]]; then
        echo "Previous venv backup retained at: ${COMFYUI_PYTHON_BACKUP}"
        echo "Remove it after confirming ComfyUI starts successfully to reclaim disk space."
    fi
    COMFYUI_PYTHON_STAGE=""
}

function pip_install() {
    local pip_log="${WORKSPACE}/pip-install.log" rc
    if [[ ! -x "$COMFYUI_PYTHON" ]]; then
        echo "ComfyUI Python interpreter is missing: $COMFYUI_PYTHON" >&2
        return 127
    fi
    mkdir -p "${WORKSPACE}/.cache/pip"
    export PIP_CACHE_DIR="${PIP_CACHE_DIR:-${WORKSPACE}/.cache/pip}"
    export PIP_DISABLE_PIP_VERSION_CHECK=1
    export PIP_NO_INPUT=1
    echo "[pip] interpreter: $COMFYUI_PYTHON"
    "$COMFYUI_PYTHON" -m pip install --prefer-binary --no-input --disable-pip-version-check "$@" 2>&1 | tee -a "$pip_log"
    rc=${PIPESTATUS[0]}
    return "$rc"
}

function pip_install_requirements_preserving_torch() {
    local requirements="$1" label="${2:-requirements}" filtered rc
    [[ -f "$requirements" ]] || { echo "Requirements file not found: $requirements" >&2; return 1; }

    if [[ "${ALLOW_NODE_TORCH_REQUIREMENTS,,}" == "true" || "${ALLOW_NODE_TORCH_REQUIREMENTS,,}" == "1" ]]; then
        echo "WARNING: ALLOW_NODE_TORCH_REQUIREMENTS is enabled; $label may replace the image's torch/torchvision/torchaudio wheels." >&2
        pip_install -r "$requirements"
        return $?
    fi

    filtered="$(mktemp "${WORKSPACE}/.requirements-no-torch.XXXXXX")" || return 1
    # AI-Dock supplies a CUDA-matched PyTorch build. Unpinned `torch` entries
    # in ComfyUI/node requirements can silently replace it with another wheel.
    awk '
        /^[[:space:]]*(torch|torchvision|torchaudio)([[:space:]<>=!~;]|$)/ {
            print "[pip] preserving image-provided package; skipped requirement: " $0 > "/dev/stderr"
            next
        }
        { print }
    ' "$requirements" > "$filtered"

    if ! grep -qvE '^[[:space:]]*(#|$)' "$filtered"; then
        echo "No non-Torch requirements to install for $label."
        rm -f "$filtered"
        return 0
    fi

    pip_install -r "$filtered"
    rc=$?
    rm -f "$filtered"
    return "$rc"
}

function provisioning_get_pip_packages() {
    if (( ${#PIP_PACKAGES[@]} )); then
        echo "Installing optional Python add-ons in one transaction..."
        pip_install "${PIP_PACKAGES[@]}"
    fi
}

function install_downloader_tools() {
    # Keep Hugging Face's downloader dependencies out of ComfyUI's Python env.
    if [[ ! -x "$HF_BIN" ]]; then
        echo "Creating isolated Hugging Face CLI environment..."
        mkdir -p "$TOOLS_DIR"
        "$SYSTEM_PYTHON" -m venv "$HF_TOOL_VENV"
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
    local ts_dir="${WORKSPACE}/.tailscale"
    local ts_state="${ts_dir}/tailscaled.state"
    local ts_socket="/tmp/tailscaled.sock"
    local ts_log="/tmp/tailscaled.log"
    local ts_err_log="/tmp/tailscaled.err.log"
    local supervisor_conf_dir="/etc/supervisor/conf.d"
    local supervisor_conf="${supervisor_conf_dir}/tailscaled.conf"
    local tailscaled_bin tailscale_bin i status_json backend_state daemon_ready=0 pid cmdline

    # This container has no alternate SSH route. Never silently skip Tailscale:
    # an auth key is required on first boot, while later boots reuse persisted state.
    if [[ -z "${TAILSCALE_AUTHKEY:-}" && ! -s "$ts_state" ]]; then
        echo "FATAL: Tailscale has no saved identity and TAILSCALE_AUTHKEY is unset." >&2
        echo "Configure a valid Tailscale auth key before starting this container." >&2
        return 1
    fi

    if ! command -v tailscale >/dev/null 2>&1 || ! command -v tailscaled >/dev/null 2>&1; then
        echo "Installing Tailscale package..."
        curl -fsSL https://tailscale.com/install.sh | sh || return 1
    fi
    tailscale_bin="$(command -v tailscale)"
    tailscaled_bin="$(command -v tailscaled)"

    if ! command -v supervisorctl >/dev/null 2>&1; then
        echo "FATAL: supervisorctl is unavailable; refusing to start an unmanaged Tailscale daemon." >&2
        return 1
    fi
    if [[ ! -d "$supervisor_conf_dir" ]] || ! grep -qsF '/etc/supervisor/conf.d/*.conf' /etc/supervisor/supervisord.conf /etc/supervisor/*.conf 2>/dev/null; then
        echo "FATAL: /etc/supervisor/conf.d/*.conf is not included by Supervisor." >&2
        echo "Cannot guarantee Tailscale daemon restart after a crash." >&2
        return 1
    fi

    mkdir -p "$ts_dir"
    chmod 700 "$ts_dir"
    touch "$ts_state"
    chmod 600 "$ts_state"

    # Hand ownership of this dedicated socket to Supervisor. Stop any older
    # daemon using this exact socket (userspace or otherwise), but leave all
    # unrelated Tailscale instances untouched.
    while read -r pid cmdline; do
        [[ -n "$pid" ]] || continue
        if [[ "$cmdline" == *"$ts_socket"* && "$cmdline" == *tailscaled* ]]; then
            echo "Stopping previous Tailscale daemon on ${ts_socket} (PID $pid)..."
            kill -TERM "$pid" 2>/dev/null || true
            for i in $(seq 1 10); do
                kill -0 "$pid" 2>/dev/null || break
                sleep 1
            done
            kill -KILL "$pid" 2>/dev/null || true
        fi
    done < <(ps -eo pid=,args=)
    rm -f "$ts_socket"

    cat > "$supervisor_conf" <<EOF
[program:tailscaled]
command=${tailscaled_bin} --tun=userspace-networking --state=${ts_state} --socket=${ts_socket}
directory=/
autostart=true
autorestart=true
startsecs=3
startretries=20
stopsignal=TERM
stopwaitsecs=20
stopasgroup=true
killasgroup=true
user=root
priority=5
stdout_logfile=${ts_log}
stdout_logfile_maxbytes=5MB
stdout_logfile_backups=2
stderr_logfile=${ts_err_log}
stderr_logfile_maxbytes=5MB
stderr_logfile_backups=2
EOF
    chmod 644 "$supervisor_conf"

    echo "Registering Tailscale userspace daemon with Supervisor..."
    supervisorctl reread || return 1
    supervisorctl update || return 1
    # If this is an already-known program, make sure it is actually running.
    supervisorctl start tailscaled >/dev/null 2>&1 || true

    # Wait for a valid local API response, not merely for the process to exist.
    for i in $(seq 1 45); do
        status_json="$("$tailscale_bin" --socket="$ts_socket" status --json 2>/dev/null || true)"
        if [[ -n "$status_json" ]] && jq -e 'type == "object" and has("BackendState")' <<<"$status_json" >/dev/null 2>&1; then
            daemon_ready=1
            break
        fi
        sleep 1
    done
    if (( daemon_ready == 0 )); then
        echo "FATAL: Tailscale userspace daemon did not become ready under Supervisor." >&2
        supervisorctl status tailscaled >&2 || true
        tail -n 80 "$ts_log" "$ts_err_log" >&2 2>/dev/null || true
        return 1
    fi

    backend_state="$(jq -r '.BackendState // "Unknown"' <<<"$status_json")"
    if [[ "$backend_state" != "Running" ]]; then
        if [[ -z "${TAILSCALE_AUTHKEY:-}" ]]; then
            echo "FATAL: saved Tailscale identity is not authenticated (state: ${backend_state}) and no auth key is configured." >&2
            return 1
        fi
        echo "Tailscale userspace daemon is ready (state: ${backend_state}); authenticating..."
        if ! "$tailscale_bin" --socket="$ts_socket" up \
            --timeout=90s \
            --auth-key="$TAILSCALE_AUTHKEY" \
            --hostname="${TS_HOSTNAME:-comfyui-${HOSTNAME:0:12}}" \
            > /tmp/tailscale-up.log 2>&1; then
            echo "Tailscale authentication failed:" >&2
            cat /tmp/tailscale-up.log >&2 || true
            tail -n 80 "$ts_log" "$ts_err_log" >&2 2>/dev/null || true
            return 1
        fi
    fi

    # Explicitly enable Tailscale SSH on EVERY boot, after authentication.
    # This is idempotent and uses the same dedicated LocalAPI socket.
    if ! "$tailscale_bin" --socket="$ts_socket" set --ssh; then
        echo "FATAL: 'tailscale set --ssh' failed; remote shell access is not ready." >&2
        return 1
    fi

    # Confirm the node is online and that Supervisor owns the long-running daemon.
    for i in $(seq 1 45); do
        status_json="$("$tailscale_bin" --socket="$ts_socket" status --json 2>/dev/null || true)"
        backend_state="$(jq -r '.BackendState // "Unknown"' <<<"$status_json" 2>/dev/null || echo Unknown)"
        [[ "$backend_state" == "Running" ]] && break
        sleep 1
    done
    if [[ "$backend_state" != "Running" ]]; then
        echo "FATAL: Tailscale did not reach Running state (state: ${backend_state})." >&2
        "$tailscale_bin" --socket="$ts_socket" status 2>&1 || true
        return 1
    fi

    if ! supervisorctl status tailscaled | grep -q 'RUNNING'; then
        echo "FATAL: tailscaled is connected but is not RUNNING under Supervisor." >&2
        supervisorctl status tailscaled >&2 || true
        return 1
    fi

    echo "Tailscale connected in userspace networking mode; Tailscale SSH enabled."
    "$tailscale_bin" --socket="$ts_socket" status || true
    "$tailscale_bin" --socket="$ts_socket" ip -4 || true
    echo "Remote shell: ssh root@${TS_HOSTNAME:-comfyui-${HOSTNAME:0:12}}"
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

    if [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$target" && ! -L "$target" ]]; then
        # Preserve valid files installed by the previous script/version too.
        # Otherwise a first run after upgrading this installer would fetch the
        # entire multi-GB file again just to populate our new cache layout.
        echo "Already present (existing Hugging Face model file): $target"
        return 0
    elif [[ "${FORCE_MODEL_DOWNLOADS,,}" != "true" && -s "$source" ]]; then
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
    local url="$1" dest="$2" version_id query file_id="" format="" metadata filename target metadata_path metadata_dir selected_file
    version_id="$(sed -nE 's#^https://civitai\.com/api/download/models/([0-9]+)(\?.*)?$#\1#p' <<< "$url")"
    [[ -n "$version_id" ]] || { echo "Could not parse Civitai model-version ID from URL: ${url%%\?*}" >&2; return 1; }
    query="${url#*\?}"
    if [[ "$query" == "$url" ]]; then query=""; fi
    file_id="$(sed -nE 's#(^|.*&)fileId=([0-9]+).*#\2#p' <<< "$query")"
    if [[ "$query" == *"format=PickleTensor"* ]]; then format="pickletensor"; fi
    if [[ "$query" == *"format=SafeTensor"* || "$query" == *"format=safetensors"* ]]; then format="safetensor"; fi

    # Cache the version metadata in persistent workspace. The current Civitai
    # API exposes the file format under files[].metadata.format (not reliably
    # under files[].format).
    metadata_dir="${WORKSPACE}/.cache/civitai"
    metadata_path="${metadata_dir}/version-${version_id}.json"
    mkdir -p "$metadata_dir"
    if [[ ! -s "$metadata_path" || "${FORCE_PROVISIONING:-0}" == "1" || "${FORCE_MODEL_DOWNLOADS,,}" == "true" ]]; then
        export CIVITAI_TOKEN CIVITAI_NO_UPDATE_CHECK
        metadata="$("$CIVITAI_BIN" model-versions get "$version_id" --json)" || {
            echo "Could not query Civitai version ${version_id}; check the CLI error above (version may be unavailable or API access may be restricted)." >&2
            return 1
        }
        if ! jq -e '.files | type == "array"' <<< "$metadata" >/dev/null; then
            echo "Civitai returned invalid file metadata for version ${version_id}." >&2
            return 1
        fi
        printf '%s\n' "$metadata" > "${metadata_path}.part" && mv -f "${metadata_path}.part" "$metadata_path" || return 1
    else
        metadata="$(cat "$metadata_path")" || return 1
    fi

    # Resolve the intended file by its real format or explicit fileId. On the
    # current API the format lives in metadata.format. Keep a primary/first-file
    # fallback only when the URL did not specify a format or fileId.
    selected_file=""
    if [[ -n "$file_id" ]]; then
        selected_file="$(jq -c --arg id "$file_id" '[.files[] | select((.id | tostring) == $id)][0] // empty' <<< "$metadata")"
    elif [[ -n "$format" ]]; then
        selected_file="$(jq -c --arg fmt "$format" '([.files[] | select(((.metadata.format // .format // "") | ascii_downcase) == $fmt)] | (map(select(.primary == true))[0] // .[0])) // empty' <<< "$metadata")"
    else
        selected_file="$(jq -c '([.files[] | select(.primary == true)][0] // .files[0] // empty)' <<< "$metadata")"
    fi

    if [[ -z "$selected_file" || "$selected_file" == "null" ]]; then
        echo "Could not find the requested Civitai file (version=${version_id}, format=${format:-default}, fileId=${file_id:-not-specified})." >&2
        echo "Available files:" >&2
        jq -r '.files[]? | "  id=\(.id) primary=\(.primary // false) format=\(.metadata.format // .format // "unknown") name=\(.name // "unknown")"' <<< "$metadata" >&2
        return 1
    fi

    file_id="$(jq -r '.id // empty' <<< "$selected_file")"
    filename="$(jq -r '.name // empty' <<< "$selected_file")"
    if [[ -z "$filename" || "$filename" == "null" ]]; then
        echo "Civitai metadata did not provide a filename for version ${version_id}, file ${file_id:-unknown}." >&2
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
    echo "Civitai: version ${version_id}, file ${file_id} (${filename}) -> ${target}"
    # Civitai CLI --file matches a filename substring, NOT the numeric API
    # file ID. Passing file_id here causes a fast selection failure. The full
    # filename is a deterministic selector.
    local -a args=(download "$version_id" --file "$filename" --out-dir "$dest")
    [[ "${FORCE_MODEL_DOWNLOADS,,}" == "true" ]] && args+=(--force)
    "$CIVITAI_BIN" "${args[@]}"
}

function timed_provisioning_download() {
    local url="$1" dest="$2" label start end elapsed rc status
    label="$("$COMFYUI_PYTHON" -c 'from urllib.parse import urlsplit, unquote; import sys; p=urlsplit(sys.argv[1]); print(unquote(p.path.rsplit("/", 1)[-1]) or p.netloc)' "$url" 2>/dev/null || printf '%s' "${url%%\?*}")"
    [[ -n "$label" ]] || label="asset"
    label="${dest##*/}/${label}"
    start="$(date +%s)"
    printf '[TIME] START download %s\n' "$label"
    if provisioning_download "$url" "$dest"; then rc=0; status="OK"; else rc=$?; status="FAIL"; fi
    end="$(date +%s)"
    elapsed=$((end - start))
    printf '[TIME] END   download %s | %s | %s\n' "$label" "$(duration_hms "$elapsed")" "$status"
    printf '%s\t%s\t%s\t%s\t%s\n' "$RUN_ID" "$(date --iso-8601=seconds 2>/dev/null || date)" "$elapsed" "$status" "download:$label" >> "$TIMING_LOG"
    return "$rc"
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

    name="$("$COMFYUI_PYTHON" -c 'from urllib.parse import urlsplit, unquote; import sys; print(unquote(urlsplit(sys.argv[1]).path.rsplit("/", 1)[-1]))' "$url")" || return 1
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

function wait_for_any_download() {
    local done_pid="" rc=0 pid
    local -a remaining=()
    # Bash 5.1+ supports wait -n -p; this lets a short download free a slot
    # immediately instead of waiting for the oldest (possibly huge) model.
    wait -n -p done_pid "${pids[@]}" || rc=$?
    if [[ -z "$done_pid" ]]; then
        echo "Could not identify a completed model-download process." >&2
        return 1
    fi
    for pid in "${pids[@]}"; do
        [[ "$pid" == "$done_pid" ]] || remaining+=("$pid")
    done
    pids=("${remaining[@]}")
    return "$rc"
}

function provisioning_get_model_assets() {
    local failed=0 max="${MAX_PARALLEL_DOWNLOADS:-2}" i rc dest url status_file status_dir
    [[ "$max" =~ ^[1-9][0-9]*$ ]] || max=2
    MODEL_JOB_URLS=()
    MODEL_JOB_DESTS=()

    queue_model_urls "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
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

    status_dir="${WORKSPACE}/.provisioning/download-status/${RUN_ID}"
    rm -rf "$status_dir"
    mkdir -p "$status_dir"
    echo "Preparing ${#MODEL_JOB_URLS[@]} unique asset/destination jobs (global parallelism: ${max})."
    echo "Per-model download results: ${status_dir}"

    local -a pids=()
    for i in "${!MODEL_JOB_URLS[@]}"; do
        while (( ${#pids[@]} >= max )); do
            wait_for_any_download || failed=1
        done
        # Each background job writes its own result file. URL query strings are
        # intentionally omitted from the report so Civitai tokens are not logged.
        (
            rc=0
            timed_provisioning_download "${MODEL_JOB_URLS[$i]}" "${MODEL_JOB_DESTS[$i]}" || rc=$?
            dest="${MODEL_JOB_DESTS[$i]}"
            url="${MODEL_JOB_URLS[$i]%%\?*}"
            printf '%s\t%s\t%s\n' "$rc" "$dest" "$url" > "${status_dir}/${i}.status"
            exit "$rc"
        ) &
        pids+=("$!")
    done
    while (( ${#pids[@]} > 0 )); do
        wait_for_any_download || failed=1
    done

    local failures_file="${status_dir}/FAILED.txt"
    : > "$failures_file"
    local success_count=0 failure_count=0
    for i in "${!MODEL_JOB_URLS[@]}"; do
        status_file="${status_dir}/${i}.status"
        if [[ ! -s "$status_file" ]]; then
            printf 'No completion record: %s | %s\n' "${MODEL_JOB_DESTS[$i]}" "${MODEL_JOB_URLS[$i]%%\?*}" >> "$failures_file"
            ((failure_count+=1))
            continue
        fi
        IFS=$'\t' read -r rc dest url < "$status_file"
        if [[ "$rc" == "0" ]]; then
            ((success_count+=1))
        else
            printf 'Exit %s: %s | %s\n' "$rc" "$dest" "$url" >> "$failures_file"
            ((failure_count+=1))
        fi
    done

    echo "Model download summary: ${success_count} succeeded, ${failure_count} failed or incomplete."
    if (( failure_count > 0 )); then
        echo "Failed model downloads:" >&2
        cat "$failures_file" >&2
        echo "Full per-model status directory: ${status_dir}" >&2
        failed=1
    else
        rm -f "$failures_file"
    fi
    return "$failed"
}

function provisioning_get_nodes() {
    local repo dir path requirements failed=0
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"; dir="${dir,,}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d "$path" ]]; then
            if [[ "${AUTO_UPDATE,,}" != "false" || "${FORCE_PROVISIONING:-0}" == "1" ]]; then
                printf "Updating node: %s...\\n" "$repo"
                run_timed "custom node update: ${dir}" git -C "$path" pull --ff-only || { echo "Warning: could not update $repo" >&2; failed=1; }
            fi
        else
            printf "Cloning node: %s...\\n" "$repo"
            run_timed "custom node clone: ${dir}" git clone --recursive "$repo" "$path" || { echo "Failed cloning $repo" >&2; failed=1; continue; }
        fi
        if [[ -f "$requirements" ]]; then
            run_timed "custom node requirements: ${dir}" pip_install_requirements_preserving_torch "$requirements" "custom node ${dir}" || { echo "Failed installing requirements for $repo; see ${WORKSPACE}/pip-install.log" >&2; failed=1; }
        fi
        if [[ -f "${path}/install.py" ]]; then
            run_timed "custom node install.py: ${dir}" "$COMFYUI_PYTHON" "${path}/install.py" || { echo "install.py failed for $repo" >&2; failed=1; }
        fi
    done
    return "$failed"
}

function provisioning_get_workflows() {
    local url filename target part failed=0
    mkdir -p "$workflows_dir"
    for url in "${WORKFLOWS[@]}"; do
        filename="$("$COMFYUI_PYTHON" -c 'from urllib.parse import urlsplit, unquote; import sys; print(unquote(urlsplit(sys.argv[1]).path.rsplit("/", 1)[-1]))' "$url")"
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

function install_comfyui_requirements_if_changed() {
    local requirements="${COMFYUI_DIR}/requirements.txt"
    local state_file="${WORKSPACE}/.comfyui-requirements.sha256"
    local current_hash old_hash=""
    [[ -f "$requirements" ]] || { echo "ComfyUI requirements file not found: $requirements" >&2; return 1; }
    current_hash="$(sha256sum "$requirements" | awk '{print $1}')" || return 1
    [[ -f "$state_file" ]] && old_hash="$(cat "$state_file")"
    if [[ "$current_hash" != "$old_hash" || "$COMFYUI_PYTHON_REBUILT" == "1" || "${FORCE_PROVISIONING:-0}" == "1" ]]; then
        run_timed "ComfyUI core Python requirements (preserving image Torch)" pip_install_requirements_preserving_torch "$requirements" "ComfyUI core" || return 1
        printf '%s\n' "$current_hash" > "$state_file"
    else
        echo "ComfyUI requirements unchanged; skipping core pip installation."
    fi
}

function upgrade_torch_if_requested() {
    if [[ "${COMFYUI_UPGRADE_TORCH,,}" != "true" && "${COMFYUI_UPGRADE_TORCH,,}" != "1" ]]; then
        echo "Keeping the AI-Dock-provided PyTorch build. Set COMFYUI_UPGRADE_TORCH=true plus COMFYUI_TORCH_INDEX_URL to upgrade deliberately."
        return 0
    fi
    if [[ "$COMFYUI_PYTHON_REBUILT" == "1" ]]; then
        echo "PyTorch was already migrated/upgraded while building the replacement Python environment."
        return 0
    fi
    [[ -n "$COMFYUI_TORCH_INDEX_URL" ]] || {
        echo "COMFYUI_UPGRADE_TORCH=true requires COMFYUI_TORCH_INDEX_URL." >&2
        echo "Choose a PyTorch wheel index compatible with the host NVIDIA driver and this container's CUDA/runtime environment." >&2
        return 1
    }
    echo "Upgrading torch, torchvision and torchaudio from ${COMFYUI_TORCH_INDEX_URL}..."
    pip_install --index-url "$COMFYUI_TORCH_INDEX_URL" torch torchvision torchaudio || return 1
    "$COMFYUI_PYTHON" -c 'import torch; print("Installed Torch:", torch.__version__, "CUDA:", torch.version.cuda, "available:", torch.cuda.is_available())' || return 1
}

function ensure_comfyui_torch_compatibility() {
    local installed_torch index_url driver_version
    installed_torch="$($COMFYUI_PYTHON -c 'import torch; print(torch.__version__.split("+")[0])' 2>/dev/null)" || {
        echo "Cannot import PyTorch from the ComfyUI runtime: $COMFYUI_PYTHON" >&2
        return 1
    }

    if "$COMFYUI_PYTHON" - "$installed_torch" "$COMFYUI_MIN_TORCH_VERSION" <<'PYTORCH_VERSION_CHECK'
from packaging.version import Version
import sys
raise SystemExit(0 if Version(sys.argv[1]) >= Version(sys.argv[2]) else 1)
PYTORCH_VERSION_CHECK
    then
        echo "PyTorch ${installed_torch} satisfies ComfyUI minimum ${COMFYUI_MIN_TORCH_VERSION}."
        return 0
    fi

    echo "PyTorch ${installed_torch} is older than the ComfyUI minimum ${COMFYUI_MIN_TORCH_VERSION}." >&2
    if [[ "${COMFYUI_AUTO_FIX_TORCH,,}" != "true" && "${COMFYUI_AUTO_FIX_TORCH,,}" != "1" ]]; then
        echo "Automatic Torch repair is disabled. Set COMFYUI_AUTO_FIX_TORCH=true or install a compatible GPU build manually." >&2
        return 1
    fi

    index_url="$COMFYUI_TORCH_INDEX_URL"
    if [[ -z "$index_url" ]]; then
        if ! command -v nvidia-smi >/dev/null 2>&1; then
            echo "nvidia-smi is unavailable, so the script cannot safely select a CUDA wheel." >&2
            echo "Set COMFYUI_TORCH_INDEX_URL explicitly (for example, a PyTorch cu126/cu128 wheel index)." >&2
            return 1
        fi
        driver_version="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n 1 | tr -d '[:space:]')"
        [[ -n "$driver_version" ]] || { echo "Could not read the NVIDIA driver version from nvidia-smi." >&2; return 1; }
        index_url="$(DRIVER_VERSION="$driver_version" "$COMFYUI_PYTHON" - <<'PYTORCH_INDEX'
import os
from packaging.version import Version
v = Version(os.environ["DRIVER_VERSION"])
if v >= Version("570.26"):
    print("https://download.pytorch.org/whl/cu128")
elif v >= Version("560.28"):
    print("https://download.pytorch.org/whl/cu126")
elif v >= Version("520.61"):
    print("https://download.pytorch.org/whl/cu118")
else:
    raise SystemExit("NVIDIA driver is too old for the supported PyTorch 2.7.1 CUDA wheels; update the host driver or set a compatible COMFYUI_TORCH_INDEX_URL.")
PYTORCH_INDEX
)" || return 1
        echo "Detected NVIDIA driver ${driver_version}; selected ${index_url}."
    else
        echo "Using explicitly configured PyTorch wheel index: ${index_url}."
    fi

    # PyTorch 2.7.1 is the first supported baseline for this ComfyUI generation.
    # Keep the three official packages version-aligned and avoid an unbounded upgrade.
    pip_install --index-url "$index_url" \
        "torch==2.7.1" "torchvision==0.22.1" "torchaudio==2.7.1" || {
        echo "Could not install the compatible PyTorch 2.7.1 package set. See ${WORKSPACE}/pip-install.log." >&2
        return 1
    }

    "$COMFYUI_PYTHON" - <<'PYTORCH_VERIFY'
import torch
print(f"Verified PyTorch: {torch.__version__}; CUDA runtime: {torch.version.cuda}; CUDA available: {torch.cuda.is_available()}")
if tuple(int(x) for x in torch.__version__.split('+')[0].split('.')[:2]) < (2, 7):
    raise SystemExit("Installed PyTorch is still below 2.7")
if torch.version.cuda and not torch.cuda.is_available():
    raise SystemExit("CUDA PyTorch installed, but CUDA is not available. Check the container GPU runtime/driver.")
PYTORCH_VERIFY
}

function report_comfyui_runtime() {
    echo "ComfyUI directory: $COMFYUI_DIR"
    echo "ComfyUI Python: $COMFYUI_PYTHON"
    "$COMFYUI_PYTHON" -V || return 1
    "$COMFYUI_PYTHON" - <<'PYRUNTIME'
import sys
try:
    import torch
    print(f"PyTorch: {torch.__version__}; CUDA runtime bundled with Torch: {torch.version.cuda}; CUDA available: {torch.cuda.is_available()}")
    version = tuple(int(x) for x in torch.__version__.split('+')[0].split('.')[:2])
    if version < (2, 7):
        print("WARNING: this ComfyUI checkout's current README recommends Torch 2.7 or newer; the image-provided Torch is older. Upgrade it deliberately using a CUDA-matched wheel index, not a generic pip install.", file=sys.stderr)
except Exception as exc:
    print(f"WARNING: unable to import PyTorch in the ComfyUI runtime: {exc}", file=sys.stderr)
PYRUNTIME
}

function repair_known_dependency_conflicts() {
    # Fix a small set of known ecosystem compatibility conflicts that can arise
    # when ComfyUI core and custom-node requirements are installed sequentially.
    # Do not downgrade NumPy: newer Numba and colour-science releases support it.
    local repairs_text repairs_file
    repairs_text="$($COMFYUI_PYTHON - <<'PYREPAIRS'
from importlib.metadata import PackageNotFoundError, version
from packaging.version import Version
import sys


def installed(name):
    try:
        return Version(version(name))
    except PackageNotFoundError:
        return None

numpy_v = installed("numpy")
numba_v = installed("numba")
colour_v = installed("colour-science")
httpcore_v = installed("httpcore")
h11_v = installed("h11")
py = sys.version_info[:2]
repairs = []

# Numba 0.60.0 only accepts NumPy <2.1. Numba 0.68 supports the current
# NumPy 2.x line and Python 3.10+; constrain to this minor release family.
if numpy_v and numpy_v >= Version("2.1") and numba_v and numba_v < Version("0.68"):
    repairs.append("numba>=0.68,<0.69")

# colour-science 0.4.4 requires NumPy <2. Use a release that supports NumPy 2.
# 0.4.6 remains Python 3.10-compatible; 0.4.7 requires Python >=3.11.
if numpy_v and numpy_v >= Version("2") and colour_v and colour_v < Version("0.4.6"):
    if py < (3, 11):
        repairs.append("colour-science==0.4.6")
    else:
        repairs.append("colour-science>=0.4.7,<0.5")

# httpcore 1.0.5 requires h11 <0.15. Newer httpcore releases support h11 0.16.
if httpcore_v and httpcore_v < Version("1.0.9") and h11_v and h11_v >= Version("0.16"):
    repairs.append("httpcore>=1.0.9,<2")

print("\n".join(repairs))
PYREPAIRS
)" || {
        echo "Could not inspect installed Python package versions." >&2
        return 1
    }

    if [[ -z "${repairs_text//[$'\r\n']/}" ]]; then
        echo "No known NumPy/Numba/colour-science/httpcore compatibility repairs are needed."
        return 0
    fi

    echo "Applying narrowly scoped dependency compatibility updates:"
    while IFS= read -r package_spec; do
        [[ -n "$package_spec" ]] && echo "  - $package_spec"
    done <<< "$repairs_text"

    # One resolver transaction is important: these related packages must be
    # selected together rather than upgraded one at a time.
    repairs_file="$(mktemp "${WORKSPACE}/.dependency-repairs.XXXXXX")" || return 1
    printf '%s\n' "$repairs_text" > "$repairs_file"
    local -a repair_args=()
    mapfile -t repair_args < "$repairs_file"
    rm -f "$repairs_file"
    pip_install --upgrade "${repair_args[@]}" || {
        echo "Known dependency compatibility updates failed. See ${WORKSPACE}/pip-install.log." >&2
        return 1
    }

    echo "Dependency versions after compatibility updates:"
    "$COMFYUI_PYTHON" -m pip show numpy numba colour-science httpcore h11 2>/dev/null \
        | grep -E '^(Name|Version):' || true
}

function provisioning_start() {
    local failed=0
    provisioning_print_header
    run_timed "provision: OS packages" provisioning_get_apt_packages || return 1
    run_timed "provision: ComfyUI core requirements" install_comfyui_requirements_if_changed || return 1
    run_timed "provision: optional Python add-ons" provisioning_get_pip_packages || return 1
    run_timed "provision: custom nodes and dependencies" provisioning_get_nodes || failed=1

    if (( failed != 0 )); then
        echo "Provisioning had custom-node failures. The .noprovisioning marker was NOT written." >&2
        echo "Review ${WORKSPACE}/pip-install.log and the failed node's requirements/install.py." >&2
        return 1
    fi

    run_timed "provision: repair known dependency compatibility conflicts" repair_known_dependency_conflicts || return 1
    run_timed "provision: pip dependency consistency check" "$COMFYUI_PYTHON" -m pip check || {
        echo "Unresolved Python dependency conflicts remain after targeted repairs." >&2
        echo "Review ${WORKSPACE}/pip-install.log and run: ${COMFYUI_PYTHON} -m pip check" >&2
        return 1
    }
    run_timed "provision: model assets (all downloads)" provisioning_get_model_assets || return 1
    run_timed "provision: workflow downloads" provisioning_get_workflows || return 1
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

run_timed "prepare: Syncthing repository" setup_syncthing_repository || { echo "Could not configure the Syncthing repository." >&2; exit 1; }
run_timed "prepare: OS packages" provisioning_get_apt_packages || { echo "Base package installation failed." >&2; exit 1; }

# Provider networking services are started early, before large model transfers.
run_timed "setup: Tailscale" setup_tailscale || { echo "Tailscale startup/authentication failed. See /tmp/tailscaled.log." >&2; exit 1; }
run_timed "setup: Syncthing" setup_syncthing || { echo "Syncthing startup failed. See ${WORKSPACE}/syncthing.log." >&2; exit 1; }

run_timed "update: ComfyUI core" update_comfyui_core || { echo "ComfyUI core update failed; inspect git status and COMFYUI_REF." >&2; exit 1; }
run_timed "setup: prepare ComfyUI Python ${COMFYUI_PYTHON_VERSION}" ensure_comfyui_python || { echo "Could not prepare the ComfyUI runtime Python environment." >&2; exit 1; }
run_timed "setup: optional PyTorch upgrade" upgrade_torch_if_requested || { echo "Requested PyTorch upgrade failed; see ${WORKSPACE}/pip-install.log." >&2; exit 1; }
run_timed "check/fix: ComfyUI PyTorch compatibility" ensure_comfyui_torch_compatibility || { echo "ComfyUI requires a compatible PyTorch build; refusing to continue with a broken runtime." >&2; exit 1; }
run_timed "check: ComfyUI Python and PyTorch runtime" report_comfyui_runtime || { echo "Could not inspect the ComfyUI runtime." >&2; exit 1; }
run_timed "setup: downloader tools" install_downloader_tools || { echo "Downloader tool installation failed." >&2; exit 1; }

# Run provisioning whenever the core changed, the Python environment changed, the
# marker is absent, or the caller explicitly requests a full recheck. AUTO_UPDATE
# also refreshes the selected custom nodes and their dependencies.
if [[ ! -f "${WORKSPACE}/.noprovisioning" || "${FORCE_PROVISIONING:-0}" == "1" || \
      "$COMFYUI_CORE_CHANGED" == "1" || "$COMFYUI_PYTHON_REBUILT" == "1" || \
      "${AUTO_UPDATE,,}" != "false" ]]; then
    run_timed "setup: full provisioning" provisioning_start || { echo "Provisioning failed; ComfyUI environment was not activated." >&2; exit 1; }
else
    echo "Provisioning marker exists; checking missing model assets/workflows and dependency hashes."
    run_timed "check: ComfyUI requirements" install_comfyui_requirements_if_changed || { echo "ComfyUI requirements installation failed." >&2; exit 1; }
    run_timed "check: missing model assets" provisioning_get_model_assets || { echo "One or more model assets are still missing; fix the errors and restart." >&2; exit 1; }
    run_timed "check: workflows" provisioning_get_workflows || { echo "Workflow download failed." >&2; exit 1; }
fi

run_timed "setup: default workflow / submit script" provisioning_get_default_workflow || echo "Warning: default workflow setup failed." >&2

# Install/update the submit-prompt cron job without a second pip requirements install.
if [[ -s "${WORKSPACE}/scripts/submit_prompt.sh" ]]; then
    chmod +x "${WORKSPACE}/scripts/submit_prompt.sh"
    cron_tmp="$(mktemp)"
    printf 'WORKSPACE=%s\n* * * * * %s/scripts/submit_prompt.sh >> %s/crontab.log 2>&1\n' \
        "$WORKSPACE" "$WORKSPACE" "$WORKSPACE" > "$cron_tmp"
    crontab "$cron_tmp"
    rm -f "$cron_tmp"
    as_root service cron start || service cron start || true
fi

# These services are provider-specific; tolerate absent supervisor groups.
for service_name in \
    'cf_quicktunnel:="cf_quicktunnel_0"' \
    'cf_quicktunnel:="cf_quicktunnel_1"' \
    'cf_quicktunnel:="cf_quicktunnel_2"' \
    'cf_quicktunnel:="cf_quicktunnel_3"' \
    'jupyter'; do
    as_root supervisorctl stop "$service_name" >/dev/null 2>&1 || true
done

# Activate an explicitly requested replacement venv only after core and custom-node dependency installs succeeded.
run_timed "finalize: activate ComfyUI Python ${COMFYUI_PYTHON_VERSION}" finalize_comfyui_python || { echo "Failed to activate the new ComfyUI Python environment." >&2; exit 1; }

# Keep existing provider port mappings, but avoid hanging forever if a service never appears.
start_socat_proxy 18000 1111
if run_timed "wait: provider service port 18188" wait_for_port 18188; then
    start_socat_proxy 19000 18188
    start_socat_proxy 8188 18188
fi
if run_timed "wait: provider service port 18384" wait_for_port 18384; then
    start_socat_proxy 20000 18384
fi

# Print the report now as well as on an early exit. This file is sourced by init.sh,
# so remove our temporary EXIT trap before returning to the caller.
trap - EXIT
finish_timing_summary

