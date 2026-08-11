#!/usr/bin/env bash
# PreToolUse hook for Read tool — logs skill access to JSONL. Fast-exits for non-skill reads.
set -euo pipefail

readonly MAX_SIZE=2097152   # 2MB

#######################################
# Check log file capacity and recycle if needed.
# Globals: MAX_SIZE (read)
# Arguments: $1 - log file path
#######################################
check_log_capacity() {
  local log_file="${1}"
  [[ -f "${log_file}" ]] || return 0
  local file_size
  file_size=$(stat -f%z "${log_file}" 2>/dev/null || stat -c%s "${log_file}" 2>/dev/null || echo 0)
  if [[ "${file_size}" -ge "${MAX_SIZE}" ]]; then
    local no_recycle_marker="$(dirname "${log_file}")/.no-recycle"
    if [[ -f "${no_recycle_marker}" ]]; then
      jq -nc '{continue: true, systemMessage: "⚠ Skill Observer log is full (2MB) — logging is paused. Run `skill-observer --clear` to reset or `skill-observer --recycle` to enable auto-recycling."}'
      return 1
    fi
    # Recycle: keep the newest half of entries
    local line_count keep tmp_file
    line_count=$(wc -l < "${log_file}" | tr -d ' ')
    keep=$(( line_count / 2 ))
    tmp_file="${log_file}.tmp"
    tail -n "${keep}" "${log_file}" > "${tmp_file}" && cat "${tmp_file}" > "${log_file}" && rm -f "${tmp_file}"
  fi
}

#######################################
# Handle session markers and append JSONL log entries.
# Arguments: $1-ts $2-session_id $3-event $4-skill $5-filename $6-file_path $7-line_range $8-log_file
#######################################
log_skill_access() {
  local timestamp="${1}" session_id="${2}" event="${3}" skill="${4}"
  local filename="${5}" file_path="${6}" line_range="${7}" log_file="${8}"
  local marker_dir="/tmp/skill-observer/${session_id}"
  local marker_file="${marker_dir}/${skill}"
  if [[ ! -f "${marker_file}" ]]; then
    mkdir -p "${marker_dir}"
    touch "${marker_file}"
    if [[ "${event}" != "skill_loaded" ]]; then
      jq -nc --arg ts "${timestamp}" --arg sid "${session_id}" --arg sk "${skill}" \
        '{ts:$ts, session_id:$sid, event:"skill_loaded", skill:$sk, file:"SKILL.md", path:"(inferred)"}' >> "${log_file}"
    fi
  fi
  jq -nc --arg ts "${timestamp}" --arg sid "${session_id}" --arg ev "${event}" \
    --arg sk "${skill}" --arg fn "${filename}" --arg fp "${file_path}" --arg lr "${line_range}" \
    '{ts:$ts, session_id:$sid, event:$ev, skill:$sk, file:$fn, path:$fp} + (if $lr != "" then {lines:$lr} else {} end)' >> "${log_file}"
}

#######################################
# Main entry point. Reads hook JSON from stdin and logs skill access events.
# Globals: MAX_SIZE (read)
# Arguments: None
#######################################
main() {
  local input tool_name file_path session_id offset limit
  input=$(cat)
  # Fast-exit before spawning jq: this hook fires on every Read, but only skill
  # files are logged. Matched against the raw payload, where Windows paths arrive
  # JSON-escaped ("\\"). Strictly wider than the file_path guard below, so no
  # event is lost.
  case "${input}" in
    *'.claude/skills/'*|*'.claude\\skills\\'*) ;;
    *) exit 0 ;;
  esac
  { read -r tool_name; read -r file_path; read -r session_id; read -r offset; read -r limit; } < <(
    printf '%s' "${input}" | jq -r '(.tool_name // ""), (.tool_input.file_path // ""), (.session_id // "unknown"), (.tool_input.offset // ""), (.tool_input.limit // "")'
  ) || true
  [[ "${tool_name}" == "Read" ]] || exit 0
  [[ "${file_path}" == *".claude/skills/"* ]] || exit 0

  local filename="${file_path##*/}"
  local tmp="${file_path#*.claude/skills/}"
  local skill="${tmp%%/*}"
  local timestamp; timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")

  local line_range=""
  if [[ "${offset}" =~ ^[0-9]+$ && "${limit}" =~ ^[0-9]+$ ]]; then
    line_range="L${offset}-$(( offset + limit ))"
  elif [[ "${offset}" =~ ^[0-9]+$ ]]; then
    line_range="L${offset}-"
  elif [[ "${limit}" =~ ^[0-9]+$ ]]; then
    line_range="L1-${limit}"
  elif [[ -f "${file_path}" ]]; then
    local total; total=$(wc -l < "${file_path}" | tr -d ' ') || total=""
    [[ -n "${total}" ]] && line_range="${total} lines"
  fi

  local event="skill_file_read"
  if [[ "${filename}" == "SKILL.md" ]]; then event="skill_loaded"
  elif [[ "${file_path}" == *"/references/"* ]]; then event="reference_read"; fi

  local log_dir log_file gitignore
  log_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.skill-observer/logs"
  mkdir -p "${log_dir}"
  gitignore="${log_dir%/logs}/.gitignore"
  [[ -f "${gitignore}" ]] || printf '*\n' > "${gitignore}"
  log_file="${log_dir}/skills.jsonl"
  if ! check_log_capacity "${log_file}"; then exit 0; fi
  log_skill_access "${timestamp}" "${session_id}" "${event}" "${skill}" \
    "${filename}" "${file_path}" "${line_range}" "${log_file}"
  exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
