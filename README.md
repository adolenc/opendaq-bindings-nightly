# opendaq-bindings-nightly

Nightly builds of what an openDAQ language binding needs: a machine-readable description of the
openDAQ C API to generate the binding from, and the C bindings library (`copendaq`) to load at run
time. Bindings such as [cl-opendaq](https://github.com/adolenc/cl-opendaq) and
[jopendaq](https://github.com/adolenc/jopendaq) pin one release of this repository and never build
openDAQ themselves.

Each release is tagged `nightly-<date>-<openDAQ sha>-<overlay sha>` and everything in it is built
from that one commit of [openDAQ](https://github.com/openDAQ/openDAQ) `main`, so the spec always
matches the libraries next to it. The overlay is the branch that holds the spec and C bindings
generators until they are upstream. Old releases are kept, so a pinned tag keeps working.

## What is in a release

**`manifest.json`** is the entry point. It names the commits the release was built from
(`upstream`, `overlay`) and lists the other files (`spec`, `natives.<triple>`, `c_headers`), each
with its file name, SHA-256 and size. Take the file names from here rather than hard-coding them.

**`opendaq-api-spec.json`** describes the C API exactly as `copendaq` exports it. It has every
interface with its id, base interface, methods (with their vtable slots), factories and functions,
plus the enums, the error codes, the plain types (aliases, structs, callbacks) and notes on the
ABI. Doc comments are included. This is the file a binding is generated from.

**`copendaq-<triple>.tar.gz`** holds the shared libraries for one platform: `linux-x64`,
`macos-arm64` or `windows-x64`. The archive is flat. It contains `copendaq`, the openDAQ libraries
it depends on (`daqcoretypes`, `daqcoreobjects`, `opendaq`) and the modules enabled in
`nightly.env`, currently the reference device, the reference function blocks and the native
streaming client. Extract it into one directory, which is then both where `copendaq` is loaded from
and the module path.

**`copendaq-headers.tar.gz`** has the C headers of `copendaq`. Only a binding that compiles against
the C API needs it; one that goes through an FFI can work from the spec alone.

## Using a release

Pin a release tag in the binding. Download `manifest.json` from that release, then the spec and
the archive for each platform you need, and check each file against its SHA-256 in the manifest.
The API can change between nightlies, so regenerate the binding from the spec whenever the pin
moves. Both JSON files carry a `schema` field (`opendaq-bindings-nightly/1` for the manifest,
`opendaq-bindings/1` for the spec) that tells you which layout you are reading.

How a nightly is built is in `.github/workflows/nightly.yml` and the scripts it calls;
`nightly.env` says what is built.
