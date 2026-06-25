# pgsereno/workflows

Shared reusable GitHub Actions workflows for psg2 projects — Blacksmith CI +
Vercel deploy. **Public on purpose:** GitHub Free blocks private→private
reusable-workflow access across an org, and public reusable workflows are
callable by private repos for free. Only workflow _logic_ lives here; every
secret stays in the caller's private repo and is passed at runtime.

## Workflows

### `ci-pnpm.yml`

pnpm/Turbo monorepo CI on Blacksmith: secrets scan (gitleaks binary), static
checks (lint + format + type-check + knip, one install, Turbo cache), Postgres
test, and build.

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened, ready_for_review]
  workflow_dispatch:
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  ci:
    uses: pgsereno/workflows/.github/workflows/ci-pnpm.yml@main
    # Optional overrides for repos that drift from the template:
    # with:
    #   node-version: "22"     # tuneline
    #   run-test: false        # promos (no test job)
    #   run-knip: false        # promos (no knip)
```

### `deploy-vercel.yml`

Deploys from CI via the Vercel CLI (build runs on Vercel, so Neon preview
branching + migrations behave exactly like a Git-triggered deploy). PR → preview,
push to `main` → production. Uploads a single tarball (`--archive=tgz`).

```yaml
name: Deploy
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened, ready_for_review]
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true
jobs:
  deploy:
    uses: pgsereno/workflows/.github/workflows/deploy-vercel.yml@main
    with:
      vercel-org-id: team_xxx       # from .vercel/project.json (not secret)
      vercel-project-id: prj_xxx
    secrets:
      VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}   # synced from 1Password via env-sync
```

## Prerequisites in each caller repo

- Repo lives in the `pgsereno` org with the **Blacksmith GitHub App** installed.
- `VERCEL_TOKEN` repo secret — synced from 1Password: `env-sync github-secrets`.
- A `bun` variant (`ci-bun.yml`) will be added when the first bun repo
  (finances-tracker) is migrated.
