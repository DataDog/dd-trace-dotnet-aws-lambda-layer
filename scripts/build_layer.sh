#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2021 Datadog, Inc.

# Usage examples :
# TRACER_VERSION=xxx ARCH=arm64 ./scripts/build_layer.sh
# ARCH is optional. Default is to build both arm and amd64 layers.

set -e

if [ -z "$TRACER_VERSION" ]; then
    echo "TRACER_VERSION is not specified, getting latest..."
    TRACER_VERSION=$(curl -sL https://api.github.com/repos/DataDog/dd-trace-dotnet/releases/latest | jq -r ".name")
    echo "Using TRACER_VERSION=${TRACER_VERSION}"
fi

# Move into the root directory, so this script can be called from any directory
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR=$SCRIPTS_DIR/..
cd $ROOT_DIR

LAYER_DIR=".layers"
TARGET_DIR=$(pwd)/$LAYER_DIR
DOCKERFILE="./scripts/Dockerfile"
if [ ! -z "$SANDBOX" ]; then
    DOCKERFILE="./scripts/Dockerfile.sandbox"
fi

if [ ! -z "$BENCHMARK" ]; then
    DOCKERFILE="./scripts/Dockerfile.benchmark"
fi

# Build the image
function docker_build_zip {
    arch=$1

    docker buildx build \
        --platform linux/${arch} \
        -t datadog/dd_trace_dotnet:$TRACER_VERSION \
        -f $DOCKERFILE \
        --build-arg TRACER_VERSION="${TRACER_VERSION}" \
        --build-arg ARCH=${arch} .

    # Run the image to copy the zip
    dockerId=$(docker create datadog/dd_trace_dotnet:$TRACER_VERSION)
    docker cp $dockerId:/dd_trace_dotnet.zip $TARGET_DIR/dd_trace_dotnet_${arch}.zip

    # Make sure the archive can be unzipped
    unzip $TARGET_DIR/dd_trace_dotnet_${arch}.zip -d $TARGET_DIR/dd_trace_dotnet_${arch}
}

# Clean and make directories in ./layers
function clean_layer_directory {
    arch=$1

    rm -rf $LAYER_DIR/dd_trace_dotnet_${arch} 2>/dev/null
    mkdir -p $LAYER_DIR/dd_trace_dotnet_${arch}
}

if [ "$ARCH" == "amd64" ]; then
    clean_layer_directory amd64
    echo "Building for amd64 only"
    docker_build_zip amd64
elif [ "$ARCH" == "arm64" ]; then
    clean_layer_directory arm64
    echo "Building for arm64 only"
    docker_build_zip arm64
else
    clean_layer_directory amd64
    clean_layer_directory arm64
    echo "Building for both amd64 and arm64"
    docker_build_zip amd64
    docker_build_zip arm64
fi
