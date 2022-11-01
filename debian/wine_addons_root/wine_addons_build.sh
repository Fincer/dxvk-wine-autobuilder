#!/bin/env bash

#    Compile DXVK git on Debian/Ubuntu/Mint and variants
#    Copyright (C) 2019, 2022  Pekka Helenius
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
WINE_ADDONS_ROOT="${PWD}"

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
git_commithash_dxvknvapi=${params[0]}
git_commithash_vkd3dproton=${params[1]}
git_commithash_dxvk=${params[2]}
git_commithash_glslang=${params[3]}
git_commithash_meson=${params[4]}

git_branch_dxvknvapi=${params[6]}
git_branch_vkd3dproton=${params[7]}
git_branch_dxvk=${params[8]}
git_branch_glslang=${params[9]}
git_branch_meson=${params[10]}

git_source_dxvknvapi_debian=${params[19]}
git_source_vkd3dproton_debian=${params[20]}
git_source_dxvk_debian=${params[21]}
git_source_glslang_debian=${params[15]}
git_source_meson_debian=${params[16]}

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

for check in ${args[@]}; do

  case ${check} in
    --no-install)
      NO_INSTALL=
      ;;
    --updateoverride)
      UPDATE_OVERRIDE=
      ;;
    --buildpkg-rm)
      BUILDPKG_RM=
      ;;
    --no-dxvk)
      NO_DXVK=
      ;;
    --no-nvapi)
      NO_NVAPI=
      ;;
    --no-vkd3d)
      NO_VKD3D=
      ;;
  esac

done

########################################################

# Check presence of Wine. Some version of Wine should
# be found in the system in order to install DXVK/DXVK NVAPI/VKD3D Proton.

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

# Alternative remote dependency packages for Debian distributions which offer too old packages for Wine addons
#
# Left side:  <package name in repositories>,<version_number>
# Right side: package alternative source URL
#
# NOTE: Determine these packages in corresponding debdata files as runtime or buildtime dependencies
#
# As this seems to be a dependency for binutils-mingw packages

if [[ $(dpkg -s "binutils-common" &>/dev/null)$? -ne 0 ]]; then
  sudo apt -y install "binutils-common"
fi

binutils_ver=$(dpkg -s "binutils-common" | sed -rn 's/^Version: ([0-9\.]+).*$/\1/p')

remote_package_repositories=(
  "https://mirrors.edge.kernel.org/ubuntu/pool/universe/d/directx-headers"
  "https://mirrors.edge.kernel.org/ubuntu/pool/main/i/isl"
  "https://mirrors.edge.kernel.org/ubuntu/pool/universe/b/binutils-mingw-w64"
  "https://mirrors.edge.kernel.org/ubuntu/pool/universe/g/gcc-mingw-w64"
  "https://mirrors.edge.kernel.org/ubuntu/pool/universe/m/mingw-w64"
)

remote_packages_pool=(
  "directx-headers-dev"
  "libisl22"
  "gcc-mingw-w64-base"
  "mingw-w64-common"
  "binutils-mingw-w64-x86-64"
  "binutils-mingw-w64-i686"
  "mingw-w64-x86-64-dev"
  "gcc-mingw-w64-x86-64"
  "g++-mingw-w64-x86-64"
  "mingw-w64-i686-dev"
  "gcc-mingw-w64-i686"
  "g++-mingw-w64-i686"
)


# NOTE: Package versions defined here *must* exist in some of the repositories!
typeset -A remote_packages_version_locks
remote_packages_version_locks=(
  [directx-headers-dev]="1.606.4"
)

pkg_multi_data_binutils=()

typeset -A rpp_alternatives
typeset -A remote_packages_selected
typeset -A remote_packages_alt_available

for rpp in "${remote_packages_pool[@]}"; do

  version_len=100
  new_rpp_url=
  new_rpp_token=
  version_lock=
  version_lock_set=0
  rpp_alternative_time=-1
  alt_remote_epoch_time=-1
  alt_remote_flat_version=-1

  rpp_alternatives=()
  remote_packages_alt_available=()

  for package_version_lock in ${!remote_packages_version_locks[@]}; do

    if [[ ${rpp} == ${package_version_lock} ]]; then
      version_lock=${remote_packages_version_locks[${package_version_lock}]}
      version_lock_set=1
      break 1
    fi

  done

  for source_url in "${remote_package_repositories[@]}"; do

    # Fetch exact package name and associated date.
    # rpp_rx is just for regex escaping purposes.
    rpp_rx=$(echo ${rpp} | sed 's/\+/\\\+/g')
    pkg_multi_data=(
      $(curl -s "${source_url}/" | \
        sed -rn 's/.*href="(.*(amd64|all)\.deb)">.*([0-9]{2}\-[A-Za-z]{3}\-[0-9]{4}).*/\1|\3/p' | \
        sed 's/%2B/+/g' | grep -E "${rpp_rx}_[0-9]" | xargs echo
      )
    )

    [[ ${#pkg_multi_data[@]} -eq 0 ]] && continue

    # binutils packages depend on system binutils-common.
    # Versions must match, even if the newest package is not available.
    if [[ ${rpp} =~ binutils ]] && [[ ${binutils_ver} != "" ]]; then
      for b in "${pkg_multi_data[@]}"; do
        if [[ ${b} =~ ${binutils_ver} ]]; then
          pkg_multi_data_binutils+=("${b}")
        fi
      done
      pkg_multi_data=( ${pkg_multi_data_binutils[@]} )
      unset pkg_multi_data_binutils
    fi

    # TODO: Remove duplicate functionality
    # Check relevant version parts while collecting
    # different versions of a package.
    # version_len is count of relevant parts.
    #
    # For instance
    # - In a case of versions 2.23.1, 2.28 and 2.34.6.1
    #   count of relevant parts is 2 as determined by
    #   version 2.28.
    #   In this fair comparison, we therefore consider
    #   normalized version 2.23, 2.28 and 2.34
    #
    for pkg_data in "${pkg_multi_data[@]}"; do

      rpp_pkg=$(printf '%s' "${pkg_data}" | awk -F '|' '{print $1}')
      rpp_version_raw=$(printf '%s' $(echo "${rpp_pkg}" | sed -r 's/.*_(.*[0-9]+)\-.*_(all|amd64).*/\1/g;'))

      version_parts=( $(echo ${rpp_version_raw} | sed 's/\./ /g') )

      new_version_len=$(printf '%d' ${#version_parts[@]})

      if [[ ${new_version_len} -lt ${version_len} ]]; then
        version_len=${new_version_len}
      fi

    done

    # Add each version of a package into associated array remote_packages_alt_available
    # We collect the next information here for each entry:
    # - package normalized version number
    # - package release date in epoch format
    # - package source root url and .deb name
    #
    # This information is collected so that we can determine which
    # package version to use, and which URL is associated to it.
    #
    for pkg_data in "${pkg_multi_data[@]}"; do

      rpp_pkg=$(printf '%s' "${pkg_data}" | awk -F '|' '{print $1}')
      rpp_epoch_time=$(date --date=$(printf '%s' "${ps}" | awk -F '|' '{print $2}') +%s)
      rpp_version_raw=$(printf '%s' $(echo "${rpp_pkg}" | sed -r 's/.*_(.*[0-9]+)\-.*_(all|amd64).*/\1/g;'))

      version_parts=( $(echo ${rpp_version_raw} | sed 's/\./ /g') )
      relevant_version_parts=( ${version_parts[@]:0:${version_len}} )

      rpp_flat_version=$(printf '%d' $(echo ${relevant_version_parts[@]} | sed 's/ //g'))
      rpp_dot_version=$(echo ${relevant_version_parts[@]} | sed 's/ /./g')

      rpp_token=$(printf '%s,%d,%d,%s' "${rpp}" "${rpp_epoch_time}" "${rpp_flat_version}" "${rpp_dot_version}")
      rpp_url=$(printf '%s/%s' "${source_url}" "${rpp_pkg}")

      remote_packages_alt_available+=(["${rpp_token}"]="${rpp_url}")

    done

  done

  # For collected package versions, get the highest available
  #
  for alt_remote_package in "${!remote_packages_alt_available[@]}"; do

    new_alt_remote_epoch_time=$(echo ${alt_remote_package} | awk -F ',' '{print $2}')
    new_alt_remote_flat_version=$(echo ${alt_remote_package} | awk -F ',' '{print $3}')
    new_alt_remote_dot_version=$(echo ${alt_remote_package} | awk -F ',' '{print $4}')

    # TODO: Remove duplicate functionality
    if [[ ${version_lock} =~ ${new_alt_remote_dot_version} ]]; then

      alt_remote_epoch_time=${new_alt_remote_epoch_time}
      alt_remote_flat_version=${new_alt_remote_flat_version}
      alt_remote_dot_version=${new_alt_remote_dot_version}

      new_rpp_token=${alt_remote_package}
      new_rpp_url=${remote_packages_alt_available[${alt_remote_package}]}

      rpp_alternatives+=(["${new_rpp_token}"]="${new_rpp_url}|${alt_remote_epoch_time}|${alt_remote_flat_version}")

    fi

    if [[ ${new_alt_remote_flat_version} -ge ${alt_remote_flat_version} ]] && [[ ${version_lock_set} -eq 0 ]]; then
      alt_remote_epoch_time=${new_alt_remote_epoch_time}
      alt_remote_flat_version=${new_alt_remote_flat_version}
      alt_remote_dot_version=${new_alt_remote_dot_version}

      new_rpp_token=${alt_remote_package}
      new_rpp_url=${remote_packages_alt_available[${alt_remote_package}]}

      rpp_alternatives+=(["${new_rpp_token}"]="${new_rpp_url}|${alt_remote_epoch_time}|${alt_remote_flat_version}")
    fi

  done

  # Do epoch time comparison for collected package versions
  #
  for rpp_alternative in ${!rpp_alternatives[@]}; do

    new_rpp_alternative=${rpp_alternative}
    new_rpp_alternative_time=$(printf '%d' $(echo ${rpp_alternative} | awk -F '|' '{print $2}') )

    if [[ ${new_rpp_alternative_time} -gt ${rpp_alternative_time} ]]; then
      rpp_alternative_time=${new_rpp_alternative_time}
    fi

    rpp_alternative=${new_rpp_alternative}

  done

  remote_packages_selected+=( ["${rpp}"]=$(echo "${rpp_alternatives[$rpp_alternative]}|${version_lock_set}") )

done

# Posix-compliant MingW alternative executables
#
typeset -A alternatives
alternatives=(
  [x86_64-w64-mingw32-gcc]="x86_64-w64-mingw32-gcc-posix"
  [x86_64-w64-mingw32-g++]="x86_64-w64-mingw32-g++-posix"
  [i686-w64-mingw32-gcc]="i686-w64-mingw32-gcc-posix"
  [i686-w64-mingw32-g++]="i686-w64-mingw32-g++-posix"
)

# Temporary symbolic links for DXVK compilation
#
typeset -A tempLinks
tempLinks=(
  ['/usr/bin/i686-w64-mingw32-gcc']='/usr/bin/i686-w64-mingw32-gcc-posix'
  ['/usr/bin/i686-w64-mingw32-g++']='/usr/bin/i686-w64-mingw32-g++-posix'
  ['/usr/bin/x86_64-w64-mingw32-gcc']='x86_64-w64-mingw32-gcc-posix'
  ['/usr/bin/x86_64-w64-mingw32-g++']='x86_64-w64-mingw32-g++-posix'
)

########################################################

function runtime_check() {

  local pkgreq_name
  local known_pkgs
  local pkglist

  # Friendly name for this package
  pkgreq_name=${1}
  # Known package names to check on Debian
  known_pkgs=${2}

  # Check if any of these Wine packages are present on the system
  i=0
  for pkg in ${known_pkgs[@]}; do
    if [[ $(echo $(dpkg -s ${pkg} &>/dev/null)$?) -eq 0 ]]; then
      pkglist[$i]=${pkg}
      let i++
    fi
  done

  if [[ -z ${pkglist[*]} ]]; then
    echo -e "\e[1mWARNING:\e[0m Not compiling Wine addons because \e[1m${pkgreq_name}\e[0m is missing on your system.\n\
${pkgreq_name} should be installed in order to use DXVK, DXVK NVAPI and VKD3D Proton.\n"

    exit 1

  fi

}

########################################################

# If the script is interrupted (Ctrl+C/SIGINT), do the following

function wine_addons_int_cleanup() {
  rm -rf ${WINE_ADDONS_ROOT}/{dxvk-git,meson,glslang,*.deb}
  rm -rf ${WINE_ADDONS_ROOT}/../compiled_deb/"${datedir}"
  exit 0
}

# Allow interruption of the script at any time (Ctrl + C)
trap "wine_addons_int_cleanup" INT

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

function pkg_compile_check() {

  local install_function
  local pkg
  local pkg_data

  install_function=${1}
  pkg=${2}
  pkg_data=${3}

  if [[ $(echo $(dpkg -s ${pkg} &>/dev/null)$?) -ne 0 ]] || [[ -v UPDATE_OVERRIDE ]]; then
    ${install_function} ${pkg_data}
  fi

}

########################################################

# ADDON CUSTOM INSTALLATION HOOKS

# These are custom installation instructions for addon
# They are not used independently.

function addon_install_custom() {

  local PATCHDIR

  PATCHDIR="${1}"

  # Use posix alternates for MinGW binaries
  function addon_posixpkgs() {

    for alt in ${!alternatives[@]}; do
      echo "Linking MingW executable ${alt} to ${alternatives[$alt]}"
      sudo rm -rf /etc/alternatives/"${alt}" 2>/dev/null
      sudo ln -sf  /usr/bin/"${alternatives[$alt]}" /etc/alternatives/"${alt}"

      if [[ $? -ne 0 ]]; then
        echo -e "\e[1mERROR:\e[0m Error occured while linking executable ${alt} to ${alternatives[$alt]}. Aborting\n"
        exit 1
      fi
    done

    for link in ${!tempLinks[@]}; do
      if [[ ! -f ${link} ]]; then
        echo "Creating temporary links for MingW executable ${link}"
        sudo ln -sf ${tempLinks["${link}"]} "${link}"
        if [[ $? -ne 0 ]]; then
          echo -e "\e[1mERROR:\e[0m Error occured while linking executable ${link}. Aborting\n"
          exit 1
        fi
      fi
    done
  }

############################
# ADDON - CUSTOM PATCHES

  # Add and apply custom addon patches
  function addon_custom_patches() {

    local CURDIR
    local addon_builddir_name
    local addon_builddir_path

    # Get our current directory, since we will change it during patching process below
    # We want to go back here after having applied the patches
    CURDIR="${PWD}"

    # Check if the following folder exists, and proceed.
    if [[ -d "${WINE_ADDONS_ROOT}/../../${PATCHDIR}" ]]; then
      find "${WINE_ADDONS_ROOT}/../../${PATCHDIR}/" \( -iname "*.patch" -or -iname "*.diff" \) -exec cp -f {} "${WINE_ADDONS_ROOT}/${pkg_name}/" 2>/dev/null \;

      addon_builddir_name=$(ls -l "${WINE_ADDONS_ROOT}/${pkg_name}" | grep ^d | awk '{print $NF}')

      # TODO Expecting just one folder here. This method doesn't work with multiple dirs present
      if [[ $(echo ${addon_builddir_name} | wc -l) -gt 1 ]]; then
        echo -e "\e[1mERROR:\e[0m Multiple entries in addon build directory detected. Can't decide which one to use. Aborting\n"
        exit 1
      fi

      addon_builddir_path="${WINE_ADDONS_ROOT}/${pkg_name}/${addon_builddir_name}"

      cd "${addon_builddir_path}"
      for pfile in ../*.{patch,diff}; do
        if [[ -f ${pfile} ]]; then
          echo -e "Applying addon's patch: ${pfile}\n"
          patch -Np1 < ${pfile}
        fi

        if [[ $? -ne 0 ]]; then
          echo -e "\e[1mERROR:\e[0m Error occured while applying addon's patch '${pfile}'. Aborting\n"
          cd ${CURDIR}
          exit 1
        fi

      done

      cd "${CURDIR}"

    fi

  }

############################
# ADDON - CUSTOM HOOKS EXECUTION

  addon_custom_patches && \
  addon_posixpkgs
}

###########################################################

# Fetch extra package files

function fetch_extra_pkg_files() {

  local pkgname
  local pkgdir
  local extra_files_dir

  pkgname=${1}
  pkgdir=${2}
  extra_files_dir=${3}

  find ${extra_files_dir} -mindepth 1 -type f -exec cp -f {} ${pkgdir}/ \;

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
  local _pkg_gitbranch="${4}"
  local _git_commithash="${5}"
  local _pkg_gitver="${6}"
  local _pkg_debinstall="${7}"
  local _pkg_debcontrol="${8}"
  local _pkg_debrules="${9}"
  local _pkg_installfile="${10}"
  local _pkg_controlfile="${11}"
  local _pkg_rulesfile="${12}"
  local _pkg_deps_build="${13}"
  local _pkg_deps_runtime="${14}"
  local _pkg_debbuilder="${15}"
  local _pkg_debcompat="${16}"
  local _pkg_compatfile="${17}"

  local extra_files_dir=$(find "../../extra_files/" -type d -iname "${_pkg_name%-*}")

  if [[ -d ${extra_files_dir} ]]; then
    [[ ! -d "debian/source" ]] && mkdir -p "debian/source"
    fetch_extra_pkg_files ${_pkg_name} "debian/source" ${extra_files_dir}
  fi

############################
# COMMON - ARRAY PARAMETER FIX

# Separate array indexes correctly
# We have streamed all array indexes, separated
# by | symbol. We reconstruct the arrays here.

  function arrayparser_reverse() {

    local arrays
    local s
    local IFS
    local y

    arrays=(
    '_pkg_deps_build'
    '_pkg_deps_runtime'
    )

    for w in ${arrays[@]}; do
      s=\${${w}}

      IFS='|'
      y=0

      for t in $(eval printf '%s\|' ${s}); do
        eval ${w}[$y]=\"${t}\"
        let y++
      done
      unset IFS

    done
  }

  arrayparser_reverse

############################

  function pkg_installcheck() {

    local full_pkg_name_found

    full_pkg_name_found_return_code=$(echo $(dpkg -s "${1}" &>/dev/null)$?)

    # Bad and error-prone fallback
    if [[ ${full_pkg_name_found_return_code} -ne 0 ]]; then
      full_pkg_name_matches=$(dpkg --get-selections | awk '{print $1}' | grep ^${1} | wc -l)
      if  [[ ${full_pkg_name_matches} -ne 0 ]]; then
        full_pkg_name_found_return_code=0
      fi
    fi
    return ${full_pkg_name_found_return_code}
  }

############################

  echo -e "Starting compilation$(if [[ ! -v NO_INSTALL ]] || [[ ${_pkg_name} =~ ^meson|glslang$ ]]; then printf " & installation"; fi) of ${_pkg_name}\n"

############################

function get_locked_packages() {

  local _lock_pkgs

  # Generate a list of version-locked-dependencies
  if [[ ${#remote_packages_selected[@]} -gt 0 ]]; then

    for alt_remote_pkg in ${!remote_packages_selected[@]}; do
      alt_remote_version_lock_set=$(echo ${remote_packages_selected[${alt_remote_pkg}]} | awk -F '|' '{print $4}')

      if [[ ${alt_remote_version_lock_set} -eq 1 ]]; then
        _lock_pkgs+=(${alt_remote_pkg})
      fi

    done
  fi

  echo "${_lock_pkgs[*]}"
}

############################
# COMMON - PACKAGE DEPENDENCIES CHECK

# Check and install package related dependencies if they are missing

  function pkg_dependencies() {

    local _pkg_list
    local _pkg_type
    local _pkg_type_str
    local a
    local b
    local _validlist
    local _lock_pkgs
    local is_locked
    local IFS

    _pkg_list=("${1}")
    _pkg_type="${2}"

    _lock_pkgs=($(get_locked_packages))

    IFS=$'\n'
    _pkg_list=$(echo "${_pkg_list}" | sed 's/([^)]*)//g')
    unset IFS

    case ${_pkg_type} in
      buildtime)
        _pkg_type_str="build time"
        ;;
      runtime)
        _pkg_type_str="runtime"
        ;;
    esac

    if [[ ${_pkg_list[0]} == "empty" ]]; then
      return 0
    fi

    a=0
    # Generate a list of missing dependencies
    for p in ${_pkg_list[@]}; do

      is_locked=0

      for lock_pkg in "${_lock_pkgs[@]}"; do
        if [[ ${p%% *} == ${lock_pkg} ]]; then
          is_locked=1
          break 1
        fi
      done

      if [[ $(pkg_installcheck ${p%% *})$? -ne 0 ]] || [[ ${is_locked} -eq 1 ]]; then
        _validlist[$a]=${p%% *}
        let a++

        # Global array to track installed build dependencies
        if [[ ${_pkg_type} == "buildtime" ]]; then
          _buildpkglist[$z]=${p%% *}
          let z++
        fi
      fi
    done

    function pkg_remoteinstall() {
      sudo apt install -y ${1} &> /dev/null
    }

    function pkg_localinstall() {
      wget ${1} -O ${WINE_ADDONS_ROOT}/"${2}".deb
      sudo dpkg -i --force-all ${WINE_ADDONS_ROOT}/"${2}".deb
    }

    function pkg_configure() {
      if [[ $(sudo dpkg-reconfigure ${1} | grep "is broken or not fully installed") ]]; then
        if [[ -v ${2} ]]; then
          pkg_localinstall ${2} ${1}
        else
          pkg_remoteinstall ${1}
        fi
      fi
    }

    # Install missing dependencies, be informative
    b=0
    for _pkg_dep in ${_validlist[@]}; do
      echo -e "$(( $b + 1 ))/$(( ${#_validlist[*]} )) - Installing ${_pkg_name} ${_pkg_type_str} dependency ${_pkg_dep}"

      if [[ ${#remote_packages_selected[@]} -gt 0 ]]; then

        for alt_remote_pkg in ${!remote_packages_selected[@]}; do

          if [[ "${_pkg_dep}" == "${alt_remote_pkg}" ]]; then

            alt_remote_url=$(echo ${remote_packages_selected[${alt_remote_pkg}]} | awk -F '|' '{print $1}')
            alt_remote_version=$(echo ${remote_packages_selected[${alt_remote_pkg}]} | awk -F '|' '{print $3}')
            alt_remote_version_lock_set=$(echo ${remote_packages_selected[${alt_remote_pkg}]} | awk -F '|' '{print $4}')

            # If remote pkg is not installed
            if [[ $(pkg_installcheck ${alt_remote_pkg})$? -ne 0 ]]; then

              # TODO remove duplicate functionality
              repository_version=$(apt-cache show "${alt_remote_pkg}" 2>/dev/null | grep -m1 -oP "(?<=^Version: )[0-9|\.]*" | sed 's/\.//g')
              [[ ! -z ${repository_version} ]] && repository_version=0

              if [[ ${repository_version} -eq ${alt_remote_version} ]]; then
                echo -e "Already updated. Skipping"
                continue 1
              fi

              if [[ ${repository_version} -lt ${alt_remote_version} ]] || [[ ${alt_remote_version_lock_set} -eq 1 ]]; then
                pkg_localinstall "${alt_remote_url}" "${alt_remote_pkg}"
                pkg_configure "${alt_remote_pkg}" "${alt_remote_url}"
              else
                pkg_remoteinstall "${alt_remote_pkg}"
                pkg_configure "${alt_remote_pkg}"
              fi

            # If remote pkg is installed
            else
              local_version=$(dpkg -s "${alt_remote_pkg}" | grep -m1 -oP "(?<=^Version: )[0-9|\.]*" | sed 's/\.//g')
              [[ ! -z ${local_version} ]] && local_version=0

              if [[ ${local_version} -eq ${alt_remote_version} ]]; then
                echo -e "Already updated. Skipping"
                continue 1
              fi

              if [[ ${local_version} -lt ${alt_remote_version} ]] || [[ ${alt_remote_version_lock_set} -eq 1 ]]; then
                pkg_localinstall "${alt_remote_url}" "${alt_remote_pkg}"
                pkg_configure "${alt_remote_pkg}" "${alt_remote_url}"
              else
                pkg_remoteinstall "${alt_remote_pkg}"
                pkg_configure "${alt_remote_pkg}"
              fi
            fi
          fi
        done
      fi

      if [[ $(pkg_installcheck ${_pkg_dep})$? -ne 0 ]]; then
        pkg_remoteinstall "${_pkg_dep}"
        pkg_configure "${_pkg_dep}"
      fi

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
      git checkout ${_pkg_gitbranch}
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

    local contents
    local targetfile

    contents=${1}
    targetfile=${2}

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

      # Get all required submodules
      git submodule update --init --recursive

      dh_make --createorig -s -y -c ${_pkg_license} && \
      pkg_override_debianfile "${_pkg_debinstall}" "${_pkg_installfile}"
      pkg_override_debianfile "${_pkg_debcontrol}" "${_pkg_controlfile}"
      pkg_override_debianfile "${_pkg_debrules}" "${_pkg_rulesfile}"
      pkg_override_debianfile "${_pkg_debcompat}" "${_pkg_compatfile}"

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
    # We do not make installation optional for deps because they may be required by the addon
    if [[ $? -eq 0 ]]; then
      rm -rf ../*.{changes,buildinfo,tar.xz}
      if [[ ! -v NO_INSTALL ]]; then
        sudo dpkg -i ../${_pkg_name}*.deb
      fi
      mv ../${_pkg_name}*.deb ../../../compiled_deb/"${datedir}" && \
      echo -e "Compiled ${_pkg_name} is stored at '$(readlink -f ../../../compiled_deb/"${datedir}")/'\n"
      cd ../..
      rm -rf {${_pkg_name},*.deb}
    else
      buildpkg_removal
      exit 1
    fi

  }

############################
# COMMON - EXECUTION HOOKS

  pkg_dependencies "${_pkg_deps_build[*]}" buildtime

  if [[ ${_pkg_deps_runtime[0]} != "empty" ]] && [[ ! -v NO_INSTALL ]]; then
    pkg_dependencies "${_pkg_deps_runtime[*]}" runtime
  fi

  pkg_folderprepare

  # TODO use package name or separate override switch here?
  if [[ "${_pkg_name%-*}" == "dxvk" ]]; then
    addon_install_custom "dxvk_custom_patches"

  elif [[ "${_pkg_name%-*}" == "dxvk-nvapi" ]]; then
    addon_install_custom "dxvk-nvapi_custom_patches"

  elif [[ "${_pkg_name%-*}" == "vkd3d-proton" ]]; then
    addon_install_custom "vkd3d-proton_custom_patches"

  fi

  pkg_debianbuild

  unset _pkg_gitver

}

########################################################

# BUILD DEPENDENCIES REMOVAL

function buildpkg_removal() {

  _buildpkglist=($(echo ${_buildpkglist[@]} | tr ' ' '\n' |sort -u | tr '\n' ' '))

  for link in ${!tempLinks[@]}; do
    if [[ $(file ${link}) == *"symbolic link"* ]]; then
      sudo rm -f "${link}"
    fi
  done

  # Build time dependencies which were installed but no longer needed
  if [[ -v _buildpkglist ]]; then
    if [[ -v BUILDPKG_RM ]]; then
      sudo apt purge --remove -y ${_buildpkglist[*]}

      # In some cases, glslang or meson may still be present on the system. Remove them
      for _extrapkg in glslang meson; do
        if [[ $(echo $(dpkg -s ${_extrapkg} &>/dev/null)$?) -eq 0 ]]; then
          sudo dpkg --remove --force-remove-reinstreq ${_extrapkg}
        fi
      done
      # Manually obtained deb packages are expected to break system configuration, thus we need to fix it.
      sudo apt --fix-broken -y install

    else
      echo -e "The following build time dependencies were installed and no longer needed:\n\n$(for l in ${_buildpkglist[*]}; do echo -e ${l}; done)\n"
    fi
  fi
}

########################################################

# Package installation instructions

function pkg_install_main() {

  local pkg_datafile

  # Read necessary variables from debdata file
  pkg_datafile=${1}

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

    local pkg_arrays
    local IFS
    local s
    local t

    pkg_arrays=(
      'pkg_deps_build'
      'pkg_deps_runtime'
    )

    local IFS=$'\n'

    for w in ${pkg_arrays[@]}; do

      s=\${${w}[@]}
      t=$(eval printf '%s\|' ${s})
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
  "${pkg_gitbranch}" \
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
  "${pkg_debbuilder}" \
  "${pkg_debcompat}" \
  "${pkg_compatfile}"

}

########################################################

# Check existence of known Wine packages
runtime_check Wine "${known_wines[*]}"

# Meson - compile (& install)
pkg_compile_check pkg_install_main meson "${WINE_ADDONS_ROOT}/../debdata/meson.debdata"

# Glslang - compile (& install)
pkg_compile_check pkg_install_main glslang "${WINE_ADDONS_ROOT}/../debdata/glslang.debdata"

if [[ ! -v NO_DXVK ]]; then
  # DXVK - compile (& install)
  pkg_install_main "${WINE_ADDONS_ROOT}/../debdata/dxvk.debdata"
fi

if [[ ! -v NO_NVAPI ]]; then
  # DXVK NVAPI - compile (& install)
  pkg_install_main "${WINE_ADDONS_ROOT}/../debdata/dxvk_nvapi.debdata"
fi

if [[ ! -v NO_VKD3D ]]; then
  # VKD3D Proton - compile (& install)
  pkg_install_main "${WINE_ADDONS_ROOT}/../debdata/vkd3d_proton.debdata"
fi

# Clean buildtime dependencies
buildpkg_removal
