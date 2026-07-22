#!/usr/bin/env python3
"""Transform a ComfyUI workflow export into API-style node payload.

Current focus:
- Promote node ids to top-level keys.
- Convert `type` -> `class_type`.
- Build link-based `inputs`.
- Resolve `GetNode`/`SetNode` passthrough links.
- Apply `extra.ue_links` virtual links.
- Drop virtual/controller nodes from output.

Usage:
    python workflow_to_payload.py workflows/latest.json -o workflows/latest_payload.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

MUTED_MODES = {2, 4}  # NEVER, BYPASS
VIRTUAL_NODE_TYPES = {"GetNode", "SetNode", "Anything Everywhere"}

LinkRecord = list[Any]
Node = dict[str, Any]
NodeRef = tuple[str, int]


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
                try:
                    return int(link_id)
                except (TypeError, ValueError):
                    continue
    return None


def _extract_var_name(node: Node) -> str | None:
    values = node.get("widgets_values")
    if isinstance(values, list) and values:
        name = values[0]
        if isinstance(name, str) and name:
            return name
    return None


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
    if _is_muted(src_node):
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

    # Heuristic: INT UE links are commonly seed/noise_seed controllers.
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


def transform_workflow_to_payload(workflow: dict[str, Any]) -> dict[str, dict[str, Any]]:
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

    # First pass: provisional direct resolution (without GetNode indirection).
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

        # If chained through another SetNode, reuse it when available.
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

    # Resolve GetNode value sources via matching SetNode variable names.
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

    # Second pass: SetNodes that receive from GetNode can now resolve.
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

    # Virtual UE links (from Anything Everywhere / Use Everywhere style controllers).
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

    for node_id in sorted(nodes_by_id):
        node = nodes_by_id[node_id]
        if _is_muted(node) or _is_virtual(node):
            continue

        node_inputs = node.get("inputs") if isinstance(node.get("inputs"), list) else []
        inputs_obj: dict[str, Any] = {}

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
            "class_type": str(node.get("type", "")),
            "_meta": {
                "title": str(node.get("title") or node.get("type") or "")
            },
        }

    # Clean dangling refs (mirrors frontend cleanup).
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert workflow to API-like payload (GetNode/SetNode + ue_links resolved)"
    )
    parser.add_argument("input", type=Path, help="Path to ComfyUI workflow JSON")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output file path (defaults to stdout)",
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
    payload = transform_workflow_to_payload(workflow)

    output_text = json.dumps(payload, ensure_ascii=False, indent=args.indent)

    if args.output:
        args.output.write_text(output_text + "\n", encoding="utf-8")
    else:
        print(output_text)


if __name__ == "__main__":
    main()
