
# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
URL="http://localhost:18188"
WORKFLOW_FILE="${1}"

LOG_TS=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$LOG_TS] === Workflow submission started ==="


# --- Generate random seed (safe range under 2^50) ---
max_seed=1125899906842624
random_seed=$(( RANDOM * RANDOM ))
random_seed=$(( random_seed % max_seed ))
echo "[$LOG_TS] 🎲 Using random seed: $random_seed"

# --- Identify removable node types ---
REMOVE_TYPES='["PreviewAny", "ShowText|pysssss"]'

random_seed="-1"

TMP_FILE="$(mktemp)".json
# --- Replace numeric seeds ---
jq --argjson new_seed "$random_seed" '
  walk(
    if type == "object" and has("seed") and (.seed | type) == "number"
    then .seed = $new_seed
    else .
    end
  )
' "$WORKFLOW_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$WORKFLOW_FILE" && TMP_FILE="$(mktemp)".json

# --- Remove unwanted nodes ---
jq '
  delpaths(
    [ paths as $p
      | select(
          ($p | last) == "class_type"
          and (getpath($p) == "PreviewAny" or getpath($p) == "ShowText|pysssss" or getpath($p) == "Image Comparer (rgthree)")
        )
      | $p[:-1]
    ]
  )
' "$WORKFLOW_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$WORKFLOW_FILE"