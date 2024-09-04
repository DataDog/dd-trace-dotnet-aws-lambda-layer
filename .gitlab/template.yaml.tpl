stages:
  - build
  - test
  - sign
  - publish

default:
  retry:
    max: 1
    when:
      - runner_system_failure

get artifacts:
  stage: build
  tags: ["arch:amd64"]
  image: registry.ddbuild.io/ci/serverless-tools:1
  artifacts:
    expire_in: 2 weeks
    paths:
      - artifacts
  rules:
    - if: '$CI_PIPELINE_SOURCE =~ /external_pull_request_event|merge_request_event|push/'
      when: never
    - when: always
  retry: 2
  script:
    - .gitlab/scripts/download_tracer_artifacts.sh

{{ range $architecture := (ds "architectures").architectures }}

build layer ({{ $architecture.name }}):
  stage: build
  tags: ["arch:amd64"]
  image: registry.ddbuild.io/images/docker:20.10
  needs: ["get artifacts"]
  dependencies: ["get artifacts"]
  artifacts:
    expire_in: 2 weeks
    paths:
      - .layers/dd_trace_dotnet_{{ $architecture.name }}.zip
  variables:
    ARCH: {{ $architecture.name }}
    R2R: true
  script:
    - TRACER_VERSION=2.56.0 ./scripts/build_layer.sh

{{ range $environment := (ds "environments").environments }}

{{ if or (eq $environment.name "prod") }}
sign layer ({{ $architecture.name }}):
  stage: sign
  tags: ["arch:amd64"]
  image: registry.ddbuild.io/images/docker:20.10-py3
  rules:
    - if: '$CI_COMMIT_TAG =~ /^v.*/'
      when: manual
  needs:
    - build layer ({{ $architecture.name }})
  dependencies:
    - build layer ({{ $architecture.name }})
  artifacts: # Re specify artifacts so the modified signed file is passed
    expire_in: 2 weeks
    paths:
      - .layers/dd_trace_dotnet_{{ $architecture.name }}.zip
  variables:
    LAYER_FILE: dd_trace_dotnet_{{ $architecture.name }}.zip
  before_script:
    - EXTERNAL_ID_NAME={{ $environment.external_id }} ROLE_TO_ASSUME={{ $environment.role_to_assume }} AWS_ACCOUNT={{ $environment.account }} source .gitlab/scripts/get_secrets.sh
  script:
    - .gitlab/scripts/sign_layers.sh {{ $environment.name }}
{{ end }}

publish layer {{ $environment.name }} ({{ $architecture.name }}):
  stage: publish
  tags: ["arch:amd64"]
  image: ${CI_DOCKER_TARGET_IMAGE}:${CI_DOCKER_TARGET_VERSION}
  rules:
    - if: '"{{ $environment.name }}" =~ /^(sandbox|staging)/'
      when: manual
      allow_failure: true
    - if: '$CI_COMMIT_TAG =~ /^v.*/'
  needs:
{{ if or (eq $environment.name "prod") }}
      - sign layer ({{ $architecture.name }})
{{ else }}
      - build layer ({{ $architecture.name }})
{{ end }}
  dependencies:
{{ if or (eq $environment.name "prod") }}
      - sign layer ({{ $architecture.name }})
{{ else }}
      - build layer ({{ $architecture.name }})
{{ end }}
  parallel:
    matrix:
      - REGION: {{ range (ds "regions").regions }}
          - {{ .code }}
        {{- end}}
  variables:
    ARCHITECTURE: {{ $architecture.name }}
    LAYER_FILE: dd_trace_dotnet_{{ $architecture.name }}.zip
    STAGE: {{ $environment.name }}
  before_script:
    - EXTERNAL_ID_NAME={{ $environment.external_id }} ROLE_TO_ASSUME={{ $environment.role_to_assume }} AWS_ACCOUNT={{ $environment.account }} source .gitlab/scripts/get_secrets.sh
  script:
    - .gitlab/scripts/publish_layers.sh

{{- end }} # environments end

{{- end }} # architectures end