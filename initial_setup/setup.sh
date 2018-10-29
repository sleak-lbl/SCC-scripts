## important: must have mellanox stack already installed in head node!
export sms_ip=10.0.1.5
export imgname=centos7.5
export CHROOT=/opt/ohpc/admin/images/${imgname:?}
wwmkchroot centos-7 ${CHROOT:?}
# this is generally handy:
yum -y --installroot=${CHROOT:?} install yum

yum -y --installroot=${CHROOT:?} groupinstall ohpc-base-compute
cp -p /etc/resolv.conf ${CHROOT:?}/etc/resolv.conf

yum -y --installroot=${CHROOT:?} groupinstall ohpc-slurm-client
# slurmd is mysteriously missing from ohcp-slurm-group:
yum -y --installroot=${CHROOT:?} install slurm-slurmd-ohpc
rsync -av /etc/slurm ${CHROOT:?}/etc/
# make sure home dirs on each node match:
mkdir $CHROOT/export ; ln -s /home $CHROOT/export

# IB support was breaking on opa (omnipath) compatibility issues, so use 
# --skip-broken .. but it might not be needed anymore, since
# have yum removed opa-basic-tools opa-fastfabric so this 
yum -y --installroot=${CHROOT:?} --skip-broken groupinstall "InfiniBand Support" 
# skip this, we're using mlnx instead
#yum -y --installroot=${CHROOT:?} install infinipath-psm
# it looks like we actually do need this:
yum -y --installroot=${CHROOT:?} install libpsm2

yum -y --installroot=${CHROOT:?} install ntp 
yum -y --installroot=${CHROOT:?} install kernel
yum -y --installroot=${CHROOT:?} install lmod-ohpc

cat ~/.ssh/cluster.pub >> ${CHROOT:?}/root/.ssh/authorized_keys
echo "${sms_ip}:/export/home /home nfs nfsvers=3,rsize=1024,wsize=1024,cto 0 0" >> ${CHROOT:?}/etc/fstab
echo "${sms_ip}:/opt/ohpc/pub /opt/ohpc/pub nfs nfsvers=3 0 0" >> ${CHROOT:?}/etc/fstab
chroot ${CHROOT:?} systemctl enable ntpd
echo "server ${sms_ip}" >> ${CHROOT:?}/etc/ntp.conf
perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' ${CHROOT:?}/etc/security/limits.conf
perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' ${CHROOT:?}/etc/security/limits.conf
yum -y --installroot=${CHROOT:?} install mrsh-ohpc mrsh-rsh-compat-ohpc mrsh-server-ohpc
chroot ${CHROOT:?} systemctl enable xinetd
echo "*.* @${sms_ip}:514" >> ${CHROOT:?}/etc/rsyslog.conf 
perl -pi -e "s/^\*\.info/\\#\*\.info/" ${CHROOT:?}/etc/rsyslog.conf
perl -pi -e "s/^authpriv/\\#authpriv/" ${CHROOT:?}/etc/rsyslog.conf
perl -pi -e "s/^mail/\\#mail/" ${CHROOT:?}/etc/rsyslog.conf
perl -pi -e "s/^cron/\\#cron/" ${CHROOT:?}/etc/rsyslog.conf
perl -pi -e "s/^uucp/\\#uucp/" ${CHROOT:?}/etc/rsyslog.conf
# the mkchroot seems to pick up the mlnx stack if it is already installed
# on head node, so can skip this:
#mount --bind /tmp ${CHROOT:?}/tmp
#ls -l ${CHROOT:?}/etc/yum.repos.d # check it is there
# yum --installroot=${CHROOT:?} group install 'MLNX_OFED ALL-3.10.0-862.EL7.X86_64'
# umount ${CHROOT:?}/tmp
chroot ${CHROOT:?} systemctl enable openibd
chroot ${CHROOT:?} systemctl enable opensmd

# for xfs and orangefs, kernel needs to have support included, make sure the modules are in the image: 
rsync -av /lib/modules/3.10.0-862.el7.x86_64/kernel/fs ${CHROOT:?}/lib/modules/3.10.0-862.el7.x86_64/kernel/

# for orangefs:
rsync -av /opt/orangefs ${CHROOT:?}/opt --exclude storage
mkdir ${CHROOT:?}/opt/orangefs/storage
echo "/dev/sda1 /opt/orangefs/storage xfs defaults 0 0" >> ${CHROOT:?}/etc/fstab
# doesn't work:
#chroot ${CHROOT:?} systemctl enable orangefs-server

## make sure orange kernel module is findable:
##d=$(find /opt/orangefs -name pvfs2)
##echo $d
## and make sure it gets into the vnfs:
##cp -vr $d ${CHROOT:?}/lib/modules/3.10.0-862.el7.x86_64/kernel/fs

## only need to do this once:
## include xfs in vnfs:
#echo "modprobe += xfs" >> /etc/warewulf/bootstrap.conf
##d=$(find /opt/orangefs -name pvfs2)
##echo $d
## and make sure it gets into the vnfs:
##cp -vr $d /lib/modules/3.10.0-862.el7.x86_64/kernel/fs
#echo "modprobe += pvfs2" >> /etc/warewulf/bootstrap.conf



# rebuild the vfns:
wwvnfs --chroot ${CHROOT:?}
# provision nodes to use it:
wwsh provision set c[2-4] --vnfs=${imgname:?}

# setup ipoib for the compute nodes: (actually only needed once)
#wwsh file import /opt/ohpc/pub/examples/network/centos/ifcfg-ib0.ww
#wwsh file set ifcfg-ib0.ww --path=/etc/sysconfig/network-scripts/ifcfg-ib0
#wwsh node set c2 -D ib0 --ipaddr=10.0.20.6 --netmask=255.255.255.0
#wwsh node set c3 -D ib0 --ipaddr=10.0.20.7 --netmask=255.255.255.0
#wwsh node set c4 -D ib0 --ipaddr=10.0.20.8 --netmask=255.255.255.0
#wwsh provision set c[2-4] --fileadd=ifcfg-ib0.ww

# and reboot all nodes to take on the new image/provision:
#pdsh -w compute[0-5] shutdown -r now
#pdsh -w c[2-4] shutdown -r now
# or if really stuck:
# ipmitool -H 10.10.150.6 -U ADMIN -P ADMIN chassis power reset
# ipmitool -H 10.10.150.7 -U ADMIN -P ADMIN chassis power reset
# ipmitool -H 10.10.150.8 -U ADMIN -P ADMIN chassis power reset
