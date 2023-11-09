#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2022 Datadog, Inc.

# Usage: TRACER_VERSION=xxx ./scripts/publish_sandbox.sh

set -e

# Move into the root directory
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd $SCRIPTS_DIR/..

# Builds both layers by default
./scripts/build_layer.sh

REGIONS=sa-east-1 ARCH=amd64 aws-vault exec sso-serverless-sandbox-account-admin -- ./scripts/publish_layer.sh
REGIONS=eu-west-1 ARCH=arm64 aws-vault exec sso-serverless-sandbox-account-admin -- ./scripts/publish_layer.sh
