#!/bin/bash
set -e
find "${WORKSPACE}ComfyUI/temp/" -type f -name "*.png" -mmin +10 -delete
mkdir -p "${WORKSPACE}ComfyUI/Inputs/Processed/Failed/"
find "${WORKSPACE}ComfyUI/processing/" -type f -name "*.*" -mmin +15 -exec mv {} "${WORKSPACE}ComfyUI/Inputs/Processed/Failed/" \;
mkdir -p "${WORKSPACE}ComfyUI/Inputs/Downloaded/Parked/"
mkdir -p "${WORKSPACE}ComfyUI/Inputs/Next/Park/"
find "${WORKSPACE}ComfyUI/Inputs/Next/Park" -type f \( \
  -iname "*.png" -o \
  -iname "*.jpeg" -o \
  -iname "*.jpg" -o \
  -iname "*.webp" \
\) -exec mv -vn -t "${WORKSPACE}ComfyUI/Inputs/Downloaded/Parked/" {} +

# --- Skip execution if .skip file exists ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.skip" ]; then
  LOG_TS=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$LOG_TS] ⚠️  Skip file detected at $SCRIPT_DIR/.skip — skipping execution."
  exit 0
fi

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
URL="http://localhost:18188"
WORKFLOW_FILE="$SCRIPT_DIR/Workflow_API.json"
UPDATED_FILE="$SCRIPT_DIR/Workflow_API_updated.json"
LOG_TS=$(date '+%Y-%m-%d %H:%M:%S')

# -- Download latest workflow file
DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/0007_3MWorkflow_API.json"
#DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/0003_3MWorkflow_API.json"
# DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/006_KRWorkflow_API.json"
#DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/004_KFWorkflow_API.json"
#DEFAULT_WORKFLOW="https://raw.githubusercontent.com/sk-palani/vastai/refs/heads/main/workflows/35_FULL_Workflow_API.json"

wget -O "${WORKFLOW_FILE}" "${DEFAULT_WORKFLOW}"
echo "Hash : " "$(md5sum ${WORKFLOW_FILE})"
jq -c . "${WORKFLOW_FILE}" > "${UPDATED_FILE}"
cp "${UPDATED_FILE}" "${WORKFLOW_FILE}"

echo "[$LOG_TS] === Workflow submission started ==="

# --- Generate random seed (safe range under 2^50) ---
max_seed=1125899906842624
random_seed=$(( RANDOM * RANDOM ))
random_seed=$(( random_seed % max_seed ))
echo "[$LOG_TS] 🎲 Using random seed: $random_seed"

target_mega_pixel="1.6"
vram_mb=0
if command -v nvidia-smi >/dev/null 2>&1; then
  vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | sort -nr | head -n 1)
fi
case "${vram_mb:-0}" in
  *[!0-9]*|"") vram_mb=0 ;;
esac
if [ "$vram_mb" -gt 24000 ]; then
  target_mega_pixel="2.0"
fi
echo "[$LOG_TS] 🖼️  Using target megapixel: $target_mega_pixel (VRAM: ${vram_mb:-unknown} MiB)"


# --- Identify removable node types ---
REMOVE_TYPES='["PreviewAny", "ShowText|pysssss"]'

## --- List nodes matching removal types ---
#echo "[$LOG_TS] 🔍 Checking for removable nodes..."
#removable_nodes=$(jq -r --argjson types "$REMOVE_TYPES" '
#  to_entries[]
#  | select(.value.class_type as $ct | $types | index($ct))
#  | .key
#' "$WORKFLOW_FILE")
#
#if [ -n "$removable_nodes" ]; then
#  echo "[$LOG_TS] 🧹 Found nodes to remove: $removable_nodes"
#else
#  echo "[$LOG_TS] ✅ No removable nodes found."
#fi

TMP_FILE="$(mktemp)"
# --- Replace numeric seeds and target megapixel settings ---
jq --argjson new_seed "$random_seed" \
   --arg target_mega_pixel "$target_mega_pixel" '
  walk(
    if type == "object" then
      (if has("seed") and (.seed | type) == "number"
       then .seed = $new_seed
       else .
       end)
      | (if has("megapixel")
         then .megapixel = $target_mega_pixel
         else .
         end)
    else .
    end
  )
' "$WORKFLOW_FILE" > "$UPDATED_FILE"

# --- Remove unwanted nodes ---
jq -c '
  delpaths(
    [ paths as $p
      | select(
          ($p | last) == "class_type"
          and (getpath($p) == "PreviewAny" or getpath($p) == "ShowText|pysssss" or getpath($p) == "Image Comparer (rgthree)")
        )
      | $p[:-1]
    ]
  )
' "$UPDATED_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$UPDATED_FILE"

# --- Convert UE-style virtual links into real links and export a ComfyUI API prompt ---
# python3 "$SCRIPT_DIR/scripts/convert_ue_to_real_links.py" --api "$UPDATED_FILE" "$UPDATED_FILE"

echo "[$LOG_TS] 🔄 Updated seeds, removed unwanted nodes, and exported a ComfyUI API prompt in $UPDATED_FILE"

# --- Check queue status ---
total=$(curl -s "$URL/queue" | jq '[.queue_running, .queue_pending] | add | length')

if [ "$total" -gt 1 ]; then
  echo "[$LOG_TS] 🚫 Queue not empty (total: $total). Skipping submission."
  echo "[$LOG_TS] === End ==="
  exit 0
fi

# --- Clear History ---
echo "[$LOG_TS] 🧹 Clearing history (ignoring failures)..."
curl -v -X POST "$URL/api/history" \
     -H "Content-Type: application/json" \
     -d '{"clear":true}' > /dev/null 2>&1 || true


# --- Submit workflow ---
echo "[$LOG_TS] 📤 Submitting workflow from $UPDATED_FILE ..."
#response=$(jq -n --argfile w "$UPDATED_FILE" '{prompt: $w}' | \
response=$(jq -n --slurpfile w "$UPDATED_FILE" '{prompt: $w[0]}' | \
  curl -s -X POST "$URL/prompt" \
       -H "Content-Type: application/json" \
       -d @-)

echo "[$LOG_TS] ✅ Workflow submitted successfully."
echo "$response" | jq '.' | sed "s/^/[$LOG_TS] /"

echo "[$LOG_TS] === End ==="
