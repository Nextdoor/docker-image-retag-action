FROM regclient/regsync:v0.3.9-alpine

# Change user to root for the purpose of doing our installs, and
# the way Github Actions run we need to have access to write to
# /home/github to create our docker credentials file.
USER root

# Needed to log into the ECR repository
RUN apk update && apk add aws-cli docker-credential-ecr-login

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
