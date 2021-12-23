#!/bin/sh
set -eu

INPUT_DRY=${INPUT_DRY:-false}
INPUT_VERBOSE=${INPUT_VERBOSE:-false}

# Misc generated settings
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-}
AWS_REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}
CONFIG=$(mktemp)
LOG_LEVEL=info
SYNC_ACTION=once


main() {
    local OLD_IMAGE_NAME NEW_IMAGE_NAME

    # Check if the image is an ECR image or not. If it is, then we can pull out
    # the account-id and region from the image name, and log into ECR.
    if [[ $INPUT_IMAGE == *"dkr.ecr"* ]]; then
        echo "::debug::Detected AWS ECR image... attempting ECR login"
        local AWS_ACCOUNT_ID AWS_REGION
        AWS_ACCOUNT_ID=$(echo "${INPUT_IMAGE}" | cut -d. -f1)
        AWS_REGION=$(echo "${INPUT_IMAGE}" | cut -d. -f4)

         # Populate the docker config file with our credhelper locations...
         mkdir -p $HOME/.docker
         cat << EOF > $HOME/.docker/config.json
{"auths" : {}, "credHelpers" : { "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" : "ecr-login" } }
EOF
    fi

    # Sanitize the INPUT_DEST_TAG. If the tag looks like a github reference
    # (refs/tags/* or refs/heads/*) then strip out the prefix and just use the
    # last portion of the string.
    INPUT_DEST_TAG=${INPUT_DEST_TAG//refs\/tags\//}
    INPUT_DEST_TAG=${INPUT_DEST_TAG//refs\/heads\//}

    OLD_IMAGE_NAME="${INPUT_IMAGE}:${INPUT_SOURCE_TAG}"
    NEW_IMAGE_NAME="${INPUT_IMAGE}:${INPUT_DEST_TAG}"

    # Prepare the regsync config file for a one-time sync.
    cat << EOF > ${CONFIG}
version: 1
defaults:
parallel: 10
rateLimit:
  min: 100
  retry: 1m
sync:
- source: ${OLD_IMAGE_NAME}
  type: image
  target: ${NEW_IMAGE_NAME}
EOF
    [ "${INPUT_VERBOSE}" == true ] && cat ${CONFIG}

    echo "Pulling ${OLD_IMAGE_NAME} and retagging it as ${NEW_IMAGE_NAME}..."
    regsync ${SYNC_ACTION} --verbosity ${LOG_LEVEL} -c ${CONFIG}
    echo "Done!!"
}

# Be really loud and verbose if we're running in VERBOSE mode
if [ "${INPUT_VERBOSE}" == "true" ]; then
  set -x
  LOG_LEVEL="debug"
fi

if [ "${INPUT_DRY}" == "true" ]; then
  SYNC_ACTION=check
fi

main
