#!/bin/bash
##
## Installs the latest RStudio daily build for OSX.
## Based on a Linux-install script: http://stackoverflow.com/a/15046636

set -e

## The page containing a list of the RStudio daily OSX builds.
DAILY_LIST_URL=http://www.rstudio.org/download/daily/desktop/mac/

## Extract the latest from the index page.
RELEASE_URL=$(curl -s ${DAILY_LIST_URL} | grep -m 1 -o "https[^\']*")
if [ "${RELEASE_URL}" ==  "" ]; then
    echo "Could not extract daily build URL from listing; maybe rstudio.org is having problems?"
    echo "Check: ${DAILY_LIST_URL}"
    exit 1
fi

echo "Downloading daily build from: ${RELEASE_URL}"

cd /tmp

TARGET=$(basename "${RELEASE_URL}")
# Volume name comes from the DMG filename.
VOLUME_NAME=$(basename "${TARGET}" .dmg)
VOLUME_MOUNT="/Volumes/${VOLUME_NAME}"

curl -o "${TARGET}" "${RELEASE_URL}"

hdiutil attach -quiet "${TARGET}"

# Remove any prior installation.
rm -rf /Applications/RStudio.app
cp -R "${VOLUME_MOUNT}/RStudio.app" /Applications

hdiutil detach -quiet "${VOLUME_MOUNT}"

rm "${TARGET}"

echo "Installed ${VOLUME_NAME} to /Applications"
