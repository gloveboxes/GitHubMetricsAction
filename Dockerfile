FROM alpine

RUN apk update  && apk add --no-cache \
    curl \
    jq

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x entrypoint.sh

ENTRYPOINT "/entrypoint.sh" $INPUT_GITHUB_PERSONAL_ACCESS_TOKEN $INPUT_GITHUB_REPO $INPUT_REPORTING_ENDPOINT $INPUT_REPORTING_GROUP
