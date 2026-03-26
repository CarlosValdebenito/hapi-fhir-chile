FROM docker.io/library/maven:3.9.12-eclipse-temurin-21 AS build-hapi
WORKDIR /tmp/hapi-fhir-jpaserver-starter

ARG OPENTELEMETRY_JAVA_AGENT_VERSION=2.24.0
RUN curl -LSsO https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OPENTELEMETRY_JAVA_AGENT_VERSION}/opentelemetry-javaagent.jar

COPY pom.xml .
COPY server.xml .
RUN mvn -ntp dependency:go-offline

COPY src/ /tmp/hapi-fhir-jpaserver-starter/src/
RUN mvn clean install -DskipTests -Djdk.lang.Process.launchMechanism=vfork

FROM build-hapi AS build-distroless
RUN mvn package -DskipTests spring-boot:repackage -Pboot
RUN mkdir /app && cp /tmp/hapi-fhir-jpaserver-starter/target/ROOT.war /app/main.war


########### Use the official Tomcat image as base image for the Tomcat variant
########### it can be built using eg. `docker build --target tomcat .`
FROM docker.io/library/tomcat:10-jre21-temurin-noble AS tomcat

USER root
RUN rm -rf /usr/local/tomcat/webapps/ROOT && \
    mkdir -p /usr/local/tomcat/data/hapi/lucenefiles && \
    chown -R 65532:65532 /usr/local/tomcat/data/hapi/lucenefiles && \
    chmod 775 /usr/local/tomcat/data/hapi/lucenefiles

RUN mkdir -p /target && chown -R 65532:65532 /target
USER 65532

COPY --chown=65532:65532 catalina.properties /usr/local/tomcat/conf/catalina.properties
COPY --chown=65532:65532 server.xml /usr/local/tomcat/conf/server.xml
COPY --from=build-hapi --chown=65532:65532 /tmp/hapi-fhir-jpaserver-starter/target/ROOT.war /usr/local/tomcat/webapps/ROOT.war
COPY --from=build-hapi --chown=65532:65532 /tmp/hapi-fhir-jpaserver-starter/opentelemetry-javaagent.jar /app

########## distroless brings focus on security and runs on plain spring boot - this is the default image
FROM gcr.io/distroless/java21-debian13:nonroot AS default
# 65532 is the nonroot user's uid
# used here instead of the name to allow Kubernetes to easily detect that the container
# is running as a non-root (uid != 0) user.
USER 65532:65532
WORKDIR /app

COPY --chown=nonroot:nonroot --from=build-distroless /app /app
COPY --chown=nonroot:nonroot --from=build-hapi /tmp/hapi-fhir-jpaserver-starter/opentelemetry-javaagent.jar /app

ENTRYPOINT ["java", "--class-path", "/app/main.war", "-Dloader.path=main.war!/WEB-INF/classes/,main.war!/WEB-INF/,/app/extra-classes", "org.springframework.boot.loader.PropertiesLauncher"]

############ Etapa intermedia para descargar el package de Chile
#FROM alpine:3.18 AS downloader
#RUN apk add --no-cache curl
#WORKDIR /downloads
## Aquí descargamos la última versión (ejemplo 1.9.3, ajusta la URL si tienes una más nueva)
#RUN curl -L https://hl7chile.cl/fhir/ig/clcore/1.9.3/package.tgz -o fhir-chile.tgz
#
############ distroless brings focus on security
#FROM gcr.io/distroless/java21-debian13:nonroot AS default
#USER 65532:65532
#WORKDIR /app
#
## Copiamos el archivo descargado desde la etapa anterior
#COPY --chown=nonroot:nonroot --from=downloader /downloads/fhir-chile.tgz /app/fhir-chile.tgz
#
## Configuramos las variables para que HAPI lo cargue
## Nota: La URL interna ahora apunta al archivo descargado dentro del contenedor
#ENV hapi_fhir_implementationguides_fhirchile_name=hl7.fhir.cl.core
#ENV hapi_fhir_implementationguides_fhirchile_version=1.9.3
#ENV hapi_fhir_implementationguides_fhirchile_url=file:///app/fhir-chile.tgz
#
#COPY --chown=nonroot:nonroot --from=build-distroless /app /app
#COPY --chown=nonroot:nonroot --from=build-hapi /tmp/hapi-fhir-jpaserver-starter/opentelemetry-javaagent.jar /app
#
#ENTRYPOINT ["java", "--class-path", "/app/main.war", "-Dloader.path=main.war!/WEB-INF/classes/,main.war!/WEB-INF/,/app/extra-classes", "org.springframework.boot.loader.PropertiesLauncher"]
