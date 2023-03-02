build:
	docker build . --file Dockerfile --tag registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry:v1.0

build-tls:
	docker build . --file ./cmd/Dockerfile --tag registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry-tls:v1.0

push:
	docker push registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry:v1.0

push-tls:
	docker push registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry-tls:v1.0

total: build push

total-tls: build-tls push-tls