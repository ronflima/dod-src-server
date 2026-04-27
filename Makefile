IMAGE_NAME := day-of-defeat-source
IMAGE_TAG := latest
IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: build up down
build:
	docker build -t $(IMAGE) .
up:
	docker-compose up -d  
	docker-compose logs -f
down:
	docker-compose down 
