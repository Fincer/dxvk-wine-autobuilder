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

# Universal core dependencies
_coredeps=('dh-make' 'make' 'gcc' 'build-essential' 'fakeroot')

##################################

function customReqs() {

  if [[ -v updateoverride ]]; then
    echo -en "Updating package databases." && \
    if [[ $(printf $(sudo -n uptime &>/dev/null)$?) -ne 0 ]]; then printf " Please provide your sudo password.\n"; else printf "\n\n"; fi
    sudo apt update
  fi

  for cmd in git tar wget; do
    if [[ $(printf $(which ${cmd} &> /dev/null)$?) -ne 0 ]]; then
      echo -e "Missing ${cmd}. Installing...\n"
      sudo apt update && sudo apt install -y ${cmd}
    fi
  done

  for coredep in ${_coredeps[@]}; do

    local coredep=$(printf ${coredep} | sed 's/\+/\\\+/g')

    if [[ $(apt version ${coredep} | wc -w) -eq 0 ]]; then
      echo -e "Installing core dependency $(printf ${coredep} | sed 's/\\//g').\n"
      sudo apt install -y ${coredep}
      if [[ $? -ne 0 ]]; then
        echo -e "Could not install ${coredep}. Aborting.\n"
        exit 1
      fi
    fi
  done

}

customReqs

##################################

function pkgcompilecheck() {

  local pkg=$(printf ${1} | sed 's/\+/\\\+/g')

  if [[ $(dpkg --get-selections | awk '{print $1}' | grep -wE "^${pkg}$" | wc -l) -eq 0 ]] || [[ -v updateoverride ]]; then
    ${2}
  fi

}

###################################################

function preparepackage() {

  echo -e "Starting compilation (& installation) of ${1}\n"

  local a=0
  local _pkgname=${1}
  local _pkgdeps=${2}
  local _pkgurl=${3}
  local _pkgver=${4}
  if [[ -n ${5} ]]; then local _pkgdeps_runtime=${5}; fi

  function pkgdependencies() {

    for pkgdep in ${@}; do

      if [[ $(apt version ${pkgdep} | wc -w) -eq 0 ]]; then

        echo -e "Installing ${_pkgname} dependency ${pkgdep} ($(($a + 1 )) / $((${#*} + 1)))\n."
        sudo apt install -y ${pkgdep} &> /dev/null
        if [[ $? -eq 0 ]]; then
          let a++
        else
          echo -e "\nError occured while installing ${pkgdep}. Aborting.\n"
          exit 1
        fi
      fi
    done

  }

  function pkgversion() {

    if [[ -n "${_pkgver}" ]] && [[ "${_pkgver}" =~ ^git ]]; then
      cd ${_pkgname}
      _pkgver=$(eval "${_pkgver}")
      cd ..
    fi

  }

  function pkgfoldername() {

    rm -rf ${_pkgname}
    mkdir ${_pkgname}
    cd ${_pkgname}
    echo -e "Retrieving source code of ${_pkgname} from $(printf ${_pkgurl} | sed 's/^.*\/\///; s/\/.*//')\n"
    git clone ${_pkgurl} ${_pkgname}

    pkgversion && \
    mv ${_pkgname} ${_pkgname}-${_pkgver}
    cd ${_pkgname}-${_pkgver}
  }

  pkgdependencies "${_pkgdeps[*]}" && \
  if [[ -v _pkgdeps_runtime ]]; then pkgdependencies "${_pkgdeps_runtime[*]}"; fi
  pkgfoldername

  unset _pkgver

}

###################################################

function meson_install_main() {

  local pkgname="meson"

  local pkgdeps_build=(
  'python3'
  'dh-python'
  'python3-setuptools'
  'ninja-build'
  )

<<DISABLED
  'zlib1g-dev'
  'libboost-dev'
  'libboost-thread-dev'
  'libboost-test-dev'
  'libboost-log-dev'
  'gobjc'
  'gobjc++'
  'gnustep-make'
  'libgnustep-base-dev'
  'libgtest-dev'
  'google-mock'
  'qtbase5-dev'
  'qtbase5-dev-tools'
  'qttools5-dev-tools'
  'protobuf-compiler'
  'libprotobuf-dev'
  'default-jdk-headless'
  'valac'
  'gobject-introspection'
  'libgirepository1.0-dev'
  'gfortran'
  'flex'
  'bison'
  'mono-mcs'
  'mono-devel'
  'libwxgtk3.0-dev'
  'gtk-doc-tools'
  'rustc'
  'bash-doc'
  'python3-dev'
  'cython3'
  'gdc'
  'itstool'
  'libgtk-3-dev'
  'g++-arm-linux-gnueabihf'
  'bash-doc'
  'valgrind'
  'llvm-dev'
  'libsdl2-dev'
  'openmpi-bin'
  'libopenmpi-dev'
  'libvulkan-dev'
  'libpcap-dev'
  'libcups2-dev'
  'gtk-sharp2'
  'gtk-sharp2-gapi'
  'libglib2.0-cil-dev'
  'libwmf-dev'
  'mercurial'
  'gcovr'
  'lcov'
  'fpga-icestorm'
  'arachne-pnr'
  'yosys'
  'qtbase5-private-dev'
DISABLED

  local pkgver_git="git describe --long | sed 's/\-[a-z].*//; s/\-/\./; s/[a-z]//g'"

  local pkgurl="https://github.com/mesonbuild/meson"

  local pkgurl_debian="http://archive.ubuntu.com/ubuntu/pool/universe/m/meson/meson_0.45.1-2.debian.tar.xz"

  function meson_debianbuild() {

    wget ${pkgurl_debian} -O debian.tar.xz
    tar xf debian.tar.xz && rm debian.tar.xz

    local sedversion=$(printf '%s' $(pwd | sed -e 's/.*\-//' -e 's/\./\\\./g'))

    # Do not perform checks
    sed -ir '/nocheck/d' debian/control
    sed -ir '/\.\/run_tests\.py/d' debian/rules

    # Downgrade debhelper version requirement for Debian compatilibity
    sed -ir 's/debhelper (>= 11)/debhelper (>= 10)/' debian/control

    sed -ir "s/0\.45\.1-2/${sedversion}/" debian/changelog

    sed -ir '/rm \$\$(pwd)\/debian\/meson\/usr\/bin\/mesontest/d' debian/rules
    sed -ir '/rm \$\$(pwd)\/debian\/meson\/usr\/bin\/mesonconf/d' debian/rules
    sed -ir '/rm \$\$(pwd)\/debian\/meson\/usr\/bin\/mesonintrospect/d' debian/rules
    sed -ir '/rm \$\$(pwd)\/debian\/meson\/usr\/bin\/wraptool/d' debian/rules

    sed -ir '/rm \-rf \$\$(pwd)\/debian\/meson\/usr\/lib\/python3/d' debian/rules

    

    #sed -ir "s/0\.45\.1-2/${sedversion}/" debian/files
    #sed -ir "s/0\.45\.1-2/${sedversion}/" debian/meson/DEBIAN/control
    rm -r debian/patches

    # Compile the package and actually install it. It is required by DXVK
    DEB_BUILD_OPTIONS="strip nodocs noddebs" dpkg-buildpackage -rfakeroot -b -us -uc

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

  preparepackage "${pkgname}" "${pkgdeps_build[*]}" "${pkgurl}" "${pkgver_git}" && \
  meson_debianbuild

}

###################################################

function glslang_install_main() {

  local pkgname="glslang"
  local pkgdeps_build=('cmake' 'python2.7')

  local pkgurl="https://github.com/KhronosGroup/glslang"

  local pkgver_git="git describe --long | sed 's/\-[a-z].*//; s/\-/\./; s/[a-z]//g'"

  function glslang_debianbuild() {

    # Compile the package and actually install it. It is required by DXVK
    dh_make --createorig -s -y
    sed -ie "s/^Build-Depends:.*$/Build-Depends: debhelper (>=10), $(echo ${_coredeps[*]} | sed 's/\s/, /g'), $(echo ${pkgdeps_build[*]} | sed 's/\s/, /g')/g" debian/control
    printf 'override_dh_usrlocal:' | tee -a debian/rules
    DEB_BUILD_OPTIONS="strip nodocs noddebs" dpkg-buildpackage -rfakeroot -b -us -uc

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

  preparepackage "${pkgname}" "${pkgdeps_build[*]}" "${pkgurl}" "${pkgver_git}" && \
  glslang_debianbuild

}

###################################################

function dxvk_install_main() {

  local pkgname="dxvk-git"

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

  local pkgdeps_runtime=('wine' 'winetricks')

  local pkgver_git="git describe --long | sed 's/\-[a-z].*//; s/\-/\./; s/[a-z]//g'"

  local pkgurl="https://github.com/doitsujin/dxvk"

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
    done

  }

  function dxvk_debianbuild() {

    local dxvx_relative_builddir="debian/source/dxvk-master"

    dh_make --createorig -s -y
    sed -ie "s/^Build-Depends:.*$/Build-Depends: debhelper (>=10), $(echo ${_coredeps[*]} | sed 's/\s/, /g'), $(echo ${pkgdeps_build[*]} | sed 's/\s/, /g')/g" debian/control
    sed -ie "s/^Depends:.*$/Depends: $(echo ${pkgdeps_runtime} | sed 's/\s/, /g')/g" debian/control

    printf "${dxvx_relative_builddir}/setup_dxvk.verb usr/share/dxvk/" > debian/install
    printf "\n${dxvx_relative_builddir}/bin/* usr/bin/" >> debian/install

    rm debian/*.{ex,EX}

cat << 'DXVK-DEBIANRULES' > debian/rules
#!/usr/bin/make -f
%:
	dh $@

override_dh_auto_configure:

override_dh_usrlocal:
DXVK-DEBIANRULES

    bash ./package-release.sh master debian/source/ --no-package

    if [[ $? -ne 0 ]]; then
      echo "Error while compiling ${pkgname}. Check messages above. Aborting\n"
      exit 1
    fi

    sed -ir '/dxvk64_dir/d' ${dxvx_relative_builddir}/setup_dxvk.verb

    mkdir -p ${dxvx_relative_builddir}/bin

    echo -e "#!/bin/sh\nwinetricks --force /usr/share/dxvk/setup_dxvk.verb" \
    > "${dxvx_relative_builddir}/bin/setup_dxvk"
    chmod +x "${dxvx_relative_builddir}/bin/setup_dxvk"

    for arch in 64 32; do
      mkdir -p ${dxvx_relative_builddir}/x${arch}

      printf "\n${dxvx_relative_builddir}/x${arch}/* usr/share/dxvk/x${arch}/" >> debian/install

    done

    DEB_BUILD_OPTIONS="strip nodocs noddebs" dpkg-buildpackage -us -uc -b --source-option=--include-binaries

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

  preparepackage "${pkgname}" "${pkgdeps_build[*]}" "${pkgurl}" "${pkgver_git}" "${pkgdeps_runtime[*]}" && \
  dxvk_posixpkgs && \
  dxvk_debianbuild

}

####################################################################

pkgcompilecheck meson meson_install_main
pkgcompilecheck glslang glslang_install_main
dxvk_install_main

