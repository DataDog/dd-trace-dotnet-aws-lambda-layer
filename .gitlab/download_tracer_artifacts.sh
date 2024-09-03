set -e

GITLAB_TOKEN=$(aws ssm get-parameter \
    --region us-east-1 \
    --name "ci.$CI_PROJECT_NAME.serverless-gitlab-token" \
    --with-decryption \
    --query "Parameter.Value" \
    --out text)

URL="$CI_API_V4_URL/projects/348/pipelines/$UPSTREAM_PIPELINE_ID/jobs"
PIPELINE_JOBS=$(curl $URL --header "PRIVATE-TOKEN: $GITLAB_TOKEN")

# Iterate over pipeline trigger jobs
for pipeline_job in $(echo "${PIPELINE_JOBS}" | jq -r '.[] | @base64'); do
    # Only check the 'download-serverless-artifacts' job
    pipeline_job_name=$(echo "${pipeline_job}" | base64 --decode | jq -r '.name')
    if [ "${pipeline_job_name}" = "download-serverless-artifacts" ]; then
        pipeline_job_id=$(echo ${pipeline_job} | base64 --decode | jq -r '.id')

        ARTIFACTS_URL="$CI_API_V4_URL/projects/348/jobs/$pipeline_job_id/artifacts"
        ARTIFACTS=$(curl $ARTIFACTS_URL --header "PRIVATE-TOKEN: $GITLAB_TOKEN" --location --output artifacts.zip)
    fi
done
