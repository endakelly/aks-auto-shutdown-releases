#!/bin/bash
source scripts/common/common-functions.sh

approver_slack_name=$(get_slack_displayname_from_github_username $APPROVER $SLACK_TOKEN)

echo APPROVER_SLACK_NAME=$approver_slack_name >>$GITHUB_ENV