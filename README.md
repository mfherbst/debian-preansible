This project allows to add preseeded installation support to any Debian ``iso`` file, such that
the installation results in a Debian minimal system which can be used with ``ansible``.
The idea would then be to continue the installation using ``ansible`` mechanisms like playbooks, roles ....

# Usage
In order to use this package download an ``iso`` from debian, e.g. ``debian-testing-amd64-netinst.iso``. 
Then just add the preseed files using
```
./add_preseeds_to_iso.sh debian-testing-amd64-netinst.iso
```
This will add a new menu to the Debian Installer Boot Menu, namely **Preansible Debian automatic install**.

# Available installation types
In the preseed menu **Preansible Debian automatic install** from the Debian Installer Boot Screen
the following preseeded configurations are available:
	- *RootOnly*: Install a machine with a ``root`` account, but no other user account. 
			Partitioning is manual and the root password will be prompted for.
	- *RootOnlyNoAsk*: Completely automated install of just a ``root`` account. 
		The full disk will be formatted and the root password is ``r00tme``.
	- *SinleUser*: Again asks for partitioning and a password, but this time an admin user account is set up and root is disabled.

# Installed packages
In all cases the following packages are automatically installed:
	- openssh-server
	- sudo
