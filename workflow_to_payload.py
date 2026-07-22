#!/usr/bin/env python3
"""Transform a ComfyUI workflow export into API-style node payload.

Key behaviors:
- Promote node ids to top-level keys.
- Convert `type` -> `class_type`.
- Build `inputs` from links + widget values.
- Resolve `GetNode`/`SetNode` passthrough links.
- Apply `extra.ue_links` virtual links.
- Drop virtual/controller nodes from output.

Usage:
    python workflow_to_payload.py workflows/latest.json -o workflows/latest_payload.json
    python workflow_to_payload.py workflows/latest.json --object-info http://localhost:8188/object_info
"""

from __future__ import annotations

import argparse
import json
import re
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

MUTED_MODES = {2, 4}  # NEVER, BYPASS
VIRTUAL_NODE_TYPES = {"GetNode", "SetNode", "Anything Everywhere"}
NON_SERIALIZED_WIDGET_NAMES = {"control_after_generate"}

# Frontend-only/non-executable nodes to drop from API payload.
# Keep this list regex-based so it is easy to extend without changing logic.
REMOVE_CLASS_TYPE_REGEXES = [
    r"^PreviewAny$",
    r"^ShowText\|pysssss$",
    r"^ShowText\|LP$",
    r"^PreviewImage$",
    r"^Bookmark \(rgthree\)$",
    r"^Fast Groups Muter \(rgthree\)$",
    r"^Reroute$",
    r"^Image Comparer \(rgthree\)$",
]
REMOVE_CLASS_TYPE_PATTERNS = [re.compile(rx) for rx in REMOVE_CLASS_TYPE_REGEXES]

LinkRecord = list[Any]
Node = dict[str, Any]
NodeRef = tuple[str, int]
ObjectInfo = dict[str, Any]
WidgetHints = dict[str, list[str]]
WidgetProfiles = dict[str, dict[str, Any]]


# -----------------------------
# Generic helpers
# -----------------------------
def _node_id(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _is_muted(node: Node) -> bool:
    return int(node.get("mode", 0)) in MUTED_MODES


def _is_virtual(node: Node) -> bool:
    return str(node.get("type", "")) in VIRTUAL_NODE_TYPES


def _first_valid_input_link(node: Node) -> int | None:
    for inp in node.get("inputs") or []:
        if isinstance(inp, dict):
            link_id = inp.get("link")
            if link_id is not None:
                parsed = _node_id(link_id)
                if parsed is not None:
                    return parsed
    return None


def _extract_var_name(node: Node) -> str | None:
    values = node.get("widgets_values")
    if isinstance(values, list) and values:
        name = values[0]
        if isinstance(name, str) and name:
            return name
    return None


# -----------------------------
# Widget mapping
# -----------------------------
def _iter_object_info_inputs(node_def: dict[str, Any]):
    input_def = node_def.get("input")
    if not isinstance(input_def, dict):
        return

    for section in ("required", "optional"):
        section_def = input_def.get(section)
        if isinstance(section_def, dict):
            for name, spec in section_def.items():
                yield name, spec


def _is_widget_input_spec(spec: Any) -> bool:
    """Heuristic for whether an object_info input corresponds to a serialized widget value."""
    if not isinstance(spec, (list, tuple)) or not spec:
        return False

    type_spec = spec[0]
    meta = spec[1] if len(spec) > 1 and isinstance(spec[1], dict) else {}

    # Combo-like => widget.
    if isinstance(type_spec, list):
        return True

    # forceInput sockets without defaults are usually pure links (no widget value).
    if meta.get("forceInput") is True and "default" not in meta:
        return False

    if isinstance(type_spec, str):
        primitive = {"INT", "FLOAT", "STRING", "BOOLEAN"}
        if type_spec in primitive:
            return True

        # Most all-caps custom types are link/socket data types.
        if type_spec.isupper() and "default" not in meta:
            return False

    # Metadata implying a widget value exists.
    widgetish_meta_keys = {
        "default",
        "min",
        "max",
        "step",
        "multiline",
        "placeholder",
        "dynamicPrompts",
        "choices",
    }
    return any(k in meta for k in widgetish_meta_keys)


def _get_widget_names_for_class_type(
    class_type: str,
    object_info: ObjectInfo | None,
    widget_hints: WidgetHints | None,
    cache: dict[str, list[str]],
) -> list[str]:
    if class_type in cache:
        return cache[class_type]

    names: list[str] = []

    if object_info and isinstance(object_info.get(class_type), dict):
        node_def = object_info[class_type]
        for name, spec in _iter_object_info_inputs(node_def):
            if name in NON_SERIALIZED_WIDGET_NAMES:
                continue
            if _is_widget_input_spec(spec):
                names.append(name)

    # If object_info did not yield anything, use local API-file hints.
    if not names and widget_hints and class_type in widget_hints:
        names = list(widget_hints[class_type])

    cache[class_type] = names
    return names


def _fallback_widget_names(class_type: str, widget_count: int) -> list[str]:
    """Light fallback when object_info is unavailable."""
    if widget_count == 1:
        if class_type in {
            "PrimitiveString",
            "PrimitiveBoolean",
            "PrimitiveInt",
            "INTConstant",
            "FloatConstant",
            "Seed (rgthree)",
        }:
            return ["value"]
        if class_type == "LoadImage":
            return ["image"]
        if class_type == "Text Multiline":
            return ["text"]
        if class_type in {"VAELoader", "DualCLIPLoader", "UNETLoader"}:
            return [
                {
                    "VAELoader": "vae_name",
                    "DualCLIPLoader": "clip_name1",
                    "UNETLoader": "unet_name",
                }[class_type]
            ]

    if class_type == "StringConstantMultiline" and widget_count >= 1:
        return ["string", "strip_newlines"][:widget_count]

    return []


def _value_type_tag(value: Any) -> str:
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "float"
    if isinstance(value, str):
        return "str"
    if isinstance(value, list):
        return "list"
    if isinstance(value, dict):
        return "dict"
    if value is None:
        return "none"
    return type(value).__name__


def _is_bool_like_key(key: str) -> bool:
    lk = key.lower()
    return any(
        token in lk
        for token in [
            "case_insensitive",
            "enable",
            "show_",
            "keep_",
            "overwrite",
            "lossless",
            "embed_",
            "optimize",
            "normalize",
            "preserve",
            "return_",
            "include_",
            "multiline",
            "dotall",
            "log",
            "invert",
            "condition",
        ]
    )


def _is_numeric_like_key(key: str) -> bool:
    lk = key.lower()
    return any(
        token in lk
        for token in [
            "seed",
            "step",
            "cfg",
            "width",
            "height",
            "padding",
            "quality",
            "dpi",
            "index",
            "strength",
            "denoise",
            "scale",
            "offset",
            "rotation",
            "gamma",
            "blur",
            "top_k",
            "top_p",
            "min_p",
            "max_tokens",
            "batch",
            "count",
            "temperature",
            "threshold",
            "percent",
            "factor",
            "size",
            "radius",
            "shift",
            "volume",
            "opacity",
        ]
    )


def _score_value_for_key(
    class_type: str,
    key: str,
    value: Any,
    widget_profiles: WidgetProfiles | None,
) -> float:
    score = 0.0
    value_tag = _value_type_tag(value)

    class_profile = widget_profiles.get(class_type, {}) if widget_profiles else {}
    key_types = class_profile.get("key_types", {}).get(key, {}) if class_profile else {}
    key_values = class_profile.get("key_values", {}).get(key, {}) if class_profile else {}

    if key_types:
        if value_tag in key_types:
            score += 4.0
        elif value_tag == "int" and "float" in key_types:
            score += 2.0
        elif value_tag == "float" and "int" in key_types:
            score += 1.5
        else:
            score -= 4.0

    if key_values and isinstance(value, (str, int, float, bool)):
        if value in key_values:
            score += 2.0

    # Name-based type priors.
    if _is_bool_like_key(key):
        if isinstance(value, bool):
            score += 2.5
        elif isinstance(value, str) and value in {"true", "false"}:
            score += 1.0
        else:
            score -= 2.0
    elif _is_numeric_like_key(key):
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            score += 2.0
        else:
            score -= 1.0
    else:
        if isinstance(value, str):
            score += 0.5

    return score


def _skip_penalty(value: Any) -> float:
    if value is None:
        return 0.1
    if value == "":
        return 0.2
    if isinstance(value, str) and value in {"fixed", "increment", "decrement", "randomize"}:
        return 0.6
    return -0.2


def _align_values_to_keys(
    class_type: str,
    keys: list[str],
    values: list[Any],
    widget_profiles: WidgetProfiles | None,
) -> tuple[list[Any] | None, float]:
    """Choose a subsequence of values that best matches key order."""
    n = len(keys)
    m = len(values)
    if n == 0:
        return [], 0.0
    if m < n:
        return None, -1e9

    neg_inf = -1e18
    dp = [[neg_inf] * (m + 1) for _ in range(n + 1)]
    take = [[False] * (m + 1) for _ in range(n + 1)]

    dp[0][0] = 0.0
    for j in range(1, m + 1):
        dp[0][j] = dp[0][j - 1] + _skip_penalty(values[j - 1])

    for i in range(1, n + 1):
        for j in range(1, m + 1):
            # Skip current value.
            best_score = dp[i][j - 1] + _skip_penalty(values[j - 1])
            best_take = False

            # Take current value for current key.
            prev = dp[i - 1][j - 1]
            if prev > neg_inf / 2:
                cand = prev + _score_value_for_key(class_type, keys[i - 1], values[j - 1], widget_profiles)
                if cand > best_score:
                    best_score = cand
                    best_take = True

            dp[i][j] = best_score
            take[i][j] = best_take

    if dp[n][m] <= neg_inf / 2:
        return None, -1e9

    selected: list[Any] = []
    i, j = n, m
    while i > 0 and j > 0:
        if take[i][j]:
            selected.append(values[j - 1])
            i -= 1
            j -= 1
        else:
            j -= 1

    if i != 0:
        return None, -1e9

    selected.reverse()
    return selected, dp[n][m]


def _is_potential_widget_input_slot(input_def: dict[str, Any]) -> bool:
    slot_type = str(input_def.get("type", ""))
    return slot_type in {"STRING", "INT", "FLOAT", "BOOLEAN", "NUMBER", "COMBO"}


def _generate_inserted_sequences(base_seq: list[str], inserts: list[str], max_variants: int = 96) -> list[list[str]]:
    """Generate ordered insertion variants (preserving insert order)."""
    variants: list[list[str]] = []

    def rec(seq: list[str], insert_idx: int, min_pos: int) -> None:
        if len(variants) >= max_variants:
            return
        if insert_idx >= len(inserts):
            variants.append(seq)
            return

        name = inserts[insert_idx]
        for pos in range(min_pos, len(seq) + 1):
            next_seq = seq[:pos] + [name] + seq[pos:]
            rec(next_seq, insert_idx + 1, pos + 1)
            if len(variants) >= max_variants:
                return

    rec(list(base_seq), 0, 0)
    return variants


def _augment_sequence_with_linked_inputs(
    base_seq: list[str],
    node: Node,
    widget_value_count: int,
) -> list[list[str]]:
    extra = widget_value_count - len(base_seq)
    if extra <= 0:
        return []

    node_inputs = node.get("inputs") if isinstance(node.get("inputs"), list) else []
    linked_insertable: list[str] = []

    for inp in node_inputs:
        if not isinstance(inp, dict):
            continue
        name = inp.get("name")
        if not isinstance(name, str) or not name:
            continue

        if inp.get("link") is not None and name not in base_seq and _is_potential_widget_input_slot(inp):
            linked_insertable.append(name)

    if not linked_insertable:
        return []

    selected = linked_insertable[:extra]
    if not selected:
        return []

    return _generate_inserted_sequences(base_seq, selected)


def _get_widget_sequence_candidates(
    class_type: str,
    node: Node,
    widget_value_count: int,
    object_info: ObjectInfo | None,
    widget_hints: WidgetHints | None,
    widget_profiles: WidgetProfiles | None,
    cache: dict[str, list[str]],
) -> list[list[str]]:
    candidates: list[list[str]] = []

    # 1) object_info-derived order (usually best when available).
    oi_names = _get_widget_names_for_class_type(class_type, object_info, None, cache)
    if oi_names:
        candidates.append(list(oi_names))

    # 2) learned sequences from API payload files.
    class_profile = widget_profiles.get(class_type, {}) if widget_profiles else {}
    seq_counter = class_profile.get("sequences", {}) if class_profile else {}
    if isinstance(seq_counter, dict):
        sorted_seqs = sorted(seq_counter.items(), key=lambda kv: (-len(kv[0]), -kv[1]))
        for seq, _count in sorted_seqs:
            candidates.append(list(seq))

    # 3) collapsed hint fallback.
    if widget_hints and class_type in widget_hints:
        candidates.append(list(widget_hints[class_type]))

    # Add linked-input-augmented variants for extra widget values.
    augmented_candidates: list[list[str]] = []
    for seq in candidates:
        augmented_variants = _augment_sequence_with_linked_inputs(seq, node, widget_value_count)
        if augmented_variants:
            augmented_candidates.extend(augmented_variants)

    candidates.extend(augmented_candidates)

    # Dedupe while preserving order.
    deduped: list[list[str]] = []
    seen: set[tuple[str, ...]] = set()
    for seq in candidates:
        key = tuple(seq)
        if not seq or key in seen:
            continue
        seen.add(key)
        deduped.append(seq)

    return deduped


def _augment_widget_names_with_seed_inputs(node: Node, widget_names: list[str], widget_values: list[Any]) -> list[str]:
    """Inject seed-like names from node input slots when hints miss linkable seed widgets."""
    if len(widget_names) >= len(widget_values):
        return widget_names

    node_inputs = node.get("inputs") if isinstance(node.get("inputs"), list) else []
    seed_candidates: list[str] = []
    for inp in node_inputs:
        if not isinstance(inp, dict):
            continue
        name = inp.get("name")
        if not isinstance(name, str):
            continue
        lname = name.lower()
        if "seed" in lname and name not in widget_names:
            seed_candidates.append(name)

    if not seed_candidates:
        return widget_names

    names = list(widget_names)
    for seed_name in seed_candidates:
        if len(names) >= len(widget_values):
            break

        # Common KSamplerAdvanced layout: add_noise, noise_seed, ...
        if names and names[0] == "add_noise":
            names.insert(1, seed_name)
        else:
            names.insert(0, seed_name)

    return names


def _strip_non_serialized_control_token(class_type: str, widget_names: list[str], widget_values: list[Any]) -> list[Any]:
    """Remove frontend-only control token when it appears in widgets_values."""
    values = list(widget_values)
    if len(values) != len(widget_names) + 1:
        return values

    control_tokens = {"fixed", "increment", "decrement", "randomize"}

    # Generic rule: if seed-like widget exists, token is often immediately after it.
    seed_idx = next((i for i, n in enumerate(widget_names) if "seed" in n.lower()), None)
    if seed_idx is not None:
        token_idx = seed_idx + 1
        if token_idx < len(values) and isinstance(values[token_idx], str) and values[token_idx] in control_tokens:
            del values[token_idx]
            return values

    # Extra fallback for known samplers.
    if class_type in {"KSampler", "KSamplerAdvanced"}:
        if len(values) > 2 and isinstance(values[2], str) and values[2] in control_tokens:
            del values[2]
            return values
        if len(values) > 1 and isinstance(values[1], str) and values[1] in control_tokens:
            del values[1]
            return values

    return values


# -----------------------------
# Link resolution
# -----------------------------
def _should_remove_class_type(class_type: str) -> bool:
    return any(pattern.search(class_type) for pattern in REMOVE_CLASS_TYPE_PATTERNS)


def _resolve_source_from_link(
    link_id: int,
    links_by_id: dict[int, LinkRecord],
    nodes_by_id: dict[int, Node],
    getnode_sources: dict[int, NodeRef],
    setnode_sources: dict[int, NodeRef],
) -> NodeRef | None:
    link = links_by_id.get(link_id)
    if not isinstance(link, list) or len(link) < 3:
        return None

    src_id = _node_id(link[1])
    src_slot = _node_id(link[2])
    if src_id is None or src_slot is None:
        return None

    src_node = nodes_by_id.get(src_id)
    if not isinstance(src_node, dict):
        return None

    src_type = str(src_node.get("type", ""))
    if src_type == "GetNode":
        return getnode_sources.get(src_id)
    if src_type == "SetNode":
        return setnode_sources.get(src_id)
    if src_type == "Anything Everywhere":
        return None
    if _is_muted(src_node) or _should_remove_class_type(src_type):
        return None

    return str(src_id), src_slot


def _resolve_ue_downstream_slot(node: Node, requested_slot: int, ue_type: str | None) -> int | None:
    inputs = node.get("inputs") or []
    if not isinstance(inputs, list) or not inputs:
        return None

    if 0 <= requested_slot < len(inputs):
        return requested_slot

    if not ue_type:
        return None

    candidates: list[int] = []
    for idx, inp in enumerate(inputs):
        if not isinstance(inp, dict):
            continue
        if str(inp.get("type", "")) == ue_type:
            candidates.append(idx)

    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]

    # Heuristic: INT UE links are usually seed/noise_seed controllers.
    if ue_type == "INT":
        seed_like = [
            idx
            for idx in candidates
            if isinstance(inputs[idx], dict)
            and isinstance(inputs[idx].get("name"), str)
            and "seed" in str(inputs[idx].get("name", "")).lower()
        ]
        if seed_like:
            return seed_like[-1]

    return candidates[-1]


# -----------------------------
# Main transform
# -----------------------------
def transform_workflow_to_payload(
    workflow: dict[str, Any],
    object_info: ObjectInfo | None = None,
    widget_hints: WidgetHints | None = None,
    widget_profiles: WidgetProfiles | None = None,
) -> dict[str, dict[str, Any]]:
    nodes = workflow.get("nodes")
    links = workflow.get("links")
    if not isinstance(nodes, list):
        raise ValueError("Input does not look like a ComfyUI workflow export: missing 'nodes' array")
    if not isinstance(links, list):
        raise ValueError("Input does not look like a ComfyUI workflow export: missing 'links' array")

    nodes_by_id: dict[int, Node] = {}
    for node in nodes:
        if not isinstance(node, dict):
            continue
        nid = _node_id(node.get("id"))
        if nid is None:
            continue
        nodes_by_id[nid] = node

    links_by_id: dict[int, LinkRecord] = {}
    for link in links:
        if isinstance(link, list) and link:
            lid = _node_id(link[0])
            if lid is not None:
                links_by_id[lid] = link

    # Resolve SetNode value sources by variable name.
    setnode_sources: dict[int, NodeRef] = {}
    latest_set_by_name: dict[str, NodeRef] = {}

    set_nodes = [
        n for n in nodes_by_id.values() if str(n.get("type", "")) == "SetNode" and not _is_muted(n)
    ]
    set_nodes.sort(key=lambda n: (int(n.get("order", 0)), int(n.get("id", 0))))

    # First pass: provisional direct resolution.
    for set_node in set_nodes:
        set_id = int(set_node["id"])
        input_link_id = _first_valid_input_link(set_node)
        if input_link_id is None:
            continue

        link = links_by_id.get(input_link_id)
        if not isinstance(link, list) or len(link) < 3:
            continue

        src_id = _node_id(link[1])
        src_slot = _node_id(link[2])
        if src_id is None or src_slot is None:
            continue

        src_node = nodes_by_id.get(src_id)
        if not isinstance(src_node, dict) or _is_muted(src_node):
            continue

        if str(src_node.get("type", "")) == "SetNode":
            src_ref = setnode_sources.get(src_id)
            if src_ref is None:
                continue
            setnode_sources[set_id] = src_ref
        elif str(src_node.get("type", "")) != "GetNode":
            setnode_sources[set_id] = (str(src_id), src_slot)

        var_name = _extract_var_name(set_node)
        if var_name and set_id in setnode_sources:
            latest_set_by_name[var_name] = setnode_sources[set_id]

    # Resolve GetNode sources via SetNode variable names.
    getnode_sources: dict[int, NodeRef] = {}
    for node in nodes_by_id.values():
        if str(node.get("type", "")) != "GetNode" or _is_muted(node):
            continue
        var_name = _extract_var_name(node)
        if not var_name:
            continue
        src_ref = latest_set_by_name.get(var_name)
        if src_ref is not None:
            getnode_sources[int(node["id"])] = src_ref

    # Second pass: SetNodes fed via GetNodes can now resolve.
    for set_node in set_nodes:
        set_id = int(set_node["id"])
        if set_id in setnode_sources:
            continue

        input_link_id = _first_valid_input_link(set_node)
        if input_link_id is None:
            continue

        src_ref = _resolve_source_from_link(
            input_link_id,
            links_by_id,
            nodes_by_id,
            getnode_sources,
            setnode_sources,
        )
        if src_ref is None:
            continue

        setnode_sources[set_id] = src_ref
        var_name = _extract_var_name(set_node)
        if var_name:
            latest_set_by_name[var_name] = src_ref

    # UE virtual links (Use Everywhere style controllers).
    ue_overrides: dict[tuple[int, int], NodeRef] = {}
    extra = workflow.get("extra")
    ue_links = extra.get("ue_links") if isinstance(extra, dict) else None
    if isinstance(ue_links, list):
        for entry in ue_links:
            if not isinstance(entry, dict):
                continue

            down_id = _node_id(entry.get("downstream"))
            down_slot = _node_id(entry.get("downstream_slot"))
            up_id = _node_id(entry.get("upstream"))
            up_slot = _node_id(entry.get("upstream_slot"))
            ue_type = entry.get("type")
            ue_type = str(ue_type) if ue_type is not None else None
            if None in {down_id, down_slot, up_id, up_slot}:
                continue

            down_node = nodes_by_id.get(down_id)
            if not isinstance(down_node, dict) or _is_muted(down_node):
                continue

            mapped_slot = _resolve_ue_downstream_slot(down_node, down_slot, ue_type)
            if mapped_slot is None:
                continue

            up_node = nodes_by_id.get(up_id)
            if not isinstance(up_node, dict) or _is_muted(up_node):
                continue

            src_ref: NodeRef | None
            up_type = str(up_node.get("type", ""))
            if up_type == "GetNode":
                src_ref = getnode_sources.get(up_id)
            elif up_type == "SetNode":
                src_ref = setnode_sources.get(up_id)
            elif up_type == "Anything Everywhere":
                src_ref = None
            else:
                src_ref = (str(up_id), up_slot)

            if src_ref is not None:
                ue_overrides[(down_id, mapped_slot)] = src_ref

    payload: dict[str, dict[str, Any]] = {}
    widget_name_cache: dict[str, list[str]] = {}

    for node_id in sorted(nodes_by_id):
        node = nodes_by_id[node_id]
        if _is_muted(node) or _is_virtual(node):
            continue

        class_type = str(node.get("type", ""))
        if _should_remove_class_type(class_type):
            continue

        inputs_obj: dict[str, Any] = {}

        # 1) Widget values (named).
        widget_values = node.get("widgets_values")
        if isinstance(widget_values, list):
            sequence_candidates = _get_widget_sequence_candidates(
                class_type,
                node,
                len(widget_values),
                object_info,
                widget_hints,
                widget_profiles,
                widget_name_cache,
            )

            if not sequence_candidates:
                fallback_names = _fallback_widget_names(class_type, len(widget_values))
                if fallback_names:
                    sequence_candidates = [fallback_names]

            linked_input_names = {
                str(inp.get("name"))
                for inp in (node.get("inputs") or [])
                if isinstance(inp, dict) and inp.get("link") is not None and isinstance(inp.get("name"), str)
            }

            best_names: list[str] | None = None
            best_values: list[Any] | None = None
            best_score = -1e18

            for names in sequence_candidates:
                aligned_values, score = _align_values_to_keys(
                    class_type,
                    names,
                    list(widget_values),
                    widget_profiles,
                )
                if aligned_values is None:
                    continue

                # Prefer candidates that don't force linked sockets to be scalar widget mappings.
                linked_scalar_penalty = 1.5 * sum(1 for k in names if k in linked_input_names)
                total_score = score - linked_scalar_penalty

                if total_score > best_score:
                    best_score = total_score
                    best_names = names
                    best_values = aligned_values

            if best_names and best_values:
                for name, value in zip(best_names, best_values):
                    inputs_obj[name] = value

        # 2) Link-based inputs (override widget values for same names).
        node_inputs = node.get("inputs") if isinstance(node.get("inputs"), list) else []
        for idx, input_def in enumerate(node_inputs):
            if not isinstance(input_def, dict):
                continue

            name = input_def.get("name")
            if not isinstance(name, str) or not name:
                continue

            ref = ue_overrides.get((node_id, idx))
            if ref is None:
                link_id = _node_id(input_def.get("link"))
                if link_id is not None:
                    ref = _resolve_source_from_link(
                        link_id,
                        links_by_id,
                        nodes_by_id,
                        getnode_sources,
                        setnode_sources,
                    )

            if ref is not None:
                inputs_obj[name] = [ref[0], ref[1]]

        payload[str(node_id)] = {
            "inputs": inputs_obj,
            "class_type": class_type,
            "_meta": {
                "title": str(node.get("title") or class_type)
            },
        }

    # Remove dangling refs to nodes omitted from payload.
    valid_ids = set(payload.keys())
    for node_data in payload.values():
        inputs = node_data.get("inputs", {})
        if not isinstance(inputs, dict):
            continue

        for key in list(inputs.keys()):
            val = inputs[key]
            if (
                isinstance(val, list)
                and len(val) == 2
                and isinstance(val[0], str)
                and val[0] not in valid_ids
            ):
                del inputs[key]

    return payload


# -----------------------------
# object_info loading
# -----------------------------
def _load_json_from_url(url: str, timeout: float = 3.0) -> Any:
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def load_object_info(source: str | None) -> ObjectInfo | None:
    candidates: list[str] = []
    if source:
        candidates.append(source)
    else:
        candidates.extend([
            "http://localhost:8188/object_info",
            "http://localhost:18188/object_info",
        ])

    for candidate in candidates:
        try:
            if candidate.startswith("http://") or candidate.startswith("https://"):
                data = _load_json_from_url(candidate)
            else:
                data = json.loads(Path(candidate).read_text(encoding="utf-8"))

            if isinstance(data, dict):
                return data
        except (OSError, urllib.error.URLError, json.JSONDecodeError):
            continue

    return None


def load_widget_profiles_from_api_files(input_workflow_path: Path) -> WidgetProfiles:
    """Learn widget-key sequences + value type profiles from existing *_API.json files."""
    workflows_dir = input_workflow_path.parent
    if not workflows_dir.exists() or not workflows_dir.is_dir():
        return {}

    profiles: WidgetProfiles = {}

    for api_file in workflows_dir.glob("*_API.json"):
        try:
            data = json.loads(api_file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue

        if not isinstance(data, dict):
            continue

        # Must look like API payload: {id: {inputs:{}, class_type:"..."}}
        sample_ok = False
        for v in data.values():
            if isinstance(v, dict) and isinstance(v.get("class_type"), str) and isinstance(v.get("inputs"), dict):
                sample_ok = True
                break
        if not sample_ok:
            continue

        for node in data.values():
            if not isinstance(node, dict):
                continue

            class_type = node.get("class_type")
            inputs = node.get("inputs")
            if not isinstance(class_type, str) or not isinstance(inputs, dict):
                continue

            class_profile = profiles.setdefault(
                class_type,
                {
                    "sequences": defaultdict(int),
                    "key_types": defaultdict(Counter),
                    "key_values": defaultdict(Counter),
                },
            )

            scalar_items: list[tuple[str, Any]] = []
            for key, value in inputs.items():
                if key.startswith("_"):
                    continue
                if not (isinstance(value, list) and len(value) == 2):
                    scalar_items.append((key, value))

            seq = tuple(key for key, _ in scalar_items)
            class_profile["sequences"][seq] += 1

            for key, value in scalar_items:
                class_profile["key_types"][key][_value_type_tag(value)] += 1
                if isinstance(value, (str, int, float, bool)):
                    class_profile["key_values"][key][value] += 1

    # Convert defaultdict/Counter to plain dicts.
    normalized: WidgetProfiles = {}
    for class_type, profile in profiles.items():
        normalized[class_type] = {
            "sequences": dict(profile.get("sequences", {})),
            "key_types": {k: dict(v) for k, v in profile.get("key_types", {}).items()},
            "key_values": {k: dict(v) for k, v in profile.get("key_values", {}).items()},
        }

    return normalized


def load_widget_hints_from_api_files(input_workflow_path: Path) -> WidgetHints:
    """Collapsed sequence hints (legacy/simple fallback)."""
    profiles = load_widget_profiles_from_api_files(input_workflow_path)
    collapsed: WidgetHints = {}

    for class_type, profile in profiles.items():
        seq_counter: dict[tuple[str, ...], int] = profile.get("sequences", {})
        if not seq_counter:
            continue
        # Prefer most informative sequence first (longest), then frequency.
        best_seq = max(seq_counter.items(), key=lambda kv: (len(kv[0]), kv[1]))[0]
        collapsed[class_type] = list(best_seq)

    return collapsed


# -----------------------------
# CLI
# -----------------------------
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert workflow to API-style payload (GetNode/SetNode + ue_links resolved)"
    )
    parser.add_argument("input", type=Path, help="Path to ComfyUI workflow JSON")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output file path (defaults to stdout)",
    )
    parser.add_argument(
        "--object-info",
        type=str,
        default=None,
        help="Object info JSON path or URL (e.g. http://localhost:8188/object_info)",
    )
    parser.add_argument(
        "--indent",
        type=int,
        default=2,
        help="JSON indentation level (default: 2)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    workflow = json.loads(args.input.read_text(encoding="utf-8"))
    object_info = load_object_info(args.object_info)
    widget_profiles = load_widget_profiles_from_api_files(args.input)
    widget_hints = load_widget_hints_from_api_files(args.input)
    payload = transform_workflow_to_payload(
        workflow,
        object_info=object_info,
        widget_hints=widget_hints,
        widget_profiles=widget_profiles,
    )

    output_text = json.dumps(payload, ensure_ascii=False, indent=args.indent)

    if args.output:
        args.output.write_text(output_text + "\n", encoding="utf-8")
    else:
        print(output_text)


if __name__ == "__main__":
    main()
