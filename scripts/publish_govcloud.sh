#!/bin/bash

# Download layer from your prod release artifacts in Gitlab. Put layers in .layers
# Use with `VERSION=<version> REGION=<govcloud region> ./publish_govcloud.sh <DESIRED_NEW_VERSION>

if [ ! -f "../.layers/dd_trace_dotnet_amd64.zip" ]; then
    printf "[ERROR]: Could not find .layers/dd_trace_dotnet_amd64.zip. Download from prod release artifacts.\n"
    exit 1
fi

if [ ! -f "../.layers/dd_trace_dotnet_arm64.zip" ]; then
    printf "[ERROR]: Could not find .layers/dd_trace_dotnet_arm64.zip. Download from prod release artifacts.\n"
    exit 1
fi

if [ -z "$VERSION" ]; then
    printf "Must specify a desired version number using VERSION env var\n"
    exit 1
fi

if [ -z "$REGION" ]; then
  printf "Must specify region using REGION env var\n"
  exit 1
fi

echo "Ensuring you have access to the AWS GovCloud account..."
aws-vault exec sso-govcloud-us1-fed-engineering -- aws sts get-caller-identity

AVAILABLE_REGIONS=$(aws-vault exec sso-govcloud-us1-fed-engineering -- aws ec2 describe-regions | jq -r '.[] | .[] | .RegionName')
echo "Available regions:"
echo "$AVAILABLE_REGIONS"
REGION_VALID=false
echo

for available_region in $AVAILABLE_REGIONS; do
    if [ "$REGION" == "$available_region" ]; then
        REGION_VALID=true
        break
    fi
done

if [ "$REGION_VALID" != "true" ]; then
    echo "[ERROR]: Invalid region '$REGION'. Available regions are:"
    echo "$AVAILABLE_REGIONS"
    echo
    exit 1
fi

LATEST_VERSION=$(aws-vault exec sso-govcloud-us1-fed-engineering \
 -- aws lambda list-layer-versions \
 --region $REGION --layer-name dd-trace-dotnet \
 --query 'LayerVersions[0].Version || `0`')
EXPECTED_VERSION=$((LATEST_VERSION + 1))


if [ "$VERSION" != "$EXPECTED_VERSION" ]; then
    echo "[ERROR]: Version must be sequential. Latest version is $LATEST_VERSION, so next version must be $EXPECTED_VERSION"
    echo
    exit 1
fi

echo "Publishing tracer layer version $VERSION to region $REGION"
read -p "Continue? (y/n): " CONFIRM
if [[ $CONFIRM != "y" ]]; then
    echo "Aborting."
    echo
    exit 1
fi

printf "Publishing dd-trace-dotnet...\n"
NEW_VERSION=$(aws-vault exec sso-govcloud-us1-fed-engineering -- \
    aws lambda publish-layer-version --layer-name dd-trace-dotnet \
    --description "dd-trace-dotnet" \
    --compatible-runtimes "dotnet6" "dotnet8" \
    --compatible-architectures "x86_64" \
    --zip-file "fileb://../.layers/dd_trace_dotnet_amd64.zip" \
    --region $REGION \
    | jq -r '.Version')

printf "Publishing dd-trace-dotnet-ARM...\n"
NEW_VERSION=$(aws-vault exec sso-govcloud-us1-fed-engineering -- \
    aws lambda publish-layer-version --layer-name dd-trace-dotnet-ARM \
    --description "dd-trace-dotnet" \
    --compatible-runtimes "dotnet6" "dotnet8" \
    --compatible-architectures "arm64" \
    --zip-file "fileb://../.layers/dd_trace_dotnet_arm64.zip" \
    --region $REGION \
    | jq -r '.Version')

printf "Setting permission for dd-trace-dotnet..."
permission=$(aws-vault exec sso-govcloud-us1-fed-engineering -- \
    aws lambda add-layer-version-permission --layer-name dd-trace-dotnet \
    --version-number $NEW_VERSION \
    --statement-id "release-$NEW_VERSION" \
    --action lambda:GetLayerVersion \
    --principal "*" \
    --region $REGION
)

printf "Setting permission for dd-trace-dotnet-ARM..."
permission=$(aws-vault exec sso-govcloud-us1-fed-engineering -- \
    aws lambda add-layer-version-permission --layer-name dd-trace-dotnet-ARM \
    --version-number $NEW_VERSION \
    --statement-id "release-$NEW_VERSION" \
    --action lambda:GetLayerVersion \
    --principal "*" \
    --region $REGION
)

echo "Published layer v$NEW_VERSION to $REGION!"