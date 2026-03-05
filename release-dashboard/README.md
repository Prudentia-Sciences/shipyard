# Release Environment Dashboard

An internal status-page-style dashboard that shows the current deployment state of every tracked service. For each service, you can see what version is deployed, who authored the deploy commit, and how stale it is compared to the default branch.

## Stack

- **Frontend:** Next.js (App Router) with TypeScript and Tailwind CSS
- **Hosting:** Vercel
- **Backend/Config:** Supabase (Postgres + Auth)
- **Deploy Data:** GitHub API via org-level GitHub App

## Setup

### 1. Supabase

Create a Supabase project and run the migrations in `supabase/migrations/` to create the schema and seed the environments table:

```bash
supabase db push
```

Or, if linking to a remote project: `supabase link` then `supabase db push`.

Disable sign-ups in your Supabase Auth settings (Dashboard > Auth > Settings) since users are invited by admins.

### 2. GitHub App

Create a GitHub App in your org with:

- **Setup URL:** `https://your-domain.com/api/github/setup`
- **Webhook URL:** `https://your-domain.com/api/github/webhook`
- **Webhook Secret:** A random string (store as `GITHUB_WEBHOOK_SECRET`)
- **Permissions:** Read access to Actions, Contents, and Metadata

Install the app on your org and select the repositories you want to track.

### 3. Environment Variables

Copy `.env.local.example` to `.env.local` and fill in the values (Supabase keys, GitHub App ID, private key, and webhook secret).

### 4. Run

```bash
npm install
npm run dev
```

## How It Works

1. Users sign in via magic link (Supabase Auth); the dashboard is protected.
2. The GitHub App installation redirect auto-discovers repositories and detects deploy workflows by matching filenames against environment keywords (`prod`, `stage`, `sandbox`).
3. When a user loads the dashboard, the app reads service configuration from Supabase, then fetches the latest successful workflow run and commit comparison from the GitHub API for each service.
4. Staleness is computed as `commits_behind / commit_ceiling` and displayed as a continuous color gradient from bright green (fresh) to pale brown (stale).
5. Environment, sort, and layout preferences persist via URL query parameters and browser cookies.
6. Search (Cmd/Ctrl+F) filters services by display name or repo; layout toggles compact (3 columns) vs comfortable (2 columns) on large screens; dark mode follows system preference.

## Bifurcated workflows (one workflow, multiple environments)

Some repositories use a single workflow file that deploys to different environments (e.g. by branch or input). The dashboard supports this by letting multiple environments point to the **same** `workflow_file` and using an optional **run matcher** to decide which runs count for which environment.

- **Model:** Each environment still has a required workflow file responsible for deploys. Multiple environments may reference the same file; then `run_match_strategy` and `run_match_value` differentiate runs.
- **Supported matchers:**
  - **`branch`** — only successful runs whose head branch equals `run_match_value` (e.g. `main` for production, `develop` for staging).
  - **`event`** — only runs triggered by the given event (e.g. `workflow_dispatch`, `push`).
  - **`any`** or NULL — latest successful run for that workflow (default; current behavior).

**Creating rows for a bifurcated repo:** Auto-discovery only creates one row per (service, environment) when a workflow filename matches an env keyword. For a single shared workflow (e.g. `deploy.yml`), add the extra (service, environment, workflow_file, matcher) rows manually:

1. Get the service `id` and the environment `id`s from the `services` and `environments` tables (e.g. in Supabase SQL editor or dashboard).
2. Insert or update `service_environments` with the same `workflow_file` for each environment and set `run_match_strategy` and `run_match_value` as needed.

Example (one workflow, production from `main`, staging from `develop`):

```sql
-- After the service and environments exist, add staging for a repo that uses deploy.yml for both:
INSERT INTO service_environments (service_id, environment_id, workflow_file, run_match_strategy, run_match_value)
SELECT s.id, e.id, 'deploy.yml', 'branch', 'develop'
FROM services s, environments e
WHERE s.github_repo = 'org/repo-name' AND e.slug = 'staging'
ON CONFLICT (service_id, environment_id) DO UPDATE SET
  workflow_file = EXCLUDED.workflow_file,
  run_match_strategy = EXCLUDED.run_match_strategy,
  run_match_value = EXCLUDED.run_match_value;
```

An admin UI or API to edit `service_environments` (including matcher) may be added in a future release.
