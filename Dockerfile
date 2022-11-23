FROM alpine

RUN apk update  && apk add --no-cache \
    curl \
    jq

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x entrypoint.sh

ENTRYPOINT "/entrypoint.sh" $INPUT_GITHUB_PERSONAL_ACCESS_TOKEN github_personal_access_token $github_repo $reporting_endpoint $reporting_group
