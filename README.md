# opendaq-bindings-nightly

Nightly builds of the two things an openDAQ language binding is generated from and loads:

- **`opendaq.json`**: a machine-readable description of the openDAQ C API (interfaces with
  their methods, factories and functions, enums, status codes and ABI types, plus interface ids
  and vtable slots), exactly as the C bindings library exports it, and
- **the C bindings library** (`copendaq`) with the openDAQ runtime and the reference modules,
  built for `linux-x64`, `darwin-arm64` and `windows-x64`.

Both come from the same commit of [openDAQ](https://github.com/openDAQ/openDAQ) `main`, so a
binding generated from the spec always matches the libraries it loads. Language bindings
([cl-opendaq](https://github.com/adolenc/cl-opendaq), [jopendaq](https://github.com/adolenc/jopendaq))
pin one release of this repository and never build openDAQ themselves.

This repository holds no openDAQ code. It is a CI runner: a config file, a handful of scripts
that do the work, and a workflow that only wires the scripts into jobs.

## Releases

Every release is tagged `nightly-<date>-<openDAQ sha>-<overlay sha>` and carries:

| Asset | Contents |
| --- | --- |
| `manifest.json` | The commits the release was built from and every asset with its SHA-256. The only file a consumer needs to know the name of. |
| `opendaq.json` | The API spec. |
| `opendaq-native-<triple>.tar.gz` | Flat archive of the shared libraries: `copendaq`, the openDAQ core libraries, and the modules. |
| `opendaq-c-headers.tar.gz` | `bindings/c/include`, for consumers that compile against the C API. |
| `bindings-overlay.patch` | Everything that differs from the upstream commit; `git apply --binary` it onto `upstream.sha` to reproduce the exact sources. |
| `SHA256SUMS` | Checksums of the above. |

```json
{
  "schema": "opendaq-bindings-nightly/1",
  "tag": "nightly-20261110-0e29cce-1a2b3c4",
  "base_url": "https://github.com/<owner>/opendaq-bindings-nightly/releases/download/nightly-20261110-0e29cce-1a2b3c4/",
  "upstream": { "repo": "https://github.com/openDAQ/openDAQ.git", "ref": "main", "sha": "0e29cce5..." },
  "overlay":  { "repo": "...", "ref": "bindings-generators", "sha": "...", "patch": { "file": "bindings-overlay.patch", "sha256": "...", "size": 0 } },
  "spec":     { "file": "opendaq.json", "sha256": "...", "size": 0, "schema": "opendaq-bindings/1" },
  "c_headers": { "file": "opendaq-c-headers.tar.gz", "sha256": "...", "size": 0 },
  "natives": {
    "linux-x64":    { "file": "opendaq-native-linux-x64.tar.gz",    "sha256": "...", "size": 0 },
    "darwin-arm64": { "file": "opendaq-native-darwin-arm64.tar.gz", "sha256": "...", "size": 0 },
    "windows-x64":  { "file": "opendaq-native-windows-x64.tar.gz",  "sha256": "...", "size": 0 }
  }
}
```

### Consuming a release

A binding keeps the tag it was generated from in a lock file and bumps it deliberately:

1. download `<base_url>manifest.json` for the pinned tag,
2. download `spec.file` and the `natives[<triple>].file` it needs, verifying each `sha256`,
3. regenerate the binding from the spec, load the libraries from the extracted archive.

Releases are never pruned or moved, so a pinned tag keeps working. `gh release list` (or the
releases page) shows what there is to bump to.

## How a nightly is built

```
prepare (linux)                          build (linux, macOS, windows)        publish
---------------                          -----------------------------        -------
clone openDAQ main                       clone openDAQ at the same commit     manifest.json
merge the generator overlay        -->   git apply bindings-overlay.patch --> SHA256SUMS
rebuild generators, regenerate           cmake, build                         GitHub release
check spec against C headers             package-natives.sh
=> opendaq.json, bindings-overlay.patch  => opendaq-native-<triple>.tar.gz
                                   \
                                    `->  test (linux): the C bindings tests,
                                         alongside the builds; does not hold
                                         up the release
```

- `nightly.env` says what is built: the upstream repository and ref, the overlay, and the
  openDAQ CMake options.
- Every step of the workflow is one script, and each runs standalone:

  | Script | Job | Does |
  | --- | --- | --- |
  | `resolve-release.sh` | prepare | picks the commits and the release tag, or skips the run |
  | `install-deps.sh` | all | installs mono (generators) or openDAQ's build dependencies |
  | `prepare-source.sh` | prepare | merges the overlay, regenerates, checks the spec against the C headers |
  | `checkout-source.sh` | build, test | upstream commit plus `bindings-overlay.patch` |
  | `build-natives.sh` | build | configures and builds one platform, then `package-natives.sh` |
  | `test-c-bindings.sh` | test | builds and runs only `bindings/c/tests` (needs Ninja) |
  | `publish-release.sh` | publish | `write-manifest.py`, then the GitHub release |

  `scripts/prepare-source.sh /tmp/work` (needs `git`, `mono`, `mcs`, `python3`) is the quickest
  way to see what a nightly would contain, and `scripts/test-c-bindings.sh <openDAQ> <build-dir>`
  runs the C bindings tests on any checkout.
- The `test` job builds the same sources with the tests switched on. It runs next to the release
  builds and `publish` does not wait for it, so a failing test shows on the run without holding
  back the spec and the libraries; add `test` to `publish`'s `needs` to make it a gate.

A run is skipped when a release for the same pair of commits already exists; dispatch the
workflow with `force` to rebuild it.

### The generator overlay

The spec generator (`RTGen.Json`) and the reworked C bindings generator are not in upstream openDAQ
yet. Until they are, they live on the `bindings-generators` branch of a fork, and the nightly
merges that branch onto upstream `main` before generating.

Generated files are never merged. Both generators discover the API from the C++ headers, so after
the merge everything generated is simply regenerated, which is what makes a new upstream interface
show up in the next nightly with no manual step. If the merge conflicts in a generated file, the
conflict is discarded and the file regenerated. If it conflicts in a hand-written file, the run
fails: the overlay branch then needs a rebase onto upstream by hand.

Once the generators are upstream, empty `OVERLAY_REPO` in `nightly.env` and the overlay step
disappears.

## Setting up

1. Create the repository and push this directory.
2. Make sure the overlay branch named in `nightly.env` is pushed and public.
3. Run the workflow once by hand (Actions → Nightly bindings → Run workflow) to get the first
   release.

Scheduled workflows are disabled by GitHub after 60 days without repository activity; re-enable
the workflow from the Actions tab if nightlies stop.
