#!/usr/bin/env bash
#
# Build the flat JSON event payload.
#
# Two consumers share it: Slack's webhook trigger (when configured) and the
# latest_event.json published to GitHub Pages for the Garmin watch to read.
#
# Usage:  scripts/slack_payload.sh [EVENT_FILE]
#
# Two constraints from Slack, both load-bearing:
#   * A webhook trigger fails the whole Slack workflow if a variable it declares
#     is absent from the payload, so EVERY key is always emitted -- unavailable
#     ones as "n/a" rather than being left out.
#   * Workflow variables cannot be nested, so every value is a flat string.
#
# Overridable from the environment: STATUS INVOKER SEED RUN_URL
#
# Kept separate from the workflow so the Slack side can be tested locally:
#   SLACK_WEBHOOK_URL=... scripts/event_payload.sh tests/real_event.hepmc3 \
#     | curl -sS -X POST -H 'Content-Type: application/json' \
#            --data @- "$SLACK_WEBHOOK_URL"

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

event_file=${1:-}
summary=""
if [[ -n $event_file && -r $event_file ]]; then
  # --ascii: the watch renders these directly and its fonts lack the symbols.
  summary=$(python3 scripts/summarize_event.py --ascii "$event_file" 2>/dev/null || true)
fi

# Pull one key=value out of the parser output, falling back to "n/a".
field() {
  local value
  value=$(printf '%s\n' "$summary" | sed -n "s/^$1=//p")
  printf '%s' "${value:-n/a}"
}

# MARLEY records the seed it actually used, which is the authoritative one;
# the caller's SEED is only a fallback for when the event could not be parsed.
seed=$(field seed)
if [[ $seed == "n/a" ]]; then
  seed=${SEED:-n/a}
fi

jq -n \
  --arg status    "${STATUS:-unknown}" \
  --arg invoker   "${INVOKER:-someone}" \
  --arg reaction  "$(field reaction)" \
  --arg energy    "$(field energy)" \
  --arg lepton    "$(field lepton)" \
  --arg lepton_ke "$(field lepton_ke)" \
  --arg residue   "$(field residue)" \
  --arg gammas    "$(field gammas)" \
  --arg energy_value "$(field energy_value)" \
  --arg residue_ex   "$(field residue_ex)" \
  --arg ejected      "$(field ejected)" \
  --arg gamma_sum    "$(field gamma_sum)" \
  --arg gamma_top    "$(field gamma_top)" \
  --arg energy_unit  "$(field energy_unit)" \
  --arg xsec      "$(field xsec)" \
  --arg seed      "$seed" \
  --arg run_url   "${RUN_URL:-n/a}" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{status: $status, invoker: $invoker, reaction: $reaction, energy: $energy,
    lepton: $lepton, lepton_ke: $lepton_ke, residue: $residue,
    gammas: $gammas, xsec: $xsec, seed: $seed, run_url: $run_url,
    energy_value: $energy_value, energy_unit: $energy_unit,
    residue_ex: $residue_ex, ejected: $ejected,
    gamma_sum: $gamma_sum, gamma_top: $gamma_top,
    generated_at: $generated_at}'
