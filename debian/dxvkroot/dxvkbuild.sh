#!/bin/env bash

#    Compile DXVK git on Debian/Ubuntu/Mint and variants
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

# DO NOT RUN INDIVIDUALLY, ONLY VIA ../../updatewine.sh PARENT SCRIPT!

########################################################

# Root directory of this script file
DXVKROOT="${PWD}"

# datedir variable supplied by ../updatewine_debian.sh script file
datedir="${1}"

########################################################

# Divide input args into array indexes
i=0
for p in ${@:2}; do
  params[$i]=${p}
  let i++
done

########################################################

# Parse input git override hashes
# This order is mandatory!
# If you change the order or contents of 'githash_overrides'
# array in ../updatewine.sh, make sure to update these
# variables!
#
git_commithash_dxvk=${params[0]}
git_commithash_glslang=${params[1]}
git_commithash_meson=${params[2]}

########################################################

# Parse input arguments, filter user parameters
# The range is defined in ../updatewine.sh
# All input arguments are:
# <datedir> 4*<githash_override> <args>
# 0         1 2 3 4              5 ...
# Filter all but <args>, i.e. the first 0-4 arguments

i=0
for arg in ${params[@]:4}; do
  args[$i]="${arg}"
  let i++
done

for check in ${args[@]}; do

  case ${check} in
    --no-install)
      NO_INSTALL=
      ;;
#    --no-winetricks)
#      NO_WINETRICKS=
#      ;;
    --updateoverride)
      UPDATE_OVERRIDE=
      ;;
    --buildpkg-rm)
      BUILDPKG_RM=
      ;;
  esac

done

########################################################

# PRESENCE OF WINE

# Check presence of Wine. Some version of Wine should
# be found in the system in order to install DXVK.

known_wines=(
'wine'
'wine-stable'
'wine32'
'wine64'
'libwine:amd64'
'libwine:i386'
'wine-git'
'wine-staging-git'
)

known_winetricks=(
'winetricks'
)

function runtimeCheck() {

  # Friendly name for this package
  local pkgreq_name=${1}
  # Known package names to check on Debian
  local known_pkgs=${2}

  # Check if any of these Wine packages are present on the system
  i=0
  for pkg in ${known_pkgs[@]}; do
    if [[ $(echo $(dpkg -s ${pkg} &>/dev/null)$?) -eq 0 ]]; then
      local pkglist[$i]=${pkg}
      let i++
    fi
  done

  if [[ -z ${pkglist[*]} ]]; then
    echo -e "\e[1mWARNING:\e[0m Not installing DXVK because \e[1m${pkgreq_name}\e[0m is missing on your system.\n\
${pkgreq_name} should be installed in order to use DXVK. Just compiling DXVK for later use.\n"

    # Do this check separately so we can warn about all missing runtime dependencies above
    if [[ ! -v NO_INSTALL ]]; then
      # Force --no-install switch
      NO_INSTALL=
    fi

  fi

}

########################################################

# If the script is interrupted (Ctrl+C/SIGINT), do the following

function DXVK_intCleanup() {
  rm -rf ${DXVKROOT}/{dxvk-git,meson,glslang}
  rm -rf ${DXVKROOT}/../compiled_deb/"${datedir}"
  exit 0
}

# Allow interruption of the script at any time (Ctrl + C)
trap "DXVK_intCleanup" INT

########################################################

# http://wiki.bash-hackers.org/snipplets/print_horizontal_line#a_line_across_the_entire_width_of_the_terminal
function INFO_SEP() { printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - ; }

########################################################

# Update all packages if UPDATE_OVERRIDE given

if [[ -v UPDATE_OVERRIDE ]]; then
  echo -en "Updating all packages" && \
  if [[ $(printf $(sudo -n uptime &>/dev/null)$?) -ne 0 ]]; then printf " Please provide your sudo password.\n"; else printf "\n\n"; fi
  sudo apt update && sudo apt upgrade -y
fi

########################################################

# Check do we need to compile the package
# given as input for this function

function pkgcompilecheck() {

  local install_function=${1}
  local pkg=${2}
  local pkg_data=${3}

  if [[ $(echo $(dpkg -s ${pkg} &>/dev/null)$?) -ne 0 ]] || [[ -v UPDATE_OVERRIDE ]]; then
    ${install_function} ${pkg_data}
  fi

}

########################################################

# DXVK CUSTOM INSTALLATION HOOKS

# These are custom installation instructions for DXVK
# They are not used independently.

function dxvk_install_custom() {

  # Use posix alternates for MinGW binaries
  function dxvk_posixpkgs() {

    local packages=(
    'i686-w64-mingw32-g++'
    'i686-w64-mingw32-gcc'
    'x86_64-w64-mingw32-g++'
    'x86_64-w64-mingw32-gcc'
    )

    for package in "${packages[@]}"; do
      local option=$(echo "" | sudo update-alternatives --config "${package}" | grep posix | sed 's@^[^0-9]*\([0-9]\+\).*@\1@')
      echo "${option}" | sudo update-alternatives --config "${package}" &> /dev/null

      if [[ $? -ne 0 ]]; then
        echo -e "\e[1mERROR:\e[0m Error occured while running 'update-alternatives' for '${package}'. Aborting\n"
        exit 1
      fi

    done

  }

############################
# DXVK - CUSTOM PATCHES

  # Add and apply custom DXVK patches
  function dxvk_custompatches() {

    # Get our current directory, since we will change it during patching process below
    # We want to go back here after having applied the patches
    local CURDIR="${PWD}"

    # Check if the following folder exists, and proceed.
    if [[ -d "${DXVKROOT}/../../dxvk_custom_patches" ]]; then
      cp -r "${DXVKROOT}/../../dxvk_custom_patches/"*.{patch,diff} "${DXVKROOT}/${pkg_name}/" 2>/dev/null

      local dxvk_builddir_name=$(ls -l "${DXVKROOT}/${pkg_name}" | grep ^d | awk '{print $NF}')

      # TODO Expecting just one folder here. This method doesn't work with multiple dirs present
      if [[ $(echo ${dxvk_builddir_name} | wc -l) -gt 1 ]]; then
        echo -e "\e[1mERROR:\e[0m Multiple entries in dxvk build directory detected. Can't decide which one to use. Aborting\n"
        exit 1
      fi

      local dxvk_builddir_path="${DXVKROOT}/${pkg_name}/${dxvk_builddir_name}"

      cd "${dxvk_builddir_path}"
      for pfile in ../*.{patch,diff}; do
        if [[ -f ${pfile} ]]; then
          echo -e "Applying DXVK patch: ${pfile}\n"
          patch -Np1 < ${pfile}
        fi

        if [[ $? -ne 0 ]]; then
          echo -e "\e[1mERROR:\e[0m Error occured while applying DXVK patch '${pfile}'. Aborting\n"
          cd ${CURDIR}
          exit 1
        fi

      done

      cd "${CURDIR}"

    fi

  }

############################
# DXVK - CUSTOM HOOKS EXECUTION

  dxvk_custompatches && \
  dxvk_posixpkgs && \
  dxvk_custom_deb_build
}

########################################################
# COMMON - COMPILE AND INSTALL DEB PACKAGE

# Instructions to compile and install a deb package
# on Debian system

# Global variable to track buildtime dependencies
z=0

function compile_and_install_deb() {

############################

  # Set local variables
  local _pkg_name="${1}"
  local _pkg_license="${2}"
  local _pkg_giturl="${3}"
  local _git_commithash="${4}"
  local _pkg_gitver="${5}"
  local _pkg_debinstall="${6}"
  local _pkg_debcontrol="${7}"
  local _pkg_debrules="${8}"
  local _pkg_installfile="${9}"
  local _pkg_controlfile="${10}"
  local _pkg_rulesfile="${11}"
  local _pkg_deps_build="${12}"
  local _pkg_deps_runtime="${13}"
  local _pkg_debbuilder="${14}"

############################
# COMMON - ARRAY PARAMETER FIX

# Separate array indexes correctly
# We have streamed all array indexes, separated
# by | symbol. We reconstruct the arrays here.

  function arrayparser_reverse() {

    local arrays=(
    '_pkg_deps_build'
    '_pkg_deps_runtime'
    )

    for w in ${arrays[@]}; do
      local s=\${${w}}

      local IFS='|'
      local y=0

      for t in $(eval printf '%s\|' ${s}); do
        eval ${w}[$y]=\"${t}\"
        let y++
      done
      unset IFS

    done
  }

  arrayparser_reverse

############################

  echo -e "Starting compilation$(if [[ ! -v NO_INSTALL ]] || [[ ${_pkg_name} =~ ^meson|glslang$ ]]; then printf " & installation"; fi) of ${_pkg_name}\n"

############################
# COMMON - PACKAGE DEPENDENCIES CHECK

# Check and install package related dependencies if they are missing

  function pkg_dependencies() {

    local _pkg_list="${1}"
    local _pkg_type="${2}"
    local IFS=$'\n'

    case ${_pkg_type} in
      buildtime)
        local _pkg_type_str="build time"
        ;;
      runtime)
        local _pkg_type_str="runtime"
        ;;
    esac

    if [[ ${_pkg_list[0]} == "empty" ]]; then
      return 0
    fi

    # Generate a list of missing dependencies
    local a=0
    for p in ${_pkg_list[@]}; do
      local p=$(printf '%s' ${p} | awk '{print $1}')
      if [[ $(echo $(dpkg -s ${p} &>/dev/null)$?) -ne 0 ]]; then
        local _validlist[$a]=${p}
        let a++

        # Global array to track installed build dependencies
        if [[ ${_pkg_type} == "buildtime" ]]; then
          _buildpkglist[$z]=${p}
          let z++
        fi

      fi
    done

    # Install missing dependencies, be informative
    local b=0
    for _pkg_dep in ${_validlist[@]}; do
      echo -e "$(( $b + 1 ))/$(( ${#_validlist[*]} )) - Installing ${_pkg_name} ${_pkg_type_str} dependency ${_pkg_dep}"
      sudo apt install -y ${_pkg_dep} &> /dev/null
      if [[ $? -eq 0 ]]; then
        let b++
      else
        echo -e "\n\e[1mERROR:\e[0m Error occured while installing ${_pkg_dep}. Aborting.\n"
        exit 1
      fi
    done
    if [[ -n ${_validlist[*]} ]]; then
      # Add empty newline
      echo ""
    fi
  }

############################
# COMMON - RETRIEVE PACKAGE
# GIT VERSION TAG

# Get git-based version in order to rename the package main folder
# This is required by deb builder. It retrieves the version number
# from that folder name

  function pkg_gitversion() {

    if [[ -n "${_pkg_gitver}" ]] && [[ "${_pkg_gitver}" =~ ^git ]]; then
      cd ${_pkg_name}
      git reset --hard ${_git_commithash}
      if [[ $? -ne 0 ]]; then
        echo -e "\e[1mERROR:\e[0m Couldn't find commit ${_git_commithash} for ${_pkg_name}. Aborting\n"
        exit 1
      fi
      _pkg_gitver=$(eval "${_pkg_gitver}")
      cd ..
    fi

  }

############################
# COMMON - OVERWRITE
# DEBIAN BUILD ENV FILES

# Overwrite a file which is given as user input
# The contents are supplied as input, too.

  function pkg_override_debianfile() {

    local contents=${1}
    local targetfile=${2}

    if [[ ${contents} != "empty" ]]; then
      echo "${contents}" > "${targetfile}"
      if [[ $? -ne 0 ]]; then
        echo -e "\e[1mERROR:\e[0m Couldn't create Debian file '${targetfile}' for ${_pkg_name}. Aborting\n"
        exit 1
      fi
    fi
  }

############################
# COMMON - GET SOURCE AND
# PREPARE SOURCE FOLDER

  function pkg_folderprepare() {

    # Remove old build directory, if present
    rm -rf ${_pkg_name}

    # Create a  new build directory, access it and download git sources there
    mkdir ${_pkg_name}
    cd ${_pkg_name}
    echo -e "Retrieving source code of ${_pkg_name} from $(printf ${_pkg_giturl} | sed 's/^.*\/\///; s/\/.*//')\n"
    git clone ${_pkg_giturl} ${_pkg_name}

    # If sources could be downloaded, rename the folder properly for deb builder
    # Access the folder after which package specific debianbuild function will be run
    # That function is defined inside package specific install_main function below
    if [[ $? -eq 0 ]]; then
      pkg_gitversion && \
      mv ${_pkg_name} ${_pkg_name}-${_pkg_gitver}
      cd ${_pkg_name}-${_pkg_gitver}

      dh_make --createorig -s -y -c ${_pkg_license} && \
      pkg_override_debianfile "${_pkg_debinstall}" "${_pkg_installfile}"
      pkg_override_debianfile "${_pkg_debcontrol}" "${_pkg_controlfile}"
      pkg_override_debianfile "${_pkg_debrules}" "${_pkg_rulesfile}"

    else
      echo -e "\e[1mERROR:\e[0m Error while downloading source of ${_pkg_name} package. Aborting\n"
      exit 1
    fi

  }

############################
# COMMON - COMPILE, INSTALL
# AND STORE DEB PACKAGE

  function pkg_debianbuild() {

    # Start deb builder
    bash -c "${_pkg_debbuilder}"

    # Once our deb package is compiled, install and store it
    # We do not make installation optional because this is a core dependency for DXVK
    if [[ $? -eq 0 ]]; then
      rm -rf ../*.{changes,buildinfo,tar.xz} && \
      sudo dpkg -i ../${_pkg_name}*.deb && \
      mv ../${_pkg_name}*.deb ../../../compiled_deb/"${datedir}" && \
      echo -e "Compiled ${_pkg_name} is stored at '$(readlink -f ../../../compiled_deb/"${datedir}")/'\n"
      cd ../..
      rm -rf ${_pkg_name}
    else
      buildpkg_removal
      exit 1
    fi

  }

############################
# COMMON - EXECUTION HOOKS

  pkg_dependencies "${_pkg_deps_build[*]}" buildtime && \

  if [[ ${_pkg_deps_runtime[0]} != "empty" ]] && [[ ! -v NO_INSTALL ]]; then
    pkg_dependencies "${_pkg_deps_runtime[*]}" runtime
  fi

  pkg_folderprepare

  # TODO use package name or separate override switch here?
  if [[ ${_pkg_name} == *"dxvk"* ]]; then
    dxvk_install_custom
  fi  
  pkg_debianbuild

  unset _pkg_gitver

}

########################################################

# BUILD DEPENDENCIES REMOVAL

function buildpkg_removal() {

  # Build time dependencies which were installed but no longer needed
  if [[ -v _buildpkglist ]]; then
    if [[ -v BUILDPKG_RM ]]; then
      sudo apt purge --remove -y ${_buildpkglist[*]}

      # In some cases, glslang or meson may still be present on the system. Remove them
      for _extrapkg in glslang meson; do
        if [[ $(echo $(dpkg -s ${_extrapkg} &>/dev/null)$?) -eq 0 ]]; then
          sudo apt purge --remove -y ${_extrapkg}
        fi
      done

    else
      echo -e "The following build time dependencies were installed and no longer needed:\n\n$(for l in ${_buildpkglist[*]}; do echo -e ${l}; done)\n"
    fi
  fi
}

########################################################

# Package installation instructions

function pkg_install_main() {

  # Read necessary variables from debdata file
  local pkg_datafile=${1}

  if [[ -f ${pkg_datafile} ]]; then
    source ${pkg_datafile}
  else
    echo -e "\e[1mERROR:\e[0m Couldn't read datafile '${pkg_datafile}'. Check the file path and try again.\n"
    exit 1
  fi

############################

  # Prepare these arrays for 'compile_and_install_deb' input
  # Separate each array index with | in these arrays
  function pkg_arrayparser() {

    local pkg_arrays=(
    'pkg_deps_build'
    'pkg_deps_runtime'
    )

    local IFS=$'\n'

    for w in ${pkg_arrays[@]}; do

      local s=\${${w}[@]}
      local t=$(eval printf '%s\|' ${s})
      unset ${w}
      eval ${w}=\"${t}\"

    done
  }

############################

  # Execute package installation procedure
  pkg_arrayparser && \
  compile_and_install_deb \
  "${pkg_name}" \
  "${pkg_license}" \
  "${pkg_giturl}" \
  "${git_commithash}" \
  "${pkg_gitver}" \
  "${pkg_debinstall}" \
  "${pkg_debcontrol}" \
  "${pkg_debrules}" \
  "${pkg_installfile}" \
  "${pkg_controlfile}" \
  "${pkg_rulesfile}" \
  "${pkg_deps_build}" \
  "${pkg_deps_runtime}" \
  "${pkg_debbuilder}"

}

########################################################

# Check existence of known Wine packages
runtimeCheck Wine "${known_wines[*]}"

# Check existence of known Winetricks packages
runtimeCheck Winetricks "${known_winetricks[*]}"

# Meson - compile (& install)
pkgcompilecheck pkg_install_main meson "${DXVKROOT}/meson.debdata"

# Glslang - compile (& install)
pkgcompilecheck pkg_install_main glslang "${DXVKROOT}/glslang.debdata"

# DXVK - compile (& install)
pkg_install_main "${DXVKROOT}/dxvk.debdata"

# Clean buildtime dependencies
buildpkg_removal
