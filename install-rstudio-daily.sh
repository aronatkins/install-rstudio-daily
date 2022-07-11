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
dailyplus() {
    sed -e 's/daily-/daily+/'
}

# From version-form to URL-form.
dailyunplus() {
    sed -e 's/daily\+/daily-/'
}

install_macos() {
    KIND="$1"
    FORCE="$2"
    REQUESTED_VERSION="$3"

    REDIRECT_URL="https://www.rstudio.org/download/latest/${KIND}/desktop/mac/RStudio-latest.dmg"
    echo "Discovering build from: ${REDIRECT_URL}"

    # Perform a HEAD request to find the redirect target. We use the name of the
    # file to derive the mounted volume name.
    LATEST_URL=$(curl -s -L -I -o /dev/null -w '%{url_effective}' "${REDIRECT_URL}")
    if [ "${LATEST_URL}" ==  "" ]; then
        echo "Could not extract build URL from listing; maybe rstudio.org is having problems?"
        echo "Check: https://dailies.rstudio.com"
        exit 1
    fi

    # Test to see if we already have this version installed.
    LATEST_URL_VERSION=$(echo "${LATEST_URL}" | sed -e 's|^.*/RStudio-\(.*\)\.dmg|\1|')
    LATEST_VERSION=$(echo "${LATEST_URL_VERSION}" | dailyplus)
    echo "Latest version:    ${LATEST_VERSION}"

    REQUESTED_URL="${LATEST_URL}"
    if [ -z "${REQUESTED_VERSION}" ] ; then
        REQUESTED_VERSION="${LATEST_VERSION}"
    elif [ "${REQUESTED_VERSION}" != "${LATEST_VERSION}" ] ; then
        echo "Requested version: ${REQUESTED_VERSION}"
        REQUESTED_URL_VERSION=$(echo "${REQUESTED_VERSION}" | dailyunplus)
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

    echo "Installed ${REQUESTED_VERSION} from volume ${VOLUME_NAME} into /Applications"
}

install_ubuntu() {
    DIST="$1"
    KIND="$2"
    URL="https://rstudio.org/download/latest/${KIND}/desktop/${DIST}/rstudio-latest-amd64.deb"
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
        curl -L --fail -o "${TARGET}" "${URL}"
    elif [ -x /usr/bin/wget ] ; then
        wget -O "${TARGET}" "${URL}"
    else
        echo "Unable to obtain the RStudio package: cannot find 'curl' or 'wget'"
        exit 1
    fi

    echo "Installing ${TARGET}"
    LAUNCH=""
    if [[ $(whoami) != "root" ]]; then
        LAUNCH="sudo"
    fi
    ${LAUNCH} dpkg -i "${TARGET}"

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
    echo "  -s, --stable  Use stable, rather than daily builds."
    echo "  -h, --help    Display this help text and exit."
}

DIST="bionic"
KIND="daily"
FORCE="no"
for arg in "$@"; do
    case $arg in
        -s|--stable)
            KIND="stable"
            shift
            ;;
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
    install_macos "${KIND}" "${FORCE}" "${VERSION}"
elif grep -q Ubuntu /etc/issue ; then
    install_ubuntu "${DIST}" "${KIND}"
else
    echo "This script only works on OSX/macOS and Ubuntu Linux."
    exit 1
fi
