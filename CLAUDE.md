# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Podman images for the mrgingham, mrcal and vnlog camera-calibration tools, built
on Debian from pinned upstream sources, plus host wrappers that run the tools as
if installed natively. User-facing docs: README.md. Make targets: the Makefile
header. Each script and Containerfile explains itself in its header comment.

## Testing changes

- Upstream test suites run inside each image's build stage, so `make` is slow;
  build just the image you changed (`make mrgingham`). Changing
  `calibration-base`, or the vnlog or libdogleg pins it builds, rebuilds and
  re-tests every image.
- Changes to `bin/` or `scripts/` need no rebuild: `make lint` (shellcheck),
  then `make check`, which runs every tool through the wrappers against the
  existing images.
- Try `make links`/`unlinks` with a scratch `BINDIR=`, not the real
  `~/.local/bin`.

## Architecture

`sources.lock` → `scripts/fetch-source` (exports pinned rev + patches into
`.cache/src/NAME`; a stamp skips re-export when nothing changed) →
`scripts/build-image` (each source becomes a `--build-context`) →
`images/*/Containerfile` → `bin/` wrappers.

- Containerfile `ARG DEBIAN_IMAGE`/`ARG PREFIX` have no defaults and the
  sources arrive as build contexts, so build only through make/`build-image`,
  never a bare `podman build`.
- The Makefile's image prerequisites and per-image source lists are written by
  hand; keep them in sync with each Containerfile's `FROM ${PREFIX}...` and
  `COPY --from=NAME` lines.
- calibration-base builds libdogleg and vnlog and keeps each install tree in
  `/stage/NAME` for the runtime images to copy (vnlog's Python module apart, in
  `/stage/vnlog-python`, since the vnlog image has no python3). The vnlog image
  has no build stage of its own.
- mrcal's runtime stage is `FROM ${PREFIX}mrgingham`, which is why it resets
  `ENTRYPOINT []`.
- Build stages share conventions; change them in every Containerfile together:
  install into `/stage`, write `/usr/share/calibration-containers/IMAGE.tools`,
  copy README/LICENSE to `/usr/share/doc/IMAGE`, list runtime packages via
  `ldd | dpkg -S`, smoke-test the runtime stage.
- `IMAGE.tools` is the only list of tools: `scripts/check` and
  `scripts/link-tools` read it from the image, so nothing on the host lists
  tools.
- `bin/in-IMAGE` are symlinks to `bin/run-in-image`, which takes the tool from
  `$0` and the image from the one-hop `readlink` target. A new image needs only
  a new `in-IMAGE` symlink on the host side.

## Gotchas

- In the Makefile, `export A=x B=y` on one line sets only `A` (to `x B=y`).
  Use one `export` per variable.
- Each patch's commit message says why it exists and when to drop it; README
  lists the current ones.
- Deliberately not included: libelas (non-free, not in Debian trixie), the
  unsigned mrcal APT repo, and a host `/` mount.
