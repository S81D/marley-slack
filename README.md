# marley-slack

<https://github.com/S81D/marley-slack>

Ask Slack for a neutrino interaction; GitHub Actions builds
[MARLEY](https://github.com/MARLEY-MC/marley), generates exactly **one** event,
and Slack announces what came out.

```
Slack  ──(button / link trigger)──▶  GitHub Actions  ──▶  MARLEY
  ▲                                                         │
  └────────────(webhook trigger, one message)───────────────┘
```

No Fermilab infrastructure is involved: no GPVMs, Kerberos, JobSub or dCache.
It is a demo, not a computing system.

## Layout

| Path | What it is |
|---|---|
| [.github/workflows/marley-generate.yml](.github/workflows/marley-generate.yml) | Builds MARLEY, generates one event, posts to Slack |
| [config/one_event.js](config/one_event.js) | MARLEY job config — one νe + ⁴⁰Ar CC event |
| [scripts/run_marley.sh](scripts/run_marley.sh) | Build + generate + dump; runs on a laptop too |
| [scripts/summarize_event.py](scripts/summarize_event.py) | HepMC3 → the handful of fields Slack quotes |
| [tests/run_tests.sh](tests/run_tests.sh) | Parser checks against both fixtures |
| [tests/sample_event.hepmc3](tests/sample_event.hepmc3) | Fixture from MARLEY's docs (no run-info block) |
| [tests/real_event.hepmc3](tests/real_event.hepmc3) | Real MARLEY v2.0.0 output, seed 18273645 |
| [slack/SETUP.md](slack/SETUP.md) | Click-by-click Slack configuration |
| [SPEC.md](SPEC.md) | The original design brief this was built from |

## Try the parser without building MARLEY

```console
$ python3 scripts/summarize_event.py tests/sample_event.hepmc3 --text
MARLEY event summary
  event_number : 1
  energy       : 21.2 MeV
  reaction     : νe + ⁴⁰Ar → e⁻ + ⁴⁰K*
  residue_ex   : 4.384 MeV
  lepton       : e⁻
  lepton_ke    : 15.3 MeV
  residue      : ⁴⁰K
  gammas       : 4
  xsec_raw     : 7.45272521695649e-05
  parse_ok     : true
```

Or run the checks, which need no MARLEY build either:

```console
$ tests/run_tests.sh
...
all checks passed
```

There are two fixtures, and the difference between them matters.
`sample_event.hepmc3` is the worked example from MARLEY's own
`docs/interpret_output.rst`. `real_event.hepmc3` is genuine MARLEY v2.0.0 output —
and it contains a **run-info block** of id-less `A <key> <value>` lines that the
docs example omits entirely. That block crashed the first version of the parser,
so both fixtures are kept: one for the documented shape, one for the real one.
Expected values are cross-checked against `marley print legacy`.

## Running it locally

```console
git clone https://github.com/MARLEY-MC/marley   # built into ./marley
scripts/run_marley.sh
python3 scripts/summarize_event.py events.hepmc3 --text
```

MARLEY v2.0.0 needs a C++17 compiler (GCC ≥ 9.1) and GNU Make. GSL, ROOT and
HepMC3 are all optional — MARLEY falls back to bundled copies, and nothing here
requires ROOT.

If you have ROOT installed, MARLEY will find and link it. To build the way CI
does instead, skip it:

```console
MAKE_FLAGS=IGNORE_ROOT=1 scripts/run_marley.sh
```

For reference, a clean build took **~47 s** on 18 cores (macOS arm64, Apple clang
21), using the system GSL and MARLEY's built-in HepMC3. Expect a few minutes on a
2-core GitHub runner; the workflow caches the build tree and allows 30 minutes.

## Notes on the physics

- Energies throughout are **MeV** (MARLEY writes `U MEV CM`). The parser warns
  rather than relabels if that ever changes.
- The config uses a pinched Fermi-Dirac νe spectrum (T = 3.5 MeV, η = 4,
  0–60 MeV), the usual supernova stand-in, on a pure ⁴⁰Ar target with the
  recommended v2 cross-section models (HF-CRPA continuum +
  Bhattacharya2009 discrete).
- `ES.react` is deliberately **not** in the reaction list, so the single event is
  always a CC interaction on the nucleus rather than sometimes an electron
  recoil. Add it back if you want the full mix.
- The output entry needs `force: true` *as well as* `mode: "overwrite"`. With only
  the latter, MARLEY stops to ask `Overwrite file events.hepmc3 [y/n]?` — fine
  interactively, fatal in CI.
- Every run uses a different seed (the GitHub run ID), echoed in the log so any
  event can be regenerated. MARLEY is pinned to tag `v2.0.0`.
- Cross sections are labelled from the file, not guessed: real output declares
  `NuHepMC.Units.CrossSection.Unit` (`pb`) and `.TargetScale` (`PerAtom`) in its
  run-info block, so the parser reports e.g. `1.575e-05 pb (PerAtom)`. A file
  without that block falls back to an unlabelled `xsec_raw`.
- MARLEY's legacy dump numbers its events from 0 while the HepMC3 `E` line starts
  at 1, so `event_number` is the HepMC3 one. Irrelevant at one event per run, but
  don't be surprised by the off-by-one when comparing the two.
