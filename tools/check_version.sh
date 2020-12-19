#!/bin/bash

KUBEINIT_AGENT_VERSION=$(cat ./agent/setup.py | grep "_REVISION = '" | cut -d"'" -f2)
KUBEINIT_COLLECTION_VERSION=$(cat ./kubeinit/galaxy.yml | grep version | cut -d' ' -f2)
KUBEINIT_UI_VERSION=$(cat ./ui/package.json | jq .version | sed 's/"//g')
KUBEINIT_UI_PACKAGE_VERSION=$(cat ./ui/app/version.py | grep __version__ | cut -d'=' -f2 | sed 's/"//g' | sed 's/ //g')

echo "Agent version: $KUBEINIT_AGENT_VERSION"
echo "Collection version: $KUBEINIT_COLLECTION_VERSION"
echo "UI version: $KUBEINIT_UI_VERSION"
echo "UI package version: $KUBEINIT_UI_PACKAGE_VERSION"

if [ "${KUBEINIT_AGENT_VERSION}" == "${KUBEINIT_COLLECTION_VERSION}" ] && [ "${KUBEINIT_AGENT_VERSION}" == "${KUBEINIT_UI_VERSION}" ] && [ "${KUBEINIT_AGENT_VERSION}" == "${KUBEINIT_UI_PACKAGE_VERSION}" ]; then
    echo "Version match"
else
    echo "Version do not match"
    exit 1
fi
