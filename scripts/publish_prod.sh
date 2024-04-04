#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2022 Datadog, Inc.

# Usage: LAYER_VERSION=xxx TRACER_VERSION=xxx ./scripts/publish_sandbox.sh

# LAYER_VERSION is the new layer version to create.
# TRACER_VERSION is the version of dd-trace-dotnet to include in the layer.

# When this script is run, we automatically build and publish for both arm and amd64

set -e

# Move into the root directory
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd $SCRIPTS_DIR/..

if [ -z "$LAYER_VERSION" ]; then
    echo "Must specify a desired LAYER_VERSION"
    exit 1
fi
if [ -z "$TRACER_VERSION" ]; then
    echo "Must specify a desired TRACER_VERSION"
    exit 1
fi

# Ensure AWS access before proceeding
ddsaml2aws login -a govcloud-us1-fed-human-engineering
AWS_PROFILE=govcloud-us1-fed-human-engineering aws sts get-caller-identity
aws-vault exec sso-prod-engineering -- aws sts get-caller-identity

read -p "Ready to publish layer version $LAYER_VERSION containg dd-trace-dotnet version $TRACER_VERSION? (y/N)" CONT
if [ "$CONT" != "y" ]; then
    echo "Exiting"
    exit 1
fi

echo
echo "Building layers..."
TRACER_VERSION=$TRACER_VERSION ./scripts/build_layer.sh

echo
echo "Signing layers..."
aws-vault exec sso-prod-engineering -- ./scripts/sign_layers.sh prod

echo
echo "Publishing layers to commercial AWS regions..."
VERSION=$LAYER_VERSION ARCH=amd64 aws-vault exec sso-prod-engineering -- ./scripts/publish_layer.sh
VERSION=$LAYER_VERSION ARCH=arm64 aws-vault exec sso-prod-engineering -- ./scripts/publish_layer.sh

echo
echo "Publishing layers to GovCloud AWS regions..."
ddsaml2aws login -a govcloud-us1-fed-human-engineering
VERSION=$LAYER_VERSION ARCH=amd64 aws-vault exec sso-govcloud-us1-fed-engineering -- ./scripts/publish_layer.sh
VERSION=$LAYER_VERSION ARCH=arm64 aws-vault exec sso-govcloud-us1-fed-engineering -- ./scripts/publish_layer.sh

echo "Creating tag in the datadog-lambda-extension repository for release on GitHub"
git tag "v$LAYER_VERSION"
git push origin "refs/tags/v$LAYER_VERSION"

# Open a PR to the documentation repo to automatically bump layer version
VERSION=$LAYER_VERSION LAYER=dd-trace-dotnet ./scripts/create_documentation_pr.sh
