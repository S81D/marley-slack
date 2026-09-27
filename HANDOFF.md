# Handoff — MARLEY on a Garmin fenix 7

Context for an agent picking this up on Ubuntu. Written 2026-09-27.

## What this is

Press START on a fenix 7 → it POSTs to the GitHub API → GitHub Actions builds
MARLEY v2.0.0 from source, generates exactly one neutrino event, and publishes a
JSON summary → the watch polls for it and draws it on a Feynman diagram.

**This all works.** It was proven end to end in the Connect IQ simulator on
2026-09-27 (runs #6–#8 in Actions were dispatched from the app; the published
`invoker` field reads `the watch`).

## The one remaining task

**Get the app onto the physical watch.** macOS cannot do this: the fenix 7
offers only MTP or Garmin's proprietary USB mode, neither mounts as a disk, and
`libmtp` fails on this device with
`get_suggested_storage_id(): could not get storage id from parent id`.

Ubuntu mounts it natively over MTP (GVFS). The job is:

1. Build `marley.prg` (below).
2. Plug the watch in with **USB mode = MTP** (Settings → System → USB Mode).
3. Copy the file to `Internal Storage/GARMIN/Apps/` — via the file manager, or
   the GVFS path, typically
   `/run/user/$UID/gvfs/mtp:host=*/Internal Storage/GARMIN/Apps/`.
4. Eject, unplug. The app appears in the watch's activity/app list.

The Connect IQ store is the only other route and makes the app **public**; it
was rejected as disproportionate for a personal app.

## Building

Needs the Connect IQ SDK (9.2.0 used here), a JDK, and a developer key.

```bash
cd garmin
"$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/marley.prg \
  -y ~/.config/garmin/developer_key -d fenix7 -w
```

**Developer key:** copy `~/.config/garmin/developer_key` from the Mac. Generating
a fresh one also works for sideloading but changes the app's signing identity.

**Export for the store** (not needed for sideloading):
`monkeyc -e -f monkey.jungle -o marley.iq -y <key>`

## The GitHub token — read this before publishing anything

`summon()` needs a fine-grained PAT (this repo only, `Actions: Read and write`).
Two ways to supply it, in precedence order:

1. **App setting** `githubToken`, set through Garmin Connect. Preferred on real
   hardware.
2. **Baked in at build time** — `scripts/make_secret.sh` reads
   `~/.config/garmin/marley_token` and generates `garmin/source/Secret.mc`.
   This was a simulator workaround because the simulator's App Settings Editor
   was unavailable.

`Secret.mc` and `*marley_token*` are gitignored. **Never commit either, and never
publish a build with a token baked in** — a store app is public and the token is
extractable from the binary.

## Gotchas already paid for

- **GitHub dispatch returns `204 No Content`.** Do not set `:responseType` on
  that request: Connect IQ tries to parse the empty body and returns `-400`
  (`INVALID_HTTP_BODY_IN_NETWORK_RESPONSE`) for a request that actually
  succeeded. `-400` is treated as success in `onDispatch` for this reason.
  This one bug cost most of a session and looked like a transport problem.
- **App settings XML:** `<properties>`, `<strings>` and `<settings>` must live in
  a single `resources/properties.xml` under one `<resources>` root with the
  schema declaration. A standalone `settings.xml` with a bare `<settings>` root
  is silently ignored — no error, and the simulator's settings menu stays greyed.
- The simulator needs BLE **and** WiFi set to `Connected`. Setting BLE to
  "Not Initialized" breaks even the working GET with `-104`.
- `strings` on a built `.prg` will reveal a baked-in token. Filter such checks.
- On the Mac, `cp` is aliased to `cp -i` and hangs scripts. Unrelated on Linux.

## Verify before you change anything

```bash
tests/run_tests.sh          # 20 checks, no MARLEY build required
```

Covers the HepMC3 parser against two fixtures (one from MARLEY's docs, one real
generator output), ASCII transliteration, the 18-field payload contract, and a
physics check that Σ E_gamma equals the residue excitation energy when nothing
is ejected.

## Known cosmetic bug

Events with zero gammas publish `gamma_sum = n/a`, so the watch renders
`0 gammas n/a`. Affects ~6% of events. Suppress the sum when the count is zero.

## Repo map

| path | what |
|---|---|
| `.github/workflows/marley-generate.yml` | builds MARLEY, generates 1 event, publishes to Pages |
| `config/one_event.js` | MARLEY job config — one nu_e + 40Ar CC event |
| `scripts/run_marley.sh` | build + generate + dump; runs on a laptop too |
| `scripts/summarize_event.py` | HepMC3 → 18 flat display fields |
| `scripts/event_payload.sh` | assembles the published JSON |
| `scripts/make_secret.sh` | bakes the token in for local builds |
| `garmin/` | the Connect IQ app |
| `tests/run_tests.sh` | parser + payload checks |
| `SPEC.md` | original design brief (Slack-era; Slack is parked — free plan lacks Workflow Builder) |

Published event: <https://s81d.github.io/marley-slack/latest_event.json>
