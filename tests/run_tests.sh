#!/usr/bin/env bash
#
# Check scripts/summarize_event.py against two fixtures:
#
#   sample_event.hepmc3  the worked example from MARLEY's docs/interpret_output.rst.
#                        Has NO run-info block, so it exercises the fallback paths.
#   real_event.hepmc3    genuine output from MARLEY v2.0.0 (seed 18273645). Has the
#                        run-info block, whose id-less "A <key> <value>" lines broke
#                        an earlier version of the parser.
#
# Expected values are cross-checked against MARLEY's own "marley print legacy".

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

failures=0

check() {  # check <fixture> <key> <expected>
  local got
  got=$(python3 scripts/summarize_event.py "tests/$1" | sed -n "s/^$2=//p")
  if [[ $got == "$3" ]]; then
    printf '  ok    %-12s %s\n' "$2" "$got"
  else
    printf '  FAIL  %-12s expected %q, got %q\n' "$2" "$3" "$got"
    failures=$((failures + 1))
  fi
}

echo "sample_event.hepmc3 (MARLEY docs example, no run-info block)"
check sample_event.hepmc3 energy    "21.2 MeV"
check sample_event.hepmc3 reaction  "νe + ⁴⁰Ar → e⁻ + ⁴⁰K*"
check sample_event.hepmc3 lepton    "e⁻"
check sample_event.hepmc3 lepton_ke "15.3 MeV"
check sample_event.hepmc3 residue   "⁴⁰K"
check sample_event.hepmc3 gammas    "4"
check sample_event.hepmc3 parse_ok  "true"

echo "real_event.hepmc3 (MARLEY v2.0.0 output, seed 18273645)"
check real_event.hepmc3 energy    "12.8 MeV"
check real_event.hepmc3 reaction  "νe + ⁴⁰Ar → e⁻ + ⁴⁰K*"
check real_event.hepmc3 lepton_ke "8.5 MeV"
check real_event.hepmc3 residue   "⁴⁰K"
check real_event.hepmc3 gammas    "3"
check real_event.hepmc3 xsec      "1.575e-05 pb (PerAtom)"
check real_event.hepmc3 seed      "18273645"
check real_event.hepmc3 parse_ok  "true"

echo "degradation on an event-less file"
empty=$(mktemp); printf 'HepMC::Version 3.03.00\n' > "$empty"
got=$(python3 scripts/summarize_event.py "$empty")
rm -f "$empty"
if [[ $got == "parse_ok=false" ]]; then
  printf '  ok    %-12s %s\n' "parse_ok" "false (and exit 0, so Slack still gets a message)"
else
  printf '  FAIL  expected parse_ok=false, got %q\n' "$got"
  failures=$((failures + 1))
fi

echo "slack payload contract"
# Slack fails the workflow if a declared variable is missing, so the payload must
# always carry all 11 keys as flat strings -- even when there is no event file.
for fixture in tests/real_event.hepmc3 does_not_exist.hepmc3; do
  payload=$(STATUS=success INVOKER=tester SEED=1 RUN_URL=http://x \
            scripts/event_payload.sh "$fixture" 2>/dev/null)
  keys=$(printf '%s' "$payload" | jq -r 'keys | length' 2>/dev/null)
  flat=$(printf '%s' "$payload" | jq -r '[.[] | type] | unique | join(",")' 2>/dev/null)
  empty=$(printf '%s' "$payload" | jq -r '[.[] | select(. == "")] | length' 2>/dev/null)
  label=$(basename "$fixture")
  if [[ $keys == 12 && $flat == "string" && $empty == 0 ]]; then
    printf '  ok    %-22s 12 flat string keys, none empty\n' "$label"
  else
    printf '  FAIL  %-22s keys=%s types=%s empty=%s\n' "$label" "$keys" "$flat" "$empty"
    failures=$((failures + 1))
  fi
done

echo
if (( failures )); then echo "$failures check(s) FAILED"; exit 1; fi
echo "all checks passed"
