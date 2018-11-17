#!/bin/env bash

#    Wine/Wine Staging build script for Debian & variants (amd64)
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

# datedir variable supplied by ../updatewine_debian.sh script file
datedir="${1}"

########################################################

# The directory this script is running at

BUILDROOT="${PWD}"

########################################################

# Staging patchsets. Default: all patchsets.
# Applies only if Wine Staging is set to be compiled
# Please see Wine Staging patchinstall.sh file for individual patchset names.
staging_patchsets=(--all)

########################################################

# Wine build dependency lists on Debian

wine_deps_build_common=(
'make'
'gcc-multilib'
'g++-multilib'
'libxml-simple-perl'
'libxml-parser-perl'
'libxml-libxml-perl'
'lzma'
'flex'
'bison'
'quilt'
'gettext'
# 'oss4-dev' # Not available on Debian
'sharutils'
'pkg-config'
'dctrl-tools'
'khronos-api'
'unicode-data'
'freebsd-glue'
'icoutils'
'librsvg2-bin'
'imagemagick'
'fontforge'
)

wine_deps_build_amd64=(
'libxi-dev:amd64'
'libxt-dev:amd64'
'libxmu-dev:amd64'
'libx11-dev:amd64'
'libxext-dev:amd64'
'libxfixes-dev:amd64'
'libxrandr-dev:amd64'
'libxcursor-dev:amd64'
'libxrender-dev:amd64'
'libxkbfile-dev:amd64'
'libxxf86vm-dev:amd64'
'libxxf86dga-dev:amd64'
'libxinerama-dev:amd64'
'libgl1-mesa-dev:amd64'
'libglu1-mesa-dev:amd64'
'libxcomposite-dev:amd64'
'libpng-dev:amd64'
'libssl-dev:amd64'
'libv4l-dev:amd64'
'libxml2-dev:amd64'
'libgsm1-dev:amd64'
'libjpeg-dev:amd64'
'libkrb5-dev:amd64'
'libtiff-dev:amd64'
'libsane-dev:amd64'
'libudev-dev:amd64'
'libpulse-dev:amd64'
'liblcms2-dev:amd64'
'libldap2-dev:amd64'
'libxslt1-dev:amd64'
'unixodbc-dev:amd64'
'libcups2-dev:amd64'
'libcapi20-dev:amd64'
'libopenal-dev:amd64'
'libdbus-1-dev:amd64'
'freeglut3-dev:amd64'
'libmpg123-dev:amd64'
'libasound2-dev:amd64'
'libgphoto2-dev:amd64'
'libosmesa6-dev:amd64'
'libpcap0.8-dev:amd64'
'libgnutls28-dev:amd64'
'libncurses5-dev:amd64'
'libgettextpo-dev:amd64'
'libfreetype6-dev:amd64'
'libfontconfig1-dev:amd64'
'libgstreamer-plugins-base1.0-dev:amd64'
'ocl-icd-opencl-dev:amd64'
'libvulkan-dev:amd64'
)

wine_deps_build_i386=(
'libxi-dev:i386'
'libxt-dev:i386'
'libxmu-dev:i386'
'libx11-dev:i386'
'libxext-dev:i386'
'libxfixes-dev:i386'
'libxrandr-dev:i386'
'libxcursor-dev:i386'
'libxrender-dev:i386'
'libxkbfile-dev:i386'
'libxxf86vm-dev:i386'
'libxxf86dga-dev:i386'
'libxinerama-dev:i386'
'libgl1-mesa-dev:i386'
'libglu1-mesa-dev:i386'
'libxcomposite-dev:i386'
'libpng-dev:i386'
'libssl-dev:i386'
'libv4l-dev:i386'
'libgsm1-dev:i386'
'libjpeg-dev:i386'
'libkrb5-dev:i386'
'libsane-dev:i386'
'libudev-dev:i386'
'libpulse-dev:i386'
'liblcms2-dev:i386'
'libldap2-dev:i386'
'unixodbc-dev:i386'
'libcapi20-dev:i386'
'libopenal-dev:i386'
'libdbus-1-dev:i386'
'freeglut3-dev:i386'
'libmpg123-dev:i386'
'libasound2-dev:i386'
'libgphoto2-dev:i386'
'libosmesa6-dev:i386'
'libpcap0.8-dev:i386'
'libncurses5-dev:i386'
'libgettextpo-dev:i386'
'libfreetype6-dev:i386'
'libfontconfig1-dev:i386'
'ocl-icd-opencl-dev:i386'
'libvulkan-dev:i386'
'libicu-dev:i386'
'libxml2-dev:i386'
'libxslt1-dev:i386'
'libtiff-dev:i386'
'libcups2-dev:i386'
'libgnutls28-dev:i386'
'gir1.2-gstreamer-1.0:i386' #required by libgstreamer1.0-dev:i386
'libgstreamer1.0-dev:i386'
'libgstreamer-plugins-base1.0-dev:i386'
)

########################################################

# Wine runtime dependency lists on Debian

wine_deps_runtime_common=(
'desktop-file-utils'
)

wine_deps_runtime_i386=(
'libxcursor1:i386'
'libxrandr2:i386'
'libxi6:i386'
# 'gettext:i386' # Conflicts with amd64 version on multiple distros
'libsm6:i386'
'libvulkan1:i386'
'libasound2:i386'
'libc6:i386'
'libfontconfig1:i386'
'libfreetype6:i386'
'libgcc1:i386'
'libglib2.0-0:i386'
'libgphoto2-6:i386'
'libgphoto2-port12:i386'
'liblcms2-2:i386'
'libldap-2.4-2:i386'
'libmpg123-0:i386'
'libncurses5:i386'
'libopenal1:i386'
'libpcap0.8:i386'
'libpulse0:i386'
'libtinfo5:i386'
'libudev1:i386'
'libx11-6:i386'
'libxext6:i386'
'libxml2:i386'
'ocl-icd-libopencl1:i386'
'zlib1g:i386'
'libgstreamer-plugins-base1.0-0:i386'
'libgstreamer1.0-0:i386'
)

wine_deps_runtime_amd64=(
'fontconfig:amd64'
'libxcursor1:amd64'
'libxrandr2:amd64'
'libxi6:amd64'
'gettext:amd64'
'libsm6:amd64'
'libvulkan1:amd64'
'libasound2:amd64'
'libc6:amd64'
'libfontconfig1:amd64'
'libfreetype6:amd64'
'libgcc1:amd64'
'libglib2.0-0:amd64'
'libgphoto2-6:amd64'
'libgphoto2-port12:amd64'
'liblcms2-2:amd64'
'libldap-2.4-2:amd64'
'libmpg123-0:amd64'
'libncurses5:amd64'
'libopenal1:amd64'
'libpcap0.8:amd64'
'libpulse0:amd64'
'libtinfo5:amd64'
'libudev1:amd64'
'libx11-6:amd64'
'libxext6:amd64'
'libxml2:amd64'
'ocl-icd-libopencl1:amd64'
'zlib1g:amd64'
'libgstreamer-plugins-base1.0-0:amd64'
'libgstreamer1.0-0:amd64'
)

########################################################

# Wine staging override list
# Wine Staging replaces and conflicts with these packages
# Applies to debian/control file

wine_overr_pkgs=(
'wine'
'wine-development'
'wine64-development'
'wine1.6'
'wine1.6-i386'
'wine1.6-amd64'
'libwine:amd64'
'libwine:i386'
'wine-stable'
'wine32'
'wine64'
'fonts-wine'
)

############################

# Suggests section in debian/control file

wine_suggested_pkgs=(
'winbind'
'winetricks'
'playonlinux'
'wine-binfmt'
'dosbox'
)

############################

# Package name and website

if [[ ! -v NO_STAGING ]]; then
  pkgname="wine-staging-git"
else
  pkgname="wine-git"
fi

pkgurl="https://www.winehq.org"

########################################################

# Architecture check. We do not support independent
# i386 environments

if [[ $(uname -a | grep -c x86_64) -eq 0 ]]; then
  echo "This script supports 64-bit architectures only."
  exit 1
fi

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
git_commithash_wine=${params[3]}

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
    --no-staging)
      NO_STAGING=
      ;;
    --no-install)
      NO_INSTALL=
      ;;
    --buildpkg-rm)
      BUILDPKG_RM=
      ;;
  esac

done

########################################################

# If the script is interrupted (Ctrl+C/SIGINT), do the following

function Wine_intCleanup() {
  cd "${BUILDROOT}"
  rm -rf "winebuild_${datedir}"
  exit 0
}

# Allow interruption of the script at any time (Ctrl + C)
trap "Wine_intCleanup" INT

########################################################

# This is specifically for Debian
# Must be done in order to install Wine i386 buildtime dependencies on amd64 environment
#
if [[ $(dpkg --print-foreign-architectures | grep i386 | wc -w) -eq 0 ]]; then
  sudo dpkg --add-architecture i386
  sudo apt update
fi

########################################################

# If user has gstreamer girl (amd64) package installed on the system
# before Wine compilation, then reinstall it after the compilation process
#
function girl_check() {

  girlpkg="gir1.2-gstreamer-1.0:amd64"

  if [[ $(echo $(dpkg -s ${girlpkg} &>/dev/null)$?) -eq 0 ]]; then
    GIRL_CHECK=
  fi
}

########################################################

function getWine() {

  local winesrc_url="git://source.winehq.org/git/wine.git"
  local winestagingsrc_url="git://github.com/wine-staging/wine-staging.git"

  function cleanOldBuilds() {
    if [[ $(find "${BUILDROOT}" -type d -name "winebuild_*" | wc -l) -ne 0 ]]; then
      echo -e "Removing old Wine build folders. This can take a while.\n"
      rm -rf "${BUILDROOT}"/winebuild_*
    fi
  }

  cleanOldBuilds

##########

  mkdir "${BUILDROOT}/winebuild_${datedir}"
  cd "${BUILDROOT}/winebuild_${datedir}"
  WINEROOT="${PWD}"

##########

  echo -e "Retrieving source code of Wine$(if [[ ! -v NO_STAGING ]]; then echo ' & Wine Staging' ; fi)\n"

  git clone ${winesrc_url}
  if [[ ! -v NO_STAGING ]]; then
    git clone ${winestagingsrc_url}
    WINEDIR_STAGING="${WINEROOT}/wine-staging"
  fi

##########

  mkdir wine-{patches,32-build,32-install,64-build,64-install,package}
  cp -r ../../../wine_custom_patches/*.{patch,diff} wine-patches/ 2>/dev/null

  WINEDIR="${WINEROOT}/wine"
  WINEDIR_PATCHES="${WINEROOT}/wine-patches"
  WINEDIR_BUILD_32="${WINEROOT}/wine-32-build"
  WINEDIR_BUILD_64="${WINEROOT}/wine-64-build"
  WINEDIR_INSTALL_32="${WINEROOT}/wine-32-install"
  WINEDIR_INSTALL_64="${WINEROOT}/wine-64-install"
  WINEDIR_PACKAGE="${WINEROOT}/wine-package"

}

function getDebianFiles() {

  local debian_archive=wine_3.0-1ubuntu1.debian.tar.xz

  cd "${WINEDIR}"
  wget http://archive.ubuntu.com/ubuntu/pool/universe/w/wine/${debian_archive}
  tar xvf ${debian_archive}
  rm ${debian_archive}

}

########################################################

# Parse Wine hash override if Staging is set to be installed

function check_gitOverride() {

  # If staging is to be installed and Wine git is frozen to a specific commit
  # We need to determine exact commit to use for Wine Staging
  # to avoid any mismatches
  #
  # Basically, when user has defined 'git_commithash_wine' variable (commit), we
  # iterate through Wine commits and try to determine previously set
  # Wine Staging commit. We use that Wine Staging commit instead of
  # the one user has defined in 'git_commithash_wine' variable
  #
  if [[ ! -v NO_STAGING ]] && [[ "${git_commithash_wine}" != HEAD ]]; then

    function form_commit_array() {

      cd "${commit_dir}"

      if [[ $? -ne 0 ]]; then
        echo -e "Error: couldn't access Wine folder ${commit_dir} to check commits. Aborting\n"
        exit 1
      fi

      local array_name=${1}
      local commits_raw=$(eval ${2})

      local i=0
      for commit in ${commits_raw[*]}; do
        eval ${array_name}[$i]="${commit}"
        let i++
      done

      if [[ $? -ne 0 ]]; then
        echo -e "Error: couldn't parse Wine commits in ${commit_dir}. Aborting\n"
        exit 1
      fi

      cd "${WINEROOT}"

    }

    function staging_change_freeze_commit() {

      local wine_commits_raw="git log --pretty=oneline | awk '{print \$1}' | tr '\n' ' '"

      # TODO this check may break quite easily
      # It depends on the exact comment syntax Wine Staging developers are using (Rebase against ...)
      # Length and order of these two "array" variables MUST MATCH!
      local staging_refcommits_raw="git log --pretty=oneline | awk '{ if ((length(\$NF)==40 || length(\$NF)==41) && \$(NF-1)==\"against\") print \$1; }'"
      local staging_rebasecommits_raw="git log --pretty=oneline | awk '{ if ((length(\$NF)==40 || length(\$NF)==41) && \$(NF-1)==\"against\") print substr(\$NF,1,40); }' | tr '\n' ' '"

      # Syntax: <function> <array_name> <raw_commit_list>
      commit_dir="${WINEDIR}"
      form_commit_array wine_commits "${wine_commits_raw}"

      commit_dir="${WINEDIR_STAGING}"
      form_commit_array staging_refcommits "${staging_refcommits_raw}"
      form_commit_array staging_rebasecommits "${staging_rebasecommits_raw}"

      # User has selected vanilla Wine commit to freeze to
      # We must get the previous Staging commit from rebase_commits array, and
      # change git_commithash_wine value to that

      # Get all vanilla Wine commits
      # Filter all newer than defined in 'git_commithash_wine'
      #
      echo -e "Determining valid Wine Staging git commit. This takes a while.\n"
      local i=0
      for dropcommit in ${wine_commits[@]}; do
        if [[ "${dropcommit}" == "${git_commithash_wine}" ]]; then
          break
        else
          local wine_dropcommits[$i]="${dropcommit}"
          let i++
        fi
      done
      wine_commits=("${wine_commits[@]:${#wine_dropcommits[*]}}")

      # For the filtered array list, iterate through 'staging_rebasecommits' array list until
      # we get a match
      for vanilla_commit in ${wine_commits[@]}; do
        local k=0
        for rebase_commit in ${staging_rebasecommits[@]}; do
          if [[ "${vanilla_commit}" == "${rebase_commit}" ]]; then
            # This is the commit we use for vanilla Wine
            git_commithash_wine="${vanilla_commit}"
            # This is equal commit we use for Wine Staging
            git_commithash_winestaging="${staging_refcommits[$k]}"
            break 2
          fi
        let k++
        done
      done

    }
  elif [[ ! -v NO_STAGING ]] && [[ "${git_commithash_wine}" == HEAD ]]; then
    git_commithash_winestaging=HEAD
  fi
  staging_change_freeze_commit
}

########################################################

# Wine dependencies removal/installation

# Global variable to track buildtime dependencies
z=0

function WineDeps() {

  local method=${1}
  local deps="${2}"
  local depsname=${3}
  local pkgtype=${4}

  case ${method} in
    install)
      local str="Installing"
      local mgrcmd="sudo apt install -y"
      ;;
    remove)
      local str="Removing"
      local mgrcmd="sudo apt purge --remove -y"
      ;;
    *)
      echo -e "Error: Unknown package management input method. Aborting\n"
      exit 1
  esac

  echo -e "${str} Wine dependencies (${depsname}).\n"

  # Check and install/remove package related dependencies if they are missing/installed
  function pkgdependencies() {

    local deplist="${1}"

    # Get a valid logic for generating 'list' array below
    case ${method} in
      install)
        # Package is not installed, install it
        local checkstatus=0
        ;;
      remove)
        # Package is installed, remove it
        local checkstatus=1
        ;;
    esac

    # Generate a list of missing/removable dependencies, depending on the logic
    local a=0
    for p in ${deplist[@]}; do
      if [[ $(echo $(dpkg -s ${p} &>/dev/null)$?) -ne ${checkstatus} ]]; then
        local validlist[$a]=${p}
        let a++

        # Global array to track installed build dependencies
        if [[ ${method} == "install" ]] && [[ ${pkgtype} == "buildtime" ]]; then
          buildpkglist[$z]=${p}
          let z++
        fi

      fi
    done

    # Install missing/Remove existing dependencies, be informative
    local b=0
    for pkgdep in ${validlist[@]}; do
      echo -e "$(( $b + 1 ))/$(( ${#validlist[*]} )) - ${str} ${depsname} dependency ${pkgdep}"
      eval ${mgrcmd} ${pkgdep} &> /dev/null
      if [[ $? -eq 0 ]]; then
        let b++
      else
        echo -e "\nError occured while processing ${pkgdep}. Aborting.\n"
        exit 1
      fi
    done
    if [[ -n ${validlist[*]} ]]; then
      # Add empty newline
      echo ""
    fi
  }

  pkgdependencies "${deps[*]}"

}

########################################################

# Feed the following data to Wine debian/control file

# If we separate i386 build to be an independent one, this function
# must be improved, if built with amd64 package together
# If we just bundle them together, single package description for
# debian/control file is enough

function feed_debiancontrol() {

cat << CONTROLFILE > debian/control
Source: ${pkgname}
Section: otherosfs
Priority: optional
Maintainer: ${USER} <${USER}@unknown>
Build-Depends: debhelper (>=9), $(echo "${wine_deps_build[*]}" | sed 's/\s/, /g')
Standards-Version: 4.1.2
Homepage: ${pkgurl}

Package: ${pkgname}
Architecture: any
Depends: $(echo ${wine_deps_runtime[*]} | sed 's/\s/, /g')
Suggests: $(echo ${wine_suggested_pkgs[*]} | sed 's/\s/, /g')
Conflicts: $(echo ${wine_overr_pkgs[*]} | sed 's/\s/, /g')
Breaks: $(echo ${wine_overr_pkgs[*]} | sed 's/\s/, /g')
Replaces: $(echo ${wine_overr_pkgs[*]} | sed 's/\s/, /g')
Provides: $(echo ${wine_overr_pkgs[*]} | sed 's/\s/, /g')
Description: A compatibility layer for running Windows programs.
 Wine is an open source Microsoft Windows API implementation for
 POSIX-compliant operating systems, including Linux.
 Git version includes the latest updates available for Wine.

CONTROLFILE

}

########################################################

# Refresh Wine GIT

function refreshWineGIT() {

  # Restore the wine tree to its git origin state, without wine-staging patches
  # (necessary for reapllying wine-staging patches in succedent builds,
  # otherwise the patches will fail to be reapplied)
  cd "${WINEDIR}"
  git reset --hard ${git_commithash_wine} # Get Wine commit
  if [[ $? -ne 0 ]]; then
    echo "Error: couldn't find git commit '${git_commithash_wine}' for Wine. Aborting\n"
    exit 1
  fi
  git clean -d -x -f # Delete untracked files

  if [[ ! -v NO_STAGING ]]; then

    if [[ ${git_commithash_wine} == HEAD ]]; then
      # Change back to the wine upstream commit that this version of wine-staging is based on
      git checkout $(bash "${WINEDIR_STAGING}"/patches/patchinstall.sh --upstream-commit)

    else
      cd "${WINEDIR_STAGING}"
      git reset --hard ${git_commithash_winestaging}
      if [[ $? -ne 0 ]]; then
        echo "Error: couldn't find git commit '${git_commithash_winestaging}' for Wine Staging. Aborting\n"
        exit 1
      fi
    fi
  fi
}

########################################################

# Get Wine version tag

function wine_version() {
  cd "${WINEDIR}"
  git describe | sed 's/^[a-z]*-//; s/-[0-9]*-[a-z0-9]*$//'
}

########################################################

# Apply patches

function patchWineSource() {

  if [[ ! -v NO_STAGING ]]; then
    bash "${WINEDIR_STAGING}/patches/patchinstall.sh" DESTDIR="${WINEDIR}" ${staging_patchsets[*]}
  fi

  cp -r ${WINEROOT}/../../../wine_custom_patches/* "${WINEDIR_PATCHES}/"

  if [[ $(find "${WINEDIR_PATCHES}" -mindepth 1 -maxdepth 1 -regex ".*\.\(patch\|diff\)$") ]]; then
    cd "${WINEDIR}"
    for i in "${WINEDIR_PATCHES}"/*.{patch,diff}; do
        patch -Np1 < $i
    done
  fi

}

########################################################

# 64-bit build

function wine64Build() {

  cd "${WINEDIR_BUILD_64}"
  "${WINEDIR}"/configure \
  --with-x \
  --with-gstreamer \
  --enable-win64 \
  --with-xattr \
  --disable-mscoree \
  --with-vulkan \
  --prefix=/usr \
  --libdir=/usr/lib/x86_64-linux-gnu/
  make -j$(nproc --ignore 1)

  make -j$(nproc --ignore 1) prefix="${WINEDIR_INSTALL_64}/usr" \
  libdir="${WINEDIR_INSTALL_64}/usr/lib/x86_64-linux-gnu/" \
  dlldir="${WINEDIR_INSTALL_64}/usr/lib/x86_64-linux-gnu/wine" install

}

# 32-bit build

function wine32Build() {

  cd "${WINEDIR_BUILD_32}"
  "${WINEDIR}"/configure \
  --with-x \
  --with-gstreamer \
  --with-xattr \
  --disable-mscoree \
  --with-vulkan \
  --libdir=/usr/lib/i386-linux-gnu/ \
  --with-wine64="${WINEDIR_BUILD_64}" \
  --prefix=/usr
  make -j$(nproc --ignore 1)

  make -j$(nproc --ignore 1) prefix="${WINEDIR_INSTALL_32}/usr" \
  libdir="${WINEDIR_INSTALL_32}/usr/lib/i386-linux-gnu/" \
  dlldir="${WINEDIR_INSTALL_32}/usr/lib/i386-linux-gnu/wine" install

}

########################################################

# Merge compiled files, build Debian archive
# Prepare compiled Wine for dpkg-buildpackage

function mergeWineBuilds() {

  cp -r "${WINEDIR_INSTALL_64}"/* "${WINEDIR_PACKAGE}"/

  cp -r "${WINEDIR_INSTALL_32}"/usr/bin/{wine,wine-preloader} "${WINEDIR_PACKAGE}"/usr/bin/
  cp -r "${WINEDIR_INSTALL_32}"/usr/lib/* "${WINEDIR_PACKAGE}"/usr/lib/

}

############################

# Trigger Wine compilation process
# Create a new deb package

function buildDebianArchive() {
  cd "${WINEROOT}"
  mv "${WINEDIR_PACKAGE}" "${WINEROOT}/${pkgname}-$(wine_version)"
  cd "${WINEROOT}/${pkgname}-$(wine_version)"
  dh_make --createorig -s -y -c lgpl
  rm debian/*.{ex,EX}
  printf "usr/* /usr" > debian/install

  feed_debiancontrol

  # Start compilation process
  DEB_BUILD_OPTIONS="strip nodocs noddebs" dpkg-buildpackage -b -us -uc

}

############################

# Install created deb package

function installDebianArchive() {
  cd "${WINEROOT}"
  # TODO Although the package name ends with 'amd64', this contains both 32 and 64 bit Wine versions
  echo -e "\nInstalling Wine$(if [[ ! -v NO_STAGING ]]; then printf " Staging"; fi).\n"
  sudo dpkg -i ${pkgname}_$(wine_version)-1_amd64.deb
}

############################

# Store deb package for later use

function storeDebianArchive() {
  cd "${WINEROOT}"
  mv ${pkgname}_$(wine_version)-1_amd64.deb ../../compiled_deb/"${datedir}" && \
  echo -e "Compiled ${pkgname} is stored at '$(readlink -f ../../compiled_deb/"${datedir}")/'\n"
  rm -rf winebuild_${datedir}
}

############################

# Clean temporary build files

function cleanTree() {
  rm -rf "${WINEROOT}"
}

########################################################

# Check presence of Wine if compiled deb is going to be installed
# This function is not relevant if --no-install switch is used

function wineCheck() {

  # Known Wine package names to check on Debian
  local known_wines=(
  'wine'
  'wine32'
  'wine64'
  'wine-git'
  'wine-staging-git'
  'libwine:amd64'
  'libwine:i386'
  'fonts-wine'
  )

  # Check if any of these Wine packages are present on the system
  for winepkg in ${known_wines[@]}; do
    if [[ $(echo $(dpkg -s ${winepkg} &>/dev/null)$?) -eq 0 ]]; then
      sudo apt purge --remove -y ${winepkg}
    fi
  done

}

########################################################

# Check existence of gstreamer girl package before further operations
girl_check

############################

# Get Wine (& Wine-Staging) sources
getWine

############################

# Check whether we need to update possible hash override
check_gitOverride

############################

# Refresh & sync Wine (+ Wine Staging) git sources
refreshWineGIT

# Update Wine source files
patchWineSource

# Get Wine/Wine Staging version
getWineVersion

########################################################

# Compile 64 & 32 bit Wine/Wine Staging

# WE MUST BUILD 64-BIT FIRST, THEN 32-BIT. THIS ORDER IS MANDATORY!

# We split 64-bit & 32-bit compilation due to two major reasons:
# - pure Debian has major conflicts between 32/64 bit dev packages
# - on Mint/Ubuntu, some 32-bit dev packages must be excluded due to conflicts, too

##########################

# Install Wine common buildtime dependencies
WineDeps install "${wine_deps_build_common[*]}" "Wine common build time" buildtime

##########################

# TODO If we do architecture separation in the future, add if check for amd64 here
# Condition would be: if amd64, then
#
# Purge i386 buildtime dependencies
# On Debian, we can't have them with i386 at the same time
#
echo -e "Preparing system environment for 64-bit Wine compilation.\n"
WineDeps remove "${wine_deps_build_i386[*]}" "Wine build time (32-bit)" buildtime

WineDeps install "${wine_deps_build_amd64[*]}" "Wine build time (64-bit)" buildtime
wine64Build && \
echo -e "\nWine 64-bit build process finished.\n"

##########################

# TODO If we do architecture separation in the future, add if check for i386 here
# Condition would be: if i386 or amd64, then
# 
# Purge amd64 buildtime dependencies
# On Debian, we can't have them with i386 at the same time
#
echo -e "Preparing system environment for 32-bit Wine compilation.\n"
WineDeps remove "${wine_deps_build_amd64[*]}" "Wine build time (64-bit)" buildtime

WineDeps install "${wine_deps_build_i386[*]}" "Wine build time (32-bit)" buildtime
wine32Build &&
echo -e "\nWine 32-bit build process finished.\n"

############################

# Remove i386 buildtime dependencies after successful compilation process
WineDeps remove "${wine_deps_build_i386[*]}" "Wine build time (32-bit)" buildtime

############################

# i386/amd64 runtime dependencies have been tested and they are able to co-exist on Debian system

if [[ ! -v NO_INSTALL ]]; then

  # Install Wine common runtime dependencies
  WineDeps install "${wine_deps_runtime_common[*]}" "Wine common runtime" runtime

  # Install architecture-dependent Wine runtime dependencies
  WineDeps install "${wine_deps_runtime_amd64[*]}" "Wine runtime (64-bit)" runtime
  WineDeps install "${wine_deps_runtime_i386[*]}" "Wine runtime (32-bit)" runtime

  # Check presence of already installed Wine packages and remove them
  wineCheck

fi

############################

# Build time dependencies which were installed but no longer needed
if [[ -v buildpkglist ]]; then
  if [[ -v BUILDPKG_RM ]]; then
    sudo apt purge --remove -y ${buildpkglist[*]}
  else
    echo -e "The following build time dependencies were installed and no longer required:\n\n$(for l in ${buildpkglist[*]}; do echo -e ${l}; done)\n"
  fi
fi

############################

if [[ -v GIRL_CHECK ]]; then
  sudo apt install -y ${girlpkg}
fi

########################################################

# Bundle compiled Wine/Wine-Staging files
mergeWineBuilds

# Bundle and install Debian deb archive
buildDebianArchive

if [[ ! -v NO_INSTALL ]]; then
  installDebianArchive
fi

storeDebianArchive

# Clean all temporary files
cleanTree
