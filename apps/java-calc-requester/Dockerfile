## Stage 1 : build with maven builder image with native capabilities
FROM quay.io/quarkus/centos-quarkus-maven:21.3.0-java11 AS build
COPY . /tmp/my-project
USER root
RUN chown -R quarkus /tmp/my-project
USER quarkus
RUN ls -l
RUN mvn -e -f /tmp/my-project/pom.xml -Pnative clean package

## Stage 2 : create the docker final image
FROM registry.access.redhat.com/ubi8/ubi-minimal
WORKDIR /usr/src/app/target/
COPY --from=build /tmp/my-project/target/*-runner /usr/src/app/target/application
COPY --from=build /tmp/my-project/applicationinsights-agent-3.2.7.jar /usr/src/app/target/
RUN chmod 775 /usr/src/app/target
ENV JAVA_OPTS="-javaagent:/usr/src/app/target/applicationinsights-agent-3.2.7.jar"
EXPOSE 8080
CMD ["./application", "-XX:+PrintGC", "-XX:+PrintGCTimeStamps", "-XX:+VerboseGC", "+XX:+PrintHeapShape", "-Xmx256m", "-Dquarkus.http.host=0.0.0.0"]