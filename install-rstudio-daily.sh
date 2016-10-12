#!/bin/bash
#
# Installs the latest RStudio daily desktop build for OSX/macOS and Ubuntu(amd64)
#
# https://support.rstudio.com/hc/en-us/articles/203842428-Getting-the-newest-RStudio-builds

set -e

install_macos_daily() {
    REDIRECT_URL="https://www.rstudio.org/download/latest/daily/desktop/mac/RStudio-latest.dmg"
    echo "Discovering daily build from: ${REDIRECT_URL}"

    # Perform a HEAD request to find the redirect target. We use the name of the
    # file to derive the mounted volume name.
    RELEASE_URL=$(curl -s -L -I -o /dev/null -w '%{url_effective}' "${REDIRECT_URL}")
    if [ "${RELEASE_URL}" ==  "" ]; then
        echo "Could not extract daily build URL from listing; maybe rstudio.org is having problems?"
        echo "Check: ${DAILY_LIST_URL}"
        exit 1
    fi

    echo "Downloading daily build from: ${RELEASE_URL}"

    cd /tmp

    TARGET=$(basename "${RELEASE_URL}")
    # Volume name mirrors the DMG filename without extension.
    # Simpler than parsing hdiutil output.
    VOLUME_NAME=$(basename "${TARGET}" .dmg)
    VOLUME_MOUNT="/Volumes/${VOLUME_NAME}"

    curl -L -o "${TARGET}" "${RELEASE_URL}"

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


if [[ `uname -s` = "Darwin" ]]; then
    install_macos_daily
elif cat /etc/issue | grep -q Ubuntu ; then
    install_ubuntu_daily
else
    echo "This script only works on OSX/macOS and Ubuntu Linux."
    exit 1
fi
