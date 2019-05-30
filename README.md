# Wine/Wine Staging + DXVK & D9VK package builder & auto-installer

![](https://i.imgur.com/5WCPioZ.png)

Boost up your Wine experience with a taste of DXVK + D9VK and automate installation of [DXVK](https://github.com/doitsujin/dxvk), [D9VK](https://github.com/Joshua-Ashton/d9vk) + [Wine](https://www.winehq.org/)/[Wine Staging](https://github.com/wine-staging/wine-staging/) on Debian/Ubuntu/Mint/Arch Linux/Manjaro. Additionally, update your GPU drivers + PlayonLinux wineprefixes to use the latest Wine & DXVK + D9VK combination available.

## About

One-click solution for accessing bleeding-edge Wine/Wine Staging, DXVK & D9VK packages _system-widely_ on Debian/Ubuntu/Mint and on Arch Linux/Manjaro. Alternatively, you can pick any version of Wine/Wine Staging, DXVK & D9VK to be used.

![](https://i.imgur.com/Tqqi7pm.png)

_Wine Staging 3.20, DXVK and winetricks on Debian 9. Normally, no winetricks, DXVK or D9VK are available, and Wine is set to very old version 1.8.7 on Debian - leaving all the sweet candies out. Not anymore - let's end this misery and give user finally a choice._

## Motivation

**Accessibility, lower the barrier.** Help people to get their hands on the latest (bleeding-edge) Wine/Wine Staging, DXVK & D9VK software on major Linux distribution platforms without hassle or headaches.

There is not an easy way to auto-install the latest Wine/Wine Staging, DXVK & D9VK, especially on Debian/Ubuntu/Mint. The newest Wine/Wine Staging is not easily accessible on Debian-based Linux distributions, and DXVK/D9VK is practically bundled to Lutris or Steam gaming platform as a form of Proton. However, not all Windows programs, like MS Office or Adobe Photoshop, could run under Linux Steam client: Many Windows programs actually rely on system-wide Wine installation which is why system-wide Wine/Wine Staging, DXVK & D9VK auto-installation this script offers becomes quite handy.

The solution provided here _is independent from Steam client or any other Wine management platform_. The latest Wine/Wine Staging, DXVK & D9VK bundle will be accessible system-widely, not just via Steam, Lutris or PlayOnLinux. Provided PlayOnLinux prefix update is optional, as well.

----------------

## Adapt system-wide Wine/DXVK to your Steam Windows games

If you want to easily use Wine/Wine Staging and DXVK + D9VK with your Steam Windows games on Linux, you may want to check out my helper script [steam-launchoptions](https://github.com/Fincer/steam-launchoptions).

With the helper script, you can set launch options for a single game/selected group of games/all games you have on your Steam account. You can customize the launch options for both Windows and Linux games and clean all existing launch options, too.

----------------

## Contents

- **Wine/Wine Staging, DXVK & D9VK:** Installation script for supported Linux distributions

- **Nvidia drivers:** Installation script for supported Debian-based distributions. Independent script.

- **Winetricks install** Installation script for supported Debian-based distributions. Can be run independently.

- **Patches:** Possibility to use your custom patches with Wine, DXVK & D9VK

----------------

## Requirements

- **Linux Distribution:** Debian/Ubuntu/Mint OR Arch Linux/Manjaro. Variants may be compatible but they are not tested.

- **RAM:** 4096 MB (DXVK build process may fail with less RAM available)

- **Not listed as a hard dependency, but recommended for DXVK & D9VK**: The latest Nvidia or AMD GPU drivers (Nvidia proprietary drivers // AMDGPU)

- **Time:** it can take between 0.5-2 hours for the script to run. Compiling Wine takes _a lot of time_. You have been warned.

----------------

## Why to compile from source?

Latest version of Wine/Wine Staging, DXVK & D9VK are only available via git as source code which must be compiled before usage. Note that compiling Wine takes a lot of time. Compiling from source has its advantages and disadvantages, some of them listed below.

**Advantages:**

- packages are directly adapted to your system

- packages do not rely on PPAs which may be abandoned in time

- using Git sources provide the latest packages available publicly

**Disadvantages:**

- takes time & CPU processing power

- is unreliable in some cases, the script may break easily due to rapid DXVK development or distro changes

- may break working already-working versions of the packages (use `--no-install` parameter to avoid installation of DXVK/D9VK & Wine, just as precaution)

----------------

## Script usage

For short help instructions, run:

```
bash updatewine.sh --help
```

on the main script folder.

You can pass arguments like:

```
bash updatewine.sh --no-staging --no-install
```

All supported arguments are:

- `--no-staging` = Compile Wine instead of Wine Staging

- `--no-install` = Do not install Wine or DXVK, just compile them. Note that Wine must be installed for DXVK compilation.

- `--no-wine` = Do not compile or install Wine/Wine Staging

- `--no-dxvk` = Do not compile or install DXVK

- `--no-d9vk` = Do not compile or install D9VK

- `--no-pol` = Do not update current user's PlayOnLinux Wine prefixes

### Force/Lock package versions

You can force/lock specific Wine, Wine Staging, DXVK, D9VK, meson & glslang versions.

There are two switches for that: Set a specific **1)** _commit_ **2)** _git branch_ you want to use

This is handy if you encounter issues during package compilation (DXVK/glslang or meson, for instance). You should consider forcing package versions either by defining the latest git commit which still works for you or by using a specific git branch for your build. You can do this by specifying the following variables in `updatewine.sh`:

- Git commit:

    - `git_commithash_dxvk`, `git_commithash_d9vk`, `git_commithash_wine`, `git_commithash_glslang`, `git_commithash_meson`

- Git branch:

    - `git_branch_dxvk`, `git_branch_d9vk`, `git_branch_wine`, `git_branch_glslang`, `git_branch_meson`

**These settings apply only on Debian/Ubuntu/Mint:**

- `git_commithash_glslang`

- `git_commithash_meson`

- `git_branch_glslang`

- `git_branch_meson`

### Force/Lock package versions: How-to (git commit)

Take a look on `updatewine.sh`. You can find above variables listed there.

Each variable applies values which must be match package git commit tree. The value format is as follows:

- **A)** 40 characters long commit hash. Use this if you want this commit to be the latest to be used in package compilation, not anything after it.

    - defined in git commit tree: [DXVK commit tree](https://github.com/doitsujin/dxvk/commits/master), D9VK commit tree](https://github.com/Joshua-Ashton/d9vk/commits/master), [Wine commit tree](https://source.winehq.org/git/wine.git/) (or [GitHub mirror](https://github.com/wine-mirror/wine)), [glslang commit tree](https://github.com/KhronosGroup/glslang/commits/master), [meson commit tree](https://github.com/mesonbuild/meson/commits/master)

    - You can obtain proper hash by opening the commit. Hash syntax is: `654544e96bfcd1bbaf4a0fc639ef655299276a39` etc...

- **B)** keyword `HEAD`. This defined the specific package to use the latest commit available on repository (read: this is bleeding-edge version of the package)

Git commit version freezing can be used on all supported platforms (Debian/Ubuntu/Mint/Arch Linux/Manjaro).

### Force/Lock package versions: How-to (git branch)

Take a look on `updatewine.sh`. You can find above variables listed there.

Each variable applies values which must be match package git branch available. The value format is as follows:

- **A)** Default value: _master_. This git branch includes usually the latest updates for a package

- **B)** Custom value: _available branch_. Optionally, use a custom value. You can find valid branch names by checking the corresponding git package repository.

Git branch selection can be used on all supported platforms (Debian/Ubuntu/Mint/Arch Linux/Manjaro).

#### Force/Lock package versions: about Wine Staging

When you install Wine Staging and you define specific vanilla Wine commit in `git_commithash_wine` (not `HEAD`) variable, _the latest available Wine Staging version compared to that vanilla Wine commit is used_. Practically, this usually means even slightly older package version since the last matching Wine Staging commit usually doesn't match the commit you define for vanilla Wine. In most cases, this shouldn't be a problem.

Any other vanilla Wine git branch setting than _master_ will be ignored if Wine Staging is set to be compiled. _master_ branch is always used for Wine Staging compilation.

### Debian users: Winetricks installation

**NOTE:** This section doesn't concern Ubuntu or Mint users.

Since Debian doesn't provide winetricks package on official repositories, it is recommended that you use provided `debian_install_winetricks.sh` to install the latest Winetricks if needed.

----------------

## Custom patches for Wine, DXVK & D9VK

You can apply your own patches for DXVK, D9VK & Wine by dropping valid `.patch` or `.diff` files into `dxvk_custom_patches` (DXVK), `d9vk_custom_patches` (D9VK) or `wine_custom_patches` (Wine) folder.

Folders `dxvk_disabled_patches` and `wine_disabled_patches` are just for management purposes, they do not have a role in script logic at all.

Wine patches are not related to Wine Staging patchset. You can use your custom Wine patches either with Wine Staging or vanilla Wine.

### Distinguish Wine staging and non-staging patches

By using keywords `_staging` or `_nostaging` in your patch filename, you can quickly distinguish similar patches which are targeted either to Wine staging or Wine vanilla version.

----------------

## Compiled packages are stored for later usage

Successfully compiled Wine, DXVK & D9VK packages are stored in separate subfolders. Their locations are as follows.

On Debian/Ubuntu/Mint:

- `main-script-folder/debian/compiled_deb/`

On Arch Linux:

- `main-script-folder/arch/compiled_pkg/`

The actual subfolders which hold compiled programs are generated according to buildtime timestamp, known as `build identifier`.

## DXVK usage

**NOTE:** DXVK must be installed before applying these steps.

To enable DXVK on existing wineprefixes, just run

```
WINEPREFIX=/path/to/my/wineprefix setup_dxvk
```

## D9VK usage

**NOTE:** D9VK must be installed before applying these steps.

To enable D9VK on existing wineprefixes, just run

```
WINEPREFIX=/path/to/my/wineprefix setup_d9vk
```

## Add DXVK/D9VK to PlayOnLinux Wine prefixes

To install DXVK or D9VK on specific PlayOnLinux wineprefix which uses a different than `system` version of Wine, apply the following command syntax:

```
WINEPREFIX="$HOME/.PlayOnLinux/wineprefix/myprefix" WINEPATH=$HOME/.PlayOnLinux/wine/{linux-amd64,linux-x86}/wineversion/bin" setup_dxvk

WINEPREFIX="$HOME/.PlayOnLinux/wineprefix/myprefix" WINEPATH=$HOME/.PlayOnLinux/wine/{linux-amd64,linux-x86}/wineversion/bin" setup_d9vk
```

where you need to set either `linux-amd64` or `linux-x86`, and `wineversion` + `myprefix` to match real ones, obviously.

### Manually uninstall temporary development packages (Debian/Ubuntu/Mint):

Development packages can take extra space on your system so you may find useful to uninstall them. The script provides an automatic method for that but you can still use additional `debian_cleanup_devpkgs.sh` script which is targeted for uninstalling build time dependencies manually. The script uninstalls majority of Wine-Staging (Git), meson & glslang buildtime dependencies which may not be longer required. Be aware that while running the script, it doesn't consider if you need a development package for any other package compilation process (out of scope of Wine/DXVK)!

To use `debian_cleanup_devpkgs.sh`, simply run:

```
bash debian_cleanup_devpkgs.sh
```

---------------------------

### EXAMPLES:

**NOTE:** If `--no-install` option is given, the script doesn't check for PlayOnLinux Wine prefixes.

**NOTE:** PlayOnLinux Wine prefixes are checked for current user only.

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

**9)** Compile D9VK, and make an installable package for it. Install the package, do not check PlayOnLinux wineprefixes:

`bash updatewine.sh --no-wine --no-dxvk --no-pol`

----------------

## GPU drivers

For DXVK, it is strongly recommended that you install the latest Nvidia/AMDGPU drivers on your Linux distribution. For that purpose, Arch Linux/Manjaro users can use Arch/AUR package database. Debian/Ubuntu/Mint users should use provided scripts files

### GPU drivers on Debian/Ubuntu/Mint

**Nvidia users**

Use `debian_install_nvidia.sh` by running `bash debian_install_nvidia.sh`

**AMD users**

Not a solution provided yet.

**NOTE:** The latest GPU drivers are usually NOT available on official Debian/Ubuntu/Mint package repositories, thus these helper scripts are provided.

**NOTE:** Nvidia & AMD driver installer shell script can be run individually, as well. It is not bundled to the rest of the scripts in this repository, so feel free to grab them for other purposes, as well.

---------------------------

### NOTES

The following section contains important notes about the script usage.

**Do not pause a virtual machine**. It is not recommended to run this script in a virtualized environment (Oracle VirtualBox, for instance) if you plan to `Pause` the virtual machine during script runtime. This causes an internal sudo validate loop to get nuts. In normal environments and in normal runtime cases, this doesn't happen. Validate loop is required to keep sudo permissions alive for the script since the execution time exceeds default system-wide sudo timeout limit (which is a normal case).

---------------------------

### Script runtime test

Runtime test done for the script to ensure it works as expected. Occasional test-runs are mandatory due to rapid development of the packages (Wine/DXVK/D9VK) it handles.

**Latest test-run:** 30th May, 2019

**Linux Distributions:** 

- Success: Arch Linux 64-bit, Ubuntu 18.04 64-bit

- Failure: N/A

#### Failure reasons:

N/A

#### Notes:

N/A

---------------------------

### TODO

- Add compilation/installation script for the latest AMDGPU on Debian/Ubuntu/Mint

- Find a way to handle real error events (ignore silenced errors)

- Add info about selected commits and branches (if they have not been set to default)

- Unify error & warning messages layout, unify internal variable & function names

- Common script clean-up

- Better handling for sudo validation loop function

    - may cause the terminal output to get nuts

    - when interrupting the script, the exit functionality may not be handled correctly?

- The script doesn't handle SIGINT correctly while executing 'pkgdependencies' function

- Add non-interactive mode for Puppet, Ansible, SaltStack and for better automation?

    - Consider the following topics/issues while developing

        - supress any warning messages, or terminate script execution if requirements not met

        - supply sudo password or run as root?

        - sudo validation loop, how to handle correctly?

---------------------------

### LICENSE

This repository uses GPLv3 license. See [LICENSE](LICENSE) for details.
