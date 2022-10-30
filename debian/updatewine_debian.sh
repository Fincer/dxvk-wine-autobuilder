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
# TODO: remove duplicate functionality. This function is defined in updatewine.sh
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
for arg in ${params[@]:24}; do
  args[$i]="${arg}"
  let i++
done

# All valid arguments given in ../updatewine.sh are handled...
# All valid arguments are passed to subscripts...
# ...but these are specifically used in this script
#
for check in ${args[@]}; do

  case ${check} in
    --no-staging)
      NO_STAGING=
      ;;
    --no-install)
      NO_INSTALL=
      # Do not check for PlayOnLinux wine prefixes
      NO_POL=
      ;;
    --no-wine)
      NO_WINE=
      ;;
    --no-dxvk)
      NO_DXVK=
      ;;
    --no-vkd3d)
      NO_VKD3D=
      ;;
    --no-nvapi)
      NO_NVAPI=
      ;;
    --no-pol)
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

# Call DXVK/DXVK NVAPI/VKD3D Proton compilation & installation subscript in the following function

function wine_addons_install_main() {

  local addon_names

  addon_names=("${@}")
  addon_names_str=$(echo ${addon_names[@]} | tr ' ' ', ')

  echo -e "Starting compilation & installation of ${addon_names_str}\n\n\
This can take up to 10-20 minutes depending on how many dependencies we need to build for it.\n"

  bash -c "cd ${ROOTDIR}/wine_addons_root && bash wine_addons_build.sh \"${datedir}\" \"${params[*]}\""
}

########################################################

function mainQuestions() {

  # General function for question responses
  # TODO: remove duplicate functionality. This function is defined in updatewine.sh
  function questionresponse() {

    local response
  
    response=${1}

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
\t- DXVK NVAPI (latest git version)\n\
\t- VKD3D Proton (latest git version)\n\
\t- meson & glslang (latest git versions; these are build time dependencies for DXVK)\n\n\
Do you want to continue? [Y/n]"

  questionresponse

  if [[ $? -ne 0 ]]; then
    echo -e "Cancelling.\n"
    exit 1
  fi

####################

  INFO_SEP

  echo -e "\e[1mQUESTION:\e[0m Do you want to remove unneeded build time dependencies after package build process? [Y/n] \n\n
  WARNING: The check is not perfect. Answering [y] MAY DAMAGE YOUR SYSTEM!\n \
  Safer approach is to answer [n] and get the list of installed packages, thus you can manually decide which packages to uninstall.
  "

  questionresponse

  if [[ $? -eq 0 ]]; then
    params+=('--buildpkg-rm')
  fi

####################

  # This question is relevant only if DXVK, DXVK NVAPI or VKD3D Proton stuff is compiled
  if [[ ! -v NO_DXVK ]] || [[ ! -v NO_NVAPI ]] || [[ ! -v NO_VKD3D ]]; then
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

# If either Wine, DXVK, DXVK NVAPI or VKD3D Proton is to be compiled
if [[ ! -v NO_WINE ]] || [[ ! -v NO_DXVK ]] || [[ ! -v NO_NVAPI ]] || [[ ! -v NO_VKD3D ]]; then
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

# If DXVK/DXVK NVAPI or VKD3D Proton is going to be installed, then
if [[ ! -v NO_DXVK ]] || [[ ! -v NO_NVAPI ]] || [[ ! -v NO_VKD3D ]]; then

  addons=()
  [[ ! -v NO_DXVK ]] && addons+=("DXVK")
  [[ ! -v NO_NVAPI ]] && addons+=("DXVK_NVAPI")
  [[ ! -v NO_VKD3D ]] && addons+=("VKD3D_Proton")

  wine_addons_install_main ${addons[@]}
else
  echo -e "Skipping Wine addons build$(if [[ ! -v NO_INSTALL ]]; then printf " & installation"; fi) process.\n"
fi

####################

# If PlayOnLinux Wine prefixes are going to be updated, then
if [[ ! -v NO_POL ]]; then
  echo -e "\e[1mINFO:\e[0m Updating your PlayOnLinux Wine prefixes.\n"
  bash -c "cd ${ROOTDIR} && bash playonlinux_prefixupdate.sh"
fi
