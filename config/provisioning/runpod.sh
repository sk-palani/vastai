#!/bin/bash

# This file will be sourced in init.sh

# https://github.com/MushroomFleet/Runpod-init
COMFYUI_DIR=${WORKSPACE}/ComfyUI
workflows_dir=${WORKSPACE}/ComfyUI/user/default/workflows

mkdir -p "${WORKSPACE}environments/python/comfyui"
cd "${WORKSPACE}environments/python/"

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
    "libmagickwand-dev"
    "axel"
    "screen"
    "tree"
    "ncdu"
    "socat"
    "cron"
)

#apt-get update --fix-missing &&  apt install -y   libmagickwand-dev axel tree screen


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
#    "https://github.com/crystian/ComfyUI-Crystools.git"
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
#    "https://github.com/kk8bit/kaytool"
    "https://github.com/TTPlanetPig/Comfyui_TTP_Toolset"
    "https://github.com/gseth/ControlAltAI-Nodes"
    "https://github.com/M1kep/ComfyLiterals"
    "https://github.com/pamparamm/ComfyUI-ppm"
    "https://github.com/quasiblob/ComfyUI-EsesImageCompare"
    "https://github.com/ostris/ComfyUI-Advanced-Vision"
    "https://github.com/orion4d/ComfyUI_SharpnessPro"
    "https://github.com/HECer/ComfyUI-FilePathCreator"
    "https://github.com/sk-palani/ComfyUI_Simpler"
)

#    "https://github.com/yolain/ComfyUI-Easy-Use.git"
#    "https://github.com/LevelPixel/ComfyUI-LevelPixel"

WORKFLOWS=(
    "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/flux_dev_example.json"
)

CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
#    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors"
    "https://huggingface.co/zer0int/CLIP-GmP-ViT-L-14/resolve/main/ViT-L-14-TEXT-detail-improved-hiT-GmP-TE-only-HF.safetensors"
    "https://huggingface.co/zer0int/CLIP-GmP-ViT-L-14/resolve/main/ViT-L-14-BEST-smooth-GmP-TE-only-HF-format.safetensors"


#    "https://huggingface.co/cyberdelia/FluxTextEnc_VAE/resolve/main/clip_l.safetensors"
#    "https://civitai.com/api/download/models/2019009?type=Model&format=SafeTensor&size=pruned&fp=fp32&token=${CIVITAI_TOKEN}"
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
)



FONTS=(
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/fonts/SevenSegment.ttf"
)


MP3=(
  "https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/assets/sound/finish.mp3"
)


UNET_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors"
#   "https://huggingface.co/black-forest-labs/FLUX.1-Krea-dev/resolve/main/flux1-krea-dev.safetensors"
#  "https://civitai.com/api/download/models/2287992?type=Model&format=SafeTensor&size=full&fp=fp16&token=${CIVITAI_TOKEN}"

)

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
#    "https://huggingface.co/Kijai/flux-fp8/resolve/main/flux-vae-bf16.safetensors"
#    "https://civitai.com/api/download/models/1749336?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
)

LORA_MODELS=(
    "https://civitai.com/api/download/models/2009929?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1065360?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/2009929?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://civitai.com/api/download/models/1065360?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    TW_Makeup.safetensors
    "https://civitai.com/api/download/models/1086588?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    Premium_Cinematic_Color-Graded_Portrait_Style__Inspired_by_Brandon_Woelfel.safetensors
    "https://civitai.com/api/download/models/2127531?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://huggingface.co/prithivMLmods/Canopus-LoRA-Flux-UltraRealism-2.0/resolve/main/Canopus-LoRA-Flux-UltraRealism.safetensors?&token=${HF_TOKEN}"
#    "https://huggingface.co/XLabs-AI/flux-lora-collection/resolve/main/realism_lora_comfy_converted.safetensors?&token=${HF_TOKEN}"
#    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-LoRA-AntiBlur/resolve/main/FLUX-dev-lora-AntiBlur.safetensors?&token=${HF_TOKEN}"
#    "https://huggingface.co/neuroplus/skin-texture-style-v4d/resolve/main/skin%20texture%20style%20v4d.safetensors?&token=${HF_TOKEN}"
#    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-LoRA-add-details/resolve/main/FLUX-dev-lora-add_details.safetensors?&token=${HF_TOKEN}"
#    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-LoRA-add-details/resolve/main/FLUX-dev-lora-add_details.safetensors?&token=${HF_TOKEN}"
#    "https://huggingface.co/XLabs-AI/flux-RealismLora/resolve/main/lora.safetensors?&token=${HF_TOKEN}"
#    "https://huggingface.co/Fantasyworld/Skin_tone_slider_Flux1.d/resolve/main/Skin_Tone_Slider_flux_v1.safetensors?&token=${HF_TOKEN}"

#ILLUSTRATION (FLUX) - V3.1.safetensors
    "https://civitai.com/api/download/models/1319198?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#Illustration Comic book_(FLUX)_06.safetensors
    "https://civitai.com/api/download/models/1815533?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#aidmaRealisticSkin-FLUX-v0.1.safetensors
    "https://civitai.com/api/download/models/1301668?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"

#aidmaRealisticSkin-FLUX-v0.1.safetensors
    "https://civitai.com/api/download/models/1301668?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#flux_realism_lora.safetensors
    "https://civitai.com/api/download/models/706528?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/712589?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/737992?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#BreastShaper_splendid_droplets_Flux_v3.0-000009.safetensors
    "https://civitai.com/api/download/models/824319?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/825288?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/893799?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/910095?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#breast-size2.safetensors
    "https://civitai.com/api/download/models/932482?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1751485?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#aidmaImageUprader-FLUX-v0.3.safetensors
    "https://civitai.com/api/download/models/984672?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    aidmaFluxProUltra-FLUX-v0.1.safetensors
    "https://civitai.com/api/download/models/1115050?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    aidmaReduxStyle-FLUX-V0.1.safetensors
    "https://civitai.com/api/download/models/1188438?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1875852?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#SameFace_Fix.safetensors
    "https://civitai.com/api/download/models/857446?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1633249?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#nosepiercing-pin-right-f1.safetensors
#    "https://civitai.com/api/download/models/1885706?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#nosepiercing-ring-right-f1.safetensors
#    "https://civitai.com/api/download/models/1885663?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#AntiBlur.safetensors
    "https://civitai.com/api/download/models/824514?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    aidmaSeeThrough-FLUX-V0.1.safetensors
    "https://civitai.com/api/download/models/936132?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/735960?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1909850?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1969712?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1956947?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/827325?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://huggingface.co/comfyanonymous/flux_RealismLora_converted_comfyui/resolve/main/flux_realism_lora.safetensors"
#    "https://civitai.com/api/download/models/755852?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1782533?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1351520?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1595505?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/909869?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1121642?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#Eye_Detail_Flux_Lora_-_Inpainting.safetensors
    "https://civitai.com/api/download/models/1001942?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    nosepiercing-pin-right-f1.safetensors.0
#    "https://civitai.com/api/download/models/1885706?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1943855?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1553172?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1245565?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/1278791?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/889659?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#expression_helper2.0.safetensors
#    "https://civitai.com/api/download/models/1023284?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/2087149?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/2063397?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/2086721?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#    "https://civitai.com/api/download/models/2124636?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#flux_vividizer.safetensors
    "https://civitai.com/api/download/models/742813?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#d351_d4rk_Desi_Espresso_Flux_Kohya_V3.safetensors
    "https://civitai.com/api/download/models/1612200?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
# SlickedBackHighPonyTail_Flux.safetensors
    "https://civitai.com/api/download/models/2252207?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#Detailed_imperfect_skin_faces_and_torso_for_FLUX-000025.safetensors
    "https://civitai.com/api/download/models/1066446?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#HASSELBLAD_x2d.safetensors
    "https://civitai.com/api/download/models/2326452?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#FLUX.1-Turbo-Alpha.safetensors
    "https://civitai.com/api/download/models/981081?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"

    "https://huggingface.co/ali-vilab/ACE_Plus/resolve/main/portrait/comfyui_portrait_lora64.safetensors"
#FLUX-_SFW_Busty.
#Detailed_Hands-000001.safetensors.0
    "https://civitai.com/api/download/models/1003317?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#Hand v2.safetensors
    "https://civitai.com/api/download/models/804967?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#Pandora-RAWr.safetensors
    "https://civitai.com/api/download/models/1943855?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#face-detailer.safetensors
    "https://civitai.com/api/download/models/1875852?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#FC Flux Perfect Busts.safetensors
    "https://civitai.com/api/download/models/1782533?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
#d351_Coffee_Krea_Kohya_V1_Unchained_prodigy-000012.safetensors
    "https://civitai.com/api/download/models/2402710?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
)


ESRGAN_MODELS=(
    "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth"
)


UPSCALE_MODELS=(
    "https://huggingface.co/Kim2091/UltraSharpV2/resolve/main/4x-UltraSharpV2.pth"
    "https://huggingface.co/Kim2091/UltraSharpV2/resolve/main/4x-UltraSharpV2.safetensors"
    "https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth"
    "https://huggingface.co/Akumetsu971/SD_Anime_Futuristic_Armor/resolve/main/4x_NMKD-Siax_200k.pth"
    "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Superscale-SP_178000_G.pth"
    "https://huggingface.co/mp3pintyo/upscale/resolve/main/4xNomos2_hq_drct-l.pth"
    "https://github.com/starinspace/StarinspaceUpscale/releases/download/Models/4xPurePhoto-span.pth"
    "https://huggingface.co/notkenski/upscalers/resolve/main/1xSkinContrast-High-SuperUltraCompact.pth"
    "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NickelbackFS_72000_G.pth"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/Kijai/flux-fp8/resolve/main/flux_shakker_labs_union_pro-fp8_e4m3fn.safetensors"
#    "https://civitai.com/api/download/models/1307407?type=Model&format=SafeTensor&token=${CIVITAI_TOKEN}"
    "https://huggingface.co/jasperai/Flux.1-dev-Controlnet-Upscaler/resolve/main/diffusion_pytorch_model.safetensors"
)


ULTRALYTICS_SEGS_MODELS=(
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8n_v2.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov9c.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt"
  "https://huggingface.co/jags/yolov8_model_segmentation-set/resolve/main/skin_yolov8m-seg_400.pt"
  "https://civitai.com/api/download/models/1324778?type=Model&format=PickleTensor"
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

#    if provisioning_has_valid_hf_token; then
#        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors")
#        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors")
#    else
#        UNET_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors")
#        VAE_MODELS+=("https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors")
#        sed -i 's/flux1-dev\.safetensors/flux1-schnell.safetensors/g' /opt/ComfyUI/web/scripts/defaultGraph.js
#    fi

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
        "${COMFYUI_DIR}/custom_nodes/ComfyUI_essentials.git/fonts/" \
        "${FONTS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/custom_nodes/ComfyUI_essentials/fonts/" \
        "${FONTS[@]}"
    provisioning_get_models \
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-Custom-Scripts.git/web/js/assets/" \
        "${MP3[@]}"
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
if [[ ! -f /workspace/.noprovisioning ]]; then
    provisioning_start
    pip install -r "${WORKSPACE}/ComfyUI/requirements.txt"
fi

/workspace/environments/python/comfyui/bin/python -m pip install -r /workspace/ComfyUI/requirements.txt
#opencv-contrib-python
provisioning_get_default_workflow

## while loop to check queue every 60 seconds


nohup  socat TCP-LISTEN:18000,fork,reuseaddr TCP:127.0.0.1:1111 &
nohup  socat TCP-LISTEN:19000,fork,reuseaddr TCP:127.0.0.1:18188 &
nohup  socat TCP-LISTEN:20000,fork,reuseaddr TCP:127.0.0.1:18384 &

# * * * * * /workspace/scripts/submit_prompt.sh >> /workspace/crontab.log
# * * * * * /workspace/submit_prompt.sh >> /workspace/crontab.log
chmod +x ${WORKSPACE}/scripts/submit_prompt.sh

JOB="* * * * * ${WORKSPACE}/scripts/submit_prompt.sh >> ${WORKSPACE}/crontab.log"

crontab -l 2>/dev/null | {
    grep -q "${WORKSPACE}/scripts/submit_prompt.sh" || echo "${JOB}"
} | crontab -


service cron start &



supervisorctl stop 'cf_quicktunnel:="cf_quicktunnel_0"'
supervisorctl stop 'cf_quicktunnel:="cf_quicktunnel_1"'
supervisorctl stop 'cf_quicktunnel:="cf_quicktunnel_2"'
supervisorctl stop 'cf_quicktunnel:="cf_quicktunnel_3"'
supervisorctl stop 'jupyter'
