# Shoalcheck gate

GitHub Action that runs [`shoalcheck`](https://shoalcheck.com) (read-only Kubernetes preflight) in a job. It downloads the release for the runner's OS and architecture, verifies `checksums.txt` with cosign against the release key, verifies the archive's sha256, puts `shoalcheck` on PATH and runs it. The step's result is shoalcheck's exit code (0 satisfied, 2 policy fired, 1 could not run, 4 licence) and it is also the `exit-code` output.

The signing key is pinned in this repository (`cosign.pub`) and compared with `cosign.pub` of `Shoalcheck/shoalcheck` at the same tag; a mismatch stops the job.

## Inputs

| input | default | meaning |
|---|---|---|
| `version` | newest at publish (`0.1.0-rc.12`) | release to install. Pin it. |
| `args` | `gate` | arguments for `shoalcheck`, split on whitespace |
| `working-directory` | `.` | where to run |
| `kubeconfig` | | kubeconfig content (secret), read-only identity |
| `capture-key` | | public key a capture must be signed by |
| `licence` | | Team licence key (secret) |

Outputs: `exit-code`, `version`. Shoalcheck is read-only (`get`/`list` only); nothing is applied to a cluster.

## (a) Pull request against a live cluster

```yaml
on: pull_request
permissions: { contents: read }
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: helm template ./chart > rendered.yaml
      - uses: Shoalcheck/shoalcheck-action@v1   # or pin a full commit SHA
        with:
          version: 0.1.0-rc.12
          kubeconfig: ${{ secrets.KUBECONFIG }}
          licence: ${{ secrets.SHOALCHECK_LICENCE }}
          args: gate --context staging --with rendered.yaml --fail-on new:high,regressed,unreadable
```

## (b) Pull request with a capture (no kubeconfig in CI)

A trusted job writes the capture with `shoalcheck audit --capture <file>`, which prints the public key. Take the capture from the base branch or a trusted artifact, never from the pull request checkout.

```yaml
      - uses: Shoalcheck/shoalcheck-action@v1
        with:
          version: 0.1.0-rc.12
          licence: ${{ secrets.SHOALCHECK_LICENCE }}
          capture-key: ${{ vars.SHOALCHECK_CAPTURE_KEY }}
          args: gate --capture ${{ runner.temp }}/capture.json --with rendered.yaml --max-age 48h
```

## (c) Manifests only (no cluster)

```yaml
      - uses: Shoalcheck/shoalcheck-action@v1
        with:
          version: 0.1.0-rc.12
          args: gate --manifests-only --with rendered.yaml
```

## Pinning

Pin `version` always. Pin the action itself by full commit SHA, not a tag, as GitHub recommends for third-party actions:

```yaml
- uses: Shoalcheck/shoalcheck-action@<40-char-sha> # v1.0.0
```

## Local self-test

`test/selftest.sh [version]` runs the same download, verify and install logic on your machine and prints `shoalcheck --version` (needs `cosign`).
