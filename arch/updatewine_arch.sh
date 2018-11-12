#!/bin/bash

#    Set up Wine Staging + DXVK on Arch Linux & Variants
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
ARCH_BUILDROOT="${PWD}"

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
    --no-pol)
      NO_POL=
      ;;
  esac

done

###########################################################

# If the script is interrupted (Ctrl+C/SIGINT), do the following

function Arch_intCleanup() {
  rm -rf ${ARCH_BUILDROOT}/{0-wine-staging-git/{wine-patches,*.tar.xz},0-dxvk-git/{dxvk-git,*.tar.xz}}
  exit 0
}

# Allow interruption of the script at any time (Ctrl + C)
trap "Arch_intCleanup" INT

###########################################################

# Check existence of ccache package

function ccacheCheck() {
  if [[ $(pacman -Q | awk '{print $1}' | grep -wE "ccache" | wc -l) -eq 0 ]]; then
    echo -e "NOTE: Please consider using 'ccache' for faster compilation times.\nInstall it by typing 'sudo pacman -S ccache'\n"
  fi
}

###########################################################

# Validate all core build files for Wine and/or DXVK exist

function checkFiles() {

  local wine_files=('30-win32-aliases.conf' 'PKGBUILD')
  local dxvk_files=('PKGBUILD')

  function validatefiles() {

    local list=${1}
    local name=${2}
    local path=${3}

    for file in ${list[@]}; do
      if [[ ! -f "${path}/${file}" ]]; then
        echo -e "Could not locate file ${} for ${name}. Aborting\n"
        exit 1
      fi
    done

  }

  if [[ ! -v NO_WINE ]]; then
    validatefiles "${wine_files[*]}" Wine "${ARCH_BUILDROOT}/0-wine-staging-git"
  fi

  if [[ ! -v NO_DXVK ]]; then
    validatefiles "${dxvk_files[*]}" DXVK "${ARCH_BUILDROOT}/0-dxvk-git"
  fi

}

###########################################################

# Disable or enable Wine Staging, depending on user's
# choice

function checkStaging() {

  # Enable Wine Staging
  if [[ ! -v NO_STAGING ]]; then
    sed -i 's/enable_staging=[0-9]/enable_staging=1/' "${ARCH_BUILDROOT}/0-wine-staging-git/PKGBUILD"
    wine_name="wine-staging-git"

  # Enable Wine, disable Staging
  else
    sed -i 's/enable_staging=[0-9]/enable_staging=0/' "${ARCH_BUILDROOT}/0-wine-staging-git/PKGBUILD"
    wine_name="wine"
  fi

}

###########################################################

# Check package dependencies beforehand, just to avoid
# annoying situations which could occur later while the script
# is already running.

# Just for "packages which are not found" array <=> ERRPKGS
# We need to set it outside of checkDepends function
# because it is a global variable for all checked packages
l=0

function checkDepends() {

  # The first and the second argument
  local packagedir=${1}
  local package=${2}

  # We get necessary variables to check from this file
  local file="./${packagedir}/PKGBUILD"

  # All but the (zero), the first and the second argument
  # We check the value of these file variables
  local file_vars=${@:3}

  for var in ${file_vars[*]}; do
    # Get the variable and set it as a new variable in the current shell
    # This is applicable only to variable arrays! Do not use if the variable is not an array.
    local field=$(awk "/^${var}/,/)/" ${file} | sed -r "s/^${var}=|[)|(|']//g")

    local i=0
    for parse in ${field[*]}; do
      if [[ ! $parse =~ ^# ]]; then
        local PKGS[$i]=$(printf '%s' $parse | sed 's/[=|>|<].*$//')
        let i++
      fi
    done

    # Sort list and delete duplicate index values
    local PKGS=($(sort -u <<< "${PKGS[*]}"))

    for pkg in ${PKGS[*]}; do

      if [[ $(printf $(pacman -Q ${pkg} &>/dev/null)$?) -ne 0 ]]; then
        ERRPKGS[$l]=${pkg}
        echo -e "\e[91mError:\e[0m Dependency '${pkg}' not found, required by '${package}' (${file} => ${var})"
        let l++
      fi

    done

  done

  echo -e "\e[92m==>\e[0m\e[1m Dependency check for ${package} done.\e[0m\n"
}

function check_alldeps() {

  if [[ -v ERRPKGS ]]; then
    echo -e "The following dependencies are missing:\n\e[91m\
$(for o in ${ERRPKGS[@]}; do printf '%s\n' ${o}; done)\
\e[0m\n"
    exit 1
  fi

}

###########################################################

# Prepare building environment for the current runtime

function prepare_env() {

  # Copy Wine & DXVK patch files
  cp -rf ${ARCH_BUILDROOT}/../wine_custom_patches ${ARCH_BUILDROOT}/0-wine-staging-git/wine-patches
  cp -rf ${ARCH_BUILDROOT}/../dxvk_custom_patches ${ARCH_BUILDROOT}/0-dxvk-git/dxvk-patches

  # Create identifiable directory for this build
  mkdir -p ${ARCH_BUILDROOT}/compiled_pkg/"${datedir}"

}

###########################################################

# Remove any existing pkg,src or tar.xz packages left by previous pacman commands

function cleanUp() {
  rm -rf ${ARCH_BUILDROOT}/*/{pkg,src,*.tar.xz}
  rm -rf ${ARCH_BUILDROOT}/0-wine-staging-git/{*.patch}
  rm -rf ${ARCH_BUILDROOT}/0-dxvk-git/{*.patch}
}

###########################################################

# Build & install package

function build_pkg() {

  local pkgname=${1}
  local pkgname_friendly=${2}
  local pkgdir=${3}
  local cleanlist=${4}

  # Create package and install it to the system
  cd "${ARCH_BUILDROOT}"/${pkgdir}
  bash -c "updpkgsums && makepkg"

  # After successful compilation...
  if [[ $(ls ${pkgname}-*tar.xz | wc -l) -ne 0 ]]; then

    if [[ ! -v NO_INSTALL ]]; then
      yes | sudo pacman -U ${pkgname}-*.tar.xz
    fi

    mv ${pkgname}-*.tar.xz ${ARCH_BUILDROOT}/compiled_pkg/${datedir}/ && \
    echo -e "\nCompiled ${pkgname_friendly} is stored at '$(readlink -f ${ARCH_BUILDROOT}/compiled_pkg/${datedir}/)/'\n"
    for rml in ${cleanlist[*]}; do
      rm -rf  "${ARCH_BUILDROOT}/${pkgdir}/${rml}"
    done

  else
    echo -e "Error occured while compliling ${pkgname} from source.\n"
    for rml in ${cleanlist[*]}; do
      rm -rf  "${ARCH_BUILDROOT}/${pkgdir}/${rml}"
    done
    exit 1
  fi

  cd "${ARCH_BUILDROOT}"

}

##########################################################

# Update user's PlayOnLinux Wine prefixes if present

function updatePOL() {

  # Check whether we will update user's PoL wine prefixes
  if [[ ! -v NO_POL ]]; then
    # Check existence of PoL default folder in user's homedir
    if [[ ! -d "$HOME/.PlayOnLinux" ]]; then
      echo -e "Warning. Couldn't find PoL directories in the user's $USERNAME homedir.\n"
      return 0
    fi
  fi


  if [[ ! -v NO_WINE ]]; then
    # If a new Wine Staging version was installed and 'System' version of Wine has been used in
    # PoL wineprefix configurations, update those existing PoL wineprefixes
    for wineprefix in $(find $HOME/.PlayOnLinux/wineprefix -mindepth 1 -maxdepth 1 -type d); do
      if [[ -d ${wineprefix}/dosdevices ]]; then

        # If VERSION string exists, skip updating that prefix.
        if [[ $(printf $(grep -ril "VERSION" ${wineprefix}/playonlinux.cfg &> /dev/null)$?) -ne 0 ]]; then
          WINEPREFIX=${wineprefix} wineboot -u
        fi
      fi
    done
  fi

  if [[ ! -v NO_DXVK ]]; then
    for wineprefix in $(find $HOME/.PlayOnLinux/wineprefix -mindepth 1 -maxdepth 1 -type d); do
      if [[ -d ${wineprefix}/dosdevices ]]; then
        WINEPREFIX=${wineprefix} setup_dxvk
      fi
    done
  fi

}

##########################################################

# Clean these temporary folders & files

# TODO Shall we remove git folders or keep them?
dxvk_wine_cleanlist=('*.patch' '*.diff' 'pkg' 'src' '*-patches' '*.tar.xz') # dxvk-git wine-*git

##########################################################

# Validate all buildtime files
checkFiles

# Check whether we build Wine or Wine Staging
checkStaging

# Check whether we have ccache installed
ccacheCheck

# Prepare building environment: copy patches and create timestamped folder for compiled packages
prepare_env

# Clean all previous trash we may have
cleanUp

#########################

# Check Wine & DXVK dependencies, depending on whether these packages
# are to be built

echo -e "\e[1mINFO:\e[0m Checking dependencies for packages.\n"

if [[ ! -v NO_WINE ]]; then
  checkDepends "0-wine-staging-git" "${wine_name}" _depends makedepends
fi

if [[ ! -v NO_DXVK ]]; then
  checkDepends "0-dxvk-git" "dxvk-git" depends makedepends
fi

check_alldeps

#########################

# Compile Wine & DXVK, depending on whether these packages
# are to be built

if [[ ! -v NO_WINE ]]; then
  build_pkg wine "${wine_name}" "0-wine-staging-git" "${dxvk_wine_cleanlist[*]}"
fi

if [[ ! -v NO_DXVK ]]; then
  build_pkg dxvk DXVK "0-dxvk-git" "${dxvk_wine_cleanlist[*]}"
fi

#########################

# Update user's PlayonLinux wine prefixes if needed

if [[ ! -v NO_POL ]]; then
  echo -e "Updating your PlayOnLinux Wine prefixes.\n"
  updatePOL
fi
