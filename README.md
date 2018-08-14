# pol-wine-dxvk
Automate installation of the newest DXVK + Wine Staging into all your PlayonLinux wineprefixes (Arch Linux)

**IMPORTANT** Set your username correctly to _USER_ variable. This variable is defined at the beginning of `updatewine.sh` shell script.

## Usage

Run with sudo

```
sudo bash ./updatewine.sh
```

**NOTE:** All commands are executed as user (defined above). Only commands which require root permissions are ones which install packages wine-staging-git and dxvk into your system.

All regular user commands have prefix 'cmd' in the main script.

### Switches:

**--refresh**

- Check for new Staging/DXVK releases, update PoL Wine prefixes if needed

- Does a comparison between local & remote git repos

**--check**

- Check for new Staging/DXVK releases

- Does a comparison between local & remote git repos

**--force**

- Force Wine Staging & DXVK installation

---------------------------

### LICENSE

This repository uses GPLv3 license. See [LICENSE](https://github.com/Fincer/pol-wine-dxvk/) for details.
