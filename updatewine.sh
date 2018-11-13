#!/bin/env bash

#    DXVK/Wine-Staging scripts dispatcher for various Linux distributions
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

##############################################################################

# Check if we're using bash or sh to run the script. If bash, OK.
# If another one, ask user to run the script with bash.

BASH_CHECK=$(ps | grep `echo $$` | awk '{ print $4 }')

if [ $BASH_CHECK != "bash" ]; then
    echo  "
Please run this script using bash (/usr/bin/bash).
    "
    exit 1
fi

###########################################################
# Allow interruption of the script at any time (Ctrl + C)
trap "exit" INT

###########################################################

COMMANDS=(
  groups
  sudo
  wget
  date
  find
  grep
  uname
  readlink
  patch
)

function checkCommands() {

    if [[ $(which --help 2>/dev/null) ]] && [[ $(echo --help 2>/dev/null) ]]; then

        local a=0
        for command in ${@}; do
            if [[ ! $(which $command 2>/dev/null) ]]; then
                local COMMANDS_NOTFOUND[$a]=${command}
                let a++
            fi
        done

        if [[ -n $COMMANDS_NOTFOUND ]]; then
            echo -e "\nError! The following commands could not be found: ${COMMANDS_NOTFOUND[*]}\nAborting\n"
            exit 1
        fi
    else
        exit 1
    fi
}

checkCommands "${COMMANDS[*]}"

###########################################################

# http://wiki.bash-hackers.org/snipplets/print_horizontal_line#a_line_across_the_entire_width_of_the_terminal
function INFO_SEP() { printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - ; }

###########################################################

if [[ $(uname -a | grep -c x86_64) -eq 0 ]]; then
  echo "This script supports 64-bit architectures only."
  exit 1
fi

if [[ $(groups | grep -c sudo) -eq 0 ]]; then
  echo "You must belong to sudo group."
  exit 1
fi

if [[ $UID -eq 0 ]]; then
  echo "Run as a regular user."
  exit 1
fi

###########################################################

# Prevent running on pure Debian

# This is just to prevent this script from running on Debian
# Although the script works quite well on Debian
# we get conflicting issues between amd64 & i386 Wine
# buildtime dependency packages
# These conflicts do not occur on Ubuntu or on Mint

# Additionally, package 'winetricks' is not found on Debian.
# This is quite trivial to get fixed, though.

if [[ -f /usr/lib/os-release ]]; then
  distroname=$(grep -oP "(?<=^NAME=\").*(?=\"$)" /usr/lib/os-release)
else
  echo -e "\nCould not verify your Linux distribution. Aborting.\n"
  exit 1
fi

case "${distroname}" in
  *Debian*)
    echo -e "\nSorry, pure Debian is not supported yet. See README for details. Aborting.\n"
    exit 0
    ;;
esac

###########################################################

# Just a title & author for this script, used in initialization and help page

SCRIPT_TITLE="\e[1mWine/Wine Staging & DXVK package builder & auto-installer\e[0m"
SCRIPT_AUTHOR="Pekka Helenius (~Fincer), 2018"

###########################################################

# User-passed arguments for the script
# We check the values of this array
# and pass them to the subscripts if supported

i=0
for arch_arg in ${@}; do

  case ${arch_arg} in
    --no-staging)
      # Do not build Wine staging version, just Wine
      ;;
    --no-install)
      # Just build, do not install DXVK or Wine-Staging
      # Note that some version of Wine is required for DXVK compilation, though!
      ;;
    --no-wine)
      # Skip Wine build & installation process all together
      ;;
    --no-dxvk)
      # Skip DXVK build & installation process all together
      ;;
    --no-pol)
      # Skip PlayOnLinux Wine prefixes update process
      ;;
    *)
      echo -e "\n\
\
${SCRIPT_TITLE} by ${SCRIPT_AUTHOR}\n\n\
Usage:\n\nbash updatewine.sh\n\nArguments:\n\n\
--no-staging\tCompile Wine instead of Wine Staging\n\
--no-install\tDo not install Wine or DXVK, just compile them. Wine, meson & glslang must be installed for DXVK compilation.\n\
--no-wine\tDo not compile or install Wine/Wine Staging\n\
--no-dxvk\tDo not compile or install DXVK\n\
--no-pol\tDo not update PlayOnLinux Wine prefixes\n\n\
Compiled packages are installed by default, unless '--no-install' argument is given.\n\
If '--no-install' argument is given, the script doesn't check or update your PlayOnLinux Wine prefixes.\n"
      exit 0
      ;;
  esac

  args[$i]="${arch_arg}"
  let i++
done

###########################################################

function sudoQuestion() {
  sudo -k
  echo -e "\e[1mINFO:\e[0m sudo password required\n\nThis script requires elevated permissions for package updates & installations. Please provide your sudo password for these script commands. Sudo permissions are not used for any other purposes.\n"
  sudo echo "" > /dev/null

  if [[ $? -ne 0 ]]; then
    echo "Invalid sudo password.\n"
    exit 1
  fi

  # PID of the current main process
  PIDOF=$$

  # Run sudo timestamp update on the background and continue the script execution
  # Refresh sudo timestamp while the main process is running
  function sudo_refresh() {
    while [[ $(printf $(ps ax -o pid --no-headers | grep -o ${PIDOF} &> /dev/null)$?) -eq 0 ]]; do
    sudo -nv && sleep 2
    done
  }

  sudo_refresh &

}

###########################################################

function checkInternet() {
    if [[ $(echo $(wget --delete-after -q -T 5 github.com -o -)$?) -ne 0 ]]; then
        echo -e "\nInternet connection failed (GitHub). Please check your connection and try again.\n"
        exit 1
    fi
    rm -f ./index.html.tmp
}

checkInternet

###########################################################

# Date timestamp and random number identifier for compiled
# DXVK & Wine Staging builds
# This variable is known as 'datedir' in other script files

datesuffix=$(echo $(date '+%Y-%m-%d-%H%M%S'))

###########################################################
# Only Debian & Arch based Linux distributions are currently supported

function determineDistroFamily() {

  # These are default package managers used by the supported Linux distributions
  pkgmgrs=('dpkg' 'pacman')

  for pkgmgr in ${pkgmgrs[@]}; do
    if [[ $(printf $(which ${pkgmgr} &> /dev/null)$?) -eq 0 ]]; then
      pkgmgr_valid=${pkgmgr}
    fi
  done

  case ${pkgmgr_valid} in

    dpkg)
      distro="debian"
      ;;
    pacman)
      distro="arch"
      ;;
    default|*)
        echo -e "Your Linux distribution is not supported. Aborting.\n"
        exit 1
      ;;
  esac
}

echo -e "\n${SCRIPT_TITLE}\n\nBuild identifier:\t${datesuffix}\n"

if [[ -n ${args[*]} ]]; then
  echo -e "Using arguments:\t${args[*]}\n"
fi

determineDistroFamily

INFO_SEP
echo -e "\e[1mNOTE: \e[0mDXVK requires very latest Nvidia/AMD drivers to work. Make sure these drivers are available on your Linux distribution.\n\
This script comes with GPU driver installation scripts for Debian-based Linux distributions.\n"
INFO_SEP

sudoQuestion
echo ""
INFO_SEP

bash -c "cd ${distro} && bash ./updatewine_${distro}.sh \"${datesuffix}\" ${args[*]}"
