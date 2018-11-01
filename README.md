# SCC-scripts

Scripts and notes for setting up SCC clusters

## Tips and gotchas from previous years

- at ISC, the students weren't given static IP addresses, a DHCP server assigned them
  - we can set up scc.nersc.gov to use a dhcp-assigned address too, try it

### Using a NUC as the head node

- nice idea, and convenient for the initial setup, but some things to be prepared for:
  - if making a partition alongside Windows, will probably need to shrink the C: volume 
    so centos installer can make a linux partition
    - in windows, disable hibernation, pagefile and system protection - these put files 
      at the back of the partition and prevent it from shrinking (can re-enable them 
      afterwards)
  - once install progresses, it will look for base repo etc. I had issue in that it 
    couldn't use the one on usb stick (not sure why, but maybe changing the grub.cfg 
    (and therefore the md5sum of the image) caused the problem)
    - can try pointing at iso saved on usb, if have it
    - or point to a mirror on www, eg  "http://mirror.centos.org/centos/7.2.1511/os/x86_64/" 
      .. however, if you see "error setting up base repository", it might be that 
      `/var/run/install/repo/repodata/repomd.xml` doesn't match what is at 
      `$wwwrepo/repodata/repomd.xml`
      - in which case you can fix it by wget repomd.xml from web repo, put it in 
        `/var/run/install/repo/repodata,` and reboot (you do need to reboot, and the fix 
        persists across it) - see 
        https://blog.hqcodeshop.fi/archives/308-CentOS-7.2-network-install-fail-Solved.html
    - `yum update ca_certificates` might also work
  - it doesn't have much memory! and even less storage, so it's good for provisioning but 
    not as a full head node
  - it's also really slow/underpowered
  - if using OrangeFS, and IB for compute nodes, it seems tempting to build OrangeFS with
    two interfaces (tcp, IB) .. don't do this! it slows everything down hugely. Just don't
    mount OrangeFS on the NUC

- only has one ethernet port, but can make virtual interfaces on it to mux the external 
  network, the internal net and the mgmt net. See
  http://www.tecmint.com/create-multiple-ip-addresses-to-one-single-network-interface/ and
  https://serverfault.com/questions/406123/second-ip-address-on-the-same-interface-but-on-a-different-subnet
  (basically: in `/etc/sysconfig/network-scripts` add a new file `ifcfg-em1:0`, mostly 
  copied from `ifcfg-em1` and stripped down. Include `bootproto="static"`, `defroute="no"`, 
  `device="em1:0"`, `ipaddr="10.10.150.4"`, `prefix=24` `gateway=128.55.216.1`.
  - note static ip for internal etc network
  - check it with ip addr

  - note that NetworkManager screws up this, and NAT, and who knows what else - disable it:
    ```
    systemctl stop NetworkManager
    systemctl disable NetworkManager
    ```


### Making and using the USB installer

- Unetbootin on Mac does not make a usb drive bootable, need to do that explicitly
  (2017, so might have been fixed now)

- in the iso, /EFI/boot/grub.cfg points to boot locations by label .. so the USB stick label 
  needs to match what is there 
  - if windows is involved at all, make sure label is short and all caps, eg "CENTOS7"
  - (with windows, can edit label by right clicking it in file explorer when stick is mounted)
  - use vim to edit grub.cfg so the label there matches the usb stick. Note it is case sensitive!

- the dvd iso seems to work better than the minimal install iso

- if the usb stick has room, copying the iso to the stick (yes so it is effectively there twice)
  can solve some problems later (especially with Windows, see NUC notes)

- 2018 motherboard didn't cope with some graphics setting in Centos, so we got to the grub screen
  and after that the screen flashed and everything froze. Hit 'e' to edit the grub line and remove 
  things like 'quiet' and graphicsy things. If all else fails, when installing Centos select the 
  "Troubleshooting" option and there is an "install simpler version" option there - that works.

### After first boot:

- If using NVMe SSD, kernel won't automagically see it

  `lspci` shows it, but `lsblk` does not

- Reason is that nvme.ko kernel module is needed

- for compute nodes: add:
  ```
  drivers += kernel/drivers/nvme/
  ```
  into `/etc/warewulf/bootstrap.conf` and re-create the vnfs

- check that date, timezone is correct / ntp doing correct thing

- probably need to disable selinux

### Security

- The attacks start almost immediately. First thing is to setup basic security:
  - in /etc/ssh/sshd_config set:
    ```
    PermitRootLogin no
    PasswordAuthentication no
    ```
  - If want to be paranoid, and users are only coming in from certain networks, can also do eg:
    ```
    AllowUsers *@128.55.216.*
    ```
  - then `systemctl restart sshd`

- At NERSC, setup MFA according to:
  https://docs.google.com/document/d/1X6DwPqL_k7Vf03GuUXSauCVyjTq9nJybidTWiKpz3rU/edit#heading=h.a57fl66lvr4t

- A NESSUS scan revealed some vulnerabilities:
  - SSH Weak Algorithms Supported: 
    ```
    arcfour
    arcfour128
    arcfour256
    ```
    See  https://www.centos.org/forums/viewtopic.php?t=59115 

  - SSH Server CBC Mode Ciphers Enabled - remove `*-cbc`

  - HTTP TRACE / TRACK Methods Allowed
    http://www.techstacks.com/howto/disable-tracetrack-in-apache-httpd.html

- General tips:
  - minimal install (don't run what you don't need)
  - no root ssh
  - no sudo (just su -, if necessary)
  - find the setuid programs, do we need them? remove setuid if not
  - make sure that nothing in root's $PATH is writable by root (or anyone)
  - know what normally runs on the system, and alert when something unusual appears (new name, new number of copies, etc)
  - `unset histfile` in bash is a bad sign! (someone is covering something)
  - lsof -i  .. check what is listening to network, does it need to be?


### Networking

- for compute nodes to be able to see outside network, need to setup NAT via iptables on master node:
```
sysctl -w net.ipv4.ip_forward=1   # do in /etc/sysctl.conf for persistent
sysctl -p    # to actually trigger it at runtime
[root@scc sleak]# iptables -X
[root@scc sleak]# iptables -F
[root@scc sleak]# iptables -t nat -X
[root@scc sleak]# iptables -t nat -F
[root@scc sleak]# iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
[root@scc sleak]# iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
[root@scc sleak]# iptables -t nat -I POSTROUTING -o enp3s0 -j MASQUERADE
```

- to persist iptables over reboot: (older sys v init.d method, but seems to be still correct way):
```
/sbin/service iptables save
```

- on compute node need:
  ```
   route add default gw 10.0.1.1
  ```
  - add it to the provisioning:
    `wwsh node set \* -D eth0 --gateway=xxx.xxx.xxx.xxx` for existing nodes
  - and/or, add it to `/etc/warewulf/defaults/node.conf` on master




### RPM dependency hell

- how to make a dummy rpm to fix false missing dependency
  ```
  mkdir -p ~/rpmbuild/{RPMS,SRPMS,BUILD,SOURCES,SPECS,tmp}
  cat <<EOF >~/.rpmmacros
  %_topdir   %(echo $HOME)/rpmbuild
  %_tmppath  %{_topdir}/tmp
  EOF
  cd ~/rpmbuild/SPECS


  [steve@scc SPECS]$ cat fixlibstcc++.spec
  Name:           fixlibstcc++.spec
  Version:        1.0.0
  Release:        0
  Summary:        adds missing symlink to /usr/lib64/libstdc++.so.6 from/usr/lib
  Group:          Development/Libraries
  License:        public domain
  Vendor:         Steve Leak
  Prefix:         %{_prefix}
  BuildRoot:      %{_tmppath}/%{name}-root
  Provides:     /usr/lib/libstdc++.so.6

  %description
  dummy package to meet a missing requires

  %files

  %post
  if  ! -e /usr/lib/libstdc++.so.6 ; then
    ln -s /usr/lib64/libstdc++.so.6 /usr/lib
  fi

  %postun
  if  -h /usr/lib/libstdc++.so.6 ; then
    rm /usr/lib/libstdc++.so.6
  fi

  [steve@scc SPECS]$ ll ../
  total 8
  drwxrwxr-x 8 steve steve 4096 May 29 03:09 BUILD
  drwxr-xr-x 2 steve steve   10 Jun  4 17:01 BUILDROOT
  drwxrwxr-x 4 steve steve   44 May 28 17:58 RPMS
  drwxrwxr-x 4 steve steve 4096 Jun  4 16:45 SOURCES
  drwxrwxr-x 2 steve steve   38 Jun  4 17:04 SPECS
  drwxrwxr-x 2 steve steve   10 May 28 06:20 SRPMS
  ```

- then:
  `rpmbuild -ba SPECS/intel-compxe-doc.spec`
  (if you have files, might need to create them under BUILDROOT)
  ```
  [steve@scc SPECS]$ cd ../RPMS/x86_64
  [steve@scc SPECS]$ sudo yum install fixlibstdc++.rpm
  ```

- here's another one that works for making rpm db believe a package is installed
  ```
  Name:           intel-compxe-doc.spec
  Version:        2016
  Release:        0
  Summary:        trick yum into thinking this dependency is met
  Group:          Development/Libraries
  License:        public domain
  Vendor:         Steve Leak
  Prefix:         %{_prefix}
  BuildRoot:      %{_tmppath}/%{name}-root
  Provides:       intel-compxe-doc

  %description
  dummy package to meet a missing requires

  %files
  %dir %attr(0755, root, root) "/opt/intel"

  %post

  %postun
  ```

