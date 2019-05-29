#!/bin/env bash

#    Wrapper for DXVK & Wine compilation scripts
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

########################################################

# DO NOT RUN INDIVIDUALLY, ONLY VIA ../updatewine.sh PARENT SCRIPT!

########################################################

# Root directory of this script file
ROOTDIR="${PWD}"

# datedir variable supplied by ../updatewine.sh script file
datedir="${1}"

########################################################

# http://wiki.bash-hackers.org/snipplets/print_horizontal_line#a_line_across_the_entire_width_of_the_terminal
function INFO_SEP() { printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - ; }

########################################################

# Divide input args into array indexes
# These are passed to the subscripts (array b)
i=0
for p in ${@:2}; do
  params[$i]=${p}
  let i++
done

########################################################

# Parse input arguments, filter user parameters
# The range is defined in ../updatewine.sh
# All input arguments are:
# <datedir> 4*<githash_override> 4*<gitbranch_override> <args>
# 0         1 2 3 4              5 6 7 8                9...
# Filter all but <args>, i.e. the first 0-8 arguments

i=0
for arg in ${params[@]:8}; do
  args[$i]="${arg}"
  let i++
done

# All valid arguments given in ../updatewine.sh are handled...
# All valid arguments are passed to subscripts...
# ...but these are specifically used in this script
#
for check in ${args[@]}; do

  case ${check} in
    --no-wine)
      NO_WINE=
      ;;
    --no-staging)
      NO_STAGING=
      ;;
    --no-dxvk)
      NO_DXVK=
      ;;
    --no-d9vk)
      NO_D9VK=
      ;;
    --no-pol)
      NO_POL=
      ;;
    --no-install)
      NO_INSTALL=
      # If this option is given, do not check PoL wineprefixes
      NO_POL=
      ;;
  esac

done

########################################################

# Create identifiable directory for this build

mkdir -p ${ROOTDIR}/compiled_deb/${datedir}

########################################################

# If the script is interrupted (Ctrl+C/SIGINT), do the following

function Deb_intCleanup() {
  cd ${ROOTDIR}
  rm -rf compiled_deb/${datedir}
  exit 0
}

# Allow interruption of the script at any time (Ctrl + C)
trap "Deb_intCleanup" INT

########################################################

# Check existence of ccache package

function ccacheCheck() {
  if [[ $(echo $(dpkg -s ccache &>/dev/null)$?) -ne 0 ]]; then
    echo -e "\e[1mNOTE:\e[0m Please consider installation of 'ccache' for faster compilation times if you compile repetitively.\nInstall it by typing 'sudo apt install ccache'\n"
  fi
}

ccacheCheck

########################################################

# Call Wine compilation & installation subscript in the following function

function wine_install_main() {

  echo -e "Starting compilation & installation of Wine$(if [[ ! -v NO_STAGING ]]; then printf " Staging"; fi)\n\n\
This can take up to 0.5-2 hours depending on the available CPU cores.\n\n\
Using $(nproc --ignore 1) of $(nproc) available CPU cores for Wine source code compilation.
"

  bash -c "cd ${ROOTDIR}/wineroot/ && bash ./winebuild.sh \"${datedir}\" \"${params[*]}\""

}

########################################################

# Call DXVK compilation & installation subscript in the following function

function dxvk_install_main() {

  echo -e "Starting compilation & installation of DXVK/D9VK\n\n\
This can take up to 10-20 minutes depending on how many dependencies we need to build for it.\n"

  bash -c "cd ${ROOTDIR}/dxvkroot && bash dxvkbuild.sh \"${datedir}\" \"${params[*]}\""
}

########################################################

function mainQuestions() {

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

##################################

  INFO_SEP

  echo -e "\e[1mINFO:\e[0m About installation\n\nThe installation may take long time because many development dependencies may be \
installed and the following packages may be compiled from source (depending on your choises):\n\n\
\t- Wine/Wine Staging (latest git version)\n\
\t- DXVK (latest git version)\n\
\t- D9VK (latest git version)\n\
\t- meson & glslang (latest git versions; these are build time dependencies for DXVK)\n\n\
Do you want to continue? [Y/n]"

  questionresponse

  if [[ $? -ne 0 ]]; then
    echo -e "Cancelling.\n"
    exit 1
  fi

####################

  INFO_SEP

  echo -e "\e[1mQUESTION:\e[0m Do you want to remove unneeded build time dependencies after package build process? [Y/n]"

  questionresponse

  if [[ $? -eq 0 ]]; then
    params+=('--buildpkg-rm')
  fi

####################

  AVAIL_SPACE=$(df -h -B MB --output=avail . | sed '1d; s/[A-Z]*//g')
  REC_SPACE=8000

  if [[ ${AVAIL_SPACE} -lt ${REC_SPACE} ]] && [[ ! -v NO_WINE ]]; then
    INFO_SEP

  echo -e "\e[1mWARNING:\e[0m Not sufficient storage space\n\nYou will possibly run out of space while compiling software.\n\
The script strongly recommends ~\e[1m$((${REC_SPACE} / 1000)) GB\e[0m at least to compile software successfully but you have only\n\
\e[1m${AVAIL_SPACE} MB\e[0m left on the filesystem the script is currently placed at.\n\n\
Be aware that the script process may fail because of this, especially while compiling Wine Staging.\n\n\
Do you really want to continue? [Y/n]"

    questionresponse

    if [[ $? -ne 0 ]]; then
      echo -e "Cancelling.\n"
      exit 1
    fi

    unset AVAIL_SPACE REC_SPACE
  fi

####################

  # This question is relevant only if DXVK or D9VK stuff is compiled
  if [[ ! -v NO_DXVK ]] || [[ ! -v NO_D9VK ]]; then
    INFO_SEP

    echo -e "\e[1mQUESTION:\e[0m Update existing dependencies?\n\nIn a case you have old build time dependencies on your system, do you want to update them?\n\
If you answer 'yes', then those dependencies are updated if needed. Otherwise, already installed\n\
build time dependencies are not updated. If you don't have 'meson' or 'glslang' installed on your system, they will be compiled, anyway.\n\
Be aware, that updating these packages may increase total run time used by this script.\n\n\
Update dependency packages & other system packages? [Y/n]"

    questionresponse

    if [[ $? -eq 0 ]]; then
      params+=('--updateoverride')
    fi

    INFO_SEP
  fi

}

########################################################

function coredeps_check() {

  # Universal core dependencies for package compilation
  _coredeps=('dh-make' 'make' 'gcc' 'build-essential' 'fakeroot')

  for coredep in ${_coredeps[@]}; do

    if [[ $(echo $(dpkg -s ${coredep} &>/dev/null)$?) -ne 0 ]]; then
      echo -e "Installing core dependency ${coredep}.\n"
      sudo apt install -y ${coredep}
      if [[ $? -ne 0 ]]; then
        echo -e "Could not install ${coredep}. Aborting.\n"
        exit 1
      fi
    fi
  done

}

########################################################

# If either Wine, DXVK or D9VK is to be compiled
if [[ ! -v NO_WINE ]] || [[ ! -v NO_DXVK ]] || [[ ! -v NO_D9VK ]]; then
  mainQuestions
  coredeps_check
fi

####################

# If Wine is going to be compiled, then
if [[ ! -v NO_WINE ]]; then
  wine_install_main
else
  echo -e "Skipping Wine build$(if [[ ! -v NO_INSTALL ]]; then printf " & installation"; fi) process.\n"
fi

####################

# If DXVK or D9VK is going to be installed, then 
if [[ ! -v NO_DXVK ]] || [[ ! -v NO_D9VK ]]; then
  dxvk_install_main
else
  echo -e "Skipping DXVK/D9VK build$(if [[ ! -v NO_INSTALL ]]; then printf " & installation"; fi) process.\n"
fi

####################

# If PlayOnLinux Wine prefixes are going to be updated, then
if [[ ! -v NO_POL ]]; then
  echo -e "\e[1mINFO:\e[0m Updating your PlayOnLinux Wine prefixes.\n"
  bash -c "cd ${ROOTDIR} && bash playonlinux_prefixupdate.sh"
fi
