IMAGE_TAG=local/zap

.PHONY: all
all: .image_build test

test:
	docker run -it -v ${PWD}:/ZAP ${IMAGE_TAG} bash /ZAP/run_tests.sh

# Build Docker image
.image_build: Dockerfile
	docker build --no-cache --rm --tag ${IMAGE_TAG} .
	touch .image_build

clean:
	rm -f .image_build
	docker image rm ${IMAGE_TAG}
