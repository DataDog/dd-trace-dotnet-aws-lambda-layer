#!/bin/bash

# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2022 Datadog, Inc.

# This script automatically opens a PR to the Documentation repo for lambda layer deploys

DOCUMENTATION_REPO_PATH=$HOME/go/src/github.com/DataDog/documentation
DOCUMENTATION_FILE=./layouts/shortcodes/latest-lambda-layer-version.html

echo "Creating a Github PR to update documentation"

if [ ! -d $DOCUMENTATION_REPO_PATH ]; then
    echo "Documentation directory does not exist, cloning into $DOCUMENTATION_REPO_PATH"
    git clone git@github.com:DataDog/documentation $DOCUMENTATION_REPO_PATH
fi

cd $DOCUMENTATION_REPO_PATH

# Make sure they don't have any local changes
if [ ! -z "$(git status --porcelain)" ]; then
    echo "Documentation directory is dirty -- please stash or save your changes and manually create the PR"
    exit 1
fi

echo "Pulling latest changes from Github"
git checkout master
git pull

echo "Checking out new branch that has version changes"
git checkout -b $USER/bump-$LAYER-version-$VERSION
sed -i '' -e '/.*"dd-trace-dotnet"/{' -e 'n;s/.*/    '"$VERSION"'/' -e '}' $DOCUMENTATION_FILE
git add $DOCUMENTATION_FILE

echo "Creating commit -- please tap your Yubikey if prompted"
git commit -m "Bump $LAYER layer to version $VERSION"
git push --set-upstream origin $USER/bump-$LAYER-version-$VERSION
dd-pr

# Reset documentation repo to clean a state that's tracking master
echo "Resetting documentation git branch to master"
git checkout -B master origin/master
