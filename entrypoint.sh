#!/bin/sh

echo "Starting GitHub reporting..."

PAT_REPO_REPORT=$1
GITHUB_REPO=$2
REPORTING_ENDPOINT_URL=$3
REPORTING_ENDPOINT_KEY=$4
REPORTING_GROUP=$5

if [ -z "$PAT_REPO_REPORT" ]; then
    echo "PAT_REPO_REPORT is not set"
    exit 1
fi

if [ -z "$GITHUB_REPO" ]; then
    echo "GITHUB_REPO is not set"
    exit 1
fi

if [ -z "$REPORTING_ENDPOINT_URL" ]; then
    echo "REPORTING_ENDPOINT_URL is not set"
    exit 1
fi

if [ -z "$REPORTING_GROUP" ]; then
    echo "REPORTING_GROUP is not set"
    exit 1
fi

post_content() {
    JSON_DATA=$1
    ENDPOINT_URL=$2

    result=$(echo $JSON_DATA | curl --silent --show-error --write-out '%{http_code}' -H "Content-Type: application/json" -H "x-functions-key: $REPORTING_ENDPOINT_KEY" -X POST --data-binary @- $ENDPOINT_URL)

    if [ "$result" = 200 ]; then
        echo "Curl publish to $ENDPOINT_URL succeeded."
    else
        echo "Curl publish to $ENDPOINT_URL failed: $result"
        exit 1
    fi
}

get_github_data(){
    GITHUB_URL=$1

    echo $(curl \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer $PAT_REPO_REPORT" \
    $GITHUB_URL)
}

validate_variable() {
    VAR_NAME=$1
    VAR_VALUE=$2
    
    if [ $VAR_VALUE == "null" ]; then
        echo "$VAR_NAME is not set"
        echo "Check that the PAT_REPO_REPORT and GITHUB_REPO variables are correct"
        exit 1
    fi
}

# Publish public stats to endpoint
echo "Publishing public stats to endpoint"

# META_DATA=$(curl \
#     --header "Accept: application/vnd.github+json" \
#     --header "Authorization: Bearer $PAT_REPO_REPORT" \
#     https://api.github.com/repos/$GITHUB_REPO)

GITHUB_DATA=$(get_github_data https://api.github.com/repos/$GITHUB_REPO)

echo $GITHUB_DATA

REPO_ID=$(echo $GITHUB_DATA | jq '.id')
REPO_STARS=$(echo $GITHUB_DATA | jq '.stargazers_count')
REPO_WATCHERS=$(echo $GITHUB_DATA | jq '.watchers_count')
REPO_FORKS=$(echo $GITHUB_DATA | jq '.forks_count')

validate_variable "REPO_ID" $REPO_ID
validate_variable "REPO_STARS" $REPO_STARS
validate_variable "REPO_WATCHERS" $REPO_WATCHERS
validate_variable "REPO_FORKS" $REPO_FORKS

JSON=$(
    echo {} |
        jq \
            --arg repo $GITHUB_REPO \
            --argjson repo_id $REPO_ID \
            --arg report_group $REPORTING_GROUP \
            --argjson stars $REPO_STARS \
            --argjson forks $REPO_FORKS \
            '{repo: $repo, repo_id: $repo_id, group: $report_group, stars: $stars, forks: $forks}'
)

post_content "$JSON" "$REPORTING_ENDPOINT_URL/api/GitHubPublicStats"

# Publish clones stats to endpoint
echo "Publishing clones stats to endpoint"

CLONE_DATA=$(curl \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer $PAT_REPO_REPORT" \
    https://api.github.com/repos/$GITHUB_REPO/traffic/clones)

JSON=$(
    echo $CLONE_DATA |
        jq \
            --arg repo $GITHUB_REPO \
            --argjson repo_id $REPO_ID \
            --arg report_group $REPORTING_GROUP \
            '.clones[] += {repo: $repo} | .clones[] += {group: $report_group} | .clones[] += {repo_id: $repo_id} '
)

post_content "$JSON" "$REPORTING_ENDPOINT_URL/api/GitHubCloneCount"

echo "Publishing views stats to endpoint"

VIEWS_DATA=$(curl \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer $PAT_REPO_REPORT" \
    https://api.github.com/repos/$GITHUB_REPO/traffic/views)

JSON=$(
    echo $VIEWS_DATA |
        jq \
            --arg repo $GITHUB_REPO \
            --argjson repo_id $REPO_ID \
            --arg report_group $REPORTING_GROUP \
            '.views[] += {repo: $repo} | .views[] += {group: $report_group} | .views[] += {repo_id: $repo_id}'
)

post_content "$JSON" "$REPORTING_ENDPOINT_URL/api/GitHubViewCount"

echo "Finished GitHub reporting..."
