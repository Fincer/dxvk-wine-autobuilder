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

###########################################################

# DO NOT RUN INDIVIDUALLY, ONLY VIA ../../updatewine.sh PARENT SCRIPT!

########################################################

# Root directory of this script file
DXVKROOT="${PWD}"

# datedir variable supplied by ../updatewine_debian.sh script file
datedir="${1}"

###########################################################

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
    --no-install)
      NO_INSTALL=
      ;;
    --updateoverride)
      updateoverride=
      ;;
  esac

done

###########################################################

# Some version of Wine must be found in the system
# Warn the user

function wineCheck() {
  if [[ ! $(which wine 2>/dev/null) ]]; then
    echo -e "Warning: You must have Wine installed before DXVK can be compiled.\n"
  fi
}

wineCheck

###########################################################

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

##################################

# Update all packages if updateoverride given

if [[ -v updateoverride ]]; then
  echo -en "Updating all packages" && \
  if [[ $(printf $(sudo -n uptime &>/dev/null)$?) -ne 0 ]]; then printf " Please provide your sudo password.\n"; else printf "\n\n"; fi
  sudo apt update && sudo apt upgrade -y
fi

##################################

# Check do we need to compile the package
# given as input for this function

function pkgcompilecheck() {

  local pkg=${1}
  local install_function=${2}

  if [[ $(echo $(dpkg -s ${coredep} &>/dev/null)$?) -ne 0 ]] || [[ -v updateoverride ]]; then
    ${install_function}
  fi

}

###################################################

function preparepackage() {

  echo -e "Starting compilation (& installation) of ${1}\n"

  # Set local variables
  local _pkgname=${1}
  local _pkgdeps=${2}
  local _pkgurl=${3}
  local _pkgver=${4}

  # Optional variable for runtime dependencies array
  if [[ -n ${5} ]]; then local _pkgdeps_runtime=${5}; fi

  # Check and install package related dependencies if they are missing
  function pkgdependencies() {

    # Generate a list of missing dependencies
    local a=0
    for p in ${@}; do
      if [[ $(echo $(dpkg -s ${p} &>/dev/null)$?) -ne 0 ]]; then
        local list[$a]=${p}
        let a++
      fi
    done

    # Install missing dependencies, be informative
    local b=0
    for pkgdep in ${list[@]}; do
      echo -e "$(( $b + 1 ))/$(( ${#list[*]} )) - Installing ${_pkgname} dependency ${pkgdep}"
      sudo apt install -y ${pkgdep} &> /dev/null
      if [[ $? -eq 0 ]]; then
        let b++
      else
        echo -e "\nError occured while installing ${pkgdep}. Aborting.\n"
        exit 1
      fi
    done
  }

  # Get git-based version in order to rename the package main folder
  # This is required by deb builder. It retrieves the version number
  # from that folder name
  function pkgversion() {

    if [[ -n "${_pkgver}" ]] && [[ "${_pkgver}" =~ ^git ]]; then
      cd ${_pkgname}
      _pkgver=$(eval "${_pkgver}")
      cd ..
    fi

  }

  function pkgfoldername() {

    # Remove old build directory, if present
    rm -rf ${_pkgname}

    # Create a  new build directory, access it and download git sources there
    mkdir ${_pkgname}
    cd ${_pkgname}
    echo -e "Retrieving source code of ${_pkgname} from $(printf ${_pkgurl} | sed 's/^.*\/\///; s/\/.*//')\n"
    git clone ${_pkgurl} ${_pkgname}

    # If sources could be downloaded, rename the folder properly for deb builder
    # Access the folder after which package specific debianbuild function will be run
    # That function is defined inside package specific install_main function below
    if [[ $? -eq 0 ]]; then
      pkgversion && \
      mv ${_pkgname} ${_pkgname}-${_pkgver}
      cd ${_pkgname}-${_pkgver}
    else
      echo -e "Error while downloading source of ${_pkgname} package. Aborting\n"
      exit 1
    fi

  }

  # Execute above functions
  pkgdependencies ${_pkgdeps[*]} && \
  if [[ -v _pkgdeps_runtime ]]; then pkgdependencies ${_pkgdeps_runtime[*]}; fi
  pkgfoldername

  unset _pkgver

}

###################################################

# MESON COMPILATION & INSTALLATION
# Required by DXVK package

function meson_install_main() {

  # Package name
  local pkgname="meson"

  # Build time dependencies
  local pkgdeps_build=(
  'python3'
  'dh-python'
  'python3-setuptools'
  'ninja-build'
  )

  # Git source location
  local pkgurl="https://github.com/mesonbuild/meson"

  # Parsed version number from git source files
  local pkgver_git="git describe --long | sed 's/\-[a-z].*//; s/\-/\./; s/[a-z]//g'"

  # Location of Debian compilation instructions archive
  local pkgurl_debian="http://archive.ubuntu.com/ubuntu/pool/universe/m/meson/meson_0.45.1-2.debian.tar.xz"

  function meson_debianbuild() {

    # Download predefined Meson debian rules archive
    # Extract it, and finally delete the archive
    wget ${pkgurl_debian} -O debian.tar.xz
    tar xf debian.tar.xz && rm debian.tar.xz

    # Get sed compatible Meson version string
    local meson_version=$(printf '%s' $(pwd | sed -e 's/.*\-//' -e 's/\./\\\./g'))

    # Do not perform any tests or checks during compilation process
    sed -ir '/nocheck/d' debian/control
    sed -ir '/\.\/run_tests\.py/d' debian/rules

    # Downgrade debhelper version requirement for Debian compatilibity
    sed -ir 's/debhelper (>= 11)/debhelper (>= 10)/' debian/control

    # Correct & update package version number + debian rules
    sed -ir "s/0\.45\.1-2/${meson_version}/" debian/changelog

    # Delete the following strings from debian/rules file
    # They are deprecated
    sed -ir '/rm \$\$(pwd)\/debian\/meson\/usr\/bin\/mesontest/d' debian/rules
    sed -ir '/rm \$\$(pwd)\/debian\/meson\/usr\/bin\/mesonconf/d' debian/rules
    sed -ir '/rm \$\$(pwd)\/debian\/meson\/usr\/bin\/mesonintrospect/d' debian/rules
    sed -ir '/rm \$\$(pwd)\/debian\/meson\/usr\/bin\/wraptool/d' debian/rules
    sed -ir '/rm \-rf \$\$(pwd)\/debian\/meson\/usr\/lib\/python3/d' debian/rules

    # Remove deprecated, downloaded patch files
    rm -r debian/patches

    # Remove irrelevant sample files
    rm -r debian/*.{ex,EX}

    # Start deb builder. Do not build either debug symbols or doc files
    DEB_BUILD_OPTIONS="strip nodocs noddebs nocheck" dpkg-buildpackage -rfakeroot -b -us -uc

    # Once compiled, install and store the compiled deb archive
    # We do not make installation optional because this is a core dependency for DXVK
    if [[ $? -eq 0 ]]; then
      rm -rf ../*.{changes,buildinfo,tar.xz} && \
      sudo dpkg -i ../${pkgname}*.deb && \
      mv ../${pkgname}*.deb ../../../compiled_deb/"${datedir}" && \
      echo -e "Compiled ${pkgname} is stored at '$(readlink -f ../../../compiled_deb/"${datedir}")/'\n"
      cd ../..
      rm -rf ${pkgname}
    else
      exit 1
    fi

  }

  # Execute above functions
  preparepackage "${pkgname}" "${pkgdeps_build[*]}" "${pkgurl}" "${pkgver_git}" && \
  meson_debianbuild

}

###################################################

# GLSLANG COMPILATION & INSTALLATION
# Required by DXVK package

function glslang_install_main() {

  # Package name
  local pkgname="glslang"

  # Build time dependencies
  local pkgdeps_build=('cmake' 'python2.7')

  # Git source location
  local pkgurl="https://github.com/KhronosGroup/glslang"

  # Parsed version number from git source files
  local pkgver_git="git describe --long | sed 's/\-[a-z].*//; s/\-/\./; s/[a-z]//g'"

  function glslang_debianbuild() {

    # Create debian subdirectory
    dh_make --createorig -s -y -c bsd

    # Set Build dependencies into debian/control file
    sed -ie "s/^Build-Depends:.*$/Build-Depends: debhelper (>=10), $(echo ${_coredeps[*]} | \
    sed 's/\s/, /g'), $(echo ${pkgdeps_build[*]} | sed 's/\s/, /g')/g" debian/control

    # Skip running override_dh_usrlocal while executing deb builder
    printf 'override_dh_usrlocal:' | tee -a debian/rules

    # Remove irrelevant sample files
    rm -r debian/*.{ex,EX}

    # Start deb builder. Do not build either debug symbols or doc files
    DEB_BUILD_OPTIONS="strip nodocs noddebs" dpkg-buildpackage -rfakeroot -b -us -uc

    # Once compiled, install and store the compiled deb archive
    # We do not make installation optional because this is a core dependency for DXVK
    if [[ $? -eq 0 ]]; then
      rm -rf ../*.{changes,buildinfo,tar.xz} && \
      sudo dpkg -i ../${pkgname}*.deb && \
      mv ../${pkgname}*.deb ../../../compiled_deb/"${datedir}" && \
      echo -e "Compiled ${pkgname} is stored at '$(readlink -f ../../../compiled_deb/"${datedir}")/'\n"
      cd ../..
      rm -rf ${pkgname}
    else
      exit 1
    fi

  }

  # Execute above functions
  preparepackage "${pkgname}" "${pkgdeps_build[*]}" "${pkgurl}" "${pkgver_git}" && \
  glslang_debianbuild

}

###################################################

# DXVK COMPILATION & INSTALLATION

function dxvk_install_main() {

  # Package name
  local pkgname="dxvk-git"

  # Build time dependencies
  local pkgdeps_build=(
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
  local pkgdeps_runtime=('wine' 'winetricks')

  # Git source location
  local pkgurl="https://github.com/doitsujin/dxvk"

  # Parsed version number from git source files
  local pkgver_git="git describe --long | sed 's/\-[a-z].*//; s/\-/\./; s/[a-z]//g'"

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
        echo -e "Error occured while running 'update-alternatives' for '${package}'. Aborting\n"
        exit 1
      fi

    done

  }

  function dxvk_custompatches() {

    # Get our current directory, since we will change it during patching process below
    # We want to go back here after having applied the patches
    local CURDIR=${PWD}

    # Check if the following folder exists, and proceed.
    if [[ -d ${DXVKROOT}/../../dxvk_custom_patches ]]; then
      cp -r ${DXVKROOT}/../../dxvk_custom_patches/*.{patch,diff} ${DXVKROOT}/${pkgname}/

      local dxvk_builddir=$(ls ${DXVKROOT}/${pkgname}/)

      # Expecting just one folder here. This method doesn't work with multiple dirs present
      if [[ $(echo ${dxvk_builddir} | wc -l) -gt 1 ]]; then
        echo "Error: Multiple dxvk build directories detected. Can't decide which one to use. Aborting\n"
        exit 1
      fi

      local dxvk_buildpath=$(readlink -f ${dxvk_builddir})

      cd ${dxvk_buildpath}
      for pfile in ../*.{patch,diff}; do
        if [[ -f ${pfile} ]]; then
          echo -e "Applying DXVK patch: ${pfile}\n"
          patch -Np1 < ${pfile}
        fi

        if [[ $? -ne 0 ]]; then
          echo -e "Error occured while applying DXVK patch '${pfile}'. Aborting\n"
          cd ${CURDIR}
          exit 1
        fi

      done

      cd ${CURDIR}

    fi

  }

  # Debian-specific compilation & installation rules
  function dxvk_debianbuild() {

    local dxvx_relative_builddir="debian/source/dxvk-master"

    # Create debian subdirectory, add supplied LICENSE file
    dh_make --createorig -s -y -c custom --copyrightfile ../LICENSE

    # Set Build dependencies into debian/control file
    sed -ie "s/^Build-Depends:.*$/Build-Depends: debhelper (>=10), $(echo ${_coredeps[*]} | \
    sed 's/\s/, /g'), $(echo ${pkgdeps_build[*]} | sed 's/\s/, /g')/g" debian/control

    # Set Runtime dependencies into debian/control file
    sed -ie "s/^Depends:.*$/Depends: $(echo ${pkgdeps_runtime} | sed 's/\s/, /g')/g" debian/control

    # Tell deb builder to bundle these files
    printf "${dxvx_relative_builddir}/setup_dxvk.verb usr/share/dxvk/" > debian/install
    printf "\n${dxvx_relative_builddir}/bin/* usr/bin/" >> debian/install

    # Remove irrelevant sample files
    rm -r debian/*.{ex,EX}

# Overwrite debian/rules file with the following contents
cat << 'DXVK-DEBIANRULES' > debian/rules
#!/usr/bin/make -f
%:
	dh $@

override_dh_auto_configure:

override_dh_usrlocal:
DXVK-DEBIANRULES

    # Start DXVK compilation
    bash ./package-release.sh master debian/source/ --no-package

    if [[ $? -ne 0 ]]; then
      echo "Error while compiling ${pkgname}. Check messages above. Aborting\n"
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
      mv ../${pkgname}*.deb ../../../compiled_deb/"${datedir}" && \
      echo -e "Compiled ${pkgname} is stored at '$(readlink -f ../../../compiled_deb/"${datedir}")/'\n"
      cd ../..
      rm -rf ${pkgname}
    else
      exit 1
    fi
  }

  # Execute above functions
  # Do not check runtime dependencies as our check method expects exact package name in
  # function 'preparepackage'. This does not apply to runtime dependency 'wine', which
  # may be 'wine', 'wine-git', 'wine-staging-git' etc. in truth
  #
  preparepackage "${pkgname}" "${pkgdeps_build[*]}" "${pkgurl}" "${pkgver_git}" && \
  dxvk_posixpkgs && \
  dxvk_custompatches && \
  dxvk_debianbuild

}

####################################################################

pkgcompilecheck meson meson_install_main
pkgcompilecheck glslang glslang_install_main
dxvk_install_main
