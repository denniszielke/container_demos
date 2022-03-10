## Stage 1 : build with maven builder image with native capabilities
FROM quay.io/quarkus/ubi-quarkus-native-image:21.3.1-java11 AS build
COPY --chown=quarkus:quarkus mvnw /code/mvnw
COPY --chown=quarkus:quarkus .mvn /code/.mvn
COPY --chown=quarkus:quarkus pom.xml /code/
USER quarkus
WORKDIR /code
RUN ./mvnw -B org.apache.maven.plugins:maven-dependency-plugin:3.1.2:go-offline
COPY src /code/src
RUN ./mvnw package -Pnative

FROM quay.io/quarkus/quarkus-micro-image:1.0
WORKDIR /work/
COPY --from=build /code/target/*-runner /work/application

# set up permissions for user `1001`
RUN chmod 775 /work /work/application \
  && chown -R 1001 /work \
  && chmod -R "g+rwX" /work \
  && chown -R 1001:root /work

EXPOSE 8080
USER 1001

CMD ["./application", "-Dquarkus.http.host=0.0.0.0"]


# FROM registry.access.redhat.com/ubi8/ubi-minimal:8.4 

# ARG JAVA_PACKAGE=java-11-openjdk-headless
# ARG RUN_JAVA_VERSION=1.3.8
# ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en'
# # ENV APPLICATIONINSIGHTS_CONNECTION_STRING='InstrumentationKey='
# # ENV ENDPOINT_HOST=host.docker.internal
# #ENV ENDPOINT_HOST=localhost
# ENV ENDPOINT_PORT=3000
# # Install java and the run-java script
# # Also set up permissions for user `1001`
# RUN microdnf install curl ca-certificates ${JAVA_PACKAGE} \
#     && microdnf update \
#     && microdnf clean all \
#     && mkdir /deployments \
#     && chown 1001 /deployments \
#     && chmod "g+rwX" /deployments \
#     && chown 1001:root /deployments \
#     && curl https://repo1.maven.org/maven2/io/fabric8/run-java-sh/${RUN_JAVA_VERSION}/run-java-sh-${RUN_JAVA_VERSION}-sh.sh -o /deployments/run-java.sh \
#     && chown 1001 /deployments/run-java.sh \
#     && chmod 540 /deployments/run-java.sh \
#     && echo "securerandom.source=file:/dev/urandom" >> /etc/alternatives/jre/conf/security/java.security

# # Configure the JAVA_OPTIONS, you can add -XshowSettings:vm to also display the heap size.
# ENV JAVA_OPTIONS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager -javaagent:/deployments/agent/applicationinsights-agent.jar"
# # We make four distinct layers so if there are application changes the library layers can be re-used
# COPY --from=BUILD --chown=1001 target/quarkus-app/lib/ /deployments/lib/
# COPY --from=BUILD --chown=1001 target/quarkus-app/lib/main/com.microsoft.azure.applicationinsights-agent-*.jar /deployments/agent/applicationinsights-agent.jar
# COPY --from=BUILD --chown=1001 target/quarkus-app/*.jar /deployments/
# COPY --from=BUILD --chown=1001 target/quarkus-app/app/ /deployments/app/
# COPY --from=BUILD --chown=1001 target/quarkus-app/quarkus/ /deployments/quarkus/

# EXPOSE 8080
# USER 1001

# ENTRYPOINT [ "/deployments/run-java.sh" ]



# ## Stage 2 : create the docker final image
# FROM registry.access.redhat.com/ubi8/ubi-minimal
# WORKDIR /usr/src/app/target/

# COPY --from=BUILD /usr/src/app/target/lib/* /deployments/lib/
# COPY --from=BUILD /usr/src/app/target/*-runner.jar /deployments/app.jar
# COPY --from=build /tmp/my-project/target/*-runner /usr/src/app/target/application
# COPY --from=build /tmp/my-project/applicationinsights-agent-3.2.7.jar /usr/src/app/target/
# RUN chmod 775 /usr/src/app/target
# ENV JAVA_OPTS="-javaagent:/usr/src/app/target/applicationinsights-agent-3.2.7.jar"
# EXPOSE 8080
# ENTRYPOINT [ "/deployments/run-java.sh" ]
# # CMD ["./application", "-XX:+PrintGC", "-XX:+PrintGCTimeStamps", "-XX:+VerboseGC", "+XX:+PrintHeapShape", "-Xmx256m", "-Dquarkus.http.host=0.0.0.0"]