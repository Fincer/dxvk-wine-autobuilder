#!/bin/env bash

#    Wrapper for DXVK & Wine compilation scripts
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

# Parse input arguments

i=0
for arg in ${@:2}; do
  args[$i]="${arg}"
  let i++
done
# Must be a true array as defined above, not a single index list!
#args="${@:2}"

# All valid arguments given in ../updatewine.sh are handled...
# All valid arguments are passed to subscripts...
# ...but these are specifically used in this script
#
for check in ${args[@]}; do

  case ${check} in
    --no-wine)
      NO_WINE=
      ;;
    --no-dxvk)
      NO_DXVK=
      ;;
    --no-pol)
      NO_POL=
      ;;
    --no-install)
      # If this option is given, do not check PoL wineprefixes
      NO_POL=
      ;;
  esac

done

########################################################

mkdir -p ${ROOTDIR}/compiled_deb/${datedir}

########################################################

function Deb_intCleanup() {
  cd ${ROOTDIR}
  rm -rf compiled_deb/${datedir}
  exit 0
}

# Allow interruption of the script at any time (Ctrl + C)
trap "Deb_intCleanup" INT

########################################################

function ccacheCheck() {
  if [[ $(apt version ccache | wc -w) -eq 0 ]]; then
    echo -e "NOTE: Please consider using 'ccache' for faster compilation times.\nInstall it by typing 'sudo apt install ccache'\n"
  fi
}

ccacheCheck

########################################################

function wine_install_main() {

  echo -e "Starting compilation & installation of Wine\n\n\
This can take up to 0.5-2 hours depending on the available CPU cores.\n\n\
Using $(nproc --ignore 1) of $(nproc) available CPU cores for Wine source code compilation.
"

  bash -c "cd ${ROOTDIR}/wineroot/ && bash ./winebuild.sh \"${datedir}\" \"${args[*]}\""

}

########################################################

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
installed and the following packages will be compiled from source (depending on your choise):\n\n\
\t- Wine/Wine Staging (latest git version)\n\
\t- DXVK (latest git version)\n\
\t- meson & glslang (latest git versions; these are build time dependencies for DXVK)\n\n\
Do you want to continue? [Y/n]"

questionresponse

if [[ $? -ne 0 ]]; then
  echo -e "Cancelling.\n"
  exit 2
fi

####################

AVAIL_SPACE=$(df -h -B MB --output=avail . | sed '1d; s/[A-Z]*//g')
REC_SPACE=8000

if [[ ${AVAIL_SPACE} -lt ${REC_SPACE} ]]; then
  INFO_SEP

echo -e "\e[1mWARNING:\e[0m Not sufficient storage space\n\nYou will possibly run out of space while compiling software.\n\
The script strongly recommends ~\e[1m$((${REC_SPACE} / 1000)) GB\e[0m at least to compile software successfully but you have only\n\
\e[1m${AVAIL_SPACE} MB\e[0m left on the filesystem the script is currently placed at.\n\n\
Be aware that the script process may fail because of this, especially while compiling Wine Staging.\n\n\
Do you really want to continue? [Y/n]"

  questionresponse

  if [[ $? -ne 0 ]]; then
    echo -e "Cancelling.\n"
    exit 2
  fi

  unset AVAIL_SPACE REC_SPACE
fi

####################

INFO_SEP

echo -e "\e[1mINFO:\e[0m Update existing dependencies?\n\nIn a case you have old build time dependencies on your system, do you want to update them?\n\
If you answer 'yes', then those dependencies are updated if needed. Otherwise, already installed\n\
build time dependencies are not updated. If you don't have 'meson' or 'glslang' installed on your system, they will be compiled, anyway.\n\
Be aware, that updating these packages may increase total run time used by this script.\n\n\
Update dependency packages & other system packages? [Y/n]"

questionresponse

if [[ $? -eq 0 ]]; then
  args+=('--updateoverride')
fi

INFO_SEP

########################################################

if [[ ! -v NO_WINE ]]; then
  wine_install_main
else
  echo -e "Skipping Wine build & installation process.\n"
fi

if [[ ! -v NO_DXVK ]]; then
  bash -c "cd ${ROOTDIR}/dxvkroot && bash dxvkbuild.sh \"${datedir}\" \"${args[*]}\""
else
  echo -e "Skipping DXVK build & installation process.\n"
fi

if [[ ! -v NO_POL ]]; then
  bash -c "cd ${ROOTDIR} && bash playonlinux_prefixupdate.sh"
fi

