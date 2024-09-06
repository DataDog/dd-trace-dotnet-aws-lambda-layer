FROM ubuntu:latest as builder
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
RUN rm datadog/createLogPath.sh && \
    rm datadog/*.so && \
    rm datadog/loader.conf && \
    rm datadog/**/loader.conf && \
    rm datadog/**/libddwaf.so && \
    # Revise to use 'Datadog.Trace.ClrProfiler.Native.so' for profiling, which calls
    # 'Datadog.Trace.Native.so' and 'Datadog.Trace.Profiler.so'.
    rm datadog/**/Datadog.Trace.ClrProfiler.Native.so && \
    rm datadog/**/Datadog.Linux.ApiWrapper.x64.so && \
    rm datadog/**/Datadog.Profiler.Native.so && \
    rm datadog/**/Datadog.Trace.MSBuild.* && \
    rm datadog/**/*.pdb && \
    rm datadog/**/*.xml && \
    rm datadog/dd-dotnet.sh && \
    rm datadog/**/dd-dotnet && \
    rm -rf datadog/netstandard2.0 && \
    rm -rf datadog/netcoreapp3.1 && \
    rm -rf datadog/continuousprofiler

# HACK: rename the tracer library so the logic in datadog_wrapper keeps working
# See also https://github.com/DataDog/datadog-lambda-extension/pull/150
#
# We are doing this because the actual 'Datadog.Trace.ClrProfiler.Native.so' is a demux which calls this binary and 'Datadog.Trace.Profiler.so'.
RUN if [ -f datadog/linux-x64/Datadog.Tracer.Native.so ]; then mv datadog/linux-x64/Datadog.Tracer.Native.so datadog/linux-x64/Datadog.Trace.ClrProfiler.Native.so; fi
RUN if [ -f datadog/linux-arm64/Datadog.Tracer.Native.so ]; then mv datadog/linux-arm64/Datadog.Tracer.Native.so datadog/linux-arm64/Datadog.Trace.ClrProfiler.Native.so; fi

# add file with tracer version
RUN echo ${TRACER_VERSION} > datadog/tracer_version.txt

# zip the layer
RUN mkdir /datadog
RUN zip -r -9 /datadog/dd_trace_dotnet.zip datadog

# keep the smallest possible docker image
FROM scratch
COPY --from=builder /datadog/dd_trace_dotnet.zip /
ENTRYPOINT ["/dd_trace_dotnet.zip"]
