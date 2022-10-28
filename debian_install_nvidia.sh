#!/bin/env bash

#    Compile latest Nvidia drivers on a Debian-based Linux
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

# Check if we're using bash or sh to run the script. If bash, OK.
# If another one, ask user to run the script with bash.

BASH_CHECK=$(ps | grep `echo $$` | awk '{ print $4 }')

if [ $BASH_CHECK != "bash" ]; then
  echo "
Please run this script using bash (/usr/bin/bash).
"
  exit 1
fi

########################################################

# Just a title & author for this script, used in initialization

SCRIPT_TITLE="\e[1mNvidia drivers package builder & installer\e[0m"
SCRIPT_AUTHOR="Pekka Helenius (~Fincer), 2019"

########################################################

BUILD_MAINDIR=${PWD}/debian_nvidia

########################################################

_pkgname="nvidia"
arch="x86_64"
pkgver=430.14

files=(
  "http://archive.ubuntu.com/ubuntu/pool/restricted/n/nvidia-graphics-drivers-418/nvidia-graphics-drivers-418_418.56-0ubuntu1.debian.tar.xz"
  "http://us.download.nvidia.com/XFree86/Linux-${arch}/${pkgver}/NVIDIA-Linux-${arch}-${pkgver}.run"
)

###################

pkgver_major=$(printf '%s' ${pkgver} | grep -oE "^[0-9]+[^.]")
pkgdir="nvidia-graphics-drivers-${pkgver_major}_${pkgver}"

typeset -A library_fixes

###################

# From time to time, bundled library version numbers change
# in Nvidia driver packages. Update library version if needed
#
# Left side: old library version
# Right side: new library version
#
library_fixes=(
  [libnvidia-egl-wayland.so.1.0.2]='libnvidia-egl-wayland.so.1.0.3'
)

###################

# These are defined build dependencies in debian/control file
nvidia_builddeps=(
  'dpkg-dev'
  'xz-utils'
  'dkms'
  'libwayland-client0'
  'libwayland-server0'
  'libxext6'
  'quilt'
  'po-debconf'
  'execstack'
  'dh-modaliases'
  'xserver-xorg-dev'
  'libglvnd-dev'
)

###################

# These packages are required by the compiled Nvidia packages
nvidia_required_packages=(

# Required by libnvidia-gl
  'libwayland-client0'
  'libwayland-server0'

# Required by libnvidia, libnvidia-decode & libnvidia-fbc1
  'libx11-6'

# Required by libnvidia, libnvidia-decode, libnvidia-fbc1 & libnvidia-ifr1
  'libxext6'

# Required by libnvidia-fbc1 & libnvidia-ifr1
  'libgl1'

# Required by xserver-xorg-video-nvidia
  'xserver-xorg-core'
  'xorg-video-abi-23'

# Required by nvidia-compute-utils
  'adduser'

)

###################

# Nvidia packages. THIS ORDER IS MANDATORY, DO NOT CHANGE!
nvidia_install_packages=(

# Similar than 'nvidia-dkms' package on Arch Linux
  "nvidia-kernel-source-${pkgver_major}"

# Nvidia DKMS
  "nvidia-kernel-common-${pkgver_major}"
  "nvidia-dkms-${pkgver_major}"

# Similar than 'nvidia-utils' package on Arch Linux
  "libnvidia-common-${pkgver_major}"
  "libnvidia-gl-${pkgver_major}"
  "libnvidia-cfg1-${pkgver_major}"
  "xserver-xorg-video-nvidia-${pkgver_major}"
  "libnvidia-compute-${pkgver_major}"
  "libnvidia-decode-${pkgver_major}"
  "libnvidia-encode-${pkgver_major}"
  "libnvidia-fbc1-${pkgver_major}"
  "libnvidia-ifr1-${pkgver_major}"
  "nvidia-compute-utils-${pkgver_major}"
  "nvidia-utils-${pkgver_major}"

)

########################################################

pkgver_sed=$(printf '%s' ${pkgver} | sed 's/\./\\\./')

i=0
for f in ${files[@]}; do
  file_basename=$(printf '%s' ${f} | awk -F / '{print $NF}')
  filebases[$i]=${file_basename}
  let i++
done

oldver=$(printf '%s' ${filebases[0]} | grep -oE "[0-9]{3}\.[0-9]{2}" | head -1)
oldver_major=$(printf '%s' ${filebases[0]} | grep -oE "[0-9]{3}" | head -1)
oldver_sed=$(printf '%s' ${oldver} | sed 's/\./\\\./')

########################################################

# http://wiki.bash-hackers.org/snipplets/print_horizontal_line#a_line_across_the_entire_width_of_the_terminal
function INFO_SEP() { printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - ; }

###########################################################

echo -e "\n${SCRIPT_TITLE}\n"

########################################################

echo -e "Selected driver version:\t${pkgver}\n"
INFO_SEP

########################################################

mkdir -p ${BUILD_MAINDIR}

if [[ $? -eq 0 ]]; then
  cd ${BUILD_MAINDIR}
  WORKDIR=${PWD}
else
  echo -e "Error: couldn't create Nvidia build directory. Aborting\n"
  exit 1
fi

########################################################

# If the script is interrupted (Ctrl+C/SIGINT), do the following

function Nvidia_intCleanup() {
  rm -rf ${WORKDIR}/{${pkgdir}
}

# Allow interruption of the script at any time (Ctrl + C)
trap "Nvidia_intCleanup && exit 0" INT

# Error event
#trap "Nvidia_intCleanup && exit 1" ERR

# Remove old build files
Nvidia_intCleanup

###########################################################

COMMANDS=(
  apt
  dpkg
  grep
  sudo
  wc
  wget
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

########################################################

# General function for question responses

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

########################################################

# Premilinary check for already compiled packages

if [[ $(ls ${WORKDIR}/*.deb 2>/dev/null | wc -l) -ne 0 ]]; then
  echo -e "\nWarning: previously compiled deb archives found on the main build directory '${WORKDIR}'.\nDelete them and continue? [Y/n]"
  questionresponse
fi

if [[ $? -ne 0 ]]; then
  echo -e "Cancelling.\n"
  exit 1
else
  rm -rfv ${WORKDIR}/*.{deb,buildinfo,changes} 2>/dev/null
fi

########################################################

# Premilinary check to see whether Nvidia card is present

if [[ ! $(lspci | grep -oiE "vga.*nvidia") ]]; then
  echo -e "\nWarning: Nvidia card could not be detected on your system. Continue anyway? [Y/n]"
  questionresponse
fi

if [[ $? -ne 0 ]]; then
  echo -e "Cancelling.\n"
  exit 1
fi

########################################################

# Auto-install question

echo -e "\nAuto-install Nvidia drivers after compilation? [Y/n]"
questionresponse

if [[ $? -eq 0 ]]; then

  if [[ ${UID} -ne 0 ]]; then
    if [[ $(echo $(sudo -vn &>/dev/null)$?) -ne 0 ]]; then
      echo -e "NVIDIA driver installation requires root permissions. Please provide your sudo password now.\n"
      sudo -v
    fi
    if [[ $? -eq 0 ]]; then
      AUTOINSTALL=
    else
      exit 1
    fi
  else
    AUTOINSTALL=
  fi
fi

########################################################

function pkg_installcheck() {
  RETURNVALUE=$(echo $(dpkg -s "${1}" &>/dev/null)$?)
  return $RETURNVALUE
}

########################################################

# Check and install package related dependencies if they are missing
function pkgdependencies() {

  local a
  local b

  # Generate a list of missing dependencies
  a=0
  for p in ${@}; do
    if [[ $(pkg_installcheck ${p}) -ne 0 ]]; then
      validlist[$a]=${p}
      let a++
    fi
  done

  if [[ -n ${validlist[*]} ]]; then
    echo -e "The following build time dependencies are missing. In order to continue, you must install them:\n$(for i in ${validlist[@]}; do echo ${i}; done)\n"
    if [[ ${UID} -ne 0 ]] && [[ $(echo $(sudo -vn &>/dev/null)$?) -ne 0 ]]; then
      echo -e "For that, sudo password is required. Please provide it now.\n"
      sudo -v
      if [[ $? -ne 0 ]]; then
        echo -e "Error: couldn't continue due to lacking permissions. Aborting\n"
        exit 1
      fi
    fi
  fi

  # Install missing dependencies, be informative
  b=0
  for pkgdep in ${validlist[@]}; do
    echo -e "$(( $b + 1 ))/$(( ${#validlist[*]} )) - Installing ${_pkgname} dependency ${pkgdep}"
    sudo apt install -y ${pkgdep} &> /dev/null
    if [[ $? -eq 0 ]]; then
      let b++
    else
      echo -e "\nError occured while installing ${pkgdep}. Aborting.\n"
      exit 1
    fi
  done
}

########################################################

function download_files() {

  mkdir -p ${WORKDIR}/${pkgdir}

  i=0
  for f in ${files[@]}; do

    if [[ ! -f ${WORKDIR}/${pkgdir}/${filebases[$i]} ]]; then
      echo ${f}

      echo -e "\nDownloading ${filebases[$i]}"
      wget ${f} -o /dev/null --show-progress -O "${WORKDIR}/${pkgdir}/${filebases[$i]}"

      if [[ $? -ne 0 ]];then
        echo -e "Error: couldn't retrieve file ${filebases[$i]}. Aborting\n"
        exit 1
      fi
    fi

  let i++
  done

}

########################################################

function prepare_deb_sources() {

  local oldlib_sed
  local lib_sed
  local oldlib_files
  local i

  # Extract debian control files
  cd ${WORKDIR}/${pkgdir}/
  tar xf ${filebases[0]}

  if [[ $? -eq 0 ]]; then

    function fix_library_versions() {

      for oldlib in ${!library_fixes[@]}; do

        # sed-friendly name
        oldlib_sed=$(printf '%s' ${oldlib} | sed 's/\./\\\./g')

        for lib in ${library_fixes[$oldlib]}; do

          # sed-friendly name
          lib_sed=$(printf '%s' ${lib} | sed 's/\./\\\./g')

          # Files which have old library files mentioned
          i=0
          for oldlib_file in $(grep -rl "${oldlib}" debian/ | tr '\n' ' '); do
            oldlib_files[$i]=${oldlib_file}
            let i++
          done

          for targetfile in ${oldlib_files[@]}; do
            sed -i "s/${oldlib_sed}/${lib_sed}/g" ${targetfile}
          done
        done
      done

    }

    function rename_deb_files() {

      local n_new
      local IFS
    
      # Remove this suffix
      sed -i 's/\-no\-compat32//' debian/rules.defs

      # Tell that Nvidia .run file is at our build root, not in amd64 subfolder
      sed -i 's|sh \$\*\/\${NVIDIA_FILENAME_\$\*}|sh \${NVIDIA_FILENAME_\$\*}|' debian/rules

      ############
      # TODO Individual fix for strange version number present in debian control files
      # Remove when not needed!
      sed -i "s/384/${pkgver_major}/g" debian/control
      sed -i "s/384/${pkgver_major}/g" debian/templates/control.in
      ############

      IFS=$'\n'
      for n in $(ls debian/ -w 1); do

        # IMPORTANT! KEEP THIS IF STATEMENT ORDER BELOW!!

        # Do this for every file in debian subfolder regardless of their name
        if [[ -f debian/${n} ]]; then
          # Keep this order. It is important!
          sed -i "s/${oldver_sed}/${pkgver_sed}/g" debian/${n}
          sed -i "s/${oldver_major}/${pkgver_major}/g" debian/${n}

        fi

        if [[ $(printf '%s' ${n} | grep ${oldver_major}) ]]; then
          n_new=$(printf '%s' ${n} | sed "s/${oldver_major}/${pkgver_major}/")
          mv debian/${n} debian/${n_new}

          if [[ $? -ne 0 ]]; then
            echo -e "Error: couldn't rename file debian/${n}. Aborting\n"
            exit 1
          fi
        fi

      done
      unset IFS
    }

    fix_library_versions
    rename_deb_files

  else
    echo -e "Error: couldn't extract Nvidia Debian archive. Aborting\n"
    exit 1
  fi

}

########################################################

function compile_nvidia() {

  cd ${WORKDIR}/${pkgdir}/
  DEB_BUILD_OPTIONS="strip noddebs" dpkg-buildpackage -rfakeroot -b -us -uc

  if [[ $? -eq 0 ]]; then
    mkdir -p ${WORKDIR}/compiled_deb
    for p in ${nvidia_install_packages[*]}; do
      mv ${WORKDIR}/${p}*.deb ${WORKDIR}/compiled_deb/
    done

    if [[ $? -eq 0 ]]; then
      echo -e "Compiled deb packages moved into '${WORKDIR}/compiled_deb/'. Install these to enable Nvidia support.\nAdditionally, you may need Vulkan loader package 'libvulkan1', too.\n"
    else
      echo -e "Error: couldn't move deb packages into '${WORKDIR}/compiled_deb/'. Aborting\n"
      exit 1
    fi

    mkdir -p ${WORKDIR}/compiled_other
    for a in ${WORKDIR}/*; do
      if [[ -f ${a} ]]; then
        mv ${a} ${WORKDIR}/compiled_other/
      fi
    done

    if [[ $? -eq 0 ]]; then
      echo -e "Other files moved into '${WORKDIR}/compiled_other/' \n"
    else
      echo -e "Error: couldn't move other files into '${WORKDIR}/compiled_other/'. Aborting\n"
      exit 1
    fi

  else
    echo -e "Error: couldn't compile Nvidia package bundle. Aborting\n"
    exit 1
  fi
}

########################################################

function install_nvidia() {

  local oldpkg
  local oldpkg_check

  for syspkg in ${nvidia_required_packages[@]}; do
    if [[ $(echo $(dpkg -s ${syspkg} &>/dev/null)$?) -ne 0 ]]; then
      echo -e "Installing missing dependency ${syspkg}\n"
      sudo apt install -y ${syspkg}
      if [[ $? -ne 0 ]]; then
        echo -e "Error: couldn't install dependency ${syspkg}. Aborting\n"
        exit 1
      fi
    fi
  done

  cd ${WORKDIR}/compiled_deb
  for pkg in ${nvidia_install_packages[@]}; do

    oldpkg=$(printf '%s' ${pkg} | sed 's/\-[0-9]*$//')
    oldpkg_check=$(dpkg --get-selections | grep ${oldpkg} | awk '{print $1}')

    if [[ $(echo ${oldpkg_check} | wc -w) -eq 1 ]]; then
      if [[ ! ${oldpkg_check} =~ ^*${pkgver_major}$ ]]; then
        echo -e "Removing old ${oldpkg}\n"
        sudo apt purge --remove -y "${oldpkg}*"
        if [[ $? -ne 0 ]]; then
          echo -e "Error: couldn't uninstall ${oldpkg}. Aborting\n"
          exit 1
        fi
      fi
    fi

    echo -e "Installing ${pkg}\n"
    sudo dpkg -i ${pkg}*.deb

    if [[ $? -ne 0 ]]; then
      echo -e "Warning: couldn't install ${pkg}\n"
    fi

  done

}

function install_vulkan() {

  local syspkg

  # Vulkan loader
  if [[ $? -eq 0 ]]; then
    syspkg=libvulkan1
    if [[ $(echo $(dpkg -s ${syspkg} &>/dev/null)$?) -ne 0 ]]; then
      sudo apt update && sudo apt install -y ${syspkg}
    fi
  fi

}

########################################################

pkgdependencies ${nvidia_builddeps[*]} && \
download_files && \
prepare_deb_sources && \
compile_nvidia

if [[ $? -eq 0 ]] && [[ -v AUTOINSTALL ]]; then
  install_nvidia && \
  install_vulkan
fi

# If any buildtime deps were installed, inform the user
if [[ -n ${validlist[*]} ]]; then
  echo -e "The following buildtime dependencies were installed, and they may not be required anymore:\n\n\
$(for h in ${validlist[*]}; do echo ${h}; done)\n"
fi
