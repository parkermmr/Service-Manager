REGISTRY                ?= localhost
IMAGE                   ?= workstation
TAG                     ?= slim
BASE_TAG                ?= base

ALPINE_REGISTRY_MIRROR  ?= https://dl-cdn.alpinelinux.org/alpine
GITHUB_MIRROR           ?= https://github.com
PYPI_MIRROR             ?= https://pypi.org/simple

GIT_TAG                 := $(shell git describe --tags --exact-match 2>/dev/null)
GIT_BRANCH              := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
GIT_REF                 := $(if $(GIT_TAG),$(GIT_TAG),$(GIT_BRANCH))
GIT_REF_SAFE            := $(subst /,-,$(GIT_REF))

COMMIT                  ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
VERSION                 ?= $(GIT_REF_SAFE)
BUILT                   ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
URI                     ?= org.default

UID                     ?= 1000
GID                     ?= 1000
USERNAME                ?= somebody
GROUPNAME               ?= somebody
HOMEDIR                 ?= /opt/home/somebody
SCRATCH                 ?= /scratch/local

PLUGINS                 ?=

AYB_CONFIG              ?= build.yaml
AYB_LOCKFILE            ?= build-lock.json
AYB_IMAGE_TAR           ?= image.tar
AYB_IMAGE_NAME          ?= workstation:base
CONTAINERFILE           ?= Containerfile

BASE_IMAGE              := $(REGISTRY)/$(IMAGE):$(BASE_TAG)
IMAGE_REF               := $(REGISTRY)/$(IMAGE)

TAG_REF                 := $(IMAGE_REF):$(GIT_REF_SAFE)
TAG_COMMIT              := $(IMAGE_REF):$(COMMIT)
TAG_REF_COMMIT          := $(IMAGE_REF):$(GIT_REF_SAFE)-$(COMMIT)

.PHONY: all base build lock clean clean-base help

all: build

lock:
	@rm -f $(AYB_LOCKFILE)
	ALPINE_REGISTRY_MIRROR=$(ALPINE_REGISTRY_MIRROR)        \
	GITHUB_MIRROR=$(GITHUB_MIRROR)                          \
	PYPI_MIRROR=$(PYPI_MIRROR)                              \
	ayb lock --config $(AYB_CONFIG)

base: lock
	@rm -f $(AYB_IMAGE_TAR)
	ALPINE_REGISTRY_MIRROR=$(ALPINE_REGISTRY_MIRROR)        \
	GITHUB_MIRROR=$(GITHUB_MIRROR)                          \
	PYPI_MIRROR=$(PYPI_MIRROR)                              \
	ayb build --config $(AYB_CONFIG) --save $(AYB_IMAGE_TAR)
	docker load < $(AYB_IMAGE_TAR)
	docker tag $(AYB_IMAGE_NAME) $(BASE_IMAGE)
	-docker rmi $(AYB_IMAGE_NAME) 2>/dev/null

build: base
	docker build                                            \
	    --build-arg REGISTRY=$(REGISTRY)                    \
	    --build-arg VERSION=$(VERSION)                      \
	    --build-arg COMMIT=$(COMMIT)                        \
	    --build-arg BUILT=$(BUILT)                          \
	    --build-arg URI=$(URI)                              \
	    --build-arg UID=$(UID)                              \
	    --build-arg GID=$(GID)                              \
	    --build-arg USERNAME=$(USERNAME)                    \
	    --build-arg GROUPNAME=$(GROUPNAME)                  \
		--build-arg HOMEDIR=$(HOMEDIR)                      \
    	--build-arg SCRATCH=$(SCRATCH)                      \
	    --build-arg PLUGINS=$(PLUGINS)                      \
	    -f $(CONTAINERFILE)                                 \
	    -t $(TAG_REF)                                       \
	    -t $(TAG_COMMIT)                                    \
	    -t $(TAG_REF_COMMIT)                                \
	    .

clean:
	rm -f $(AYB_LOCKFILE) $(AYB_IMAGE_TAR)

clean-base: clean
	-docker rmi $(BASE_IMAGE) $(TAG_REF) $(TAG_COMMIT) $(TAG_REF_COMMIT) 2>/dev/null

help:
	@echo "Targets:"
	@echo "  lock       - regenerate ayb lockfile"
	@echo "  base       - build ayb base image and load into docker"
	@echo "  build      - build final image (default)"
	@echo "  clean      - remove lockfile and tar"
	@echo "  clean-base - clean + remove docker images"
	@echo ""
	@echo "Build args:"
	@echo "  PLUGINS = $(PLUGINS)"
	@echo ""
	@echo "Resolved:"
	@echo "  BASE_IMAGE     = $(BASE_IMAGE)"
	@echo "  TAG_REF        = $(TAG_REF)"
	@echo "  TAG_COMMIT     = $(TAG_COMMIT)"
	@echo "  TAG_REF_COMMIT = $(TAG_REF_COMMIT)"
	@echo "  GIT_REF        = $(GIT_REF)"
	@echo "  COMMIT         = $(COMMIT)"
	@echo "  BUILT          = $(BUILT)"