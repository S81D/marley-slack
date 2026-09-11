# MARLEY Slack Slash Command via GitHub Actions

## Goal

Build a small, self-contained demonstration that allows users in our Slack workspace to run:

    /marley-generate

The command should trigger a GitHub Actions workflow that builds/runs MARLEY and generates exactly ONE neutrino interaction event.

This is primarily a fun/demo project, not a production computing system.

The architecture should be:

    Slack
      |
      | /marley-generate
      v
    Google Apps Script
      |
      | authenticated HTTPS request
      v
    GitHub Actions
      |
      v
    MARLEY
      |
      v
    One generated event
      |
      v
    Slack response

Do NOT involve Fermilab machines, Kerberos, GPVMs, JobSub, or FNAL infrastructure.

---

# 1. Repository structure

Create a small GitHub repository with approximately:

    marley-slack/
    ├── .github/
    │   └── workflows/
    │       └── marley-generate.yml
    ├── config/
    │   └── one_event.js
    ├── scripts/
    │   └── run_marley.sh
    ├── slack/
    │   └── appscript.js
    ├── README.md
    └── .gitignore

Do not over-engineer this.

---

# 2. MARLEY

Use the official MARLEY repository:

    https://github.com/MARLEY-MC/marley

Do not invent a MARLEY API.

Inspect the current repository and documentation before implementing the build/run commands.

Prefer building MARLEY from source inside the GitHub Actions runner.

Use the simplest supported build process documented by MARLEY.

The workflow should:

1. Check out this repository.
2. Obtain MARLEY.
3. Build MARLEY.
4. Configure MARLEY for one event.
5. Generate exactly one event.
6. Parse the resulting event enough to provide a useful Slack response.

Do not generate large samples.

The initial implementation must be limited to ONE event per invocation.

---

# 3. GitHub Actions workflow

Create:

    .github/workflows/marley-generate.yml

The workflow should be triggered using:

    workflow_dispatch

It should NOT run automatically on every push.

Example conceptual trigger:

    on:
      workflow_dispatch:

The workflow should:

1. Run on a standard Ubuntu GitHub-hosted runner.
2. Build/install MARLEY.
3. Run the MARLEY example/configuration for one event.
4. Produce an event output file.
5. Extract a concise event summary.
6. Send that summary to Slack.

Keep the workflow deterministic and easy to debug.

---

# 4. Slack architecture

The Slack slash command is:

    /marley-generate

The Slack command should invoke a Google Apps Script web app.

The Google Apps Script should NOT itself run MARLEY.

It should trigger GitHub Actions.

The Apps Script should use the GitHub API to dispatch:

    workflow_dispatch

for the MARLEY workflow.

Do not put a GitHub Personal Access Token directly in source code.

The GitHub token must be stored securely in Google Apps Script Properties.

For example:

    GITHUB_TOKEN

Do not commit this value to GitHub.

---

# 5. GitHub API

Use GitHub's official workflow-dispatch API.

The conceptual endpoint is:

    POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches

The request should specify the repository owner, repository name, workflow filename/ID, and branch/ref.

Do not use a GitHub Actions webhook unless there is a compelling reason.

The Apps Script should simply dispatch the workflow.

---

# 6. Slack response behavior

Slack slash commands have a short response timeout.

Therefore the Apps Script should NOT wait for GitHub Actions or MARLEY to finish.

When `/marley-generate` is called:

1. Validate the request.
2. Dispatch the GitHub workflow.
3. Immediately return something like:

    🌴 *MARLEY Event Generator*

    Summoning one neutrino interaction...

    GitHub Actions has been dispatched.
    The event will appear here shortly.

The eventual MARLEY result should be posted to Slack separately.

---

# 7. Posting the completed result to Slack

Use a Slack Incoming Webhook or another appropriate Slack bot mechanism for the asynchronous response.

The workflow should eventually POST the result to Slack.

The Slack webhook URL MUST NOT be committed to the repository.

Store it as a GitHub Actions secret:

    SLACK_WEBHOOK_URL

The workflow should send a concise message when MARLEY finishes.

For example:

    🌴 *MARLEY Event Generator*

    One event has entered the chat.

    νe + ⁴⁰Ar → e⁻ + ⁴⁰K*

    Neutrino energy: 12.3 MeV
    Final-state lepton: e⁻

    MARLEY: ✓
    HepMC3: ✓
    Nuclear de-excitation: ✓

Do NOT invent physics values.

Only report values actually extracted from the generated event.

---

# 8. Slack security

This is important.

The slash command may be available to many Slack users.

Do not expose a general-purpose command execution interface.

The Slack command must ONLY:

    /marley-generate

It must not accept arbitrary shell commands.

Do NOT implement:

    /marley-generate "some shell command"

Do NOT pass arbitrary user input to subprocesses.

Initially ignore all slash-command arguments.

Every invocation should generate exactly one predefined MARLEY event using one predefined configuration.

---

# 9. Rate limiting / concurrency

Multiple users may invoke:

    /marley-generate

at approximately the same time.

Prevent accidental runaway execution.

GitHub Actions should use a concurrency group, for example conceptually:

    concurrency:
      group: marley-generate
      cancel-in-progress: false

The desired behavior is:

- One MARLEY workflow can run.
- Additional requests should either queue or be rejected gracefully.
- Never allow unlimited simultaneous MARLEY jobs.

A friendly Slack response for an already-running job is:

    🌴 MARLEY is already generating an event.

    Please wait for the current neutrino.

Do not build a complicated queue unless necessary.

---

# 10. Slack slash-command authentication

The Google Apps Script endpoint is publicly reachable.

Do not assume that the URL itself provides authentication.

Slack signs slash-command requests.

Implement Slack request verification if practical in Google Apps Script.

At minimum, investigate how Slack's signing secret can be validated in Apps Script.

The Slack signing secret must be stored securely using:

    PropertiesService

Never commit the signing secret.

If full Slack signature verification is awkward in Apps Script, document the limitation rather than silently pretending the endpoint is authenticated.

---

# 11. Google Apps Script configuration

The Apps Script should use Script Properties for:

    GITHUB_TOKEN
    GITHUB_OWNER
    GITHUB_REPO
    GITHUB_WORKFLOW
    GITHUB_REF

Potentially also:

    SLACK_SIGNING_SECRET

Do not hard-code secrets.

The Apps Script should use UrlFetchApp to call the GitHub API.

The basic flow should be:

    function doPost(e) {
        // Validate Slack request
        // Confirm command is /marley-generate
        // Dispatch GitHub workflow
        // Return immediate Slack response
    }

---

# 12. Error handling

Handle at least:

- GitHub API unavailable
- Invalid GitHub token
- Workflow dispatch failure
- MARLEY build failure
- MARLEY execution failure
- Slack webhook failure
- Duplicate/concurrent requests

Slack should receive a useful error message.

For example:

    ❌ MARLEY failed to launch.

    GitHub Actions could not be dispatched.

Do not expose secrets or full API credentials in Slack.

---

# 13. MARLEY event configuration

Use a fixed, simple configuration suitable for demonstrating MARLEY.

Do not require user-supplied physics parameters initially.

The configuration should generate exactly one event.

Use a reasonable low-energy neutrino interaction that MARLEY supports.

Before writing the configuration, inspect the MARLEY repository's current examples and documentation.

Prefer an existing official example over inventing a new configuration.

---

# 14. Event parsing

The first version does not need sophisticated HepMC parsing.

It only needs enough information to demonstrate that an event was generated.

At minimum, report:

- Successful generation
- Event number
- Output file
- Any neutrino energy available from the generated event
- Any simple final-state information that can be reliably extracted

If extracting physics information becomes complicated, simplify the Slack response rather than implementing a large parser.

For example:

    🌴 MARLEY EVENT GENERATOR

    ✓ MARLEY initialized
    ✓ One event generated
    ✓ Output written successfully

    One neutrino event has entered the chat.

This is completely acceptable for version 1.

---

# 15. Do not use unnecessary infrastructure

Do NOT use:

- Fermilab GPVMs
- Kerberos
- JobSub
- dCache
- Google Sheets
- a persistent server
- a personal computer as a public server
- Docker Hub unless actually needed
- Kubernetes
- databases

The desired system is:

    Slack
      ↓
    Google Apps Script
      ↓
    GitHub Actions
      ↓
    MARLEY

Keep it simple.

---

# 16. Development order

Implement incrementally.

### Step 1

Prove MARLEY can build and generate one event in GitHub Actions.

Do not touch Slack yet.

### Step 2

Make the workflow produce a clear success/failure summary.

### Step 3

Add a Slack webhook to the workflow and manually trigger the workflow.

Verify that the workflow can post:

    MARLEY generated an event.

### Step 4

Implement the Google Apps Script.

Make:

    /marley-generate

dispatch the workflow.

### Step 5

Test the complete chain:

    Slack
      ↓
    Apps Script
      ↓
    GitHub Actions
      ↓
    MARLEY
      ↓
    Slack

### Step 6

Add concurrency protection and better error handling.

---

# 17. Important implementation philosophy

Do not rewrite large amounts of code unnecessarily.

Prefer minimal, understandable files.

Explain any assumptions about the current MARLEY build system before changing them.

Before implementing commands from this document, inspect:

    https://github.com/MARLEY-MC/marley

and use the repository's current documentation/examples rather than relying on potentially outdated assumptions.

The final project should be something another physicist can clone, inspect, and understand in a few minutes.

The goal is a fun Slack demonstration:

    /marley-generate

→ GitHub Actions spins up MARLEY

→ one neutrino interaction is generated

→ Slack announces:

    🌴 One neutrino event has entered the chat.