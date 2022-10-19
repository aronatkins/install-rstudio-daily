#!/usr/bin/env bash
#
# Installs the latest RStudio daily desktop build for OSX/macOS and Ubuntu(amd64)
#
# https://support.rstudio.com/hc/en-us/articles/203842428-Getting-the-newest-RStudio-builds

set -e

# A version like 2022.01.0-daily+294 will have a filename/URL like
# RStudio-2022.01.0-daily-294.dmg. There was a brief period of time when the
# URL contained the plus (which required escaping).

# From URL-form to version-form.
# 2022.07.0-548 => 2022.07.0+548
# 2022.10.0-daily-9 => 2022.10.0-daily+9
dailyplus() {
    sed -e 's/-\([0-9]*\)$/+\1/'
}

# From version-form to URL-form.
# 2022.07.0+548 => 2022.07.0-548
# 2022.10.0-daily+9 => 2022.10.0-daily-9
dailyunplus() {
    sed -e 's/+\([0-9]*\)$/-\1/'
}

installed_macos_version() {
    PLIST="/Applications/RStudio.app/Contents/Info.plist"
    if [ -f "${PLIST}" ] ; then
        # Maybe CFBundleShortVersionString or CFBundleVersion?
        INSTALLED_VERSION=$(defaults read "${PLIST}" CFBundleLongVersionString)
        echo "${INSTALLED_VERSION}"
        return
    fi
    echo "none"
}

install_macos_daily() {
    FORCE="$1"
    REQUESTED_VERSION="$2"

    JSON=$(curl -s https://dailies.rstudio.com/rstudio/latest/index.json)
    LATEST_URL=$(echo "${JSON}" | jq -r .products.electron.platforms.macos.link)
    LATEST_VERSION=$(echo "${JSON}" | jq -r .products.electron.platforms.macos.version)
    LATEST_URL_VERSION=$(echo "${LATEST_VERSION}" | dailyunplus)

    echo "Latest version:    ${LATEST_VERSION}"

    REQUESTED_URL="${LATEST_URL}"
    if [ -z "${REQUESTED_VERSION}" ] ; then
        REQUESTED_VERSION="${LATEST_VERSION}"
    elif [ "${REQUESTED_VERSION}" != "${LATEST_VERSION}" ] ; then
        echo "Requested version: ${REQUESTED_VERSION}"
        REQUESTED_URL_VERSION=$(echo "${REQUESTED_VERSION}" | dailyunplus)
        # shellcheck disable=SC2001
        REQUESTED_URL=$(echo "${LATEST_URL}" | sed -e "s|${LATEST_URL_VERSION}|${REQUESTED_URL_VERSION}|")
    fi

    INSTALLED_VERSION=$(installed_macos_version)
    echo "Installed version: ${INSTALLED_VERSION}"
    if [ "${REQUESTED_VERSION}" == "${INSTALLED_VERSION}" ] ; then
        if [ "${FORCE}" == "yes" ] ; then
            echo "RStudio ${REQUESTED_VERSION} is already installed. Forcing re-installation."
        else
            echo "RStudio ${REQUESTED_VERSION} is already installed. Use '-f' to force re-installation."
            exit 0
        fi
    fi
    
    install_macos_url "${REQUESTED_URL}"
}

install_macos_url() {
    REQUESTED_URL="$1"

    echo "Downloading build from: ${REQUESTED_URL}"

    cd /tmp

    TARGET=$(basename "${REQUESTED_URL}")
    # Volume name mirrors the DMG filename without extension.
    # Simpler than parsing hdiutil output.
    VOLUME_NAME=$(basename "${TARGET}" .dmg)
    VOLUME_MOUNT="/Volumes/${VOLUME_NAME}"

    curl -L --fail -o "${TARGET}" "${REQUESTED_URL}"

    hdiutil attach -quiet "${TARGET}"

    # Remove any prior installation.
    rm -rf /Applications/RStudio.app
    cp -R "${VOLUME_MOUNT}/RStudio.app" /Applications

    hdiutil detach -quiet "${VOLUME_MOUNT}"

    rm "${TARGET}"

    echo "Installed RStudio from volume ${VOLUME_NAME} into /Applications"
}

install_ubuntu() {
    DISTRIBUTION="$1"
    REQUESTED_VERSION="$2"

    JSON=$(curl -s https://dailies.rstudio.com/rstudio/latest/index.json)
    DIST_JSON=$(echo "${JSON}" | jq .products.electron.platforms['"'"${DISTRIBUTION}"'"'])
    LATEST_URL=$(echo "${DIST_JSON}" | jq -r '.link')
    LATEST_VERSION=$(echo "${DIST_JSON}" | jq -r '.version')
    LATEST_URL_VERSION=$(echo "${LATEST_VERSION}" | dailyunplus)

    echo "Latest version:    ${LATEST_VERSION}"

    REQUESTED_URL="${LATEST_URL}"
    if [ -z "${REQUESTED_VERSION}" ] ; then
        REQUESTED_VERSION="${LATEST_VERSION}"
    elif [ "${REQUESTED_VERSION}" != "${LATEST_VERSION}" ] ; then
        echo "Requested version: ${REQUESTED_VERSION}"
        REQUESTED_URL_VERSION=$(echo "${REQUESTED_VERSION}" | dailyunplus)
        # shellcheck disable=SC2001
        REQUESTED_URL=$(echo "${LATEST_URL}" | sed -e "s|${LATEST_URL_VERSION}|${REQUESTED_URL_VERSION}|")
    fi

    PACKAGE=$(basename "${REQUESTED_URL}")
    TARGET="/tmp/${PACKAGE}"
    
    echo "Downloading daily build from: ${REQUESTED_URL}"
    if [ -x /usr/bin/curl ] ; then
        curl -L --fail -o "${TARGET}" "${REQUESTED_URL}"
    elif [ -x /usr/bin/wget ] ; then
        wget -O "${TARGET}" "${REQUESTED_URL}"
    else
        echo "Unable to obtain the RStudio package: cannot find 'curl' or 'wget'"
        exit 1
    fi

    echo "Installing ${TARGET}"
    LAUNCH=""
    if [[ $(whoami) != "root" ]]; then
        LAUNCH="sudo"
    fi
    ${LAUNCH} apt install -y "${TARGET}"

    rm "${TARGET}"
}

help() {
    echo "$0 [-h] [-s] [-f]"
    echo ""
    echo "Install the most recent RStudio build. Supports macOS and Ubuntu 18.04."
    echo ""
    echo "Arguments:"
    echo "  -f, --force   Force installation when the same version is already"
    echo "                installed (macOS only)."
    echo "  -h, --help    Display this help text and exit."
}

FORCE="no"
for arg in "$@"; do
    case $arg in
        -f|--force)
            FORCE="yes"
            shift
            ;;
        -h|--help)
            help
            exit
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

if [[ $(uname -s) = "Darwin" ]]; then
    install_macos_daily "${FORCE}" "${VERSION}"
elif grep -q "Ubuntu 18" /etc/issue ; then
    install_ubuntu "bionic-amd64" "${VERSION}"
elif grep -q "Ubuntu 20" /etc/issue ; then
    install_ubuntu "bionic-amd64" "${VERSION}"
elif grep -q "Ubuntu 22" /etc/issue ; then
    install_ubuntu "jammy-amd64" "${VERSION}"
else
    echo "This script only works on OSX/macOS and Ubuntu Linux."
    exit 1
fi
