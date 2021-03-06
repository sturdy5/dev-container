#!/usr/bin/env bash
#
# Syntax: ./spdx-generator-debian.sh [spdx generator version] [non-root user] [Update rc files flag]

SPDX_GENERATOR_VERSION=${1:-"latest"}
USERNAME=${2:-"automatic"}
UPDATE_RC=${3:-"true"}

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" > /etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in ${POSSIBLE_USERS[@]}; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

function updaterc() {
    if [ "${UPDATE_RC}" = "true" ]; then
        echo "Updating /etc/bash.bashrc and /etc/zsh/zshrc..."
        echo -e "$1" >> /etc/bash.bashrc
        if [ -f "/etc/zsh/zshrc" ]; then
            echo -e "$1" >> /etc/zsh/zshrc
        fi
    fi
}

export DEBIAN_FRONTEND=noninteractive

# Install curl, zip, unzip if missing
if ! dpkg -s curl ca-certificates zip unzip sed > /dev/null 2>&1; then
    if [ ! -d "/var/lib/apt/lists" ] || [ "$(ls /var/lib/apt/lists/ | wc -l)" = "0" ]; then
        apt-get update
    fi
    apt-get -y install --no-install-recommends curl ca-certificates zip unzip sed
fi

# Install spdx generator
curl -sSL https://github.com/spdx/spdx-sbom-generator/releases/download/v${SPDX_GENERATOR_VERSION}/spdx-sbom-generator-v${SPDX_GENERATOR_VERSION}-linux-amd64.tar.gz -o /tmp/spdx-generator.tar.gz
tar -xzf /tmp/spdx-generator.tar.gz -C /usr/local/bin

echo "Done!"
