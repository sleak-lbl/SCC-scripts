#!/bin/bash -x

#pdsh -w c[2-4] 'umount /global || {echo "ERROR could not umount /global" }' || exit
pdsh -w c[2-4] umount /global ||  echo "ERROR could not umount /global" 
umount /global || echo "ERROR could not umount /global"
pdsh -w c[2-4] killall -q pvfs2-client pvfs2-client-core
killall -q pvfs2-client pvfs2-client-core
sleep 3
pdsh -w c[2-4] rmmod pvfs2
rmmod pvfs2
## stop all clients before any servers!
pdsh -w c[2-4] killall pvfs2-server
killall pvfs2-server

