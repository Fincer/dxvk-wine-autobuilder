#!/bin/env bash

#    DXVK/D9VK/Wine-Staging scripts dispatcher for various Linux distributions
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

# Just a title & author for this script, used in initialization and help page

SCRIPT_TITLE="\e[1mWine/Wine Staging, DXVK & D9VK package builder & auto-installer\e[0m"
SCRIPT_AUTHOR="Pekka Helenius (~Fincer), 2018"

########################################################

# Should we freeze Git versions of these packages?
# This is handy in some cases, if breakages occur
# (although we actually compile an older version of a package)
#
# Define a commit hash to freeze to
# Use keyword 'HEAD' if you want to use the latest git
# version available
# Do NOT leave these variable empty!

git_commithash_dxvk=HEAD
git_branch_dxvk=master

git_commithash_d9vk=HEAD
git_branch_d9vk=master

git_commithash_wine=HEAD
git_branch_wine=master

# These apply only on Debian/Ubuntu/Mint
git_commithash_meson=5d6dcf8850fcc5d552f55943b6aa3582754dedf8
git_branch_meson=master

git_commithash_glslang=HEAD
git_branch_glslang=master

###########################################################
# Allow interruption of the script at any time (Ctrl + C)
trap "exit" INT

###########################################################

COMMANDS=(
  date
  df
  find
  git
  grep
  groups
  nproc
  patch
  readlink
  sudo
  tar
  uname
  wc
  wget
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

# User-passed arguments for the script
# We check the values of this array
# and pass them to the subscripts if supported

i=0
for arg in ${@}; do

  case ${arg} in
    --no-staging)
      # Do not build Wine staging version, just Wine
      ;;
    --no-install)
      # Just build, do not install DXVK or Wine-Staging
      # Note that some version of Wine is required for DXVK compilation, though!
      ;;
    --no-wine)
      # Skip Wine build & installation process all together
      NO_WINE=
      ;;
    --no-dxvk)
      # Skip DXVK build & installation process all together
      NO_DXVK=
      ;;
    --no-d9vk)
      # Skip D9VK build & installation process all together
      NO_D9VK=
      ;;
    --no-pol)
      # Skip PlayOnLinux Wine prefixes update process
      ;;
    *)
      echo -e "\n\
\
${SCRIPT_TITLE} by ${SCRIPT_AUTHOR}\n\n\
Usage:\n\nbash updatewine.sh\n\nArguments:\n\n\
--no-install\tDo not install Wine, DXVK or D9VK. Just compile them. Wine, meson & glslang must be installed for DXVK & D9VK compilation.\n\
--no-dxvk\tDo not compile or install DXVK\n\
--no-d9vk\tDo not compile or install D9VK\n\
--no-pol\tDo not update PlayOnLinux Wine prefixes\n\n\
--no-staging\tCompile Wine instead of Wine Staging\n\
--no-wine\tDo not compile or install Wine/Wine Staging\n\n\
Compiled packages are installed by default, unless '--no-install' argument is given.\n\
If '--no-install' argument is given, the script doesn't check or update your PlayOnLinux Wine prefixes.\n"
      exit 0
      ;;
  esac

  args[$i]="${arg}"
  let i++
done

###########################################################

# Date timestamp and random number identifier for compiled
# DXVK & Wine Staging builds
# This variable is known as 'datedir' in other script files

datesuffix=$(echo $(date '+%Y-%m-%d-%H%M%S'))

###########################################################

# Add git commit hash overrides to argument list
# Pass them to subscripts, as well.

githash_overrides=(
"${git_commithash_dxvk}"
"${git_commithash_d9vk}"
"${git_commithash_glslang}"
"${git_commithash_meson}"
"${git_commithash_wine}"
)

# Add git branches to argument list
# Pass them to subscripts, as well.

gitbranch_overrides=(
"${git_branch_dxvk}"
"${git_branch_d9vk}"
"${git_branch_glslang}"
"${git_branch_meson}"
"${git_branch_wine}"
)

#############################

# Commit syntax validity check

for githash in ${githash_overrides[@]}; do

  if [[ ! $(printf ${githash} | wc -c) -eq 40 ]] && \
  [[ ! ${githash} == HEAD ]]; then
    echo -e "\nError: badly formatted commit hash '${githash}' in the script file 'updatewine.sh'. Aborting\n"
    exit 1
  fi
done

#############################

params=(${datesuffix} ${githash_overrides[@]} ${gitbranch_overrides[@]} ${args[@]})

###########################################################

function sudoQuestion() {
  sudo -k
  echo -e "\e[1mINFO:\e[0m sudo password required\n\nThis script requires elevated permissions for package updates & installations. Please provide your sudo password for these script commands. Sudo permissions are not used for any other purposes.\n"
  sudo -v

  if [[ $? -ne 0 ]]; then
    echo -e "Invalid sudo password.\n"
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
        echo -e "\nDNS name resolution failed (GitHub). Please check your network connection settings and try again.\n"
        exit 1
    fi
    rm -f ./index.html.tmp
}

checkInternet

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

if [[ ! -v NO_WINE ]] || [[ ! -v NO_DXVK ]] || [[ ! -v NO_D9VK ]]; then
  echo -e "\n${SCRIPT_TITLE}\n\nBuild identifier:\t${datesuffix}\n"
else
  echo ""
fi

if [[ -n ${args[*]} ]]; then
  echo -e "Using arguments:\t${args[*]}\n"
fi

determineDistroFamily

INFO_SEP
echo -e "\e[1mNOTE: \e[0mDXVK/D9VK requires very latest Nvidia/AMD drivers to work.\nMake sure these drivers are available on your Linux distribution.\n\
This script comes with GPU driver installation scripts for Debian-based Linux distributions.\n"
INFO_SEP

if [[ ! -v NO_WINE ]] || [[ ! -v NO_DXVK ]] || [[ ! -v NO_D9VK ]]; then
  sudoQuestion
  echo ""
fi

bash -c "cd ${distro} && bash ./updatewine_${distro}.sh ${params[*]}"
