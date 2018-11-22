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

# Check existence of known Wine packages
runtimeCheck Wine "${known_wines[*]}"

# Check existence of known Winetricks packages
runtimeCheck Winetricks "${known_winetricks[*]}"

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

  local pkg=${1}
  local install_function=${2}

  if [[ $(echo $(dpkg -s ${pkg} &>/dev/null)$?) -ne 0 ]] || [[ -v UPDATE_OVERRIDE ]]; then
    ${install_function}
  fi

}

########################################################

# Global variable to track buildtime dependencies
z=0

function preparepackage() {

############################

  # Set local variables
  local _pkg_name=${1}
  local _pkg_license=${2}
  local _pkg_maintainer=${3}
  local _pkg_section=${4}
  local _pkg_priority=${5}
  local _pkg_arch=${6}
  local _pkg_commondesc=${7}
  local _pkg_longdesc=${8}
  local _pkg_giturl=${9}
  local _pkg_homeurl=${10}
  local _git_commithash=${11}
  local _pkg_gitver=${12}
  local _pkg_controlfile=${13}
  local _pkg_rulesfile=${14}
  local _pkg_rules_override=${15}
  local _pkg_suggests=${16}
  local _pkg_overrides=${17}
  local _pkg_deps_build=${18}
  local _pkg_deps_runtime=${19}
  local _pkg_extra_1=${20}
  local _pkg_extra_2=${21}
  local _pkg_debbuilder=${22}

############################

  # Separate array indexes correctly
  # We have streamed all array indexes, separated
  # by | symbol. We reconstruct the arrays here.
  function arrayparser_reverse() {

    local arrays=(
    '_pkg_suggests'
    '_pkg_overrides'
    '_pkg_deps_build'
    '_pkg_deps_runtime'
    '_pkg_extra_1'
    '_pkg_extra_2'
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

# TODO HANDLE EMPTY LINES CORRECTLY

  function pkg_feed_debiancontrol() {

    # For correct array index handling
    local IFS=$'\n'

    cat << CONTROLFILE > "${_pkg_controlfile}"
Source: ${_pkg_name}
Section: ${_pkg_section}
Priority: ${_pkg_priority}
Maintainer: ${_pkg_maintainer}
Build-Depends: debhelper (>=9), $(if [[ ${_pkg_deps_build[0]} != "empty" ]]; then \
for w in ${_pkg_deps_build[@]}; do printf '%s, ' ${w}; done; fi)
Standards-Version: 4.1.3
Homepage: ${_pkg_homeurl}
$(if [[ ${_pkg_extra_1[0]} != "empty" ]]; then for w in ${_pkg_extra_1[@]}; do echo ${w}; done ; fi)

Package: ${_pkg_name}
Architecture: ${_pkg_arch}
Depends: \${shlibs:Depends}, \${misc:Depends}, $(if [[ ${_pkg_deps_runtime[0]} != "empty" ]]; then \
for w in ${_pkg_deps_runtime[@]}; do printf '%s, ' ${w}; done; fi)
Description: ${_pkg_commondesc}
$(echo -e ${_pkg_longdesc} | sed 's/^/ /g; s/\n/\n /g')
$(if [[ ${_pkg_extra_2[0]} != "empty" ]]; then for w in ${_pkg_extra_2[@]}; do echo ${w}; done ; fi)
$(if [[ ${_pkg_suggests[0]} != "empty" ]]; then echo "Suggests: $(echo ${_pkg_suggests[*]} | sed 's/\s/, /g')"; fi)
$(if [[ ${_pkg_overrides[0]} != "empty" ]]; then echo "Conflicts: $(echo ${_pkg_overrides[*]} | sed 's/\s/, /g')"; fi)
$(if [[ ${_pkg_overrides[0]} != "empty" ]]; then echo "Breaks: $(echo ${_pkg_overrides[*]} | sed 's/\s/, /g')"; fi)
$(if [[ ${_pkg_overrides[0]} != "empty" ]]; then echo "Replaces: $(echo ${_pkg_overrides[*]} | sed 's/\s/, /g')"; fi)
$(if [[ ${_pkg_overrides[0]} != "empty" ]]; then echo "Provides: $(echo ${_pkg_overrides[*]} | sed 's/\s/, /g')"; fi)
CONTROLFILE

    if [[ ! -f "${_pkg_controlfile}" ]]; then
      echo -e "\e[1mERROR:\e[0m Couldn't create Debian control file for ${_pkg_name}. Aborting\n"
      exit 1
    fi

  }

############################

  function pkg_override_debianrules() {
    if [[ $(echo ${_pkg_rules_override} | wc -w) -ne 0 ]]; then
      echo "${_pkg_rules_override}" > "${_pkg_rulesfile}"
      if [[ $? -ne 0 ]]; then
        echo "\e[1mERROR:\e[0m Couldn't create Debian rules file for ${_pkg_name}. Aborting\n"
        exit 1
      fi
    fi
  }

############################

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
      pkg_feed_debiancontrol
      pkg_override_debianrules

    else
      echo -e "\e[1mERROR:\e[0m Error while downloading source of ${_pkg_name} package. Aborting\n"
      exit 1
    fi

  }

############################

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
      exit 1
    fi

  }

############################

  # Execute above functions
  pkg_dependencies "${_pkg_deps_build[*]}" buildtime && \
  if [[ ${_pkg_deps_runtime[0]} != "empty" ]] && [[ ! -v NO_INSTALL ]]; then pkg_dependencies "${_pkg_deps_runtime[*]}" runtime ; fi
  pkg_folderprepare

  # TODO use package name or separate override switch here?
  if [[ ${_pkg_name} != "dxvk-git" ]]; then
    pkg_debianbuild
  fi

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
########################################################
########################################################

# MESON COMPILATION & INSTALLATION
# Required by DXVK package

function meson_install_main() {

  # Package name
  local pkg_name="meson"
  local pkg_license="apache"
  local pkg_maintainer="${USER} <${USER}@unknown>"
  local pkg_section="devel"
  local pkg_priority="optional"
  local pkg_arch="all"

  local pkg_commondesc="high-productivity build system"
  local pkg_longdesc="
Meson is a build system designed to increase programmer\n\
productivity. It does this by providing a fast, simple and easy to\n\
use interface for modern software development tools and practices.
  "

  local pkg_giturl="https://github.com/mesonbuild/meson"
  local pkg_homeurl="http://mesonbuild.com"

  local git_commithash=${git_commithash_meson}
  local pkg_gitver="git describe --long | sed 's/\-[a-z].*//; s/\-/\./; s/[a-z]//g'"

  local pkg_controlfile="./debian/control"
  local pkg_rulesfile="./debian/rules"

##############
# MESON - Debian rules file override

local pkg_rules_override="\
#!/usr/bin/make -f
# Original script by Jussi Pakkanen

export MESON_PRINT_TEST_OUTPUT=1
export QT_SELECT=qt5
export LC_ALL=C.UTF-8
%:
	dh \$@ --with python3 --buildsystem=pybuild

override_dh_auto_configure:

override_dh_auto_build:

override_dh_auto_test:

override_dh_clean:
	dh_clean
	rm -f *.pyc
	rm -rf __pycache__
	rm -rf mesonbuild/__pycache__
	rm -rf mesonbuild/*/__pycache__
	rm -rf work\ area
	rm -rf install\ dir/*
	rm -f meson-test-run.txt meson-test-run.xml
	rm -rf meson.egg-info
	rm -rf build
	rm -rf .pybuild

override_dh_install:
# Helper script to autogenerate cross files.
	python3 setup.py install --root=\$\$(pwd)/debian/meson --prefix=/usr --install-layout=deb --install-lib=/usr/share/meson --install-scripts=/usr/share/meson
	rm -rf \$\$(pwd)/debian/meson/usr/share/meson/mesonbuild/__pycache__
	rm -rf \$\$(pwd)/debian/meson/usr/share/meson/mesonbuild/*/__pycache__
	rm \$\$(pwd)/debian/meson/usr/bin/meson
	ln -s ../share/meson/meson \$\$(pwd)/debian/meson/usr/bin/meson
"

##############

# MESON

  # Debian control file Suggests section
  local pkg_suggests=(
  empty
  )

  # Debian control file override etc. sections
  local pkg_overrides=(
  empty
  )

  # Build time dependencies
  local pkg_deps_build=(
  'python3 (>= 3.5)'
  'dh-python'
  'python3-setuptools'
  'ninja-build (>= 1.6)'
  )

  # Runtime dependencies
  local pkg_deps_runtime=(
  'ninja-build (>=1.6)'
  'python3'
  )

  # Extra fields for Debian control file Source section
  local pkg_extra_1=(
  'X-Python3-Version: >= 3.5'
  )

  # Extra fields for Debian control file Package section
  local pkg_extra_2=(
  empty
  )

############################

# MESON

  # Deb builder execution field
  # Do not build either debug symbols or doc files
  local pkg_debbuilder="DEB_BUILD_OPTIONS=\"strip nodocs noddebs nocheck\" dpkg-buildpackage -rfakeroot -b -us -uc"

############################

# MESON

  # Prepare these arrays for preparepackage input
  # Separate each array index with | in these arrays
  function arrayparser() {

    local arrays=(
    'pkg_suggests'
    'pkg_overrides'
    'pkg_deps_build'
    'pkg_deps_runtime'
    'pkg_extra_1'
    'pkg_extra_2'
    )

    for w in ${arrays[@]}; do

      local s=\${${w}[@]}
      local t=$(eval printf '%s\|' ${s})
      unset ${w}
      eval ${w}=\"${t}\"

    done
  }

############################

# MESON

  # Execute above functions
  arrayparser && \
  preparepackage \
  "${pkg_name}" \
  "${pkg_license}" \
  "${pkg_maintainer}" \
  "${pkg_section}" \
  "${pkg_priority}" \
  "${pkg_arch}" \
  "${pkg_commondesc}" \
  "${pkg_longdesc}" \
  "${pkg_giturl}" \
  "${pkg_homeurl}" \
  "${git_commithash}" \
  "${pkg_gitver}" \
  "${pkg_controlfile}" \
  "${pkg_rulesfile}" \
  "${pkg_rules_override}" \
  "${pkg_suggests}" \
  "${pkg_overrides}" \
  "${pkg_deps_build}" \
  "${pkg_deps_runtime}" \
  "${pkg_extra_1}" \
  "${pkg_extra_2}" \
  "${pkg_debbuilder}"

}

########################################################

# GLSLANG COMPILATION & INSTALLATION
# Required by DXVK package

function glslang_install_main() {

  # Package name
  local pkg_name="glslang"
  local pkg_license="bsd"
  local pkg_maintainer="${USER} <${USER}@unknown>"
  local pkg_section="devel"
  local pkg_priority="optional"
  local pkg_arch="all"

  local pkg_commondesc="Khronos OpenGL and OpenGL ES shader front end and validator."
  local pkg_longdesc="
Khronos reference front-end for GLSL and ESSL, and sample SPIR-V generator
  "

  local pkg_giturl="https://github.com/KhronosGroup/glslang"
  local pkg_homeurl="https://www.khronos.org/opengles/sdk/tools/Reference-Compiler/"

  local git_commithash=${git_commithash_glslang}
  local pkg_gitver="git describe --long | sed 's/\-[a-z].*//; s/\-/\./; s/[a-z]//g'"

  local pkg_controlfile="./debian/control"
  local pkg_rulesfile="./debian/rules"

##############
# GLSLANG - Debian rules file override

local pkgrules_override="
#!/usr/bin/make -f

%:
	dh $@

override_dh_usrlocal:
"

##############

# GLSLANG

  # Debian control file Suggests section
  local pkg_suggests=(
  empty
  )

  # Debian control file override etc. sections
  local pkg_overrides=(
  empty
  )

  # Build time dependencies
  local pkg_deps_build=(
  #${_coredeps[*]}
  'cmake'
  'python2.7'
  )

  # Runtime dependencies
  local pkg_deps_runtime=(
  empty
  )

  # Extra fields for Debian control file Source section
  local pkg_extra_1=(
  empty
  )

  # Extra fields for Debian control file Package section
  local pkg_extra_2=(
  empty
  )

############################

# GLSLANG

  # Deb builder execution field
  # Do not build either debug symbols
  local pkg_debbuilder="DEB_BUILD_OPTIONS=\"strip nodocs noddebs\" dpkg-buildpackage -rfakeroot -b -us -uc"

############################

# GLSLANG

  # Prepare these arrays for preparepackage input
  # Separate each array index with | in these arrays
  function arrayparser() {

    local arrays=(
    'pkg_suggests'
    'pkg_overrides'
    'pkg_deps_build'
    'pkg_deps_runtime'
    'pkg_extra_1'
    'pkg_extra_2'
    )

    for w in ${arrays[@]}; do

      local s=\${${w}[@]}
      local t=$(eval printf '%s\|' ${s})
      unset ${w}
      eval ${w}=\"${t}\"

    done
  }

############################

# GLSLANG

  # Execute above functions
  arrayparser && \
  preparepackage \
  "${pkg_name}" \
  "${pkg_license}" \
  "${pkg_maintainer}" \
  "${pkg_section}" \
  "${pkg_priority}" \
  "${pkg_arch}" \
  "${pkg_commondesc}" \
  "${pkg_longdesc}" \
  "${pkg_giturl}" \
  "${pkg_homeurl}" \
  "${git_commithash}" \
  "${pkg_gitver}" \
  "${pkg_controlfile}" \
  "${pkg_rulesfile}" \
  "${pkg_rules_override}" \
  "${pkg_suggests}" \
  "${pkg_overrides}" \
  "${pkg_deps_build}" \
  "${pkg_deps_runtime}" \
  "${pkg_extra_1}" \
  "${pkg_extra_2}" \
  "${pkg_debbuilder}"

}

########################################################

# DXVK COMPILATION & INSTALLATION

function dxvk_install_main() {

  # Package name
  local pkg_name="dxvk-git"
  local pkg_license="custom --copyrightfile ../LICENSE"
  local pkg_maintainer="${USER} <${USER}@unknown>"
  local pkg_section="otherosfs"
  local pkg_priority="optional"
  local pkg_arch="all"

  local pkg_commondesc="Vulkan-based D3D11 and D3D10 implementation for Linux / Wine"
  local pkg_longdesc="
A Vulkan-based translation layer for Direct3D 10/11 which
allows running 3D applications on Linux using Wine.
  "

  local pkg_giturl="https://github.com/doitsujin/dxvk"
  local pkg_homeurl="https://github.com/doitsujin/dxvk"

  local git_commithash=${git_commithash_dxvk}
  local pkg_gitver="git describe --long | sed 's/\-[a-z].*//; s/\-/\./; s/[a-z]//g'"

  local pkg_controlfile="./debian/control"
  local pkg_rulesfile="./debian/rules"

##############
# DXVK - Debian rules file override

local pkg_rules_override="\
#!/usr/bin/make -f

%:
	dh \$@

override_dh_auto_configure:

override_dh_usrlocal:
"

##############

# DXVK

  # Debian control file Suggests section
  local pkg_suggests=(
  empty
  )

  # Debian control file override etc. sections
  local pkg_overrides=(
  empty
  )

  # Build time dependencies
  local pkg_deps_build=(
  #${_coredeps[*]}
  'meson'
  'glslang'
  'gcc-mingw-w64-x86-64'
  'gcc-mingw-w64-i686'
  'g++-mingw-w64-x86-64'
  'g++-mingw-w64-i686'
  'mingw-w64-x86-64-dev'
  'mingw-w64-i686-dev'
  )

  # Runtime dependencies
  local pkg_deps_runtime=(
  'wine'
  'winetricks'
  )

  # Extra fields for Debian control file Source section
  local pkg_extra_1=(
  empty
  )

  # Extra fields for Debian control file Package section
  local pkg_extra_2=(
  empty
  )

############################

# DXVK

  # Prepare these arrays for preparepackage input
  # Separate each array index with | in these arrays
  function arrayparser() {

    local arrays=(
    'pkg_suggests'
    'pkg_overrides'
    'pkg_deps_build'
    'pkg_deps_runtime'
    'pkg_extra_1'
    'pkg_extra_2'
    )

    for w in ${arrays[@]}; do

      local s=\${${w}[@]}
      local t=$(eval printf '%s\|' ${s})
      unset ${w}
      eval ${w}=\"${t}\"

    done
  }

############################

# DXVK

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

# DXVK

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
        echo "\e[1mERROR:\e[0m Multiple entries in dxvk build directory detected. Can't decide which one to use. Aborting\n"
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

# DXVK

  # Debian-specific compilation & installation rules for DXVK
  function dxvk_custom_deb_build() {

    local dxvx_relative_builddir="debian/source/dxvk-master"

    # Tell deb builder to bundle these files
    printf "${dxvx_relative_builddir}/setup_dxvk.verb usr/share/dxvk/" > debian/install
    printf "\n${dxvx_relative_builddir}/bin/* usr/bin/" >> debian/install

    # Start DXVK compilation
    bash ./package-release.sh master debian/source/ --no-package

    if [[ $? -ne 0 ]]; then
      echo -e "\e[1mERROR:\e[0m Error while compiling ${pkg_name}. Check messages above. Aborting\n"
      buildpkg_removal
      exit 1
    fi

    # Make a proper executable script for setup_dxvk.verb file
    mkdir -p ${dxvx_relative_builddir}/bin

    echo -e "#!/bin/sh\nwinetricks --force /usr/share/dxvk/setup_dxvk.verb" \
    > "${dxvx_relative_builddir}/bin/setup_dxvk"
    chmod +x "${dxvx_relative_builddir}/bin/setup_dxvk"

    # Tell deb builder to install DXVK x32 & x64 subfolders
    for arch in 64 32; do
      mkdir -p ${dxvx_relative_builddir}/x${arch}
      printf "\n${dxvx_relative_builddir}/x${arch}/* usr/share/dxvk/x${arch}/" >> debian/install
    done

    # Start deb builder. Do not build either debug symbols or doc files
    DEB_BUILD_OPTIONS="strip nodocs noddebs" dpkg-buildpackage -us -uc -b --source-option=--include-binaries

    # Once compiled, possibly install and store the compiled deb archive
    if [[ $? -eq 0 ]]; then

      if [[ ! -v NO_INSTALL ]]; then
        sudo dpkg -i ../${pkgname}*.deb
      fi

      rm -rf ../*.{changes,buildinfo,tar.xz}
      mv ../${pkg_name}*.deb ../../../compiled_deb/"${datedir}" && \
      echo -e "Compiled ${pkg_name} is stored at '$(readlink -f ../../../compiled_deb/"${datedir}")/'\n"
      cd ../..
      rm -rf ${pkg_name}
    else
      exit 1
    fi
  }

############################

# DXVK

  # Execute above functions
  # Do not check runtime dependencies as our check method expects exact package name in
  # function 'preparepackage'. This does not apply to runtime dependency 'wine', which
  # may be 'wine', 'wine-git', 'wine-staging-git' etc. in truth
  #
  arrayparser && \
  preparepackage \
  "${pkg_name}" \
  "${pkg_license}" \
  "${pkg_maintainer}" \
  "${pkg_section}" \
  "${pkg_priority}" \
  "${pkg_arch}" \
  "${pkg_commondesc}" \
  "${pkg_longdesc}" \
  "${pkg_giturl}" \
  "${pkg_homeurl}" \
  "${git_commithash}" \
  "${pkg_gitver}" \
  "${pkg_controlfile}" \
  "${pkg_rulesfile}" \
  "${pkg_rules_override}" \
  "${pkg_suggests[*]}" \
  "${pkg_overrides[*]}" \
  "${pkg_deps_build[*]}" \
  "${pkg_deps_runtime[*]}" \
  "${pkg_extra_1[*]}" \
  "${pkg_extra_2[*]}" \
  "${pkg_debbuilder}" && \
  \
  dxvk_custompatches && \
  dxvk_posixpkgs && \
  dxvk_custom_deb_build

}

########################################################

pkgcompilecheck meson meson_install_main
pkgcompilecheck glslang glslang_install_main
dxvk_install_main

buildpkg_removal
