#!/bin/env bash

#    DXVK/Wine-Staging scripts dispatcher for various Linux distributions
#    Copyright (C) 2019  Pekka Helenius
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

source options.conf

###########################################################

# Check if we're using bash or sh to run the script. If bash, OK.
# If another one, ask user to run the script with bash.

BASH_CHECK=$(ps | grep `echo $$` | awk '{ print $4 }')

if [ $BASH_CHECK != "bash" ]; then
  echo "
Please run this script using bash (/usr/bin/bash).
"
  exit 1
fi

###########################################################

# Just a title & author for this script, used in initialization and help page

SCRIPT_TITLE="\e[1mWine/Wine Staging, DXVK, DXVK NVAPI, VKD3D Proton package bundle builder & auto-installer\e[0m"
SCRIPT_AUTHOR="Pekka Helenius (~Fincer), 2019-2022"

###########################################################
# Allow interruption of the script at any time (Ctrl + C)
trap "exit" INT

###########################################################

COMMANDS=(
  curl
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

SUDO_GROUPS=(
  sudo
  wheel
)

function checkCommands() {

  local COMMANDS_NOTFOUND
  local a

  if [[ $(which --help 2>/dev/null) ]] && [[ $(echo --help 2>/dev/null) ]]; then

    a=0
    for command in ${@}; do
      if [[ ! $(which $command 2>/dev/null) ]]; then
        COMMANDS_NOTFOUND[$a]=${command}
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

if [[ $(groups | grep -cE $(echo ${SUDO_GROUPS[*]} | sed 's/ /|/g')) -eq 0 ]]; then
  echo "You must belong to a sudo group (checked groups: ${SUDO_GROUPS[*]})."
  exit 1
fi

unset sudogrp

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
      NO_STAGING=
      ;;
    --no-install)
      # Just build, do not install DXVK or Wine-Staging
      # Note that some version of Wine is required for DXVK compilation, though!
      NO_INSTALL=
      ;;
    --no-wine)
      # Skip Wine build & installation process all together
      NO_WINE=
      ;;
    --no-dxvk)
      # Skip DXVK build & installation process all together
      NO_DXVK=
      ;;
    --no-vkd3d)
      # Skip VKD3D Proton build & installation process all together
      NO_VKD3D=
      ;;
    --no-nvapi)
      # Skip DXVK NVAPI build & installation process all together
      NO_NVAPI=
      ;;
    --no-pol)
      # Skip PlayOnLinux Wine prefixes update process
      NO_POL=
      ;;
    *)
      echo -e "\n\
\
${SCRIPT_TITLE} by ${SCRIPT_AUTHOR}\n\n\
Usage:\n\nbash updatewine.sh\n\nArguments:\n\n\
--no-install\tDo not install Wine or DXVK. Just compile them. Wine, meson & glslang must be installed for DXVK compilation.\n\
--no-dxvk\tDo not compile or install DXVK\n\
--no-vkd3d\tDo not compile or install VKD3D Proton\n\
--no-nvapi\tDo not compile or install DXVK NVAPI\n\
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
  "${git_commithash_dxvknvapi}"   # 0  
  "${git_commithash_vkd3dproton}" # 1  
  "${git_commithash_dxvk}"        # 2
  "${git_commithash_glslang}"     # 3
  "${git_commithash_meson}"       # 4
  "${git_commithash_wine}"        # 5
)

# Add git branches to argument list
# Pass them to subscripts, as well.

gitbranch_overrides=(
  "${git_branch_dxvknvapi}"    # 6
  "${git_branch_vkd3dproton}"  # 7
  "${git_branch_dxvk}"         # 8
  "${git_branch_glslang}"      # 9
  "${git_branch_meson}"        # 10
  "${git_branch_wine}"         # 11
)

# Add git sources to argument list
# Pass them to subscripts, as well.

gitsources=(
  "${git_source_dxvknvapi}"      # 12
  "${git_source_vkd3dproton}"    # 13
  "${git_source_dxvk}"           # 14
  "${git_source_glslang_debian}" # 15
  "${git_source_meson_debian}"   # 16
  "${git_source_wine}"           # 17
  "${git_source_winestaging}"    # 18

  # Debian
  "${git_source_dxvknvapi_debian}"   # 19
  "${git_source_vkd3dproton_debian}" # 20
  "${git_source_dxvk_debian}"        # 21
  "${git_source_wine_debian}"        # 22
  "${git_source_winestaging_debian}" # 23
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

###########################################################

params=(${datesuffix} ${githash_overrides[@]} ${gitbranch_overrides[@]} ${gitsources[@]} ${args[@]})

###########################################################

# General function for question responses
function questionresponse() {

  local response=${1}

  read -r -p "" response
  if [[ $(echo $response | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    return 0
  else
    return 1
  fi

}

###########################################################

function reqsCheck() {

  local AVAIL_SPACE
  local REC_SPACE
  local MSG_SPACE
  local AVAIL_RAM
  local REC_RAM
  local MSG_RAM

  AVAIL_SPACE=$(df -h -B MB --output=avail . | sed '1d; s/[A-Z]*//g')
  REC_SPACE=8000
  MSG_SPACE="\e[1mWARNING:\e[0m Not sufficient storage space\n\nYou will possibly run out of space while compiling software.\n\
The script strongly recommends ~\e[1m$((${REC_SPACE} / 1000)) GB\e[0m at least to compile software successfully but you have only\n\
\e[1m${AVAIL_SPACE} MB\e[0m left on the filesystem the script is currently placed at.\n\n\
Be aware that the script process may fail because of this, especially while compiling Wine Staging.\n\n\
Do you really want to continue? [Y/n]"

  AVAIL_RAM=$(( $(grep -oP "(?<=^MemFree:).*[0-9]" /proc/meminfo | sed 's/ //g') / 1024 ))
  REC_RAM=4096
  MSG_RAM="\e[1mWARNING:\e[0m Not sufficient RAM available\n\nCompilation processes will likely fail.\n\
The script strongly recommends ~\e[1m${REC_RAM} MB\e[0m at least to compile software successfully but you have only\n\
\e[1m${AVAIL_RAM} MB\e[0m left on the computer the script is currently placed at.\n\n\
Be aware that the script process may fail because of this, especially while compiling DXVK.\n\n\
Do you really want to continue? [Y/n]"

  function reqs_property() {

    local avail_prop
    local req_prop
    local req_message
    local req_installtargets
    local req_targetconditions
    local fullcondition
    local i

    avail_prop="${1}"
    req_prop="${2}"
    req_message="${3}"
    req_installtargets="${4}"

    i=0
    for req_installtarget in ${req_installtargets}; do
      req_targetconditions[$i]=$(echo "[[ ! -v ${req_installtarget} ]] ||")
      let i++
    done

    req_targetconditions=($(echo ${req_targetconditions[@]} | sed 's/\(.*\) ||/\1 /'))
    fullcondition="[[ "${avail_prop}" -lt "${req_prop}" ]] && ($(echo ${req_targetconditions[@]}))"

    if $(eval ${fullcondition}); then
      INFO_SEP
      echo -e "${req_message}"
      questionresponse
      if [[ $? -ne 0 ]]; then
        echo -e "Cancelling.\n"
        exit 1
      fi
      unset avail_prop req_prop req_installtarget req_targetconditions fullcondition
    fi
  }

  reqs_property "${AVAIL_SPACE}" "${REC_SPACE}" "${MSG_SPACE}" "NO_WINE"
  reqs_property "${AVAIL_RAM}" "${REC_RAM}" "${MSG_RAM}" "NO_DXVK"
}

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

if [[ ! -v NO_WINE ]] || [[ ! -v NO_DXVK ]] || [[ ! -v NO_VKD3D ]] || [[ ! -v NO_NVAPI ]]; then
  echo -e "\n${SCRIPT_TITLE}\n\nBuild identifier:\t${datesuffix}\n"
else
  echo ""
fi

if [[ -n ${args[*]} ]]; then
  echo -e "Using arguments:\t${args[*]}\n"
fi

determineDistroFamily

INFO_SEP
echo -e "\e[1mNOTE: \e[0mDXVK requires very latest Nvidia/AMD drivers to work.\nMake sure these drivers are available on your Linux distribution.\n\
This script comes with GPU driver installation scripts for Debian-based Linux distributions.\n"
INFO_SEP

if [[ ! -v NO_WINE ]] || [[ ! -v NO_DXVK ]] || [[ ! -v NO_VKD3D ]] || [[ ! -v NO_NVAPI ]]; then
  reqsCheck
  sudoQuestion
  echo ""
fi

bash -c "cd ${distro} && bash ./updatewine_${distro}.sh ${params[*]}"
