# Builds the camera-calibration tool images from the upstream sources pinned in
# sources.lock, and links the tools into $(BINDIR) so they run like native
# commands. See README.md.
#
#   make                   # build vnlog, mrgingham and mrcal (and their base)
#   make mrgingham         # build one image
#   make check             # smoke-test the images from the host
#   make lint              # shellcheck the wrapper and scripts
#   make links             # symlink every tool into $(BINDIR)
#   make unlinks           # remove those symlinks
#   make outdated          # list upstream tags newer than the pins
#   make bump-debian       # re-pin DEBIAN_IMAGE to the current digest
#
# Build from local checkouts instead of the pins:
#
#   make mrgingham SRC_mrgingham=~/Code/mrgingham
#   make LOCAL=1           # every source from $(LOCAL_ROOT)/NAME
#
# Extra build args (NAME=VALUE, space-separated) for the Containerfiles:
#
#   make mrcal BUILD_ARGS=MRCAL_TESTS=test-all

ENGINE     ?= podman
PREFIX     ?= localhost/
BINDIR     ?= $(HOME)/.local/bin
LOCAL_ROOT ?= $(HOME)/Code

# Every image starts from this. Pinned by its multi-arch digest so a rebuild
# doesn't silently pick up a new Debian point release; "make bump-debian"
# updates it
DEBIAN_TAG   := docker.io/library/debian:trixie-slim
DEBIAN_IMAGE ?= $(DEBIAN_TAG)@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f

export ENGINE PREFIX DEBIAN_IMAGE LOCAL LOCAL_ROOT BUILD_ARGS
# For bin/run-in-image, which check and links go through
export CALIBRATION_ENGINE = $(ENGINE)
export CALIBRATION_PREFIX = $(PREFIX)
export $(filter SRC_%,$(.VARIABLES))

IMAGES := vnlog mrgingham mrcal

all: $(IMAGES)

calibration-base:
	scripts/build-image $@ mrbuild libdogleg
vnlog: calibration-base
	scripts/build-image $@ vnlog
mrgingham: calibration-base
	scripts/build-image $@ mrgingham
mrcal: calibration-base mrgingham
	scripts/build-image $@ mrcal

check:
	scripts/check $(IMAGES)

links:
	scripts/link-tools link $(BINDIR) $(IMAGES)
unlinks:
	scripts/link-tools unlink $(BINDIR) $(IMAGES)

lint:
	shellcheck bin/run-in-image $(wildcard scripts/*)

outdated:
	scripts/outdated

bump-debian:
	@digest=$$(skopeo inspect --format '{{.Digest}}' docker://$(DEBIAN_TAG)) \
	  && sed -i "s|^\(DEBIAN_IMAGE ?= .*@\).*|\1$$digest|" Makefile \
	  && echo "DEBIAN_IMAGE pinned to $(DEBIAN_TAG)@$$digest"

# Removes the fetched sources. The images stay; remove those with "podman rmi"
clean:
	rm -rf .cache

.PHONY: all calibration-base $(IMAGES) check lint links unlinks outdated bump-debian clean
