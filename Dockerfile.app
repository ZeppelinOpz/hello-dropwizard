FROM maven:3.6.0-jdk-11-slim

RUN mkdir -p /var/app/hello-dropwizard
COPY example.yaml /var/app/hello-dropwizard/example.yaml
COPY target/hello-dropwizard-1.0-SNAPSHOT.jar /var/app/hello-dropwizard/.
WORKDIR /var/app/hello-dropwizard/
ENTRYPOINT ["java", "-jar", "hello-dropwizard-1.0-SNAPSHOT.jar", "server", "example.yaml"]

EXPOSE 8080 8081