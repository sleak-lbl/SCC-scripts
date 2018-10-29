#!/bin/bash -x

/opt/orangefs/sbin/pvfs2-server -a c1 /opt/orangefs/etc/orangefs-server.conf
pdsh -w c[2-4] '/opt/orangefs/sbin/pvfs2-server -a $(uname -n) /opt/orangefs/etc/orangefs-server.conf'
modprobe pvfs2
pdsh -w c[2-4] 'modprobe pvfs2'
/opt/orangefs/sbin/pvfs2-client -p /opt/orangefs/sbin/pvfs2-client-core
pdsh -w c[2-4] /opt/orangefs/sbin/pvfs2-client -p /opt/orangefs/sbin/pvfs2-client-core
sleep 3
mount /global
pdsh -w c[2-4] mount /global
