#    Uninstall Wine-Staging, DXVK, meson & glslang buildtime deps on Debian
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

meson_deps=(
'dh-python'
'python3-setuptools'
'ninja-build'
)

#glslang_deps=(
# Nothing to remove actually, just python2.7 which is likely required by other packages
#)

wine_deps=(
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
'libxslt1-dev:i386'
'libxml2-dev:i386'
'libicu-dev:i386'
'libtiff-dev:i386'
'libcups2-dev:i386'
'libgnutls28-dev:i386'
'libgstreamer1.0-dev:i386'
'libgstreamer-plugins-base1.0-dev:i386'
)

dxvk_deps=(
'meson'
'glslang'
'gcc-mingw-w64-x86-64'
'gcc-mingw-w64-i686'
'g++-mingw-w64-x86-64'
'g++-mingw-w64-i686'
'mingw-w64-x86-64-dev'
'mingw-w64-i686-dev'
)

wine_deps_noremove=(
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
#'oss4-dev'
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

core_deps_noremove=(
'make' 'cmake' 'gcc' 'git' 'build-essential' 'fakeroot'
)

removals_name=('Meson' 'Wine Staging' 'DXVK')
removals=('${meson_deps[*]}' '${wine_deps[*]}' '${dxvk_deps[*]}')

echo -e "This script removes any development/build time dependencies related to Wine & DXVK\n"

i=0
for k in ${removals[*]}; do
  echo -e "\nRemoving ${removals_name[$i]} buildtime dependencies\n"
  sudo apt-get purge --remove $(eval echo ${k})
  let i++
done

echo -e "\nThe following Wine Staging buildtime dependencies were not removed:\n$(for o in ${wine_deps_noremove[*]}; do echo ${o}; done)\n"

echo -e "\nThe following core buildtime dependencies were not removed:\n$(for o in ${core_deps_noremove[*]}; do echo ${o}; done)\n"

read -r -p "Show list of auto removable packages which are no longer needed? [Y/n] " question

if [[ $(echo $question | sed 's/ //g') =~ ^([yY][eE][sS]|[yY])$ ]]; then
  sudo apt-get purge --autoremove
fi

