# AGENTS.md - VASTAI Codebase Guide

## Project Overview
**VASTAI** is a containerized ComfyUI deployment system for VAST.AI and RunPod GPU infrastructure. It manages AI image generation workflows using the FLUX.1 model family with extensive model support (LoRAs, upscalers, ControlNets).

**Core Purpose:** Define reproducible, scalable image generation pipelines with model provisioning, workflow management, and seed control for batch processing.

---

## Architecture & Data Flow

### 1. **Container Ecosystem**
- **Base Image:** AI Dock ComfyUI (`ai-dock/comfyui:pytorch-*-cuda-12.1.1`)
- **Orchestration:** `docker-compose.yml` - configures ComfyUI service with GPU, volumes, ports
- **Key Ports:** 8188 (ComfyUI API), 8888 (Jupyter), 2222 (SSH)
- **Workspace:** `/workspace` volume (persists models, outputs, metadata)

**Why:** Running ComfyUI in Docker abstracts infrastructure differences (bare metal vs RunPod vs VAST.AI) while enabling reproducible environments.

### 2. **Model Management Pipeline**
- **Entry:** `check.sh` - downloads & validates models from HuggingFace/CivitAI using checksums
- **Structure:** Models organized in `/workspace/ComfyUI/models/{unet,vae,clip,loras,upscalers,controlnets}`
- **Authentication:** HF_TOKEN, CIVITAI_TOKEN passed via environment
- **Download Strategy:** Uses `axel` (parallel) for CivitAI, `wget` (auth headers) for HuggingFace
- **Checksum Validation:** MD5 of last 100MB (not full file) for large models

**Why:** Checksums prevent re-downloads on container restarts; parallel downloads optimize bandwidth.

### 3. **Workflow Execution Flow**
```
FULL_Workflow_API.json (template)
        ↓
submit_prompt.sh (or clean.sh)
        ↓
Process with jq (replace seeds, remove preview nodes)
        ↓
POST /api/prompt → ComfyUI (localhost:8188)
        ↓
Generate images → /workspace/ComfyUI/Outputs/
```

**Key Details:**
- Workflows are numbered JSON node graphs: `{"1": {...}, "2": {...}, ...}`
- Each node has `inputs`, `class_type`, `_meta.title`
- Node connections use `[node_id, output_index]` references
- Seeds randomized per execution (`RANDOM * RANDOM % 2^50`)

---

## Project Patterns & Conventions

### 1. **Shell Script Provisioning**
**Files:** `config/provisioning/{vastai.sh,runpod.sh,container.sh}`
- **Pattern:** Define arrays of URLs, iterate with `provisioning_get_*()` functions
- **Token Handling:** Inline token injection (e.g., `?token=${CIVITAI_TOKEN}`)
- **Conditional Download:** Check `AUTO_UPDATE` flag before git pull/pip install
- **Pre-condition Functions:** `provisioning_has_valid_hf_token()` validates tokens before use

**Convention:** Master repo path is `sk-palani/vastai` (see `PROVISIONING_SCRIPT` in env.example)

### 2. **JSON Workflow Manipulation**
**Tool:** `jq` (JSON query language in bash)
- **Seed Replacement:** `walk(if .seed then .seed=$new_seed else . end)`
- **Node Deletion:** `delpaths([paths | select(...)])`  for conditional removal
- **Validation:** `jq -c . file.json` compacts & validates JSON

**Pattern:** Always pipe through `jq -c` before submission (removes previews, ensures valid JSON)

### 3. **Environment-Driven Configuration**
**File:** `env.example` (copy to `.env` for docker-compose)
- Token injection: `WEB_PASSWORD="{{ RUNPOD_SECRET_WEB_PASSWORD }}"` (replaced by RunPod at deploy time)
- ConfigMaps: `COMFYUI_DIR`, `WORKSPACE`, `WORKSPACE_SYNC` control runtime behavior
- Defaults in docker-compose: `${VAR_NAME:-default}`

**Key Vars:**
- `AUTO_UPDATE`: Skip git/pip updates if "false"
- `CIVITAI_TOKEN`, `HF_TOKEN`: Required for model downloads
- `PYTHON_VERSION`, `PYTORCH_VERSION`: Build args (rarely change)

### 4. **Model Dependency Structure**
**FLUX.1 Stack:**
1. **UNet:** `flux1-dev.safetensors` or `flux1-schnell.safetensors` (base model, 24GB or 14GB)
2. **Text Encoders:** `clip_l.safetensors` + `t5xxl_fp16.safetensors` (required, ~5GB total)
3. **VAE:** `ae.safetensors` (auto-encoder, ~1.3GB)
4. **Optional:** LoRAs, ControlNet Union, Redux style model

**Convention:** Conditional download based on token validity (`provisioning_has_valid_hf_token()`)

---

## Developer Workflows

### 1. **Local Testing**
```bash
# Copy env template
cp env.example .env

# Build & start container (builds image + runs service)
docker-compose up --build

# Access ComfyUI at http://localhost:8188
# Jupyter at http://localhost:8888
```

### 2. **Workflow Development**
- **Editor:** Export JSON from ComfyUI web UI → Copy to `workflows/`
- **Naming Convention:** `Workflow_*.json` for custom, `FULL_Workflow_API.json` for production
- **Testing:** Run via `submit_prompt.sh` after updating `WORKFLOW_FILE` path
- **Validation:** Use `clean.sh Workflow_test.json` to dry-run transformations

### 3. **Model Addition**
```bash
# Add to check.sh arrays (with checksums):
LORA_MODELS+=(
  "https://huggingface.co/org/model/resolve/main/model.safetensors?token=${HF_TOKEN}"
)

# Or add to vastai.sh for provisioning:
NODES+=(
  "https://github.com/user/custom-node-repo"
)
```

### 4. **Debugging**
- **ComfyUI Logs:** `docker exec vastai-supervisor tail -f /workspace/logs/comfyui.log`
- **Workflow Parse:** `jq . workflows/FULL_Workflow_API.json | less` (inspect node structure)
- **API Queue Status:** `curl http://localhost:8188/queue | jq .`
- **Node List:** `curl http://localhost:8188/object_info | jq 'keys'`

### 5. **Deployment to VAST.AI**
- Point `PROVISIONING_SCRIPT` in `.env` to GitHub URL: `https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/config/provisioning/vastai.sh`
- VAST.AI automatically executes `provisioning_start()` on container launch
- Models download in parallel during startup (~5-10 min for ~50GB)

---

## Critical Integration Points

### 1. **ComfyUI API (http://localhost:8188)**
- **`GET /queue`:** Returns `{queue_running: [], queue_pending: []}`
- **`POST /prompt`:** Submit workflow → returns `{prompt_id: "uuid", number: N}`
- **`POST /api/history`:** Clear completion history with `{"clear": true}`
- **Error Handling:** API returns 200 with error details in JSON (not HTTP error codes)

### 2. **Model Sources**
- **HuggingFace:** Supports Bearer token in URL query `?token=` OR header `Authorization: Bearer $HF_TOKEN`
- **CivitAI:** Requires `token=` query param in URL; `axel` handles resume/parallel
- **GitHub Gists:** Used for workflow templates (see `WORKFLOWS` array in `vastai.sh`)

### 3. **Cross-Component Communication**
- **Entry Script:** `submit_prompt.sh` reads `WORKFLOW_FILE`, modifies with `jq`, submits to API
- **Validation:** `check.sh` verifies model checksums before provisioning script runs
- **Skip Mechanism:** `.skip` file presence bypasses `submit_prompt.sh` execution (graceful pause)

---

## Common Pitfalls & Conventions

### 1. **Seed Management**
- **Fixed Seed:** Set `seed: -1` to use model's default (in clean.sh)
- **Random:** Use `RANDOM * RANDOM % max_seed` (avoid overflow)
- **Range:** Must be < 2^50 (1125899906842624) for safe representation

### 2. **Node Removal Patterns**
- **Always Remove:** PreviewAny, ShowText|pysssss, Image Comparer (rgthree)
- **Reason:** Preview nodes block queue in batch mode; submission fails server-side otherwise
- **Pattern:** Use `delpaths` with conditional selection on `class_type`

### 3. **Model Token Injection**
- URL must contain domain pattern: `huggingface.co`, `civitai.com`, or `raw.githubusercontent.com`
- Token injection happens in provisioning script conditionally (check domain first)
- **Warning:** Never commit `.env` with real tokens; use `.env.example` template

### 4. **Docker Volume Mounts**
- `./workspace:${WORKSPACE}` - make sure permissions allow container writes
- Read-only mounts like `./config/authorized_keys` use `:ro` flag
- In-dev mount: `/opt/ai-dock/api-wrapper` allows hot-reload of API wrapper

---

## Key Files Reference

| File | Purpose | Edit When |
|------|---------|-----------|
| `docker-compose.yml` | Container config, ports, volumes | Adding GPU, changing exposed ports |
| `env.example` | Build-time env vars | Changing default Python/PyTorch versions |
| `config/provisioning/vastai.sh` | VAST.AI provisioning | Adding models/nodes to auto-download |
| `workflows/FULL_Workflow_API.json` | Production workflow template | Image generation pipeline changes |
| `check.sh` | Model downloader with checksums | Adding new models to pre-cache |
| `submit_prompt.sh` | Workflow submitter + seed randomizer | Changing queue logic or node filter rules |
| `config/provisioning/custom_nodes.txt` | Custom node list (if used) | Extending ComfyUI with custom ops |

---

## How to Help the Codebase

1. **Adding Models:** Update `check.sh` OR provisioning script with URL + checksum; validate with `jq .` on workflows
2. **New Workflows:** Export from ComfyUI → validate JSON structure → test with `submit_prompt.sh`
3. **Custom Nodes:** Add GitHub URL to provisioning script; ensure `requirements.txt` exists in repo
4. **Debugging:** Check curl responses from `/queue` endpoint; inspect `_meta.title` for node identification

