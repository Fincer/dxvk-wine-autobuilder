#!/bin/env bash

#    Wrapper for DXVK & Wine compilation scripts
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
ROOTDIR="${PWD}"

# datedir variable supplied by ../updatewine.sh script file
datedir="${1}"

########################################################

# http://wiki.bash-hackers.org/snipplets/print_horizontal_line#a_line_across_the_entire_width_of_the_terminal
function INFO_SEP() { printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - ; }

########################################################

# Divide input args into array indexes
# These are passed to the subscripts (array b)
i=0
for p in ${@:2}; do
  params[$i]=${p}
  let i++
done

########################################################

# Parse input arguments, filter user parameters
# The range is defined in ../updatewine.sh
# All input arguments are:
# <datedir> 4*<githash_override> 4*<gitbranch_override> <args>
# 0         1 2 3 4              5 6 7 8                9...
# Filter all but <args>, i.e. the first 0-8 arguments

i=0
for arg in ${params[@]:8}; do
  args[$i]="${arg}"
  let i++
done

# All valid arguments given in ../updatewine.sh are handled...
# All valid arguments are passed to subscripts...
# ...but these are specifically used in this script
#
for check in ${args[@]}; do

  case ${check} in
    --no-wine)
      NO_WINE=
      ;;
    --no-staging)
      NO_STAGING=
      ;;
    --no-dxvk)
      NO_DXVK=
      ;;
    --no-pol)
      NO_POL=
      ;;
    --no-winetricks)
      NO_WINETRICKS=
      ;;
    --no-install)
      NO_INSTALL=
      # If this option is given, do not check PoL wineprefixes
      NO_POL=
      ;;
  esac

done

########################################################

# Create identifiable directory for this build

mkdir -p ${ROOTDIR}/compiled_deb/${datedir}

########################################################

# If the script is interrupted (Ctrl+C/SIGINT), do the following

function Deb_intCleanup() {
  cd ${ROOTDIR}
  rm -rf compiled_deb/${datedir}
  exit 0
}

# Allow interruption of the script at any time (Ctrl + C)
trap "Deb_intCleanup" INT

########################################################

# Check existence of ccache package

function ccacheCheck() {
  if [[ $(echo $(dpkg -s ccache &>/dev/null)$?) -ne 0 ]]; then
    echo -e "\e[1mNOTE:\e[0m Please consider installation of 'ccache' for faster compilation times if you compile repetitively.\nInstall it by typing 'sudo apt install ccache'\n"
  fi
}

ccacheCheck

########################################################

# Call Wine compilation & installation subscript in the following function

function wine_install_main() {

  echo -e "Starting compilation & installation of Wine$(if [[ ! -v NO_STAGING ]]; then printf " Staging"; fi)\n\n\
This can take up to 0.5-2 hours depending on the available CPU cores.\n\n\
Using $(nproc --ignore 1) of $(nproc) available CPU cores for Wine source code compilation.
"

  bash -c "cd ${ROOTDIR}/wineroot/ && bash ./winebuild.sh \"${datedir}\" \"${params[*]}\""

}

########################################################

# Call Winetricks compilation & installation subscript in the following function

function winetricks_install_main() {

  local pkg="winetricks"

  # Location of expected Winetricks deb archive from
  # the point of view of this script file
  local pkgdebdir=".."

  # Winetricks availability check
  function winetricks_availcheck() {

    local apt_searchcheck=$(apt-cache search ^${pkg}$ | wc -l)

    if [[ $(echo $(dpkg -s ${pkg} &>/dev/null)$?) -ne 0 ]]; then

      # TODO expecting only 1 match from apt-cache output
      if [[ ${apt_searchcheck} -eq 1 ]]; then
        sudo apt install -y ${pkg}
        if [[ $? -eq 0 ]]; then
          # Winetricks already installed by the previous command
          return 0
        else
          echo -e "\e[1mWARNING:\e[0m Can't install Winetricks from repositories. Trying to compile from source.\n"
          # TODO Force Winetricks compilation from source. Is this a good practice?
          return 1
        fi
      else
        # Multiple or no entries from apt-cache output. Can't decide which package to use, so force winetricks compilation.
        echo -e "\e[1mWARNING:\e[0m Can't install Winetricks from repositories. Trying to compile from source.\n"
        # TODO Force Winetricks compilation from source. Is this a good practice?
        return 1
      fi
    else
      # Winetricks already installed on the system
      echo -e "Winetricks is installed on your system. Use your package manager or 'debian_install_winetricks.sh' script to update it.\n"
      return 0
    fi
  }

  # Winetricks installation from local deb package
  function winetricks_localdeb() {

    # Check that Wine exists on the system. If yes, then
    # install other required winetricks dependencies
    # so that Winetricks install script won't complain about
    # missing them.
    #
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

    # Other winetricks dependencies
    local winetricks_deps=('cabextract' 'unzip' 'x11-utils')

    # If known wine is found, then check winetricks_deps and install them if needed.
    for winepkg in ${known_wines[@]}; do
      if [[ $(echo $(dpkg -s ${winepkg} &>/dev/null)$?) -eq 0 ]]; then
        for tricksdep in ${winetricks_deps[@]}; do
          if [[ $(echo $(dpkg -s ${tricksdep} &>/dev/null)$?) -ne 0 ]]; then
            sudo apt install -y ${tricksdep}
            if [[ $? -ne 0 ]]; then
              echo -e "\e[1mERROR:\e[0m Couldn't install Winetricks dependency ${tricksdep}. Skipping Winetricks installation.\n"
              # TODO revert installation of any installed 'tricksdep' installed on previous loop cycle
              if [[ ! -v NO_INSTALL ]];then
                echo -e "DXVK won't be installed\n"
                # We can set this value because winetricks function is intented to be called
                # after Wine compilation & installation BUT before DXVK install function
                # DXVK runtime (not build time) depends on Winetricks
                params+=('--no-install')
              fi
              # Special variable only to inform user about errors in Winetricks installation
              WINETRICKS_ERROR=
              return 1
            fi
          fi
        done
        # If known wine has already been found, do not iterate through other candidates
        break
      fi
    done

    # Check for existing winetricks deb archives in the previous folder
    local localdeb=$(find ${pkgdebdir} -type f -name "${pkg}*.deb" | wc -l)

    case ${localdeb} in
      0)
        # No old winetricks archives
        # Just fall through
        ;;
      1)
        # One old winetricks archive found
        echo -e "Found already compiled Winetricks archive, installing it.\n"
        # TODO ask user? Note that asking this limits the automation process of this script
        # unless a solution will be implemented (e.g. parameter switch)
        sudo dpkg -i ${pkgdebdir}/${pkg}*.deb
        return 0
        ;;
      *)
        # Multiple old winetricks archives found
        # Move them and compile a new one
        if [[ ! -d ${pkgdebdir}/winetricks_old ]]; then
          mkdir -p ${pkgdebdir}/winetricks_old
        fi
        mv ${pkgdebdir}/${pkg}*.deb ${pkgdebdir}/winetricks_old/
        if [[ $? -ne 0 ]]; then
          echo -e "\e[1mWARNING:\e[0m Couldn't move old Winetricks archives. Not installing Winetricks.\n"
          if [[ ! -v NO_INSTALL ]];then
            echo -e "DXVK won't be installed\n"
            # We can set this value because winetricks function is intented to be called
            # after Wine compilation & installation BUT before DXVK install function
            # DXVK runtime (not build time) depends on Winetricks
            params+=('--no-install')
          fi
        fi
        ;;
    esac

    echo -e "Starting compilation & installation of Winetricks\n"
    bash -c "cd .. && bash ./debian_install_winetricks.sh"

    if [[ $? -eq 0 ]]; then
      # The compiled Winetricks deb package is found in the previous folder
      sudo dpkg -i ${pkgdebdir}/${pkg}*.deb

      if [[ $? -ne 0 ]]; then
        echo -e "\e[1mWARNING:\e[0m Couldn't install Winetricks.\n"

        if [[ ! -v NO_INSTALL ]];then
          echo -e "DXVK won't be installed\n"
          # We can set this value because winetricks function is intented to be called
          # after Wine compilation & installation BUT before DXVK install function
          # DXVK runtime (not build time) depends on Winetricks
          params+=('--no-install')
        fi
        # Special variable only to inform user about errors in Winetricks installation
        WINETRICKS_ERROR=
        return 1
      fi
    else
      echo -e "\e[1mWARNING:\e[0m Couldn't compile Winetricks.\n"
      if [[ ! -v NO_INSTALL ]];then
        echo -e "DXVK won't be installed\n"
        # We can set this value because winetricks function is intented to be called
        # after Wine compilation & installation BUT before DXVK install function
        # DXVK runtime (not build time) depends on Winetricks
        params+=('--no-install')
      fi
      # Special variable only to inform user about errors in Winetricks compilation
      WINETRICKS_ERROR=
      return 1
    fi

  }

  winetricks_availcheck
  if [[ $? -ne 0 ]]; then
    winetricks_localdeb
  fi

}

########################################################

# Call DXVK compilation & installation subscript in the following function

function dxvk_install_main() {

  echo -e "Starting compilation & installation of DXVK\n\n\
This can take up to 10-20 minutes depending on how many dependencies we need to build for it.\n"

  bash -c "cd ${ROOTDIR}/dxvkroot && bash dxvkbuild.sh \"${datedir}\" \"${params[*]}\""

}

########################################################

function mainQuestions() {

  # General function for question responses
  function questionresponse() {

    local response=${1}

    read -r -p "" response
    if [[ $(echo $response | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo ""
      return 0
    else
      return 1
    fi

  }

##################################

  INFO_SEP

  echo -e "\e[1mINFO:\e[0m About installation\n\nThe installation may take long time because many development dependencies may be \
installed and the following packages may be compiled from source (depending on your choises):\n\n\
\t- Wine/Wine Staging (latest git version)\n\
\t- DXVK (latest git version)\n\
\t- meson & glslang (latest git versions; these are build time dependencies for DXVK)\n\n\
Do you want to continue? [Y/n]"

  questionresponse

  if [[ $? -ne 0 ]]; then
    echo -e "Cancelling.\n"
    exit 1
  fi

####################

  INFO_SEP

  echo -e "\e[1mQUESTION:\e[0m Do you want to remove unneeded build time dependencies after package build process? [Y/n]"

  questionresponse

  if [[ $? -eq 0 ]]; then
    params+=('--buildpkg-rm')
  fi

####################

  AVAIL_SPACE=$(df -h -B MB --output=avail . | sed '1d; s/[A-Z]*//g')
  REC_SPACE=8000

  if [[ ${AVAIL_SPACE} -lt ${REC_SPACE} ]] && [[ ! -v NO_WINE ]]; then
    INFO_SEP

  echo -e "\e[1mWARNING:\e[0m Not sufficient storage space\n\nYou will possibly run out of space while compiling software.\n\
The script strongly recommends ~\e[1m$((${REC_SPACE} / 1000)) GB\e[0m at least to compile software successfully but you have only\n\
\e[1m${AVAIL_SPACE} MB\e[0m left on the filesystem the script is currently placed at.\n\n\
Be aware that the script process may fail because of this, especially while compiling Wine Staging.\n\n\
Do you really want to continue? [Y/n]"

    questionresponse

    if [[ $? -ne 0 ]]; then
      echo -e "Cancelling.\n"
      exit 1
    fi

    unset AVAIL_SPACE REC_SPACE
  fi

####################

  # This question is relevant only if DXVK stuff is compiled
  if [[ ! -v NO_DXVK ]]; then
    INFO_SEP

    echo -e "\e[1mQUESTION:\e[0m Update existing dependencies?\n\nIn a case you have old build time dependencies on your system, do you want to update them?\n\
If you answer 'yes', then those dependencies are updated if needed. Otherwise, already installed\n\
build time dependencies are not updated. If you don't have 'meson' or 'glslang' installed on your system, they will be compiled, anyway.\n\
Be aware, that updating these packages may increase total run time used by this script.\n\n\
Update dependency packages & other system packages? [Y/n]"

    questionresponse

    if [[ $? -eq 0 ]]; then
      params+=('--updateoverride')
    fi

    INFO_SEP
  fi

}

########################################################

function coredeps_check() {

  # Universal core dependencies for package compilation
  _coredeps=('dh-make' 'make' 'gcc' 'build-essential' 'fakeroot')

  for coredep in ${_coredeps[@]}; do

    if [[ $(echo $(dpkg -s ${coredep} &>/dev/null)$?) -ne 0 ]]; then
      echo -e "Installing core dependency ${coredep}.\n"
      sudo apt install -y ${coredep}
      if [[ $? -ne 0 ]]; then
        echo -e "Could not install ${coredep}. Aborting.\n"
        exit 1
      fi
    fi
  done

}

########################################################

# If either Wine or DXVK is to be compiled
if [[ ! -v NO_WINE ]] || [[ ! -v NO_DXVK ]]; then
  mainQuestions
  coredeps_check
fi

####################

# If Wine is going to be compiled, then
if [[ ! -v NO_WINE ]]; then
  wine_install_main
else
  echo -e "Skipping Wine build$(if [[ ! -v NO_INSTALL ]]; then printf " & installation"; fi) process.\n"
fi

####################

# Run winetricks installation, if needed
if [[ ! -v NO_DXVK ]] && [[ ! -v NO_INSTALL ]]; then
  if [[ ! -v NO_WINETRICKS ]]; then
    winetricks_install_main
  else
    echo -e "Skipping Winetricks build & installation process.\n \
    DXVK will not be installed, unless Winetricks is already installed on your system.\n"
  fi
fi

####################

# If DXVK is going to be installed, then 
if [[ ! -v NO_DXVK ]]; then
  dxvk_install_main
else
  echo -e "Skipping DXVK build$(if [[ ! -v NO_INSTALL ]]; then printf " & installation"; fi) process.\n"
fi

####################

# If PlayOnLinux Wine prefixes are going to be updated, then
if [[ ! -v NO_POL ]]; then
  echo -e "\e[1mINFO:\e[0m Updating your PlayOnLinux Wine prefixes.\n"
  bash -c "cd ${ROOTDIR} && bash playonlinux_prefixupdate.sh"
fi

# If error occured during Winetricks script runtime, then
if [[ -v WINETRICKS_ERROR ]]; then
  echo -e "\e[1mWARNING:\e[0m Couldn't compile or install Winetricks.\
  $(if [[ ! -v NO_DXVK ]]; then printf " DXVK installation may have failed, too."; fi)\n"
fi
