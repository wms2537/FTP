.PHONY: build-windows-amd64 build-windows-arm64 build-macos-amd64 build-macos-arm64 build-linux-amd64 build-linux-arm64

build-windows-amd64:
	docker build -f Dockerfile.windows -t ftp-client:windows-amd64 .

build-windows-arm64:
	docker build -f Dockerfile.windows -t ftp-client:windows-arm64 .

build-macos-amd64:
	docker build --platform linux/amd64 -f Dockerfile.macos -t ftp-client:macos-amd64 .

build-macos-arm64:
	docker build --platform linux/arm64 -f Dockerfile.macos -t ftp-client:macos-arm64 .

build-linux:
	docker buildx rm ftp-client-builder
	docker buildx create --use --name ftp-client-builder
	docker buildx build --platform linux/amd64,linux/arm64 \
		-f Dockerfile.build_linux \
		-t ftp-client:linux \
		--output type=local,dest=./build/linux .

build-all: build-windows-amd64 build-windows-arm64 build-macos-amd64 build-macos-arm64 build-linux
