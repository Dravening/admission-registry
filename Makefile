REPO=registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry
TAG=v1.0

build:
	docker build . --file Dockerfile --tag registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry:v1.0
    docker build . --file ./cmd/Dockerfile --tag registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry-tls:v1.0
push:
	docker push registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry:v1.0
	docker push registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry-tls:v1.0
all: build push