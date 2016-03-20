#!/bin/bash
#
# dhcpd-chroot.sh is a modified bind-chroot.sh script that enables the 
# dhcpd server to run in a chroot jail under an unprivileged user 
# account (dhcpd).  It requires that the ISC DHCP software is patched
# with the paranoia patch (listed below) by Ari Edelkind.
#
# http://www.episec.com/people/edelkind/patches/dhcp/dhcp-3.0+paranoia.patch
#
# The current ISC DHCP software should have this patch applied,
# otherwise you shouldn't be able to lurk in here reading this.
#
# Copyright Fri Dec 24 2004:
#
#            bind-chroot.sh:  Florin Grad <florin@mandrakesoft.com>
#            dhcpd-chroot.sh: Oden Eriksson <oeriksson@mandrakesoft.com>
# 
# GPL License

# Source function library.
. /etc/rc.d/init.d/functions

[ -f /etc/sysconfig/dhcpd ] && . /etc/sysconfig/dhcpd

# chroot
if [ "$1" == "-s" -o "$1" == "--status" ]; then

	if [ -n "${ROOTDIR}" ]; then
		echo ""
		echo "ROOTDIR is defined in your /etc/sysconfig/dhcpd file." 
		echo "You already appear to have a chroot ISC DHCPD setup."
		echo "ROOTDIR=${ROOTDIR}" 
		exit
	else
		echo "Your ISC DHCPD server is not chrooted."
	fi
		
elif [ "$1" == "-c" -o "$1" == "--chroot" -o "$1" == "-i" -o "$1" == "--interactive" ]; then

	if [ -n "${ROOTDIR}" ]; then
		echo ""
		echo "In your /etc/sysconfig/dhcpd file: ROOTDIR=${ROOTDIR} exists" 
		echo "You already appear to have a chroot ISC DHCPD setup."
		exit

	#interactive
	elif [ "$1" == "-i" -o "$1" == "--interactive" ]; then
		echo ""
		echo "Please enter the  ROOTDIR path (ex: /var/lib/dhcpd-chroot):"
		# can't use ctrl-c, we trap all signal.
		read answer;
		export ROOTDIR="$answer"
	#non interactive
	elif [ "$1" == "-c" -a -n "$2" -o "$1" == "--chroot" -a -n "$2" ]; then
		export ROOTDIR="$2"
	else 
		echo ""
		echo "Missing path for chroot."
	fi

	echo "I have to stop the ISC DHCP server before continuing..."
	PIDFILE="/var/run/dhcpd/dhcpd.pid"
	[ -f ${PIDFILE} ] && kill -9 `cat ${PIDFILE}` >/dev/null 2>&1
	[ -f ${ROOTDIR}/${PIDFILE} ] && kill -9 `cat ${ROOTDIR}/${PIDFILE}` >/dev/null 2>&1
	usleep 3600; rm -f ${PIDFILE} ${ROOTDIR}/${PIDFILE} >/dev/null 2>&1

	# add the dhcpd user
	/usr/sbin/useradd -r -M -s /dev/false -c "system user for dhcpd" -d ${ROOTDIR} dhcpd 2> /dev/null || :

	# create directories and set permissions
	mkdir -p ${ROOTDIR}
	chmod 700 ${ROOTDIR}
	cd ${ROOTDIR}
	mkdir -p dev etc var/run/dhcpd var/lib/dhcp
	[ -e dev/null ] || mknod dev/null c 1 3
	[ -e dev/random ] || mknod dev/random c 1 8
	cp /etc/localtime etc/
#	[ -f /etc/dhcpd.conf ] && cp -f /etc/dhcpd.conf etc/
	[ -f /var/lib/dhcp/dhcpd.leases ] && cp -f /var/lib/dhcp/dhcpd.leases var/lib/dhcp/
	[ -f /var/lib/dhcp/dhcpd.leases~ ] && cp -f /var/lib/dhcp/dhcpd.leases~ var/lib/dhcp/
	chown -R dhcpd:dhcpd ${ROOTDIR}

	#update the OPTIONS in /etc/sysconfig/dhcpd
	if grep -q ^OPTIONS= /etc/sysconfig/dhcpd; then
		if sed 's!^\(OPTIONS=".*\)"$!\1 -user dhcpd -group dhcpd"!' < /etc/sysconfig/dhcpd > /etc/sysconfig/dhcpd.new; then
			mv -f /etc/sysconfig/dhcpd.new /etc/sysconfig/dhcpd
		fi
	else
		echo "Updating OPTIONS in /etc/sysconfig/dhcpd"
		echo "OPTIONS=\"-user dhcpd -group dhcpd\"" >> /etc/sysconfig/dhcpd
	fi

	#update the ROOTDIR in /etc/sysconfig/dhcpd
	echo "Updating ROOTDIR in /etc/sysconfig/dhcpd"
	echo "ROOTDIR=\"${ROOTDIR}\"" >> /etc/sysconfig/dhcpd

	echo ""
	echo "Chroot configuration for ISC DHCPD is complete."
	echo "You should review your ${ROOTDIR}/etc/dhcpd.conf"
	echo "and make any necessary changes."
	echo ""
	echo "Run \"/sbin/service dhcpd restart\" when you are done."
	echo ""

# unchroot
elif [ "$1" == "-u" -o "$1" == "--unchroot" ]; then

	if ! grep -q "^ROOTDIR=" /etc/sysconfig/dhcpd; then
		echo ""
		echo "Your dhcpd is not currently chrooted"
		echo ""
		exit
	fi

	echo "I have to stop the ISC DHCP server before continuing..."
	PIDFILE="/var/run/dhcpd/dhcpd.pid"
	[ -f ${PIDFILE} ] && kill -9 `cat ${PIDFILE}` >/dev/null 2>&1
	[ -f ${ROOTDIR}/${PIDFILE} ] && kill -9 `cat ${ROOTDIR}/${PIDFILE}` >/dev/null 2>&1
	usleep 3600; rm -f ${PIDFILE} ${ROOTDIR}/${PIDFILE} >/dev/null 2>&1

	echo ""
	echo "Removing ROOTDIR from /etc/sysconfig/dhcpd"
	sed -e '/^\(ROOTDIR=".*\)"$/d' < /etc/sysconfig/dhcpd > /etc/sysconfig/dhcpd.new
	mv -f /etc/sysconfig/dhcpd.new /etc/sysconfig/dhcpd
	echo "Cleaning the OPTIONS in /etc/sysconfig/dhcpd"
	sed -e 's|-user dhcpd -group dhcpd[ ]*||' < /etc/sysconfig/dhcpd > /etc/sysconfig/dhcpd.new
	mv -f /etc/sysconfig/dhcpd.new /etc/sysconfig/dhcpd
	sed -e 's|[ ][ ]*"|"|' < /etc/sysconfig/dhcpd > /etc/sysconfig/dhcpd.new
	mv -f /etc/sysconfig/dhcpd.new /etc/sysconfig/dhcpd
	echo ""
	echo "Moving the following files to their original location :"
#	echo "/etc/dhcpd.conf"
	echo "/var/lib/dhcp/dhcpd.leases"
	echo "/var/lib/dhcp/dhcpd.leases~"
#	[ -f /etc/dhcpd.conf ] || mv -f ${ROOTDIR}/etc/dhcpd.conf /etc/
	[ -f /var/lib/dhcp/dhcpd.leases~ ] || mv -f ${ROOTDIR}/var/lib/dhcp/dhcpd.leases~ /var/lib/dhcp/
	[ -f /var/lib/dhcp/dhcpd.leases ] || mv -f ${ROOTDIR}/var/lib/dhcp/dhcpd.leases /var/lib/dhcp/
	#chown -R dhcpd:dhcpd /var/run/dhcpd

	echo ""
	echo "Removing the ${ROOTDIR}"
	rm -rf ${ROOTDIR}
	echo "Your dhcpd server is not chrooted anymore."
	echo ""
	echo "Run \"/sbin/service dhcpd restart\" when you are done."
	echo ""

#usage 
else 
	echo ""
	echo "Usage: $0 [arguments]"
	echo ""
	echo -e "\t-s, --status (current dhcpd configuration type)"
	echo ""
	echo "arguments:"
	echo -e "\t-i, --interactive (so you can choose your path)"
	echo ""
	echo -e "\t-c, --chroot (choose a chroot location. ex: /var/lib/dhcpd-chroot)"
	echo ""
	echo -e "\t-u, --unchroot (back to the original configuration)"
	echo ""
fi
