#!/usr/bin/env bash
# PreToolUse hook for Read tool — logs skill access to JSONL. Fast-exits for non-skill reads.
set -euo pipefail

readonly MAX_SIZE=5242880   # 5MB
readonly WARN_SIZE=4194304  # 4MB

#######################################
# Check log file capacity and emit hook warnings.
# Globals: MAX_SIZE, WARN_SIZE (read), WARN_MSG (write)
# Arguments: $1 - log file path
#######################################
check_log_capacity() {
  local log_file="${1}"
  [[ -f "${log_file}" ]] || return 0
  local file_size
  file_size=$(stat -f%z "${log_file}" 2>/dev/null || stat -c%s "${log_file}" 2>/dev/null || echo 0)
  if [[ "${file_size}" -ge "${MAX_SIZE}" ]]; then
    jq -nc '{continue: true, systemMessage: "⚠ Skill Observer log is full (5MB) — logging is paused. Ask the user to either:\n1. Run `skill-logs --clear` in their terminal to reset the logs\n2. Disable the skill-observer plugin if it is no longer needed (`/plugin marketplace remove silverlogic/skill-observer`)"}'
    return 1
  fi
  if [[ "${file_size}" -ge "${WARN_SIZE}" ]]; then
    WARN_MSG="Skill Observer log is approaching capacity ($(( file_size / 1048576 ))MB/5MB). Logging will pause at 5MB. Run skill-logs --clear to reset, or disable the plugin if no longer needed."
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
# Globals: MAX_SIZE, WARN_SIZE (read)
# Arguments: None
#######################################
main() {
  local input tool_name file_path session_id offset limit
  input=$(cat)
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

  local log_dir log_file
  log_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.claude/logs"
  mkdir -p "${log_dir}"
  log_file="${log_dir}/skills.jsonl"
  WARN_MSG=""
  if ! check_log_capacity "${log_file}"; then exit 0; fi
  log_skill_access "${timestamp}" "${session_id}" "${event}" "${skill}" \
    "${filename}" "${file_path}" "${line_range}" "${log_file}"
  [[ -n "${WARN_MSG}" ]] && jq -nc --arg m "${WARN_MSG}" '{continue: true, systemMessage: $m}'
  exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
