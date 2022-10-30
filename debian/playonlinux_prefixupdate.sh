#!/bin/env bash

#    Update PoL Wine prefixes (DXVK & Wine Staging) on Debian/Ubuntu/Mint
#    Copyright (C) 2018, 2022  Pekka Helenius
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

# Check existence of PoL default folder in user's homedir
if [[ ! -d "$HOME/.PlayOnLinux" ]]; then
  echo -e "\e[1mWARNING:\e[0m Couldn't find PoL directories in $USER's homedir.\n"
  exit 0
fi

# Install dxvk-git to every PlayOnLinux wineprefix
if [[ $? -eq 0 ]] && [[ ! -v NO_POL ]]; then

  for wineprefix in $(find $HOME/.PlayOnLinux/wineprefix -mindepth 1 -maxdepth 1 -type d); do
    if [[ -d ${wineprefix}/dosdevices ]]; then
    
      if [[ ! -v NO_DXVK ]]; then
        WINEPREFIX=${wineprefix} setup_dxvk install --symlink
      fi

      if [[ ! -v NO_NVAPI ]]; then
        WINEPREFIX=${wineprefix} setup_dxvk_nvapi install --symlink
      fi

      if [[ ! -v NO_VKD3D ]]; then
        WINEPREFIX=${wineprefix} setup_vkd3d_proton install --symlink
      fi
      
    fi
  done
fi

# If a new Wine Staging version was installed and 'System' version of Wine has been used in
# PoL wineprefix configurations, update those existing PoL wineprefixes
if [[ ! -v NO_POL ]]; then
  for wineprefix in $(find $HOME/.PlayOnLinux/wineprefix -mindepth 1 -maxdepth 1 -type d); do
    if [[ -d ${wineprefix}/dosdevices ]]; then

    # If VERSION string exists, skip updating that prefix.
      if [[ $(printf $(grep -ril "VERSION" ${wineprefix}/playonlinux.cfg &> /dev/null)$?) -ne 0 ]]; then
        WINEPREFIX=${wineprefix} wineboot -u
      fi
    fi
  done
fi
