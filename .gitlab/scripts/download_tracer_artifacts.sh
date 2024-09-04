#!/bin/bash

set -e

GITLAB_TOKEN=$(aws ssm get-parameter \
    --region us-east-1 \
    --name "ci.$CI_PROJECT_NAME.serverless-gitlab-token" \
    --with-decryption \
    --query "Parameter.Value" \
    --out text)

TRACER_PROJECT_ID=348

# Clean environment variables if they are set as 'placeholder'
if [ "$UPSTREAM_PIPELINE_ID" = "placeholder" ]; then
    UPSTREAM_PIPELINE_ID=""
fi

if [ "$TRACER_BRANCH" = "placeholder" ]; then
    TRACER_BRANCH=""
fi

echo "Running with the following configuration:"
echo "UPSTREAM_PIPELINE_ID: $UPSTREAM_PIPELINE_ID"
echo "TRACER_BRANCH: $TRACER_BRANCH"

# If 'UPSTREAM_PIPELINE_ID' or 'TRACER_BRANCH' are not set, exit
if [ -z "$UPSTREAM_PIPELINE_ID" ] && [ -z "$TRACER_BRANCH" ]; then
    echo "None of UPSTREAM_PIPELINE_ID or TRACER_BRANCH is set. Exiting..."
    exit 1
fi

# If 'UPSTREAM_PIPELINE_ID' is not set, calculate the latest based on the 'TRACER_BRANCH' or,
# if 'TRACER_BRANCH' is set, prioritize it over 'UPSTREAM_PIPELINE_ID' even if it's set
#
# This might happen when doing a manual trigger of the pipeline, normally done for Production deployments with tags.
if [ -z "$UPSTREAM_PIPELINE_ID" ] || [ -n "$TRACER_BRANCH" ]; then
    echo "UPSTREAM_PIPELINE_ID is not set, or TRACER_BRANCH is set. Calculating the latest pipeline ID..."

    URL="$CI_API_V4_URL/projects/$TRACER_PROJECT_ID/pipelines?ref=$TRACER_BRANCH&per_page=1&order_by=id&sort=desc"
    echo "Getting pipelines for '$TRACER_BRANCH' from: $URL"
    PIPELINES=$(curl $URL --header "PRIVATE-TOKEN: $GITLAB_TOKEN")

    # Get the latest pipeline ID
    UPSTREAM_PIPELINE_ID=$(echo "${PIPELINES}" | jq -r '.[0] | @base64' | base64 --decode | jq -r '.id')
fi

echo "UPSTREAM_PIPELINE_ID: $UPSTREAM_PIPELINE_ID"

# Get the jobs of the upstream pipeline
URL="$CI_API_V4_URL/projects/$TRACER_PROJECT_ID/pipelines/$UPSTREAM_PIPELINE_ID/jobs"
echo "Looking for the artifacts job 'download-serverless-artifacts' for pipeline ID '$UPSTREAM_PIPELINE_ID' in '$URL'"
PIPELINE_JOBS=$(curl $URL --header "PRIVATE-TOKEN: $GITLAB_TOKEN")

FOUND_ARTIFACTS_JOB=false
# Iterate over pipeline trigger jobs
for pipeline_job in $(echo "${PIPELINE_JOBS}" | jq -r '.[] | @base64'); do
    # Only check the 'download-serverless-artifacts' job
    pipeline_job_name=$(echo "${pipeline_job}" | base64 --decode | jq -r '.name')
    if [ "${pipeline_job_name}" = "download-serverless-artifacts" ]; then
        FOUND_ARTIFACTS_JOB=true
        pipeline_job_id=$(echo ${pipeline_job} | base64 --decode | jq -r '.id')

        ARTIFACTS_URL="$CI_API_V4_URL/projects/348/jobs/$pipeline_job_id/artifacts"
        echo "Downloading artifacts from: $ARTIFACTS_URL"
        ARTIFACTS=$(curl $ARTIFACTS_URL --header "PRIVATE-TOKEN: $GITLAB_TOKEN" --location --output artifacts.zip)
    fi
done

if [ "$FOUND_ARTIFACTS_JOB" = false ]; then
    echo "No artifacts job found in the pipeline. Exiting..."
    exit 1
fi

target_dir=artifacts

mkdir -p $target_dir
unzip artifacts.zip -d $target_dir
mv $target_dir/artifacts/* $target_dir
rmdir $target_dir/artifacts

ls -R $target_dir