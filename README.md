# calibration-containers

Unofficial container images for the camera-calibration toolchain by Dima
Kogan: [mrgingham](https://github.com/dkogan/mrgingham) (chessboard corner
finder), [mrcal](https://github.com/dkogan/mrcal) (calibration solver and
tools) and [vnlog](https://github.com/dkogan/vnlog) (the text-table tools they
both use). The images are built on Debian from the upstream sources, and the
tools run from a Fedora (or any Podman) host as if they were installed natively.

The upstream projects are distributed through native packages (Debian, Ubuntu,
Homebrew, …) and don't carry container files. This repository holds only the
build instructions, and builds from pinned upstream commits. Report bugs in the
tools upstream; report problems with the images here.

## Quick start

```sh
make            # fetch the pinned sources, build and test every image
make check      # smoke-test the images from the host
make links      # symlink every tool into ~/.local/bin
```

Then use the tools as usual:

```sh
mrgingham --jobs 4 --gridn 14 '*.jpg' > corners.vnl
mrcal-calibrate-cameras --corners-cache corners.vnl --lensmodel LENSMODEL_OPENCV8 \
    --focal 1900 --object-spacing 0.0588 --object-width-n 14 '*.jpg'
vnl-filter -p x,y < corners.vnl
```

`make unlinks` removes the links. Needs Podman (rootless is fine), git, GNU
make and `patch`; `make bump-debian` also needs skopeo.

## Images

| Image                | Contents                                                       |
|----------------------|----------------------------------------------------------------|
| `calibration-base`   | Build stage only: Debian toolchain, mrbuild, libdogleg, vnlog  |
| `vnlog`              | `vnl-*` tools, libvnlog, the Perl modules                      |
| `mrgingham`          | `mrgingham*` tools, libmrgingham, the Python module, plus vnlog with its Python module |
| `mrcal`              | everything in `mrgingham`, plus libmrcal, the `mrcal` Python package and the `mrcal-*` tools |

```
calibration-base ──┬──> vnlog
 (mrbuild,         ├──> mrgingham ──> mrcal (runtime layered on mrgingham)
  libdogleg,       └───────────────────┘ (build stage)
  vnlog)
```

`calibration-base` builds and tests libdogleg and vnlog, so every image, and
every test suite, uses the pinned vnlog. mrgingham and mrcal each build in
`calibration-base`, run the upstream test suite, install into a staging tree,
and copy that into a slim Debian runtime image with only the runtime libraries
it links against, then smoke-test the result. The vnlog image is just the
runtime part, copied from `calibration-base`; it has no Python, so vnlog's
Python module is only in mrgingham and mrcal. Images are
tagged `localhost/NAME:VERSION` (from `git describe` of the source) and
`localhost/NAME:latest`, and labelled with the source URL and commit
(`podman image inspect`).

mrcal's build runs the `test-nosampling` test set. Pick another with
`make mrcal BUILD_ARGS=MRCAL_TESTS=test-all`, or skip the tests with
`BUILD_ARGS=MRCAL_TESTS=`. `BUILD_ARGS` takes space-separated `NAME=VALUE`
build args and applies to every image that run builds.

## Sources and patches

`sources.lock` pins each upstream to a tag or full commit hash. `make` clones
each upstream once into `.cache/git/`, exports the pinned commit into
`.cache/src/`, and applies `patches/NAME/*.patch` on top. The image versions get
a `-patched` suffix when patches apply.

- **Moving a pin:** `make outdated` lists newer upstream tags. Edit
  `sources.lock` and run `make`.
- **Carrying a fix:** put it in `patches/NAME/` (`git format-patch` output),
  send it upstream, and delete it once upstream has it.
- **Current patches:**
  - `mrgingham/0001`: run the rotate-corners test with `zsh` from the
    `PATH` instead of `/bin/zsh`.
  - `mrcal/0001`: skip `test-optimizer-callback.py`. Its golden reference data
    predates upstream's 2026-06-20 "Reworked regularization" commit, so it fails
    on upstream master too. Drop the patch when upstream refreshes the data.
- **Debian base:** every stage starts from `DEBIAN_IMAGE` in the Makefile,
  pinned by digest. `make bump-debian` moves it to the current `trixie-slim`.

### Building from a local checkout

```sh
make mrgingham SRC_mrgingham=~/Code/mrgingham
make LOCAL=1                     # every source from ~/Code/NAME (LOCAL_ROOT=…)
```

This builds the checkout's working tree, including uncommitted edits but not
ignored files such as build outputs. The image version is the checkout's
`git describe --dirty`.

## How the wrappers work

`make links` points each tool at `bin/in-IMAGE`, which runs it through
`bin/run-in-image`:

- `$HOME`, `/tmp`, `/mnt`, `/media`, `/run/media`, `/srv` and the current
  directory are mounted at the same paths, so file arguments under those work
  unchanged. Paths elsewhere (e.g. `/opt/data`) aren't visible.
- `--userns=keep-id`: files are written as you.
- `label=disable`: no SELinux relabelling of your directories.
- X11/XWayland passthrough when `DISPLAY` is set, so `--show` plots and the
  `mrcal-stereo --viz` window open. No network otherwise.
- `--init`, so Ctrl-C works.

To run anything else in an image: `bin/in-mrcal python3 -c 'import mrcal'`.
`CALIBRATION_TAG=1.28-5-g8775c09-patched mrgingham …` runs a specific build
instead of `latest`.

## Licenses

The images contain the upstream projects, which carry their own licenses
(mrgingham and vnlog: LGPL-2.1+; mrcal: Apache-2.0; see each project), plus
Debian packages under theirs. Each
image keeps the upstream README and LICENSE files in `/usr/share/doc/NAME/`. If
you publish the images, link the exact source commits from `sources.lock`
alongside them.
