# Wine/Wine Staging & DXVK package builder & auto-installer

Automate installation of the newest DXVK + Wine Staging, and optionally update all your PlayonLinux wineprefixes (Ubuntu/Mint/Arch Linux/Manjaro)

## About

This script bundle offers an easy-way solution to use the bleeding edge Wine Staging & DXVK packages system-wide on Ubuntu/Mint and Arch Linux based Linux distributions.

## Motivation

**Accessibility, lower the barrier.** My personal motivation to develop this script bundle was to lower the barried to people to get their hands on the latest bleeding-edge Wine / Wine Staging & DXVK versions on major Linux distribution platforms.

I have seen that there is not a clear way to install Wine Staging Git & DXVK, especially on Ubuntu/Mint. Therefore, I decided someone has to do something, so this script bundle was born.

Additionally, the benefits of the bleeding-edge Wine/Wine Staging & DXVK versions are quite limited at the moment. Wine Staging is not easily available on Debian-based Linux distributions, and DXVK is practically bundled to Lutris or Steam gaming platform as a form of Proton. We have to keep in mind that not all Windows programs are run under Steam on Linux but many programs are run via PlayOnLinux or without relying on any other third-party management software.

The solution I provide here _is not bundled to any commercial or other Wine management platform_. The latest Wine/Wine Staging & DXVK bundle is available system-wide, not just Steam, Lutris or PlayOnLinux.

----------------

## Requirements

- Ubuntu, Mint or any other Linux distribution which uses `dpkg` and `àpt` for package management

    - pure Debian is not supported yet

- Arch Linux, Manjaro or any other Linux distribution which uses `pacman` for package management

- **Not listed as a hard dependency, but actually required by DXVK**: The latest Nvidia or AMD GPU drivers. Personally, I've used proprietary Nvidia drivers & AMDGPU (not AMDGPU Pro). 

----------------

## Why to compile from source?

**Advantages:**
- packages are directly adapted to your system
- packages do not rely on PPAs which may be abandoned in time
- using Git sources provide the latest packages available publicly

**Disadvantages:**
- takes time & CPU processing
- is unreliable in some cases, the script may break easily due to rapid DXVK development or distro changes
- may break working already-working versions of the packages (use `--no-install` parameter to avoid installation of DXVK & Wine)

----------------

## Script usage

For instructions, run:

```
bash updatewine.sh --help
```

on the main script folder.

You can pass arguments like:

```
bash updatewine.sh --no-staging --no-install
```

All supported arguments are:

- `--no-staging` = Build Wine instead of Wine Staging

- `--no-install` = Do not install Wine or DXVK, just compile them. Note that Wine must be installed for DXVK compilation.

- `--no-wine` = Do not compile or install Wine/Wine Staging

- `--no-dxvk` = Do not compile or install DXVK

- `--no-pol` = Do not update current user's PlayOnLinux Wine prefixes

----------------

## Compiled packages are stored for later usage

Successfully compiled Wine & DXVK packages are stored as follows:

On Ubuntu/Mint:

- `main script folder/debian/compiled_deb/`

On Arch Linux:

- `main script folder/arch/compiled_pkg/`

The subfolders there are generated according to buildtime timestamp, known as `build identifier`

## DXVK usage

**NOTE:** DXVK must be installed before applying these steps!

To enable DXVK on existing wineprefixes, just run

```
WINEPREFIX=/path/to/my/wineprefix setup_dxvk
```

`winetricks` is required for this command. 

## Add DXVK to PlayOnLinux Wine prefixes

To install DXVK on specific PlayOnLinux wineprefix which uses a different than `system` version of Wine, apply the following command syntax:

```
WINEPREFIX="$HOME/.PlayOnLinux/wineprefix/myprefix" WINEPATH=$HOME/.PlayOnLinux/wine/{linux-amd64,linux-x86}/wineversion/bin" setup_dxvk
```

where you need to set either `linux-amd64` or `linux-x86` and set `wineversion` to match a real one, obviously.

system-wide `winetricks` executable (`/usr/bin/winetricks`) is required for this command.

### Uninstall temporary development packages (Ubuntu/Mint etc. only):

Development packages can take extra space on your system so you may find useful to uninstall them.
This package comes with `debian_devpkgremoval.sh` script which is targeted for that purpose.
It uninstalls majority of Wine-Staging (Git), meson & glslang buildtime dependencies.

To use `debian_devpkgremoval.sh`, simply run:

```
bash debian_devpkgremoval.sh
```

---------------------------

### EXAMPLES:

**NOTE:** If `--no-install` option is given, the script doesn't check for PlayOnLinux Wine prefixes.

**NOTE:** PlayOnLinux Wine prefixes is checked for current user only.

**1)** Compile Wine Staging & DXVK, and make installable packages for them. Install the packages:

`bash updatewine.sh`

**2)** Compile DXVK and make an installable package for it. Do not install:

`bash updatewine.sh --no-wine --no-install`

**3)** Compile Wine Staging and make an installable package for it. Do not install:

`bash updatewine.sh --no-dxvk --no-install`

**4)** Compile Wine and make an installable package for it. Do not install:

`bash updatewine.sh --no-staging --no-dxvk --no-install`

**5)** Compile Wine & DXVK, and make installable packages for them. Do not install:

`bash updatewine.sh --no-staging --no-install`

**6)** Compile Wine Staging & DXVK, and make installable packages for them. Do not install:

`bash updatewine.sh --no-install`

**7)** Compile Wine & DXVK, and make installable packages for them. Install the packages:

`bash updatewine.sh --no-staging`

**8)** Compile Wine, and make an installable package for it. Install the package, do not check PlayOnLinux wineprefixes:

`bash updatewine.sh --no-staging --no-dxvk --no-pol`

---------------------------

### NOTES

**NOTE: Do not pause a virtual machine**. It is not recommended to run this script in a virtualized environment (Oracle VirtualBox, for instance) if you plan to `Pause` the virtual machine during script runtime. This causes an internal sudo validate loop to get nuts. In normal environments and in normal runtime cases, this doesn't happen. Validate loop is required to keep sudo permissions alive for the script since the execution time exceeds default system-wide sudo timeout limit.

---------------------------

### Test-run validation

This is validation test done for the script. This test is to ensure it works as expected. It is mandatory due to rapid development of the packages it handles.

**Latest test-run:** 11th November, 2018

**Linux Distributions:** 

- Success: Arch Linux, Linux Mint 19

- Failure: Debian 9 (Wine), Ubuntu 18.04 (DXVK)

#### Failure reasons:

Debian:

  - conflicting amd64/i386 Wine build time dependency packages, must find workaround for this

  - no winetricks package

Ubuntu 18.04:

- during DXVK compilation, the following error appears:

```
...
[162/192] Compiling C++ object 'src/d3d11/src@d3d11@@d3d11@sha/d3d11_swapchain.cpp.obj'.
FAILED: src/d3d11/src@d3d11@@d3d11@sha/d3d11_swapchain.cpp.obj 
x86_64-w64-mingw32-g++ -Isrc/d3d11/src@d3d11@@d3d11@sha -Isrc/d3d11 -I../../../../src/d3d11 -I../../../.././include -fdiagnostics-color=always -pipe -Wall -Winvalid-pch -Wnon-virtual-dtor -std=c++1z -O3 -DNOMINMAX  -MD -MQ 'src/d3d11/src@d3d11@@d3d11@sha/d3d11_swapchain.cpp.obj' -MF 'src/d3d11/src@d3d11@@d3d11@sha/d3d11_swapchain.cpp.obj.d' -o 'src/d3d11/src@d3d11@@d3d11@sha/d3d11_swapchain.cpp.obj' -c ../../../../src/d3d11/d3d11_swapchain.cpp
{standard input}: Assembler messages:
{standard input}:3269: Warning: end of file not at end of a line; newline inserted
{standard input}: Error: open SEH entry at end of file (missing .seh_endproc)
x86_64-w64-mingw32-g++: internal compiler error: Killed (program cc1plus)
...

```

or

```
...
[137/192] Compiling C++ object 'src/d3d11/src@d3d11@@d3d11@sha/d3d11_view_uav.cpp.obj'.
FAILED: src/d3d11/src@d3d11@@d3d11@sha/d3d11_view_uav.cpp.obj 
x86_64-w64-mingw32-g++ -Isrc/d3d11/src@d3d11@@d3d11@sha -Isrc/d3d11 -I../../../../src/d3d11 -I../../../.././include -fdiagnostics-color=always -pipe -Wall -Winvalid-pch -Wnon-virtual-dtor -std=c++1z -O3 -DNOMINMAX  -MD -MQ 'src/d3d11/src@d3d11@@d3d11@sha/d3d11_view_uav.cpp.obj' -MF 'src/d3d11/src@d3d11@@d3d11@sha/d3d11_view_uav.cpp.obj.d' -o 'src/d3d11/src@d3d11@@d3d11@sha/d3d11_view_uav.cpp.obj' -c ../../../../src/d3d11/d3d11_view_uav.cpp
x86_64-w64-mingw32-g++: internal compiler error: Killed (program cc1plus)
Please submit a full bug report,
with preprocessed source if appropriate.
See <https://gcc.gnu.org/bugs/> for instructions.
[144/192] Compiling C++ object 'src/d3d11/src@d3d11@@d3d11@sha/d3d11_context.cpp.obj'.
ninja: build stopped: subcommand failed.
...
```

---------------------------

### TODO

- Add support for pure Debian. Main issue is conflicting amd64/i386 Wine buildtime packages

    - Workaround must be found, maybe split single Wine deb package into two, with suffixes amd64 & i386?

    - For pure Debian, package 'winetricks' must be compiled, too

- Add compilation scripts for the latest AMDGPU & Nvidia drivers on Arch Linux/Debian/Ubuntu/Mint

- Remove temp folders in case of failure (meson/glslang/dxvk-git/wine... temp build folders)

- Add support for custom DXVK patches

- Add proper license information for meson, glslang, Wine & DXVK

- Add option (?): do not store compiled packages, just install them

- Better handling for sudo validation loop function

    - may cause the terminal output to get nuts

    - when interrupting the script, the exit functionality may not be handled correctly?

---------------------------

### LICENSE

This repository uses GPLv3 license. See [LICENSE](LICENSE) for details.
