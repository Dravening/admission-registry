REPO=registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry
TAG=v1.0

build:
	docker build . --file Dockerfile --tag $(REPO):$(TAG)
push:
	docker push $(REPO):$(TAG)
all: build push