PROJECT_NAME ?= coreemu-dtn
REGISTRY ?= ghcr.io/slintak
IMAGE ?= $(REGISTRY)/$(PROJECT_NAME)

# CORE version (maps to Dockerfile ARG VERSION)
COREEMU_VERSION ?= release-9.2.1

# Tags
TAG_LATEST := $(IMAGE):latest
TAG_VERSION := $(IMAGE):$(COREEMU_VERSION)

DOCKERFILE ?= Dockerfile
RUN_SCRIPT ?= ./run.sh

.PHONY: build push run

build:
	docker build --pull -f $(DOCKERFILE) \
		--build-arg VERSION=$(COREEMU_VERSION) \
		-t $(TAG_LATEST) \
		-t $(TAG_VERSION) \
		.

push:
	docker push $(TAG_LATEST)
	docker push $(TAG_VERSION)

run:
	IMAGE=$(TAG_LATEST) $(RUN_SCRIPT)
