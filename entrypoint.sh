#!/bin/sh

echo "Starting GitHub reporting..."

PAT_REPO_REPORT=$1
GITHUB_REPO=$2
ENDPOINT_REPO_REPORT=$3
REPORT_GROUP=$4

if [ -z "$PAT_REPO_REPORT" ]; then
    echo "PAT_REPO_REPORT is not set"
    exit 1
fi

if [ -z "$GITHUB_REPO" ]; then
    echo "GITHUB_REPO is not set"
    exit 1
fi

if [ -z "$ENDPOINT_REPO_REPORT" ]; then
    echo "ENDPOINT_REPO_REPORT is not set"
    exit 1
fi

if [ -z "$REPORT_GROUP" ]; then
    echo "REPORT_GROUP is not set"
    exit 1
fi

post_content() {
    JSON_DATA=$1
    ENDPOINT=$2

    result=$(echo $JSON_DATA | curl --silent --show-error --write-out '%{http_code}' -H "Content-Type: application/json" -X POST --data-binary @- $ENDPOINT)

    if [ "$result" = 200 ]; then
        echo "Curl publish to $ENDPOINT succeeded."
    else
        echo "Curl publish to $ENDPOINT failed: $result"
        exit 1
    fi
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

META_DATA=$(curl \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer $PAT_REPO_REPORT" \
    https://api.github.com/repos/$GITHUB_REPO)

REPO_ID=$(echo $META_DATA | jq '.id')
REPO_STARS=$(echo $META_DATA | jq '.stargazers_count')
REPO_WATCHERS=$(echo $META_DATA | jq '.watchers_count')
REPO_FORKS=$(echo $META_DATA | jq '.forks_count')

validate_variable "REPO_ID" $REPO_ID
validate_variable "REPO_STARS" $REPO_STARS
validate_variable "REPO_WATCHERS" $REPO_WATCHERS
validate_variable "REPO_FORKS" $REPO_FORKS

JSON=$(
    echo {} |
        jq \
            --arg repo $GITHUB_REPO \
            --argjson repo_id $REPO_ID \
            --arg report_group $REPORT_GROUP \
            --argjson stars $REPO_STARS \
            --argjson forks $REPO_FORKS \
            '{repo: $repo, repo_id: $repo_id, group: $report_group, stars: $stars, forks: $forks}'
)

post_content "$JSON" "$ENDPOINT_REPO_REPORT/api/GitHubPublicStats"

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
            --arg report_group $REPORT_GROUP \
            '.clones[] += {repo: $repo} | .clones[] += {group: $report_group} | .clones[] += {repo_id: $repo_id} '
)

post_content "$JSON" "$ENDPOINT_REPO_REPORT/api/GitHubCloneCount"

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
            --arg report_group $REPORT_GROUP \
            '.views[] += {repo: $repo} | .views[] += {group: $report_group} | .views[] += {repo_id: $repo_id}'
)

post_content "$JSON" "$ENDPOINT_REPO_REPORT/api/GitHubViewCount"

echo "Finished GitHub reporting..."
