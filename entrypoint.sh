#!/bin/bash

set -eu

AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-}
AWS_REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}

ecr_login(){
  echo '::debug::Logging into AWS ECR...'
  aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
}

main() {
    local OLD_IMAGE_NAME NEW_IMAGE_NAME

    # Check if the image is an ECR image or not. If it is, then we can pull out
    # the account-id and region from the image name, and log into ECR.
    if [[ $INPUT_IMAGE == *"dkr.ecr"* ]]; then
        echo "::debug::Detected AWS ECR image... attempting ECR login"
        local AWS_ACCOUNT_ID AWS_REGION
        AWS_ACCOUNT_ID=$(echo "${INPUT_IMAGE}" | cut -d. -f1)
        AWS_REGION=$(echo "${INPUT_IMAGE}" | cut -d. -f4)
        ecr_login
    fi

    # Sanitize the INPUT_DEST_TAG. If the tag looks like a github reference
    # (refs/tags/* or refs/heads/*) then strip out the prefix and just use the
    # last portion of the string.
    INPUT_DEST_TAG=${INPUT_DEST_TAG//refs\/tags\//}
    INPUT_DEST_TAG=${INPUT_DEST_TAG//refs\/heads\//}

    OLD_IMAGE_NAME="${INPUT_IMAGE}:${INPUT_SOURCE_TAG}"
    NEW_IMAGE_NAME="${INPUT_IMAGE}:${INPUT_DEST_TAG}"

    echo "Pulling ${OLD_IMAGE_NAME} and retagging it as ${NEW_IMAGE_NAME}..."
    docker pull "${OLD_IMAGE_NAME}"
    docker tag "${OLD_IMAGE_NAME}" "${NEW_IMAGE_NAME}"

    [ "${INPUT_DRY}" == 'true' ] && return 0

    echo "Pushing ${NEW_IMAGE_NAME}..."
    docker push "${NEW_IMAGE_NAME}"
}

# Be really loud and verbose if we're running in VERBOSE mode
if [ "${INPUT_VERBOSE}" == "true" ]; then
  set -x
fi

main
