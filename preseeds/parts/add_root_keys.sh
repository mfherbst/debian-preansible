#!/bin/sh

mkdir -p 700 /target/root/.ssh
chown root:root /target/root/.ssh
cp /cdrom/preseeds/root_keys /target/root/.ssh/authorized_keys
chown root:root /target/root/.ssh/authorized_keys
exit 0
