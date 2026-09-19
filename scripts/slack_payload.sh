#!/usr/bin/env bash
#
# Build the flat JSON payload for Slack's webhook trigger.
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
#   SLACK_WEBHOOK_URL=... scripts/slack_payload.sh tests/real_event.hepmc3 \
#     | curl -sS -X POST -H 'Content-Type: application/json' \
#            --data @- "$SLACK_WEBHOOK_URL"

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

event_file=${1:-}
summary=""
if [[ -n $event_file && -r $event_file ]]; then
  summary=$(python3 scripts/summarize_event.py "$event_file" 2>/dev/null || true)
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
  --arg xsec      "$(field xsec)" \
  --arg seed      "$seed" \
  --arg run_url   "${RUN_URL:-n/a}" \
  '{status: $status, invoker: $invoker, reaction: $reaction, energy: $energy,
    lepton: $lepton, lepton_ke: $lepton_ke, residue: $residue,
    gammas: $gammas, xsec: $xsec, seed: $seed, run_url: $run_url}'
