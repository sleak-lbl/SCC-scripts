#!/bin/bash
# if compute nodes are powered down or jammed, kick them:
# ipmitool -H 10.10.150.6 -U ADMIN -P ADMIN chassis power cycle
# ipmitool -H 10.10.150.7 -U ADMIN -P ADMIN chassis power cycle
# ipmitool -H 10.10.150.8 -U ADMIN -P ADMIN chassis power cycle
# check if up with:
# pdsh -w c[2-4] uptime

systemctl restart opensm
./start_orange.sh
systemctl restart slurmd
pdsh -w c[2-4] systemctl restart slurmd
scontrol update nodename=c[1-4] state=resume
###
# now login as a user, and:
# cd /global/mpi-hello
# sbatch submitme.sh
#
# .. and check that it worked!
