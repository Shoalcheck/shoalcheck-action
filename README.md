# shoalcheck gate — GitHub Action

Reads a Kubernetes cluster read-only and fails the job on what a pull request, or the cluster, changed. One step, no
code-scanning licence needed: the verdict lands in the job log, the run's summary, on the lines of the pull request's
diff, and in one pull-request comment that is updated on every push. On a public repository it publishes none of that
unless the workflow says so (below).

This is v2 of `Shoalcheck/shoalcheck-action`. v1 is a different interface, a passthrough of shoalcheck's arguments, and
stays at its tags `v1` and `v1.0.0`.

```yaml
on:
  pull_request:
    paths: ['deploy/**']

permissions:
  contents: read
  pull-requests: write   # the comment

jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
      - name: Render the pull request's manifests
        run: mkdir -p "$RUNNER_TEMP/change" && kubectl kustomize deploy/ > "$RUNNER_TEMP/change/rendered.yaml"
      - uses: Shoalcheck/shoalcheck-action@<commit> # v2.0.0
        with:
          version: 0.2.0
          licence: ${{ secrets.SHOALCHECK_LICENCE }}
          kubeconfig: ${{ secrets.KUBECONFIG }}
          context: staging
          with: ${{ runner.temp }}/change
          fail-on: new:high,regressed,unreadable,not-evaluated
```

## What it does

1. Installs the release you pin and checks it the way it is signed: the cosign signature over `checksums.txt` with the
   release key written into the action, then the archive against its checksum.
2. Takes `.shoalcheck/baseline.json` and `.shoalcheck/accept.yaml` from **the branch being merged into**, never from
   the pull request. A request that edits either file could record or accept its own finding and pass its own gate.
3. Runs `shoalcheck gate` once. From that one run it writes the log (`-o text`), the comment (`--md`) and the
   annotations (`--annotations`). Each finding is placed on the manifest line that carried it, through the manifest
   itself, Helm's `# Source:` comment or kustomize's `config.kubernetes.io/origin` annotation
   (`buildMetadata: [originAnnotations]`).
4. Posts the verdict as one comment, found by its `<!-- shoalcheck-gate -->` marker and updated in place.
5. Ends on the gate's own exit code: `0` satisfied, `2` the policy fired, `1` the run could not be judged, `4` the
   licence does not cover the gate.

A pull request from a fork is given no secrets, so that run is **not gated**, and the action **fails** it: a
required check that went green over nothing would merge what nobody looked at. A repository that accepts that for
forks sets `allow-ungated: 'true'`; the run then ends on 0 with a warning saying it was not gated.

The baseline and acceptances come from the pull request's base branch, from a merge queue's base commit, or, on a
push, schedule or manual run, from the branch itself. They are fetched into a ref of their own, and a failed fetch
stops the run. On any other event the action refuses to read them.

## On a public repository

A public repository's job log, run summary, annotations and comments are readable by anyone, and a reading names
namespaces, workloads and nodes; an error can name the API server's address. So there the action prints one line, the
gate's exit code and what it means, and writes nothing else: no comment, no annotations, no summary beyond that line.
The job still fails or passes on the gate. `public-details: 'true'` publishes the details as on a private repository.
A repository whose visibility the action cannot read is treated as public.

## Inputs

| input | default | |
|---|---|---|
| `version` | required | the release, without the leading `v`; pinned, never "latest" |
| `licence` | required | a Team licence key |
| `kubeconfig` | required | a kubeconfig with the read-only access `shoalcheck audit --show-permissions` prints |
| `context` | the current one | the kube context to read |
| `baseline` | `.shoalcheck/baseline.json` | read from the base branch; judged when it exists there |
| `with` | none | the pull request's rendered manifests (file or directory) |
| `namespace` | `default` | with `with`, where a manifest that names no namespace lands |
| `fail-on` | `new:high,regressed,unreadable` | `new`, `regressed`, `present`, `unreadable`, `not-evaluated`, `cost:+N`, `none` |
| `accept` | `.shoalcheck/accept.yaml` | read from the base branch; each entry names one finding, an owner, a reason and an end date |
| `comment` | `true` | post or update the pull-request comment (on a public repository, only with `public-details`) |
| `annotations` | `true` | put findings on the diff's lines |
| `public-details` | `false` | `true` publishes the log, summary, annotations and comment on a public repository too |
| `allow-ungated` | `false` | `true` lets a run with no licence or no cluster credentials end on 0 |

Outputs: `exit-code`, `gated` (`false` when the run had no licence or no cluster credentials), and `published`
(`false` when a public repository withheld the details).
