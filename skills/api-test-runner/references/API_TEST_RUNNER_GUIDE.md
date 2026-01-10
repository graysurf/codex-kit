# API Test Runner Guide

This guide complements `skills/api-test-runner/SKILL.md` with practical repo layout options and copy/paste commands.

## Directory layouts

### Option A (recommended): `setup/` canonical layout

Why:

- Matches existing `rest-api-testing` / `graphql-api-testing` conventions
- Avoids coupling to any particular test framework’s directory structure

Typical structure:

```text
setup/
  api/
    suites/
      smoke.suite.json
  rest/
    endpoints.env
    tokens.env
    requests/
      health.request.json
  graphql/
    endpoints.env
    jwts.env
    operations/
      countries.graphql
      countries.variables.json
```

Run:

```bash
$CODEX_HOME/skills/api-test-runner/scripts/api-test.sh \
  --suite smoke \
  --out out/api-test-runner/results.json \
  --junit out/api-test-runner/junit.xml
```

### Option B: put everything under `tests/`

This is supported today, but with one important note:

- `api-test-runner --suite <name>` currently resolves only to `setup/api/suites/<name>.suite.json`
- If your suite files live under `tests/`, run with `--suite-file <path>` instead

Recommended structure:

```text
tests/
  api/
    suites/
      smoke.suite.json
  rest/
    endpoints.env          # optional (use --url or REST_URL instead)
    tokens.env             # optional (use ACCESS_TOKEN in CI instead)
    requests/
      health.request.json
  graphql/
    endpoints.env          # optional (use --url or GQL_URL instead)
    jwts.env               # optional (use ACCESS_TOKEN in CI instead)
    operations/
      countries.graphql
      countries.variables.json
```

#### Bootstrap (copy bundled templates, then rename/move)

```bash
mkdir -p tests
cp -R "$CODEX_HOME/skills/api-test-runner/template/setup/api" tests/
cp -R "$CODEX_HOME/skills/api-test-runner/template/setup/rest" tests/
cp -R "$CODEX_HOME/skills/api-test-runner/template/setup/graphql" tests/
```

Then edit your suite file to reference `tests/...` paths and set `configDir` defaults.

Example (minimal pattern):

```json
{
  "version": 1,
  "name": "smoke",
  "defaults": {
    "noHistory": true,
    "rest": { "configDir": "tests/rest" },
    "graphql": { "configDir": "tests/graphql" }
  },
  "cases": [
    { "id": "rest.health", "type": "rest", "request": "tests/rest/requests/health.request.json" },
    { "id": "graphql.countries", "type": "graphql", "op": "tests/graphql/operations/countries.graphql" }
  ]
}
```

Run:

```bash
$CODEX_HOME/skills/api-test-runner/scripts/api-test.sh \
  --suite-file tests/api/suites/smoke.suite.json \
  --out out/api-test-runner/results.json \
  --junit out/api-test-runner/junit.xml
```

#### CI note (URLs/tokens)

In CI, prefer explicit env vars (and runtime login) instead of committing real secrets into `tests/**/tokens.env` / `jwts.env`:

- REST:
  - URL: `--url ...` or `REST_URL=...`
  - Auth (option A): `ACCESS_TOKEN=...` (Bearer token)
- GraphQL:
  - URL: `--url ...` or `GQL_URL=...`
  - Auth (option A): `ACCESS_TOKEN=...` (Bearer token)

Option B (recommended when JWTs expire): runtime login via a single JSON secret + suite `auth` block:

- Provide a GitHub Secret (default name): `API_TEST_AUTH_JSON`
- Add `auth` to your suite manifest (`setup/api/suites/*.suite.json`)
- The runner logs in once per profile and injects `ACCESS_TOKEN` per case (no token files needed in CI)

## GitHub Actions

The repo ships a working example workflow using the bundled public suite:

- `.github/workflows/api-test-runner.yml`

If you want to run a committed `tests/` layout instead:

- Remove the “Bootstrap public suite” step
- Change the run command to use `--suite-file tests/api/suites/<suite>.suite.json`

### Matrix sharding (parallel by tags)

For large suites, split cases into shards by adding shard tags and running the suite in a matrix.

Tagging pattern (example):

- Add a stable tag for the environment (e.g. `staging`)
- Add a mutually exclusive shard tag for every case (e.g. `shard:0`, `shard:1`)

Workflow sketch:

```yaml
strategy:
  fail-fast: false
  matrix:
    shard: ["0", "1"]

steps:
  - name: Run suite shard
    env:
      CODEX_HOME: ${{ github.workspace }}
      API_TEST_AUTH_JSON: ${{ secrets.API_TEST_AUTH_JSON }}
    run: |
      skills/api-test-runner/scripts/api-test.sh \
        --suite my-suite \
        --tag staging \
        --tag "shard:${{ matrix.shard }}" \
        --out "out/api-test-runner/results.shard-${{ matrix.shard }}.json" \
        --junit "out/api-test-runner/junit.shard-${{ matrix.shard }}.xml"
```

Notes:

- `--tag` uses AND semantics when repeated: a case must include all selected tags to run.
- Use per-shard output filenames (and per-shard artifacts) to avoid collisions.
