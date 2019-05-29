#!/bin/env bash

#    Set up Wine Staging + DXVK & D9VK on Arch Linux & Variants
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

########################################################

# DO NOT RUN INDIVIDUALLY, ONLY VIA ../updatewine.sh PARENT SCRIPT!

########################################################

# Root directory of this script file
ARCH_BUILDROOT="${PWD}"

# datedir variable supplied by ../updatewine.sh script file
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
git_commithash_d9vk=${params[1]}
git_commithash_wine=${params[4]}

git_branch_dxvk=${params[5]}
git_branch_d9vk=${params[6]}
git_branch_wine=${params[9]}

########################################################

# Parse input arguments, filter user parameters
# The range is defined in ../updatewine.sh
# All input arguments are:
# <datedir> 4*<githash_override> <args>
# 0         1 2 3 4              5 ...
# Filter all but <args>, i.e. the first 0-4 arguments

i=0
for arg in ${params[@]:8}; do
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
      # Do not check for PlayOnLinux wine prefixes
      NO_POL=
      ;;
    --no-wine)
      NO_WINE=
      ;;
    --no-dxvk)
      NO_DXVK=
      ;;
    --no-d9vk)
      NO_D9VK=
      ;;
    --no-pol)
      NO_POL=
      ;;
  esac

done

########################################################

# http://wiki.bash-hackers.org/snipplets/print_horizontal_line#a_line_across_the_entire_width_of_the_terminal
function INFO_SEP() { printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - ; }

###########################################################

# If the script is interrupted (Ctrl+C/SIGINT), do the following

function Arch_intCleanup() {
  rm -rf ${ARCH_BUILDROOT}/{0-wine-staging-git/{wine-patches,*.tar.xz},0-dxvk-git/{dxvk-git,*.tar.xz},0-d9vk-git/{d9vk-git,*.tar.xz}}
  exit 0
}

# Allow interruption of the script at any time (Ctrl + C)
trap "Arch_intCleanup" INT

# Error event
trap "Arch_intCleanup" ERR

###########################################################

# Check existence of ccache package

function ccacheCheck() {
  if [[ $(pacman -Q | awk '{print $1}' | grep -wE "ccache" | wc -l) -eq 0 ]]; then
    echo -e "\e[1mNOTE:\e[0m Please consider using 'ccache' for faster compilation times.\nInstall it by typing 'sudo pacman -S ccache'\n"
  fi
}

###########################################################

# Validate all core build files for Wine and/or DXVK exist

function checkFiles() {

  local wine_files=('30-win32-aliases.conf' 'PKGBUILD')
  local dxvk_files=('PKGBUILD')
  local d9vk_files=('PKGBUILD')

  function validatefiles() {

    local list=${1}
    local name=${2}
    local path=${3}

    for file in ${list[@]}; do
      if [[ ! -f "${path}/${file}" ]]; then
        echo -e "\e[1mERROR:\e[0m Could not locate file ${} for ${name}. Aborting\n"
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

  if [[ ! -v NO_D9VK ]]; then
    validatefiles "${d9vk_files[*]}" D9VK "${ARCH_BUILDROOT}/0-d9vk-git"
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
        echo -e "\e[91mERROR:\e[0m Dependency '${pkg}' not found, required by '${package}' (${file} => ${var})"
        let l++
      fi

    done

  done

  echo -e "\e[92m==>\e[0m\e[1m Dependency check for ${package} done.\e[0m\n"
}

function check_alldeps() {

  if [[ -v ERRPKGS ]]; then
    echo -e "\e[1mERROR:\e[0m The following dependencies are missing:\n\e[91m\
$(for o in ${ERRPKGS[@]}; do printf '%s\n' ${o}; done)\
\e[0m\n"
    exit 1
  fi

}

###########################################################

# Prepare building environment for the current runtime

function prepare_env() {

  # Copy Wine, DXVK & D9VK patch files
  cp -rf ${ARCH_BUILDROOT}/../wine_custom_patches ${ARCH_BUILDROOT}/0-wine-staging-git/wine-patches
  cp -rf ${ARCH_BUILDROOT}/../dxvk_custom_patches ${ARCH_BUILDROOT}/0-dxvk-git/dxvk-patches
  cp -rf ${ARCH_BUILDROOT}/../d9vk_custom_patches ${ARCH_BUILDROOT}/0-d9vk-git/d9vk-patches

  # Create identifiable directory for this build
  mkdir -p ${ARCH_BUILDROOT}/compiled_pkg/"${datedir}"

}

########################################################

# Parse Wine hash override if Staging is set to be installed

function check_gitOverride_wine() {

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
        echo -e "\e[1mERROR:\e[0m Couldn't access Wine folder ${commit_dir} to check commits. Aborting\n"
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
        echo -e "\e[1mERROR:\e[0m Couldn't parse Wine commits in ${commit_dir}. Aborting\n"
        exit 1
      fi

      cd "${ARCH_BUILDROOT}/0-wine-staging-git/"

    }

    function staging_change_freeze_commit() {

      local wine_commits_raw="git log --pretty=oneline | awk '{print \$1}' | tr '\n' ' '"

      # TODO this check may break quite easily
      # It depends on the exact comment syntax Wine Staging developers are using (Rebase against ...)
      # Length and order of these two "array" variables MUST MATCH!
      local staging_refcommits_raw="git log --pretty=oneline | awk '{ if ((length(\$NF)==40 || length(\$NF)==41) && \$(NF-1)==\"against\") print \$1; }'"
      local staging_rebasecommits_raw="git log --pretty=oneline | awk '{ if ((length(\$NF)==40 || length(\$NF)==41) && \$(NF-1)==\"against\") print substr(\$NF,1,40); }' | tr '\n' ' '"

      # Syntax: <function> <array_name> <raw_commit_list>
      commit_dir="${ARCH_BUILDROOT}/0-wine-staging-git/wine-git"
      form_commit_array wine_commits "${wine_commits_raw}"

      commit_dir="${ARCH_BUILDROOT}/0-wine-staging-git/wine-staging-git"
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
    git_branch_wine=master
    staging_change_freeze_commit

  elif [[ ! -v NO_STAGING ]] && [[ "${git_commithash_wine}" == HEAD ]]; then
    git_branch_wine=master
    git_commithash_winestaging=HEAD
  fi
}

###########################################################

function set_gitOverride() {
  local git_name=${1}
  local git_commithash=${2}
  local pkgbuild_file=${3}

  # Match string ${git_name}#commit=<replacethis>
  # where replace <replacethis>, but exclude ' " and ) after that
  #
  # TODO consider when there is nothing/no string after = symbol
  sed -i "s!\(${git_name}#commit=\)\(.*[^'|^\"|^\)]\)!\1${git_commithash}!" "${pkgbuild_file}"
}

###########################################################

# Remove any existing pkg,src or tar.xz packages left by previous pacman commands

function cleanUp() {
  rm -rf ${ARCH_BUILDROOT}/*/{pkg,src,*.tar.xz,*.patch,*.diff}
}

###########################################################

# Build & install package

function build_pkg() {

  local pkgname=${1}
  local pkgname_friendly=${2}
  local pkgdir=${3}
  local cleanlist=${4}

  # Create package and install it to the system
  # We need to download git sources beforehand in order
  # to determine git commit hashes
  cd "${ARCH_BUILDROOT}"/${pkgdir}
  bash -c "updpkgsums && makepkg -o"

  # Check git commit hashes
  if [[ $? -eq 0 ]] && \
  [[ ${5} == gitcheck ]]; then
    if [[ ${pkgname} == wine ]]; then
      check_gitOverride_wine

      local pkgbuild_file="${ARCH_BUILDROOT}/${pkgdir}/PKGBUILD"

      set_gitOverride "wine.git" "${git_commithash_wine}" ${pkgbuild_file}
      sed -i "s/\(^_wine_commit=\).*/\1${git_commithash_wine}/" ${pkgbuild_file}
      sed -i "s/\(^_git_branch_wine=\).*/\1${git_branch_wine}/" ${pkgbuild_file}

      if [[ ! -v NO_STAGING ]]; then
        set_gitOverride "wine-staging.git" "${git_commithash_winestaging}" ${pkgbuild_file}
        sed -i "s/\(^_staging_commit=\).*/\1${git_commithash_winestaging}/" ${pkgbuild_file}
      fi

    elif [[ ${pkgname} == dxvk ]]; then
      local pkgbuild_file="${ARCH_BUILDROOT}/${pkgdir}/PKGBUILD"
      set_gitOverride "dxvk.git" "${git_commithash_dxvk}" ${pkgbuild_file}
      sed -i "s/\(^_git_branch_dxvk=\).*/\1${git_branch_dxvk}/" ${pkgbuild_file}
      sed -i "s/\(^_dxvk_commit=\).*/\1${git_commithash_dxvk}/" ${pkgbuild_file}

    elif [[ ${pkgname} == d9vk ]]; then
      local pkgbuild_file="${ARCH_BUILDROOT}/${pkgdir}/PKGBUILD"
      set_gitOverride "d9vk.git" "${git_commithash_d9vk}" ${pkgbuild_file}
      sed -i "s/\(^_git_branch_d9vk=\).*/\1${git_branch_d9vk}/" ${pkgbuild_file}
      sed -i "s/\(^_d9vk_commit=\).*/\1${git_commithash_d9vk}/" ${pkgbuild_file}
    fi

  fi

  if [[ $? -eq 0 ]]; then bash -c "updpkgsums && makepkg"; else exit 1; fi

  # After successful compilation...
  if [[ $(ls ./${pkgname}-*tar.xz 2>/dev/null | wc -l) -ne 0 ]]; then

    if [[ ! -v NO_INSTALL ]]; then
      yes | sudo pacman -U ${pkgname}-*.tar.xz
    fi

    mv ${pkgname}-*.tar.xz ${ARCH_BUILDROOT}/compiled_pkg/${datedir}/ && \
    echo -e "\nCompiled ${pkgname_friendly} is stored at '$(readlink -f ${ARCH_BUILDROOT}/compiled_pkg/${datedir}/)/'\n"
    for rml in ${cleanlist[*]}; do
      rm -rf  "${ARCH_BUILDROOT}/${pkgdir}/${rml}"
    done

  else
    echo -e "\e[1mERROR:\e[0m Error occured during ${pkgname} compilation.\n"
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
      echo -e "\e[1mWARNING:\e[0m Couldn't find PoL directories in $USER's homedir.\n"
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

  # TODO remove duplicate functionality
  if [[ ! -v NO_DXVK ]]; then
    for wineprefix in $(find $HOME/.PlayOnLinux/wineprefix -mindepth 1 -maxdepth 1 -type d); do
      if [[ -d ${wineprefix}/dosdevices ]]; then
        WINEPREFIX=${wineprefix} setup_dxvk
      fi
    done
  fi
  if [[ ! -v NO_D9VK ]]; then
    for wineprefix in $(find $HOME/.PlayOnLinux/wineprefix -mindepth 1 -maxdepth 1 -type d); do
      if [[ -d ${wineprefix}/dosdevices ]]; then
        WINEPREFIX=${wineprefix} setup_d9vk
      fi
    done
  fi
}

##########################################################

# Clean these temporary folders & files

# TODO Shall we remove git folders or keep them?
dxvk_wine_cleanlist=('*.patch' '*.diff' 'pkg' 'src' '*-patches' '*.tar.xz')

##########################################################

# Validate all buildtime files
checkFiles

# Check whether we build Wine or Wine Staging
checkStaging

# Check whether we have ccache installed
ccacheCheck

# Clean all previous trash we may have
cleanUp

# Prepare building environment: copy patches and create timestamped folder for compiled packages
prepare_env

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

if [[ ! -v NO_D9VK ]]; then
  checkDepends "0-d9vk-git" "d9vk-git" depends makedepends
fi

check_alldeps

#########################

# Compile Wine & DXVK, depending on whether these packages
# are to be built

# Although the folder name is '0-wine-staging-git', we can still build vanilla Wine
if [[ ! -v NO_WINE ]]; then
  build_pkg wine "${wine_name}" "0-wine-staging-git" "${dxvk_wine_cleanlist[*]}" gitcheck
fi

if [[ ! -v NO_DXVK ]]; then
  build_pkg dxvk DXVK "0-dxvk-git" "${dxvk_wine_cleanlist[*]}" gitcheck
fi

if [[ ! -v NO_D9VK ]]; then
  build_pkg d9vk D9VK "0-d9vk-git" "${dxvk_wine_cleanlist[*]}" gitcheck
fi

#########################

# Update user's PlayonLinux wine prefixes if needed

if [[ ! -v NO_POL ]]; then
  echo -e "\e[1mINFO:\e[0m Updating your PlayOnLinux Wine prefixes.\n"
  updatePOL
fi
