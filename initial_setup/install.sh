sms_name=scc
sms_ip=10.0.1.5
sms_eth_internal=em0:0
eth_provision=em0
internal_netmask=255.255.255.0
#ntp_server=  # Local ntp server for time synchronization
bmc_username=ADMIN
bmc_password=ADMIN
num_computes=3
c_ip=( 10.0.1.{6..8} )
c_bmc=( 10.0.150.{6..8} )
c_name=( c{2..4} )
compute_regex=c[2-4]
compute_prefix=c
sms_ipoib=10.0.20.5
ipoib_netmask=255.255.255.0
c_ipoib=( 10.0.20.{6..8} )


echo ${sms_ip} ${sms_name} >> /etc/hosts

systemctl disable firewalld
systemctl stop firewalld

yum install http://build.openhpc.community/OpenHPC:/1.3/CentOS_7/x86_64/ohpc-release-1.3-1.el7.x86_64.rpm

yum -y install ohpc-base
yum -y install ohpc-warewulf

systemctl enable ntpd.service
# use the defaults instead
#echo "server ${ntp_server}" >> /etc/ntp.conf
systemctl restart ntpd 

yum -y install ohpc-slurm-server
perl -pi -e "s/ControlMachine=\S+/ControlMachine=${sms_name}/" /etc/slurm/slurm.conf
## edit slurm.conf to hardcode the node setup (sockets/cores/threads etc)
# /etc/slurm/slurm.conf
## note that to use the master as a compute node too, use NodeHostName for the 
## actual nodename (hostname -s) and NodeName for its alias, eg:
# NodeName=c1 NodeHostName=scc Sockets=2 CoresPerSocket=8 ThreadsPerCore=2 State=UNKNOWN

# also, if using master node as compute node, install the slurm client there:
#yum -y groupinstall ohpc-slurm-client
## slurmd is mysteriously missing from ohcp-slurm-group:
#yum -y install slurm-slurmd-ohpc
#systemctl enable munge
#systemctl enable slurmd

## optional, maybe skip if using Mellanox OFED stack:
#yum -y groupinstall "InfiniBand Support"
#yum -y install infinipath-psm
## Load IB drivers
#systemctl start rdma

# if using IB, setup IPoIB:
cp /opt/ohpc/pub/examples/network/centos/ifcfg-ib0 /etc/sysconfig/network-scripts
# Define local IPoIB address and netmask
perl -pi -e "s/master_ipoib/${sms_ipoib}/" /etc/sysconfig/network-scripts/ifcfg-ib0
perl -pi -e "s/ipoib_netmask/${ipoib_netmask}/" /etc/sysconfig/network-scripts/ifcfg-ib0
# Initiate ib0
ifup ib0 

## Configure Warewulf provisioning to use desired internal interface
# Enable tftp service for compute node image distribution
perl -pi -e "s/device = eth1/device = ${sms_eth_internal}/" /etc/warewulf/provision.conf 
perl -pi -e "s/^\s+disable\s+= yes/ disable = no/" /etc/xinetd.d/tftp
# Enable internal interface for provisioning
ifconfig ${sms_eth_internal} ${sms_ip} netmask ${internal_netmask} up
# Restart/enable relevant services to support provisioning
systemctl restart xinetd
systemctl enable mariadb.service
systemctl restart mariadb
systemctl enable httpd.service
systemctl restart httpd
systemctl enable dhcpd.service


