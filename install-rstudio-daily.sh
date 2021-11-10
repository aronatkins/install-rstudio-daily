#!/usr/bin/env bash
#
# Installs the latest RStudio daily desktop build for OSX/macOS and Ubuntu(amd64)
#
# https://support.rstudio.com/hc/en-us/articles/203842428-Getting-the-newest-RStudio-builds

set -e

plusdecode() {
    sed -e 's/%2B/+/gi'
}

plusencode() {
    sed -e 's/\+/%2B/g'
}

install_macos_daily() {
    FORCE="$1"
    REQUESTED_VERSION="$2"

    REDIRECT_URL="https://www.rstudio.org/download/latest/daily/desktop/mac/RStudio-latest.dmg"
    echo "Discovering daily build from: ${REDIRECT_URL}"

    # Perform a HEAD request to find the redirect target. We use the name of the
    # file to derive the mounted volume name.
    LATEST_URL=$(curl -s -L -I -o /dev/null -w '%{url_effective}' "${REDIRECT_URL}")
    if [ "${LATEST_URL}" ==  "" ]; then
        echo "Could not extract daily build URL from listing; maybe rstudio.org is having problems?"
        echo "Check: ${DAILY_LIST_URL}"
        exit 1
    fi

    # Test to see if we already have this version installed.
    LATEST_URL_VERSION=$(echo "${LATEST_URL}" | sed -e 's|^.*/RStudio-\(.*\)\.dmg|\1|')
    LATEST_VERSION=$(echo "${LATEST_URL_VERSION}" | plusdecode)
    echo "Latest version:    ${LATEST_VERSION}"

    REQUESTED_URL="${LATEST_URL}"
    if [ -z "${REQUESTED_VERSION}" ] ; then
        REQUESTED_VERSION="${LATEST_VERSION}"
    elif [ "${REQUESTED_VERSION}" != "${LATEST_VERSION}" ] ; then
        echo "Requested version: ${REQUESTED_VERSION}"
        REQUESTED_URL_VERSION=$(echo "${REQUESTED_VERSION}" | plusencode)
        REQUESTED_URL=$(echo "${LATEST_URL}" | sed -e "s|${LATEST_URL_VERSION}|${REQUESTED_URL_VERSION}|")
    fi

    PLIST="/Applications/RStudio.app/Contents/Info.plist"
    if [ -f "${PLIST}" ] ; then
        # Maybe CFBundleShortVersionString or CFBundleVersion?
        INSTALLED_VERSION=$(defaults read "${PLIST}" CFBundleLongVersionString)
        echo "Installed version: ${INSTALLED_VERSION}"
        if [ "${REQUESTED_VERSION}" == "${INSTALLED_VERSION}" ] ; then
            if [ "${FORCE}" == "yes" ] ; then
                echo "RStudio-${REQUESTED_VERSION} is already installed. Forcing re-installation."
            else
                echo "RStudio-${REQUESTED_VERSION} is already installed. Use '-f' to force re-installation."
                exit 0
            fi
        fi
    else
        echo "Installed version: <none>"
    fi

    echo "Downloading daily build from: ${REQUESTED_URL}"

    cd /tmp

    TARGET=$(basename "${REQUESTED_URL}")
    # Volume name mirrors the DMG filename without extension.
    # Simpler than parsing hdiutil output.
    VOLUME_NAME=$(basename "${TARGET}" .dmg | plusdecode)
    VOLUME_MOUNT="/Volumes/${VOLUME_NAME}"

    curl -L -o "${TARGET}" "${REQUESTED_URL}"

    hdiutil attach -quiet "${TARGET}"

    # Remove any prior installation.
    rm -rf /Applications/RStudio.app
    cp -R "${VOLUME_MOUNT}/RStudio.app" /Applications

    hdiutil detach -quiet "${VOLUME_MOUNT}"

    rm "${TARGET}"

    echo "Installed ${VOLUME_NAME} to /Applications"
}

install_ubuntu_daily() {
    URL="https://www.rstudio.org/download/latest/daily/desktop/ubuntu64/rstudio-latest-amd64.deb"
    PACKAGE=$(basename "${URL}")
    TARGET="/tmp/${PACKAGE}"

    # If previous file exists (from previous partial download, for example),
    # remove it.
    if [[ -f "${TARGET}" ]]; then
        echo -e "Removing existing package file: ${TARGET}"
        rm "${TARGET}"
    fi

    echo "Downloading daily build from: ${URL}"
    if [ -x /usr/bin/curl ] ; then
        curl -L -o "${TARGET}" "${URL}"
    elif [ -x /usr/bin/wget ] ; then
        wget -O "${TARGET}" "${URL}"
    else
        echo "Unable to obtain the RStudio package: cannot find 'curl' or 'wget'"
        exit 1
    fi

    echo "Installing ${TARGET}"
    LAUNCH=""
    if [[ `whoami` != "root" ]]; then
        LAUNCH="sudo"
    fi
    ${LAUNCH} dpkg -i "${TARGET}"

    rm "${TARGET}"
}

FORCE=no
for arg in "$@"; do
    case $arg in
        -f|--force)
            FORCE=yes
            shift
        ;;
    esac
done

VERSION=
if [[ $# -eq 1 ]]; then
    VERSION="$1"
elif [[ $# -ne 0 ]]; then
    echo "Only one (optional) version argument is supported."
    exit 1
fi

if [[ `uname -s` = "Darwin" ]]; then
    install_macos_daily $FORCE "${VERSION}"
elif cat /etc/issue | grep -q Ubuntu ; then
    install_ubuntu_daily $FORCE "${VERSION}"
else
    echo "This script only works on OSX/macOS and Ubuntu Linux."
    exit 1
fi
