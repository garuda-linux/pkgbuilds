#!/usr/bin/env bash

function trigger-deployment() {
    echo "Starting the deployment of $TO_DEPLOY.."
    ssh -p "$BUILD_PORT" -o StrictHostKeyChecking=no "$BUILD_USER"@"$BUILD_HOST" "chaotictrigger $TO_DEPLOY" &>"$TO_DEPLOY.log"
}

function check-logs() {
    grep -q "Creating updated database file 'garuda.db.tar.zst'" "$TO_DEPLOY.log" &&
        grep -q "Invalid package, last build did not succeed" "$TO_DEPLOY.log" &&
        echo "Deployment job $1 seems to have failed. $2" || 
        exit 0
}

TO_DEPLOY=$(cat /tmp/TO_DEPLOY)
trigger-deployment
check-logs "1" "Retrying in case its a temporary failure.."
trigger-deployment
check-logs "2" "Deployment failed twice, trying once again just in case.."
trigger-deployment
check-logs "3" "Deployment failed three times, aborting.. It is now debugging time! 🧐"
exit 1