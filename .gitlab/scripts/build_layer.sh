#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2021 Datadog, Inc.

# Usage examples :
# TRACER_VERSION=xxx ARCH=arm64 ./scripts/build_layer.sh
# ARCH is optional. Default is to build both arm and amd64 layers.

set -e

if [ "$TRACER_VERSION" = "placeholder" ]; then
    TRACER_VERSION=""
fi

if [ -z "$TRACER_VERSION" ]; then
    # Running on dev
    echo "Running on dev environment"
    TRACER_VERSION="dev"
else
    echo "Found version tag in environment variables"
    echo "Tracer version: ${TRACER_VERSION}"
fi

# Move into the root directory, so this script can be called from any directory
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR=$SCRIPTS_DIR/..
cd $ROOT_DIR

LAYER_DIR=".layers"
TARGET_DIR=$(pwd)/$LAYER_DIR
DOCKERFILE="./scripts/Dockerfile.r2r"

# Build the image
function docker_build_zip {
    arch=$1

    tmp_dir=$(mktemp -d)
    docker buildx build -t datadog/dd_trace_dotnet:$TRACER_VERSION . \
        -f $DOCKERFILE \
        --no-cache \
        --platform linux/${arch} \
        --build-arg TRACER_VERSION="${TRACER_VERSION}" \
        --build-arg ARCH=${arch} \
        -o $tmp_dir/datadog

    cp $tmp_dir/datadog/dd_trace_dotnet.zip $TARGET_DIR/dd_trace_dotnet_${arch}.zip
    unzip $tmp_dir/datadog/dd_trace_dotnet.zip -d $TARGET_DIR/dd_trace_dotnet_${arch}

    rm -rf $tmp_dir
}

# Clean and make directories in ./layers
function clean_layer_directory {
    arch=$1

    rm -rf $LAYER_DIR/dd_trace_dotnet_${arch} 2>/dev/null
    mkdir -p $LAYER_DIR/dd_trace_dotnet_${arch}
}

echo "Building layers for ${ARCH}"
clean_layer_directory $ARCH
docker_build_zip $ARCH

echo "Finished building layers for ${ARCH}"