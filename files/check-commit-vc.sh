#!/usr/bin/env bash
# Consul check: compare running validator client commit age against latest branch commit
# Usage: check-commit-vc -r <repo> -b <branch> -p <metrics_port> [-w <warn_seconds>] [-c <crit_seconds>]
set -uo pipefail

WARN_SECONDS=86400
CRIT_SECONDS=172800

while getopts ':r:b:p:w:c:' opt; do
    case "${opt}" in
        r) REPO="${OPTARG}" ;;
        b) BRANCH="${OPTARG}" ;;
        p) METRICS_PORT="${OPTARG}" ;;
        w) WARN_SECONDS="${OPTARG}" ;;
        c) CRIT_SECONDS="${OPTARG}" ;;
        :) echo "UNKNOWN: Option -${OPTARG} requires an argument"; exit 3 ;;
        ?) echo "UNKNOWN: Unknown option -${OPTARG}"; exit 3 ;;
    esac
done

GITHUB_API_RETRIES=4
GITHUB_API_RETRY_BASE=2

curl_with_backoff() {
    local url="$1" attempt=0 wait=${GITHUB_API_RETRY_BASE} response
    while [[ ${attempt} -lt ${GITHUB_API_RETRIES} ]]; do
        response=$(curl -sf --max-time 10 "${url}") && [[ -n "${response}" ]] && echo "${response}" && return 0
        attempt=$(( attempt + 1 ))
        [[ ${attempt} -lt ${GITHUB_API_RETRIES} ]] && sleep "${wait}" && wait=$(( wait * 2 ))
    done
    return 1
}

RUNNING_COMMIT=$(curl -sf --max-time 5 "http://localhost:${METRICS_PORT}/metrics" \
    | grep '^version{' | grep -oP 'commit="\K[^"]+')

[[ -z "${RUNNING_COMMIT}" ]] && echo "CRITICAL: Unable to parse commit from metrics endpoint :${METRICS_PORT}" && exit 2

BRANCH_DATA=$(curl_with_backoff "https://api.github.com/repos/${REPO}/commits/${BRANCH}") \
    || { echo "WARNING: GitHub API unavailable after ${GITHUB_API_RETRIES} attempts"; exit 1; }

LATEST_COMMIT=$(echo "${BRANCH_DATA}" | jq -r '.sha[:8]')
[[ -z "${LATEST_COMMIT}" || "${LATEST_COMMIT}" == "null" ]] && echo "CRITICAL: Unable to parse latest commit" && exit 2

[[ "${RUNNING_COMMIT}" == "${LATEST_COMMIT:0:${#RUNNING_COMMIT}}" ]] && echo "OK: Running latest commit ${RUNNING_COMMIT}" && exit 0

RUNNING_DATE_DATA=$(curl_with_backoff "https://api.github.com/repos/${REPO}/commits/${RUNNING_COMMIT}") \
    || { echo "WARNING: GitHub API unavailable after ${GITHUB_API_RETRIES} attempts"; exit 1; }

RUNNING_DATE=$(echo "${RUNNING_DATE_DATA}" | jq -r '.commit.author.date')
LATEST_DATE=$(echo "${BRANCH_DATA}" | jq -r '.commit.author.date')
BEHIND_SECONDS=$(( $(date -d "${LATEST_DATE}" +%s) - $(date -d "${RUNNING_DATE}" +%s) ))
BEHIND_HOURS=$(( BEHIND_SECONDS / 3600 ))
MSG="Running ${RUNNING_COMMIT}, branch head ${LATEST_COMMIT} (${BRANCH}), ${BEHIND_HOURS}h behind"

[[ ${BEHIND_SECONDS} -ge ${CRIT_SECONDS} ]] && echo "CRITICAL: ${MSG}" && exit 2
[[ ${BEHIND_SECONDS} -ge ${WARN_SECONDS} ]] && echo "WARNING: ${MSG}" && exit 1
echo "OK: ${MSG}" && exit 0