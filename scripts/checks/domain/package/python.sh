#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/lib/package_scan.sh
# pkg_rel_path, fp_*, pp_* provided by caller

pp__dir_has_any_satisfier() {
  local dir="$1"
  shift
  local s
  for s in "$@"; do
    [[ -n "$s" && -f "${dir}/${s}" ]] && return 0
  done
  return 1
}

pp_python_allowed_combo_sorted_space_lines() {
  local mf
  mf="$(pp_python_merged_file)"
  [[ -z "$mf" || ! -f "$mf" ]] && return 0
  if command -v yq >/dev/null 2>&1; then
    while IFS= read -r j; do
      [[ -z "$j" || "$j" == "null" ]] && continue
      python3 -c 'import json,sys; print(" ".join(sorted(json.loads(sys.argv[1]))))' "$j" 2>/dev/null || true
    done < <(yq -o=json '(.allowed_trigger_combinations // [])[]' "$mf" 2>/dev/null || true)
  else
    pp_python_allowed_combo_sorted_space_lines_fallback
  fi
}

pp_python_allowed_combo_sorted_space_lines_fallback() {
  printf '%s\n' "requirements.in requirements.txt" "requirements-dev.in requirements-dev.txt" "pyproject.toml requirements.txt"
}

pp__python_multi_trigger_allowed() {
  local path_root="$1"
  local dir="$2"
  shift 2
  local -a triggers=("$@")
  local n="${#triggers[@]}"
  ((n <= 1)) && return 0
  local tkey combo match=0
  tkey="$(printf '%s\n' "${triggers[@]}" | sort -u | paste -sd' ' -)"
  while IFS= read -r combo; do
    [[ -z "$combo" ]] && continue
    [[ "$tkey" == "$combo" ]] && match=1
  done < <(pp_python_allowed_combo_sorted_space_lines)
  ((match == 1)) && return 0
  local rel_probe
  rel_probe="$(pkg_rel_path "$path_root" "${dir}/trigger")"
  rel_probe="${rel_probe%/trigger}"
  fb_report "error" "Ambiguous Python dependency triggers in one directory; use a single trigger or a whitelisted pair." "${rel_probe}/" "" \
    "See guardrails package_policy defaults or override package_policy.python in .guardrails.file-patterns.yml." "python"
  return 1
}

sec03__validate_pip_requirements_txt_hashes() {
  local path_root="$1"
  local abs="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$abs")"
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    if [[ "$row" == UNPINNED\|* ]]; then
      local rest ln content
      rest="${row#UNPINNED|}"
      ln="${rest%%|*}"
      content="${rest#*|}"
      fb_report "error" "Unpinned python dependency '${content}'." "$rel" "$ln" \
        "Pin each dependency with exact == version and pip --hash lines (pip-compile --generate-hashes)." "python"
    elif [[ "$row" == MISSING_HASH\|* ]]; then
      local rest pkg ln
      rest="${row#MISSING_HASH|}"
      if [[ "$rest" == *'|'* ]]; then
        ln="${rest%%|*}"
        pkg="${rest#*|}"
      else
        ln=""
        pkg="$rest"
      fi
      fb_report "error" "Python requirement is pinned but missing a pip --hash= line for '${pkg}'." "$rel" "$ln" \
        "Regenerate with pip-compile --generate-hashes (or equivalent) and commit the lock output." "python"
    fi
  done < <(
    python3 - "$abs" <<'PY'
import re, sys

path = sys.argv[1]
raw_lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
drop_physical = re.compile(r"^\s*(#|-r |--|-i |)$")
events = []

for phys_ln, line in enumerate(raw_lines, start=1):
    if drop_physical.match(line):
        continue
    if "==" in line:
        continue
    s = line.strip()
    if not s:
        continue
    events.append((phys_ln, 0, "UNPINNED", s))


def logical_blocks(raw):
    out = []
    for lineno, line in enumerate(raw, start=1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        s = line.rstrip("\n")
        if out and out[-1][1].rstrip().endswith("\\"):
            prev_ln, prev_text = out[-1]
            out[-1] = (
                prev_ln,
                prev_text.rstrip().rstrip("\\").rstrip() + " " + s.lstrip(),
            )
            continue
        out.append((lineno, s))
    return out


def is_skipped(st):
    t = st.lstrip()
    if t.startswith("-r ") or t.startswith("-c ") or t.startswith("--"):
        return True
    if t.startswith("-i ") or t.startswith("-e "):
        return True
    if t.startswith("-") and not re.match(r"^[A-Za-z0-9_.+\[\]-]+==", t):
        return True
    return False


def is_requirement(st):
    t = st.lstrip()
    if not t or t.startswith("#"):
        return False
    if is_skipped(t):
        return False
    return bool(re.match(r"^[A-Za-z0-9_.+\[\]-]+(?:==|>=|<=|~=|!=|>|<|@)", t))


for start_ln, block in logical_blocks(raw_lines):
    b = block.strip()
    if not b or is_skipped(b):
        continue
    if not is_requirement(b):
        continue
    if "--hash=" not in b and " --hash=" not in b:
        pkg = b.split()[0] if b.split() else b
        events.append((start_ln, 1, "MISSING_HASH", pkg))

for ln, _prio, kind, payload in sorted(events, key=lambda x: (x[0], x[1])):
    if kind == "UNPINNED":
        print(f"UNPINNED|{ln}|{payload}")
    else:
        print(f"MISSING_HASH|{ln}|{payload}")
PY
  )
}

sec03__validate_poetry_lock_hashes() {
  local path_root="$1"
  local abs="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$abs")"
  local err
  err="$(
    python3 - "$abs" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
if "[metadata]" not in text or "content-hash" not in text:
    print("missing_lock_metadata")
    sys.exit(0)
if "[[package]]" not in text:
    print("no_packages")
    sys.exit(0)
blocks = text.split("[[package]]")[1:]
for i, blk in enumerate(blocks, start=1):
    if "sha256" not in blk and "sha512" not in blk and "hash =" not in blk:
        print(f"package_without_hash:{i}")
        sys.exit(0)
PY
  )"
  [[ -z "$err" ]] && return 0
  case "$err" in
    missing_lock_metadata)
      fb_report "error" "poetry.lock is missing metadata content-hash (invalid or stale lock)." "$rel" "" \
        "Run poetry lock and commit poetry.lock." "python"
      ;;
    no_packages)
      fb_report "error" "poetry.lock contains no [[package]] entries." "$rel" "" \
        "Run poetry lock and commit poetry.lock." "python"
      ;;
    package_without_hash:*)
      fb_report "error" "poetry.lock has a package block without integrity hash evidence." "$rel" "" \
        "Regenerate poetry.lock with a current Poetry version and commit." "python"
      ;;
  esac
}

sec03__validate_uv_lock_hashes() {
  local path_root="$1"
  local abs="$2"
  local rel
  rel="$(pkg_rel_path "$path_root" "$abs")"
  local err
  err="$(
    python3 - "$abs" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
if "[[package]]" not in text:
    print("no_packages")
    sys.exit(0)
blocks = text.split("[[package]]")[1:]
digest_re = re.compile(r"sha256-[0-9a-fA-F]{64}")
for i, blk in enumerate(blocks, start=1):
    if not digest_re.search(blk):
        print(f"package_without_digest:{i}")
        sys.exit(0)
PY
  )"
  [[ -z "$err" ]] && return 0
  case "$err" in
    no_packages)
      fb_report "error" "uv.lock contains no [[package]] entries." "$rel" "" \
        "Run uv lock and commit uv.lock." "python"
      ;;
    package_without_digest:*)
      fb_report "error" "uv.lock has a package block without a sha256 digest." "$rel" "" \
        "Run uv lock and commit uv.lock." "python"
      ;;
  esac
}

sec03__run_hash_validator() {
  local vid="$1"
  local path_root="$2"
  local abs="$3"
  case "$vid" in
    pip_requirements_txt_hashes) sec03__validate_pip_requirements_txt_hashes "$path_root" "$abs" ;;
    poetry_lock_hashes) sec03__validate_poetry_lock_hashes "$path_root" "$abs" ;;
    uv_lock_hashes) sec03__validate_uv_lock_hashes "$path_root" "$abs" ;;
    *)
      fb_report "warning" "Unknown hash validator id '${vid}' for $(basename "$abs"); skipped." "$(pkg_rel_path "$path_root" "$abs")" "" \
        "Fix package_policy.hash_validators in guardrails defaults or overlay." "python"
      ;;
  esac
}

cicd_sec_03_run_python_package_policy() {
  local path_root="$1"
  local mf
  mf="$(pp_python_merged_file)"
  if [[ -z "$mf" || ! -f "$mf" ]]; then
    return 0
  fi

  local -a sat_list=()
  while IFS= read -r s; do
    [[ -n "$s" ]] && sat_list+=("$s")
  done < <(pp_python_satisfier_names)

  local -a uniq_dirs=()
  while IFS= read -r d; do
    [[ -n "$d" ]] && uniq_dirs+=("$d")
  done < <(
    local t abs rel
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      while IFS= read -r abs; do
        [[ -z "$abs" || ! -f "$abs" ]] && continue
        rel="$(pkg_rel_path "$path_root" "$abs")"
        if fp_should_skip_validation "$rel"; then
          continue
        fi
        dirname "$abs"
      done < <(fp_find_with_names "$path_root" "$t")
    done < <(pp_python_trigger_names) | sort -u
  )

  local dir
  for dir in "${uniq_dirs[@]+"${uniq_dirs[@]}"}"; do
    [[ -z "$dir" ]] && continue
    local -a triggers=()
    local tb
    while IFS= read -r tb; do
      [[ -n "$tb" && -f "${dir}/${tb}" ]] && triggers+=("$tb")
    done < <(pp_python_trigger_names | sort -u)
    ((${#triggers[@]} == 0)) && continue

    pp__python_multi_trigger_allowed "$path_root" "$dir" "${triggers[@]+"${triggers[@]}"}" || true

    if ((${#sat_list[@]} > 0)); then
      if ! pp__dir_has_any_satisfier "$dir" "${sat_list[@]+"${sat_list[@]}"}"; then
        local rel_dir probe
        probe="${dir}/${triggers[0]}"
        rel_dir="$(pkg_rel_path "$path_root" "$probe")"
        rel_dir="${rel_dir%/*}"
        fb_report "error" "Python project directory is missing a required lock or hashed requirements file." "${rel_dir}/" "" \
          "Add one of the configured satisfier files next to the trigger manifest (see package_policy defaults)." "python"
      fi
    fi

    local sf
    for sf in "${sat_list[@]+"${sat_list[@]}"}"; do
      [[ -f "${dir}/${sf}" ]] || continue
      local rel_sf vid
      rel_sf="$(pkg_rel_path "$path_root" "${dir}/${sf}")"
      if fp_should_skip_validation "$rel_sf"; then
        continue
      fi
      vid="$(pp_python_validator_for "$sf")"
      [[ -z "$vid" ]] && continue
      sec03__run_hash_validator "$vid" "$path_root" "${dir}/${sf}" || true
    done
  done

  local py_n="${#uniq_dirs[@]}"
  local sat_desc=""
  if ((${#sat_list[@]} > 0)); then
    sat_desc="$(printf '%s, ' "${sat_list[@]}" | sed 's/, $//')"
  else
    sat_desc="(none configured)"
  fi
  local lim samp="" cnt=0
  lim="$(fb_coverage_path_sample_limit)"
  for dir in "${uniq_dirs[@]+"${uniq_dirs[@]}"}"; do
    cnt=$((cnt + 1))
    [[ $cnt -gt $lim ]] && break
    local rd
    rd="$(pkg_rel_path "$path_root" "$dir")"
    samp="${samp:+$samp; }${rd}/"
  done
  local more=""
  if [[ $py_n -gt $lim ]]; then
    more=" (+$((py_n - lim)) more directories)"
  fi
  if [[ $py_n -eq 0 ]]; then
    fb_add_coverage "Python package_policy: no directories with trigger files after applying repository validation rules."
  else
    fb_add_coverage "Python package_policy: ${py_n} director(ies) with triggers; satisfiers: ${sat_desc}${samp:+; sample: }${samp}${more}"
  fi
}
