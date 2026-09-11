# Slack setup

Two independent halves. The **inbound** half (GitHub → Slack) is verified against
Slack's documentation and needs no app install, so build it first. The
**outbound** half (Slack → GitHub) depends on a Workflow Builder capability I
could not confirm — read the caveat before starting it.

Both halves need a **paid** Slack plan (Workflow Builder is not on the free
tier). Neither needs you to be an admin: workflow creation is open to all
members by default, though owners/admins *can* restrict it. If you don't see
Workflow Builder, that restriction is why.

---

## Half 1 — GitHub → Slack (the result message)

This is a webhook-*triggered* workflow: GitHub POSTs to Slack to start it.

1. Slack → **Automations** → **Workflow Builder** → **New Workflow**.
2. Choose **"From a webhook"** as the way to start it.
3. Declare these variables, all of type **text**. The names must match exactly —
   the workflow in this repo sends precisely these keys:

   | Variable | Example |
   |---|---|
   | `status` | `success` |
   | `invoker` | `doran` |
   | `reaction` | `νe + ⁴⁰Ar → e⁻ + ⁴⁰K*` |
   | `energy` | `21.2 MeV` |
   | `lepton` | `e⁻` |
   | `lepton_ke` | `15.3 MeV` |
   | `residue` | `⁴⁰K` |
   | `gammas` | `3` |
   | `xsec` | `1.575e-05 pb (PerAtom)` |
   | `seed` | `18273645` |
   | `run_url` | `https://github.com/.../runs/18273645` |

   > **Every one of these is always sent.** A webhook trigger fails the whole
   > workflow if a declared variable is absent from the payload, which is why
   > the GitHub job substitutes `n/a` rather than omitting a key.

4. Add a **"Send a message to a channel"** step and compose the message from
   those variables. Something like:

   ```
   🌴 *MARLEY Event Generator*

   One neutrino event has entered the chat. (for {{invoker}})

   {{reaction}}

   Neutrino energy: {{energy}}
   Final-state lepton: {{lepton}} (KE {{lepton_ke}})
   Residual nucleus: {{residue}}
   De-excitation γ's: {{gammas}}
   Cross section: {{xsec}}

   status {{status}} · seed {{seed}} · <{{run_url}}|run log>
   ```

   Nested JSON is not supported in workflow variables, so Block Kit is not an
   option here — the formatting has to live in this step.

5. **Publish**, then copy the request URL (it looks like
   `https://hooks.slack.com/triggers/…`).
6. In GitHub: repo → Settings → Secrets and variables → Actions → **New
   repository secret**, named `SLACK_WEBHOOK_URL`, pasted value.

Test it by running the workflow from GitHub's Actions tab. Note the trigger is
rate limited to **one request per second**, which the concurrency group in the
workflow already keeps you well under.

---

## Half 2 — Slack → GitHub (asking for an event)

> ### Check this first
> I could not confirm from Slack's own documentation that Workflow Builder has a
> general "send a web request" step that lets you set request **headers**.
> Slack's official step documentation describes Slack steps, *connector* steps
> and *custom* steps, with no generic HTTP step; only third-party write-ups
> claim one exists. So **open Workflow Builder and look** before following this
> section. You need a step that can POST to an arbitrary URL *and* set an
> `Authorization` header. If there isn't one, skip to "If there's no HTTP step".

### If the HTTP step exists

1. Create a GitHub **fine-grained** personal access token:
   - Settings → Developer settings → Personal access tokens → Fine-grained.
   - **Only select repository:** this one.
   - Repository permissions → **Actions: Read and write**. Nothing else.
   - Avoid a classic token: its `repo` scope would cover every repo you own.
2. New workflow in Workflow Builder, started **from a link or a button in a
   channel** (that is your `/marley-generate` equivalent).
3. Add the web-request step:
   - Method: `POST`
   - URL:
     `https://api.github.com/repos/S81D/marley-slack/actions/workflows/marley-generate.yml/dispatches`
   - Headers:
     - `Authorization: Bearer <your token>`
     - `Accept: application/vnd.github+json`
   - Body: `{"ref": "main"}`
     (`ref` is required. To pass the invoker through, use
     `{"ref": "main", "inputs": {"invoker": "..."}}`.)
4. Add a message step that replies immediately, e.g. *"🌴 Summoning one neutrino
   interaction… the event will appear here shortly."* Do not make the workflow
   wait for MARLEY — the build takes minutes.
5. Publish and click it. A successful dispatch returns **204 No Content** (treat
   any 2xx as success); the run then appears in the Actions tab.

### If there's no HTTP step

You need something in between that can hold a token and sign requests. In rough
order of effort:

1. **Google Apps Script** (the original SPEC.md design). Free, no server. But
   note the real limitation: Apps Script's `doPost(e)` **cannot read request
   headers**, so Slack's `X-Slack-Signature` cannot be verified there. The only
   check available is the deprecated `token` field in the request body, which is
   a shared secret with no replay protection. Document it; don't pretend the
   endpoint is authenticated.
2. **Cloudflare Worker** — serverless, free tier, and it *can* see headers, so
   proper HMAC-SHA256 signature verification works. This is the only option here
   that is genuinely authenticated.
3. **GitHub's Actions tab** — no Slack outbound at all. Fine while you're still
   testing Half 1.

---

## Security notes

- **This repo is public.** Nothing secret is committed, and `workflow_dispatch`
  can only be triggered by someone with write access, so a passer-by cannot
  summon neutrinos. But run artifacts and logs are world-readable, so keep it
  that way: never echo the webhook URL or token into the log.
- The GitHub token is the one thing worth guarding. Scope the fine-grained PAT to
  **only** `S81D/marley-slack` with `Actions: Read and write`, so a leak cannot
  reach anything else you own.
- The trigger takes **no arguments**. `invoker` is passed through for display
  only and never reaches a shell. No Slack input is interpolated into a command.
- The GitHub token lives only in the Slack step's configuration; the Slack
  webhook URL lives only in the GitHub secret. Neither is committed, and the
  workflow never echoes either.
- `concurrency: marley-generate` with `cancel-in-progress: false` means
  simultaneous requests queue rather than running many MARLEY builds at once.
