#!/bin/env bash

#    Winetricks package builder for Debian
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

########################################################

# Just a title & author for this script, used in initialization

SCRIPT_TITLE="\e[1mWinetricks package builder & installer\e[0m"
SCRIPT_AUTHOR="Pekka Helenius (~Fincer), 2018"

########################################################

pkgname="winetricks"
pkgsrc="https://github.com/Winetricks/winetricks"
pkgurl="https://winetricks.org"

# TODO Do not require wine as a hard dependency since
# it may break things. Wine is practically required, though.
#
pkgdeps_runtime=('cabextract' 'unzip' 'x11-utils') # 'wine'

########################################################

WORKDIR="${PWD}"

###########################

# DO NOT CHANGE THIS if you intend to use this shell
# script as a part updatewine.sh shell script!

BUILD_MAINDIR="${WORKDIR}/debian/winetricks-git"

########################################################

echo -e "\n${SCRIPT_TITLE}\n"

########################################################

# If the script is interrupted (Ctrl+C/SIGINT), do the following

function Winetricks_intCleanup() {
  rm -rf ${BUILD_MAINDIR}
  exit 0
}

# Allow interruption of the script at any time (Ctrl + C)
trap "Winetricks_intCleanup" INT

###########################################################

COMMANDS=(
  apt
  dpkg
  git
  grep
  sudo
  wc
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

########################################################

function runtimeCheck() {

  # Runtime package names to check on Debian
  local known_pkgs=${1}

##########################

  # This array applies only if wine is defined
  # as a runtime dependency for Winetricks
  #
  # 'dpkg -s' check is quite primitive,
  # do this additional check for Wine
  local known_wines=(
  'wine'
  'wine-stable'
  'wine32'
  'wine64'
  'libwine:amd64'
  'libwine:i386'
  'wine-git'
  'wine-staging-git'
  )

##########################

  # Check if these packages are present on the system
  i=0
  for pkg in ${known_pkgs[@]}; do
    if [[ $(echo $(dpkg -s ${pkg} &>/dev/null)$?) -ne 0 ]]; then
      local pkglist[$i]=${pkg}
      let i++
    fi
  done

  # This loop applies only if wine is defined
  # as a runtime dependency for Winetricks
  #
  # If known wine is found, drop 'wine' from pkglist array
  for winepkg in ${known_wines[@]}; do
    if [[ $(echo $(dpkg -s ${winepkg} &>/dev/null)$?) -eq 0 ]]; then
      pkglist=( "${pkglist[@]/wine}" )
    fi
  done

  if [[ -n ${pkglist[*]} ]]; then
    echo -e "\e[1mWARNING:\e[0m Not installing Winetricks because the following runtime dependencies are missing:\n\n$(for l in ${pkglist[*]}; do echo ${l}; done)\n\n\
These should be installed in order to use Winetricks. Just compiling Winetricks for later use.\n"

    # Force --no-install switch
    NO_INSTALL=
  fi

}

########################################################

function winetricks_prepare() {

  # Define package folder path and create it
  # Clone package source from 'pkgurl'
  pkgdir="${BUILD_MAINDIR}/${pkgname}"
  mkdir -p ${pkgdir} && \
  git clone ${pkgsrc} "${pkgdir}"

  if [[ $? -ne 0 ]]; then
    echo -e "Error while downloading source of ${pkgname} package. Aborting\n"
    exit 1
  fi

  # Parse package version field
  function pkgver() {
    cd "${pkgdir}"
    git describe --long | sed 's/\-[^0-9].*//; s/\-/\./g'
    if [[ $? -ne 0 ]]; then
      echo -e "Error while parsing ${pkgname} version field. Aborting\n"
      exit 1
    fi
  }

  # Define package version field variable 'pkgver'
  pkgver=$(pkgver)

  # Rename the source folder to meet the standards of Debian builder
  cd "${BUILD_MAINDIR}" && \
  mv "${pkgname}" "${pkgname}-${pkgver}"

  # Source folder which is used now, just added version string suffix
  pkgdir="${BUILD_MAINDIR}/${pkgname}-${pkgver}"

}

########################################################

function coredeps_check() {

  # Universal core build time dependencies for package compilation
  _coredeps=('dh-make' 'make' 'gcc' 'build-essential' 'fakeroot')

  local i=0
  for coredep in ${_coredeps[@]}; do

    if [[ $(echo $(dpkg -s ${coredep} &>/dev/null)$?) -ne 0 ]]; then
      echo -e "Installing core dependency ${coredep}.\n"
      buildpkglist[$i]=${coredep}
      sudo apt install -y ${coredep}
      if [[ $? -ne 0 ]]; then
        echo -e "Could not install ${coredep}. Aborting.\n"
        exit 1
      fi
      let i++
    fi
  done

}

########################################################

function feed_debiancontrol() {

cat << CONTROLFILE > "${pkgdir}/debian/control"
Source: ${pkgname}
Section: unknown
Priority: optional
Maintainer: ${USER} <${USER}@unknown>
Build-Depends: debhelper (>= 9)
Standards-Version: 3.9.8
Homepage: ${pkgurl}

Package: ${pkgname}
Architecture: all
Depends: $(echo "${pkgdeps_runtime[*]}" | sed 's/\s/, /g')
Suggests: wine
Description: Script to install various redistributable runtime libraries in Wine.

CONTROLFILE

}

########################################################

function winetricks_debianbuild() {

  cd "${pkgdir}"

  # Delete existing debian folder
  rm -rf debian

  # Create debian subdirectory
  dh_make --createorig -s -y -c lgpl

  # Update debian/control file
  feed_debiancontrol

  # Skip tests while executing deb builder
  printf 'override_dh_auto_test:' | tee -a debian/rules

  # Remove irrelevant sample files
  rm -rf debian/*.{ex,EX}

  # Start deb builder. Do not build either debug symbols or doc files
  DEB_BUILD_OPTIONS="strip nodocs noddebs" dpkg-buildpackage -rfakeroot -b -us -uc

  if [[ $? -ne 0 ]]; then
    echo -e "Error while compiling ${pkgname}. Check messages above. Aborting\n"
    exit 1
  fi

  # Once compiled, possibly install and store the compiled deb archive
  if [[ $? -eq 0 ]]; then

    if [[ ! -v NO_INSTALL ]]; then
      sudo dpkg -i ../${pkgname}*.deb
    fi

    mv ../${pkgname}*.deb "${WORKDIR}"/ && \
    cd "${WORKDIR}"
    rm -rf "${BUILD_MAINDIR}"
  else
    exit 1
  fi

}

########################################################

runtimeCheck "${pkgdeps_runtime[*]}"

winetricks_prepare

# If we run this script via debian/updatewine_debian.sh, this check is already done there
coredeps_check

winetricks_debianbuild

########################################################

# Build time dependencies which were installed but no longer needed
if [[ -v buildpkglist ]]; then
  echo -e "The following build time dependencies were installed and no longer needed:\n\n$(for l in ${buildpkglist[*]}; do echo ${l}; done)\n"
fi
