%define git_repo dhcp
%define git_head HEAD

%define _catdir /var/cache/man

%define major_version    4.2.5
%define patch_version    P1

Name:		dhcp
Epoch:		3
Version:	%git_get_ver
Release:	%mkrel %git_get_rel2
Summary:	The ISC DHCP (Dynamic Host Configuration Protocol) server/relay agent/client
License:	Distributable
Group:		System/Servers
URL:		http://www.isc.org/software/dhcp
Source:		%git_bs_source %{name}-%{version}.tar.gz
Source1:	%{name}-gitrpm.version
Source2:	%{name}-changelog.gitrpm.txt
# (eugeni) dhclient-exit-hooks script
# mageia patches
# prevents needless deassociation, working around mdv bug #43441
# fedora patches
BuildRequires:	groff-for-man
BuildRequires:	openldap-devel
Requires(post):	rpm-helper >= 0.24.8-1
Requires(preun): rpm-helper >= 0.24.8-1

%description
DHCP (Dynamic Host Configuration Protocol) is a protocol which allows 
individual devices on an IP network to get their own network configuration
information (IP address, subnetmask, broadcast address, etc.) from a DHCP
server. The overall purpose of DHCP is to make it easier to administer a 
large network. The dhcp package includes the DHCP server and a DHCP relay
agent. You will also need to install the dhcp-client or dhcpcd package,
or pump or dhcpxd, which provides the DHCP client daemon, on client machines.

If you want the DHCP server and/or relay, you will also need to install the
dhcp-server and/or dhcp-relay packages.

%package common
Summary:	The ISC DHCP (Dynamic Host Configuration Protocol) server
Group:		System/Servers

%description common
DHCP (Dynamic Host Configuration Protocol) is a protocol which allows 
individual devices on an IP network to get their own network 
configuration information (IP address, subnetmask, broadcast address, 
etc.) from a DHCP server.  The overall purpose of DHCP is to make it 
easier to administer a large network.  The dhcp package includes the 
DHCP server and a DHCP relay agent.

You will also need to install the dhcp-client or dhcpcd package, or pump or
dhcpxd, which provides the DHCP client daemon, on  client machines. If you
want the DHCP server and/or relay, you will also need to install the
dhcp-server and/or dhcp-relay packages.

%package doc
Summary:	Documentation about the ISC DHCP server/client
Group:		System/Servers

%description doc
This package contains RFC/API/protocol documentation about the ISC
DHCP server and client.

DHCP (Dynamic Host Configuration Protocol) is a protocol which allows 
individual devices on an IP network to get their own network 
configuration information (IP address, subnetmask, broadcast address, 
etc.) from a DHCP server.  The overall purpose of DHCP is to make it 
easier to administer a large network.  The dhcp package includes the 
DHCP server and a DHCP relay agent.

%package server
Summary:	The ISC DHCP (Dynamic Host Configuration Protocol) server
Group:		System/Servers
Requires:	dhcp-common = %{epoch}:%{version}-%{release}
Requires(post):  systemd >= %{systemd_required_version}
Requires(post):  rpm-helper >= 0.24.8-1
Requires(preun): rpm-helper >= 0.24.8-1

%description server
DHCP server is the Internet Software Consortium (ISC) DHCP server for various
UNIX operating systems. It allows a UNIX mac hine to serve DHCP requests from
the network.

You should install dhcp-server if you want to set up a DHCP server on your
network. You will also need to install the base dhcp package.

%package client
Summary:	The ISC DHCP (Dynamic Host Configuration Protocol) client
Group:		System/Servers
Requires:	dhcp-common = %{epoch}:%{version}-%{release}
Requires(post):  systemd >= %{systemd_required_version}

%description client
DHCP client is the Internet Software Consortium (ISC) DHCP client for various
UNIX operating systems.  It allows a UNIX mac hine to obtain it's networking
parameters from a DHCP server.

You should install dhcp-client if you want to use the ISC DHCP client instead
of the Red Hat DHCP client, pump, or dhcpcd, or dhcpxd. You will also need to
install the base dhcp package.

%package relay
Summary:	The ISC DHCP (Dynamic Host Configuration Protocol) relay
Group:		System/Servers
Requires:	dhcp-common = %{epoch}:%{version}-%{release}
Requires(post):  systemd >= %{systemd_required_version}
Requires(post):  rpm-helper >= 0.24.8-1
Requires(preun): rpm-helper >= 0.24.8-1

%description relay
DHCP relay is the Internet Software Consortium (ISC) relay agent for DHCP
packets. It is used on a subnet with DHCP clients to "relay" their requests
to a subnet that has a DHCP server on it. Because DHCP packets can be
broadcast, they will not be routed off of the local subnet. The DHCP relay
takes care of this for the client. You will need to set the environment
variable SERVERS and optionally OPTIONS in /etc/sysconfig/dhcrelay before
starting the server.

%package devel
Summary:	Development headers and libraries for the dhcpctl API
Group:		Development/Other
Requires:	dhcp-common = %{epoch}:%{version}-%{release}

%description devel
DHCP devel contains all of the libraries and headers for developing with the
Internet Software Consortium (ISC) dhcpctl API.

%prep
%git_get_source
%setup -q

# Add NIS domain, NIS servers, NTP servers, interface-mtu and domain-search
# to the list of default requested DHCP options
# Handle Xen partial UDP checksums
# If the ipv6 kernel module is missing, do not segfault
# (Submitted to dhcp-bugs@isc.org - [ISC-Bugs #19367])
# Handle cases in add_timeout() where the function is called with a NULL
# value for the 'when' parameter
# Ensure 64-bit platforms parse lease file dates & times correctly

install -m0644 contrib/mageia/draft-ietf-dhc-ldap-schema-01.txt doc

%build
%serverbuild
%configure2_5x --enable-paranoia --enable-early-chroot \
    --with-ldapcrypto \
    --with-srv-lease-file=%{_var}/lib/dhcpd/dhcpd.leases \
    --with-srv6-lease-file=%{_var}/lib/dhcpd/dhcpd6.leases \
    --with-cli-lease-file=%{_var}/lib/dhclient/dhclient.leases \
    --with-cli6-lease-file=%{_var}/lib/dhclient/dhclient6.leases \
    --with-srv-pid-file=/run/dhcpd/dhcpd.pid \
    --with-srv6-pid-file=/run/dhcpd/dhcpd6.pid \
    --with-cli-pid-file=/run/dhclient/dhclient.pid \
    --with-cli6-pid-file=/run/dhclient/dhclient6.pid \
    --with-relay-pid-file=/run/dhcrelay/dhcrelay.pid \
    --disable-static
%make

%install
rm -rf %{buildroot}

%makeinstall_std

# Install correct dhclient-script
install -d %{buildroot}/sbin
mv %{buildroot}%{_sbindir}/dhclient %{buildroot}/sbin/dhclient
install -m 755 client/scripts/linux %{buildroot}/sbin/dhclient-script

install -d %{buildroot}%{_unitdir}
install -m 644 contrib/mageia/dhcpd.service %{buildroot}%{_unitdir}/dhcpd.service
install -m 644 contrib/mageia/dhcpd6.service %{buildroot}%{_unitdir}/dhcpd6.service
install -m 644 contrib/mageia/dhcrelay.service %{buildroot}%{_unitdir}/dhcrelay.service

install -D -p -m 644 contrib/mageia/dhcpd.tmpfiles %{buildroot}%{_tmpfilesdir}/dhcpd.conf
install -D -p -m 644 contrib/mageia/dhclient.tmpfiles %{buildroot}%{_tmpfilesdir}/dhclient.conf
install -D -p -m 644 contrib/mageia/dhcrelay.tmpfiles %{buildroot}%{_tmpfilesdir}/dhcrelay.conf

install -m 755 contrib/mageia/dhcpreport.pl contrib/mageia/dhcpd-chroot.sh %{buildroot}%{_sbindir}
install -m 644 contrib/mageia/dhcpd.conf %{buildroot}%{_sysconfdir}
install -m 755 contrib/ldap/dhcpd-conf-to-ldap %{buildroot}%{_sbindir}

# install exit-hooks script to /etc/
install -m 755 contrib/mageia/dhclient-exit-hooks %{buildroot}%{_sysconfdir}

install -d %{buildroot}%{_sysconfdir}/sysconfig
cat > %{buildroot}%{_sysconfdir}/sysconfig/dhcpd <<EOF
# You can set here various option for dhcpd

# Which configuration file to use.
# CONFIGFILE="/etc/dhcpd.conf"

# Where to store the lease state information.
# LEASEFILE="/var/lib/dhcpd/dhcpd.leases"

# Define INTERFACES to limit which network interfaces dhcpd listens on.
# The default null value causes dhcpd to listen on all interfaces.
#INTERFACES=""

# Define OPTIONS with any other options to pass to the dhcpd server.
# See dhcpd(8) for available options and syntax.
OPTIONS="-q"
EOF

install -d %{buildroot}%{_var}/lib/dhcpd
touch %{buildroot}%{_var}/lib/dhcpd/dhcpd.leases
install -d %{buildroot}%{_var}/lib/dhclient
touch %{buildroot}%{_var}/lib/dhclient/dhclient.leases

cat > %{buildroot}%{_sysconfdir}/sysconfig/dhcrelay <<EOF
# Define SERVERS with a list of one or more DHCP servers where
# DHCP packets are to be relayed to and from.  This is mandatory.
#SERVERS="10.11.12.13 10.9.8.7"
SERVERS=""

# Define OPTIONS with any other options to pass to the dhcrelay server.
# See dhcrelay(8) for available options and syntax.
#OPTIONS="-q -i eth0 -i eth1"
OPTIONS="-q"
EOF

find . -type d -exec chmod 0755 {} \;
find . -type f -exec chmod 0644 {} \;

rm -rf doc/ja_JP.eucJP

# remove empty files
find -size 0 |grep ldap | xargs rm -rf 

# remove unwanted file
rm -f %{buildroot}%{_sysconfdir}/dhclient.conf.example
rm -f %{buildroot}%{_sysconfdir}/dhcpd.conf.example
rm -f %{buildroot}%{_libdir}/*.a

%pre server
%_pre_useradd dhcpd /dev/null /bin/false

%post server
%_post_service dhcpd
%_tmpfilescreate dhcpd
# New dhcpd lease file
if [ ! -f %{_var}/lib/dhcpd/dhcpd.leases ]; then
    touch %{_var}/lib/dhcpd/dhcpd.leases
fi

%preun server
%_preun_service dhcpd

%post relay
%_post_service dhcrelay
%_tmpfilescreate dhcrelay

%preun relay
%_preun_service dhcrelay

%post client
touch %{_var}/lib/dhclient/dhclient.leases
%_tmpfilescreate dhclient

%postun client
rm -rf %{_var}/lib/dhclient/dhclient.leases

%files common
%doc README contrib/ldap/README.ldap RELNOTES
%doc contrib/3.0b1-lease-convert
%{_mandir}/man5/dhcp-options.5*

%files doc
%doc doc/*

%files server
%doc server/dhcpd.conf.example tests/failover contrib/ldap/dhcp.schema
%{_unitdir}/dhcpd.service
%{_unitdir}/dhcpd6.service
%{_tmpfilesdir}/dhcpd.conf
%config(noreplace) %{_sysconfdir}/dhcpd.conf
%config(noreplace) %{_sysconfdir}/dhclient-exit-hooks
%config(noreplace) %{_sysconfdir}/sysconfig/dhcpd
%{_sbindir}/dhcpd
%{_sbindir}/dhcpreport.pl
%{_sbindir}/dhcpd-conf-to-ldap
%{_sbindir}/dhcpd-chroot.sh
%{_bindir}/omshell
%{_mandir}/man1/omshell.1*
%{_mandir}/man3/omapi.3*
%{_mandir}/man5/dhcpd.conf.5*
%{_mandir}/man5/dhcpd.leases.5*
%{_mandir}/man5/dhcp-eval.5*
%{_mandir}/man8/dhcpd.8*
%dir %{_var}/lib/dhcpd
%config(noreplace) %ghost %{_var}/lib/dhcpd/dhcpd.leases

%files relay
%{_unitdir}/dhcrelay.service
%{_tmpfilesdir}/dhcrelay.conf
%config(noreplace) %{_sysconfdir}/sysconfig/dhcrelay
%{_sbindir}/dhcrelay
%{_mandir}/man8/dhcrelay.8*

%files client
%doc client/dhclient.conf.example
%attr (0755,root,root) /sbin/dhclient-script
%{_tmpfilesdir}/dhclient.conf
/sbin/dhclient
%{_mandir}/man5/dhclient.conf.5*
%{_mandir}/man5/dhclient.leases.5*
%{_mandir}/man8/dhclient.8*
%{_mandir}/man8/dhclient-script.8*
%dir %{_var}/lib/dhclient
%config(noreplace) %ghost %{_var}/lib/dhclient/dhclient.leases

%files devel
%{_includedir}/*
%{_mandir}/man3/*
