NS = gwihlidal
VERSION ?= vk_rt8

REPO = docker-shader
NAME = docker-shader
INSTANCE = default

.PHONY: build push shell run start stop rm release cloud-build

build:
	docker build -t $(NS)/$(REPO):$(VERSION) .

push: build
	docker push $(NS)/$(REPO):$(VERSION)

shell: build
	docker run --rm --name $(NAME)-$(INSTANCE) --entrypoint=/bin/sh -i -t $(PORTS) $(VOLUMES) $(ENV) $(NS)/$(REPO):$(VERSION)

run: build
	docker run --rm --name $(NAME)-$(INSTANCE) $(PORTS) $(VOLUMES) $(ENV) $(NS)/$(REPO):$(VERSION)

start: build
	docker run -d --name $(NAME)-$(INSTANCE) $(PORTS) $(VOLUMES) $(ENV) $(NS)/$(REPO):$(VERSION)

release: build
	make push -e VERSION=$(VERSION)

stop:
	docker stop $(NAME)-$(INSTANCE)

rm:
	docker rm $(NAME)-$(INSTANCE)

cloud-build:
	gcloud container builds submit . --config=cloudbuild.yaml

default: build