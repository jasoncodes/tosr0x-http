build:
	docker build \
		--tag jasoncodes/tosr0x-http \
		--progress plain \
		.

push:
	docker buildx build \
		--platform linux/arm64/v8,linux/amd64 \
		--tag jasoncodes/tosr0x-http \
		--push \
		.
