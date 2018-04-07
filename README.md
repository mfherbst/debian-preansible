This project allows to add preseeded installation support to any Debian ``iso`` file, such that
the installation results in a Debian minimal system which can be used with ``ansible``.
The idea would then be to continue the installation using ``ansible`` mechanisms like playbooks, roles ....

# Usage

## Downloading
In order to use this package, download an ``iso`` from debian, e.g. ``debian-testing-amd64-netinst.iso``. 
You can use the script ``./download_iso.sh`` for this.
It will download the ``iso`` as well as the ``sha512`` checksums and verify your download.
Just run for example
```
./download_iso.sh http://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-testing-amd64-netinst.iso
```

If you want to add the non-free firmware blobs to the iso image,
download additionally the appropriate tarball from
[cdimage.debian.org](http://cdimage.debian.org/cdimage/unofficial/non-free/firmware),
e.g.
```
./download_iso.sh http://cdimage.debian.org/cdimage/unofficial/non-free/firmware/testing/20180402/firmware.tar.gz
```
The script will add the firmware files to the iso automatically alongside the preseeds.

## Adding the preseeds
Then just add the preseed files using
```
./add_preseeds_to_iso.sh debian-testing-amd64-netinst.iso
```
This will ask you for your preferred locale and keyboard configuration.
It will also ask you for ssh keys to include in the installation image.
Those will be installed automatically to ``/root/.ssh/authorized_keys`` in some of the installation modes (see below).

# Available installation modes
Adding the preseeds using the aforementioned command adds a new menu to the Debian Installer Boot Menu, namely **Preansible Debian automatic install**.
It should contain the following preseeded configurations:

## RootOnly
Install a machine, ready for ``ansible``, which only has a ``root`` but no other user accounts.
During installation it will ask the following:
  - Hostname
  - Password for ``root``
  - Partitioning of your hard drives
  - Location where to install grub

After the installation ``root`` login is possible on the terminal via the provided password and login via ``ssh`` is possible using the preseeded ssh keys.

## RootOnlyNoAsk
Completely automated install yielding a ``root`` account, but no other user accounts.
It partitions the full hard drive, i.e. it **erases all data without asking** for confirmation.
``root`` login is only possible via ``ssh`` and the preseeded ssh keys.
The hostname is ``ansible.lan``, which may be overwritten using a properly configured dhcp server 
during the installation process.

## RootOnlyWeakPass
Same as *RootOnlyNoAsk*, but the ``root`` account is additionally assigned the
default password `r00tme`,
so login is possible via `ssh` and the terminal.
Needless to say that this is very **insecure**,
so only run the installation like this inside a local network and change
the password immediately after the installation has succeeded.

## SingleUser
Install a machine, which has a disabled ``root`` account as well as a user-configured admin account.
During installation we query for:
  - Hostname
  - Admin user name
  - Admin user password
  - Partitioning of your hard drive
  - Location where to install grub

No ssh keys are added to ``root`` in this case and only login to the admin user is possible.
Login can be accomplished both via ``ssh`` as well as the terminal.

# Installed packages
In all cases the following packages are automatically installed (next to debian minimal):
  - openssh-server
  - sudo
  - python3-apt

# Warning: What has been tested
These scripts have only been tested using ``jessie``, ``stretch`` and ``buster``
amd64 netinstall images.
They *should* also work for i386 or other images as well, but I have not tested this.
Please let me know if things break or work sucessfully there.
