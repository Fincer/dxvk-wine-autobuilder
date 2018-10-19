#!/bin/bash

#    getsource - Simple script to set up Wine Staging + DXVK for PoL wineprefixes
#    Copyright (C) 2018  Pekka Helenius
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

###########################################################

if [[ $UID -ne 0 ]]; then
    echo "Run as root or sudo"
    exit 1
fi

###########################################################

# Your system username (who has PoL profile // existing Wine prefixes)
# Get it by running 'whoami'

read -r -p "Who has PoL profiles // existing Wine prefixes on the system? [username] " username

  function check_username {

  if [[ $username == "" ]]; then
    echo "Empty username is invalid. Aborting."
    exit 1
  fi

  if [[ $username == "root" ]]; then
    echo "Can't use 'root' user. Aborting."
    exit 1
  fi

  local IFS=$'\n'
  for validname in $(cat /etc/passwd | awk -F : '{print $1}'); do
    if [[ $validname == $username ]]; then
      USERNAME=$username
    fi
  done

  if [[ ! -n $USERNAME ]]; then
    echo "Couldn't find user $username. Please check the name and try again."
    exit 1
  fi

}

function check_pol {

  # Check existence of PoL default folder in user's homedir

  local USERHOME=$(grep $USERNAME /etc/passwd | awk -F : '{print $(NF-1)}')

  if [[ ! -d "$USERHOME/PlayOnLinux's virtual drives" ]]; then
    echo "Warning. Couldn't find PoL directories in the homedir of user $USERNAME."
    NOPOL=
  fi

}

check_username
check_pol

###########################################################

# REQUIREMENTS:

# - Arch Linux or equivalent (uses pacman)
#
# - Existing PlayonLinux package installation and $HOME/.PlayOnLinux folder
# with all relevant subfolders
#
# - git, sudo, pwd...etc.
#
# - dxvk-git and wine-staging-git package dependencies installed
# (see PKGBUILD files ./PKGBUILD and ./0-dxvk-git/PKGBUILD for details)
#
# - Internet connection
#
# - GPU Vulkan support and the most recent Nvidia/AMD drivers

###########################################################

# Usage

# Run with sudo
#
# # sudo bash ./updatewine.sh
#
# NOTE: All commands are executed as user (defined above).
# Only commands which require root permissions are ones
# which install packages wine-staging-git and dxvk into
# your system

# All regular user commands have prefix 'cmd' below

# Switches:
#
#   --refresh
#
#       Check for new Staging/DXVK releases, update PoL Wine prefixes if needed
#       Does a comparison between local & remote git repos
#
#   --check
#
#       Check for new Staging/DXVK releases
#       Does a comparison between local & remote git repos
#
#   --force
#
#       Force Wine Staging & DXVK installation
#

###########################################################

# Get current date
CURDATE=$(date "+%d-%m-%Y %H:%M:%S")

# This variable value is automatically generated. DO NOT CHANGE.
LASTUPDATE=

# This variable value is automatically generated. DO NOT CHANGE.
WINE_VERSION=

###########################################################

# Switches

if [[ "${1}" == "--refresh" ]]; then
    WINE_INSTALL=
    CHECK=
fi

if [[ "${1}" == "--check" ]]; then
    CHECK=
fi

if [[ "${1}" == "--force" ]] || [[ $WINE_VERSION == "" ]] || [[ $LASTUPDATE == "" ]]; then
    WINE_INSTALL=
    FORCE_INSTALL=
fi

if [[ $LASTUPDATE == "" ]]; then
    LASTUPDATE="Unknown"
fi

###########################################################

echo -e "\nLast update: $LASTUPDATE\n"

ORG_CURDIR=$(pwd)

cmd() {
    sudo -u $USERNAME bash -c "${*}"
}

###########################################################
# Check for existing PoL user folder

#if [[ ! -d /home/$USERNAME/.PlayOnLinux ]]; then
#    echo "No existing PlayonLinux profiles in $USERNAME's home folder. Aborting"
#    exit 1
#fi

###########################################################
# Check internet connection

function netCheck() {
    if [[ $(echo $(wget --delete-after -q -T 5 github.com -o -)$?) -ne 0 ]]; then
        echo -e "\nInternet connection failed (GitHub). Please check your connection and try again.\n"
        exit 1
    fi
}

###########################################################
# Local/Remote git comparisons

function gitCheck() {

    netCheck

    if [[ -v FORCE_INSTALL ]]; then
        NEEDSBUILD=1
        return 0
    fi

    if [[ ! -d "${1}" ]]; then
        NEEDSBUILD=1
        return 1
    fi

    echo -e "=> Checking ${2} GIT for changes\n"

    local CURDIR="${PWD}"
    cd "${1}"
    local LOCAL_GIT=$(git rev-parse @)
    local REMOTE_GIT=$(git ls-remote origin -h refs/heads/master | awk '{print $1}')

    echo -e "\t${2}:\n\tlocal git:  $LOCAL_GIT\n\tremote git: $REMOTE_GIT"

    if [[ $LOCAL_GIT != $REMOTE_GIT ]]; then
        # true
        echo -e "\e[91m\n\t${2} needs to be updated\e[0m\n"
        NEEDSBUILD=1
    else
        # false
        echo -e "\e[92m\n\t${2} is updated\e[0m\n"
        NEEDSBUILD=0
    fi

    cd "${CURDIR}"
}

###########################################################

# Remove any existing pkg,src or tar.xz packages left by previous pacman commands

cmd "rm -rf ./*/{pkg,src,*.tar.xz}"
cmd "rm -f ./0-wine-staging-git/*.patch"

if [[ $? -ne 0 ]]; then
    echo "Could not remove previous pacman-generated Wine source folders"
    exit 1
fi

###########################################################

# Do git check for Wine Staging
gitCheck ./0-wine-staging-git/wine-staging-git Wine

# If needs build and --check switch is not used
if [[ $NEEDSBUILD -eq 1 ]] && [[ ! -v CHECK ]]; then

    # Create wine-staging-git package and install it to the system
    cd "${ORG_CURDIR}"/0-wine-staging-git
    cmd "updpkgsums && makepkg ;"

    if [[ $(find . -mindepth 1 -maxdepth 1 -type f -iname "wine-*tar.xz" | wc -l) -ne 0 ]]; then
        pacman -U --noconfirm wine-*.tar.xz
    else
        cmd "rm -rf ./{*.patch,pkg,src}"
        exit 1
    fi

    if [[ $? -eq 0 ]]; then
        cmd "rm -rf ./{*.patch,pkg,src,*.tar.xz}"
        WINE_INSTALL=
        WINE_VERSION_UPDATE=$(pacman -Qi wine-staging-git | grep 'Version' | awk '{print $NF}')
    else
        exit 1
    fi

    cd ..

fi

#############################

# Create dxvk-git package and install it to the system
gitCheck ./0-dxvk-git/dxvk-git DXVK

# If needs build and --check switch is not used
if [[ $NEEDSBUILD -eq 1 ]] && [[ ! -v CHECK ]]; then

    # Create dxvk-git package and install it to the system
    cd "${ORG_CURDIR}"/0-dxvk-git
    cmd "updpkgsums && makepkg ;"

    if [[ $(find . -mindepth 1 -maxdepth 1 -type f -iname "dxvk-git-*tar.xz" | wc -l) -ne 0 ]]; then
        pacman -U --noconfirm dxvk-git*.tar.xz
    else
        cmd "rm -rf ./{pkg,src}"
        exit 1
    fi

    if [[ $? -eq 0 ]]; then
        cmd "rm -rf ./{pkg,src,dxvk-git*.tar.xz}"
    else
        exit 1
    fi

fi

cd ..

# If a new Wine Staging version was installed and 'System' version of Wine has been used in
# PoL wineprefix configurations, update those existing PoL wineprefixes
if [[ -v WINE_INSTALL ]] && [[ ! -v NOPOL ]]; then
    for wineprefix in $(find /home/$USERNAME/.PlayOnLinux/wineprefix -mindepth 1 -maxdepth 1 -type d); do
        if [[ -d ${wineprefix}/dosdevices ]]; then

        # If VERSION string exists, skip updating that prefix.
            if [[ $(printf $(grep -ril "VERSION" ${wineprefix}/playonlinux.cfg &> /dev/null)$?) -ne 0 ]]; then

                # If currently installed Wine version is not same than we just built.
                if [[ -v WINE_VERSION_UPDATE ]]; then
                    if [[ "${WINE_VERSION}" != "${WINE_VERSION_UPDATE}" ]]; then
                        cmd "WINEPREFIX=${wineprefix} wineboot -u"
                    fi
                fi
            fi
        fi
    done
fi

# Install dxvk-git to every PlayOnLinux wineprefix
if [[ $? -eq 0 ]] && [[ ! -v NOPOL ]]; then

    for wineprefix in $(find /home/$USERNAME/.PlayOnLinux/wineprefix -mindepth 1 -maxdepth 1 -type d); do

        if [[ -d ${wineprefix}/dosdevices ]]; then

            if [[ $(printf $(grep -ril "\"d3d11\"=\"native\"" ${wineprefix}/user.reg &> /dev/null)$?) -ne 0 ]]; then
                cmd "WINEPREFIX=${wineprefix} setup_dxvk32"
                cmd "WINEPREFIX=${wineprefix} setup_dxvk64"
            fi

            # For D3D10 DXVK support
            if [[ $(printf $(grep -ril "\"\*d3dcompiler_43\"=\"native\"" ${wineprefix}/user.reg &> /dev/null)$?) -ne 0 ]]; then
                cmd "WINEPREFIX=${wineprefix} winetricks d3dcompiler_43"
            fi

        fi

    done
fi

# If a new Wine Staging version was installed, update WINE_VERSION string variable in this script file
if [[ -v WINE_VERSION_UPDATE ]]; then
    cmd "sed -i 's/^WINE_VERSION=.*/WINE_VERSION=\"${WINE_VERSION_UPDATE}\"/' $ORG_CURDIR/updatewine.sh"
fi

# Update LASTUPDATE variable string, if --check switch is not used + a new Wine Staging version is used or NEEDSBUILD variable is set to 1
if [[ ! -v CHECK ]]; then
    if [[ -v WINE_INSTALL ]] || [[ $NEEDSBUILD -eq 1 ]]; then
        cmd "sed -i 's/^LASTUPDATE=.*/LASTUPDATE=\"$CURDATE\"/' $ORG_CURDIR/updatewine.sh"
    fi
fi

# Unset various env vars
unset CHECK
unset WINE_INSTALL
unset FORCE_INSTALL
