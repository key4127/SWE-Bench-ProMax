#!/usr/bin/env python3
"""
Data inspector for shiyl_dev/clean-data.
Loads golden.json, eval.json, swe-format/all.json, merges by instance_id,
and provides a Streamlit UI for manual inspection of issues and patches.

Install: pip install streamlit
Run: streamlit run data_inspector.py --server.port 10888
"""

import json
from pathlib import Path

import streamlit as st

DATA_DIR = Path(__file__).resolve().parent / "data"


def load_and_merge() -> list[dict]:
    """Load all JSON files and merge by instance_id."""
    golden_path = DATA_DIR / "golden.json"
    eval_path = DATA_DIR / "eval.json"
    all_path = DATA_DIR / "swe-format" / "all.json"

    with open(golden_path) as f:
        golden = {x["instance_id"]: x for x in json.load(f)}

    with open(eval_path) as f:
        eval_data = json.load(f)

    with open(all_path) as f:
        all_data = json.load(f)

    merged = []
    for item in all_data:
        iid = item["instance_id"]
        rec = dict(item)
        if iid in eval_data:
            rec["dockerfile"] = eval_data[iid].get("dockerfile", "")
            rec["eval_script"] = eval_data[iid].get("eval_script", "")
            rec["setup_scripts"] = eval_data[iid].get("setup_scripts", {})
        if iid in golden:
            for k, v in golden[iid].items():
                if k not in rec:
                    rec[k] = v
        merged.append(rec)

    return merged


@st.cache_data
def get_data():
    return load_and_merge()


def main():
    st.set_page_config(page_title="Clean Data Inspector", layout="wide")
    st.title("Data Inspector")
    st.caption("Manual inspection of issues and patches")

    data = get_data()

    # Sidebar: filters (cascading: Language → Repository)
    st.sidebar.header("Filters")
    languages = sorted({x.get("language", "unknown") for x in data})
    lang_filter = st.sidebar.multiselect("Language", languages, default=[])

    # After language filter, limit available repos to those with matching language
    lang_filtered = data
    if lang_filter:
        lang_filtered = [x for x in lang_filtered if x.get("language") in lang_filter]
    repos = sorted({x["repo"] for x in lang_filtered})

    repo_filter = st.sidebar.multiselect("Repository", repos, default=[])

    filtered = lang_filtered
    if repo_filter:
        filtered = [x for x in filtered if x["repo"] in repo_filter]

    # Search and instance selector
    search = st.sidebar.text_input("Search instance_id or repo", "")
    if search:
        search_lower = search.lower()
        filtered = [
            x
            for x in filtered
            if search_lower in x["instance_id"].lower() or search_lower in x["repo"].lower()
        ]

    st.sidebar.caption(f"Showing {len(filtered)} / {len(data)} instances")

    options = [f"{x['instance_id']} ({x['repo']})" for x in filtered]
    instance_idx = st.sidebar.selectbox(
        "Select instance",
        range(len(filtered)),
        format_func=lambda i: options[i],
    )
    rec = filtered[instance_idx] if filtered else None

    if not rec:
        st.warning("No instances match the filters.")
        return

    # Main content
    col1, col2 = st.columns([1, 1])

    with col1:
        st.subheader("Issue / Problem Statement")
        problem = rec.get("problem_statement") or ""
        st.markdown(problem)

        st.subheader("Hints")
        hints = rec.get("hints_text") or ""
        if hints:
            st.markdown(hints)
        else:
            st.info("No hints")

    with col2:
        st.subheader("Metadata")
        meta_rows = [
            {"Field": "instance_id", "Value": rec.get("instance_id", "")},
            {"Field": "repo", "Value": rec.get("repo", "")},
            {"Field": "base_commit", "Value": rec.get("base_commit", "")},
            {"Field": "language", "Value": rec.get("language", "")},
            {"Field": "pull_number", "Value": rec.get("pull_number", "")},
        ]
        meta_rows = [{**r, "Value": str(r["Value"]) if r["Value"] is not None else ""} for r in meta_rows]
        st.table(meta_rows)

    st.divider()
    st.subheader("Patch (golden)")

    patch = rec.get("patch") or ""
    if patch:
        st.code(patch, language="diff", line_numbers=True)
    else:
        st.warning("No patch")

    st.subheader("Test Patch")
    test_patch = rec.get("test_patch") or ""
    if test_patch:
        st.code(test_patch, language="diff", line_numbers=True)
    else:
        st.info("No test patch")

    with st.expander("Dockerfile", expanded=False):
        st.code(rec.get("dockerfile", ""), language="dockerfile")

    with st.expander("Eval Script", expanded=False):
        st.code(rec.get("eval_script", ""), language="bash")


if __name__ == "__main__":
    main()
