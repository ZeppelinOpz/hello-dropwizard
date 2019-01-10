all: build

build:
	(docker stop hello-dropwizard-build > /dev/null 2>&1 || true) && (docker rm hello-dropwizard-build> /dev/null 2>&1 || true) 
	docker run --name hello-dropwizard-build -v $(PWD):/var/app/hello-dropwizard -v ~/.m2:/root/.m2 -w=/var/app/hello-dropwizard -it  maven:3.6.0-jdk-11-slim mvn package	

run:
	docker-compose up --build -d 

stop:
	docker-compose down

run: stop build run

.PHONY: all 