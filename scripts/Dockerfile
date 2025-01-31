FROM ubuntu:latest AS builder
ARG TRACER_VERSION
ARG ARCH

# make the args mandatory
RUN : "${TRACER_VERSION:?TRACER_VERSION needs to be provided}"
RUN : "${ARCH:?ARCH needs to be provided}"

RUN apt-get update && \
    apt-get install -y zip curl

# download the required tracer
RUN ARTIFACT_NAME=datadog-dotnet-apm_${TRACER_VERSION}_${ARCH}.deb && \
    REPO_NAME="DataDog/dd-trace-dotnet" && \
    curl -Lo /tmp/tracer.deb https://github.com/${REPO_NAME}/releases/download/v${TRACER_VERSION}/${ARTIFACT_NAME}

# uncompress the package
RUN dpkg -i /tmp/tracer.deb

WORKDIR /opt

# remove some useless files in a serverless context to keep the package as small as possible
RUN rm -f datadog/createLogPath.sh && \
    rm -f datadog/*.so && \
    rm -f datadog/loader.conf && \
    rm -f datadog/**/loader.conf && \
    rm -f datadog/**/libddwaf.so && \
    rm -f datadog/**/Datadog.Linux.ApiWrapper.x64.so && \
    rm -f datadog/**/Datadog.Profiler.Native.so && \
    rm -f datadog/**/Datadog.Trace.MSBuild.* && \
    rm -f datadog/**/*.pdb && \
    rm -f datadog/**/*.xml && \
    rm -f datadog/dd-dotnet.sh && \
    rm -f datadog/**/dd-dotnet && \
    rm -rf datadog/net461 && \
    rm -rf datadog/netstandard2.0 && \
    rm -rf datadog/netcoreapp3.1 && \
    rm -rf datadog/continuousprofiler

# add file with tracer version
RUN echo ${TRACER_VERSION} > datadog/tracer_version.txt

# zip the layer
RUN mkdir /datadog
RUN zip -r -9 /datadog/dd_trace_dotnet.zip datadog

# keep the smallest possible docker image
FROM scratch
COPY --from=builder /datadog/dd_trace_dotnet.zip /
ENTRYPOINT ["/dd_trace_dotnet.zip"]
