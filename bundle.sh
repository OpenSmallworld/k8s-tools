sep() {
	>&2 echo -n '.' 
	echo ''
	echo ":--- $1"
	echo ''
}

sep2() {
	echo ":------ $1 $2"
	echo ''
}

basic() {
	sep ${FUNCNAME[0]}
	date
	TZ=UTC date +%FT%T%Z
	echo 
	host=`hostname --fqdn`
	echo "Hostname: $host (`hostname`)"
	if [ `expr index $host "."` == 0 ]; then
		echo "*** Warning: Hostname is not domain qualified"
	fi
	echo IP address: `hostname -I`
	echo
	uname -a
	echo
	df -h
	echo
	fdisk -l 2>/dev/null # silence experimental warning for GPT
	echo
	ifconfig -a
}

info() {
	sep ${FUNCNAME[0]}
	docker version
	kubectl version
	docker info 2>&1
}

nodes() {
	sep ${FUNCNAME[0]}
	sep2 status ${FUNCNAME[0]}
	kubectl get node
	sep2 debug ${FUNCNAME[0]}
	kubectl describe node
}

pods() {
	sep ${FUNCNAME[0]}
	sep2 status ${FUNCNAME[0]}
	kubectl get pods 2>/dev/null
	sep2 debug ${FUNCNAME[0]}
	kubectl describe pods
}

certificates() {
	sep ${FUNCNAME[0]}
	sep2 bifrost ${FUNCNAME[0]}

	if [ ! -z $(which curl) ]; then
		echo curl -v -k https://`hostname`:30443
		no_proxy=`hostname`,$no_proxy curl -v -k https://`hostname`:30443/ 2>&1
	else
		echo "*** curl not installed!"
	fi
}

logs() {
	sep ${FUNCNAME[0]}

	kubectl get pods --no-headers 2>/dev/null | awk '{ print $1 }' | while read pod; do
		sep2 $pod ${FUNCNAME[0]}
		kubectl logs $pod 2>&1
	done
}

gather() {
	basic
	info
	nodes
	pods
	certificates
	logs
}

( 
	sep 'begin bundle'
	gather
	sep 'end bundle'
#) | tee info.txt
) >info.txt

echo '' # terminate progress indicator line

if [ $(which gzip | wc -l) == 1 ]; then
	args=z
	suffix=.gz
else
	args=
	suffix=
fi

now=$(date --utc +%Y%m%d_%H%M%SZ)
file=bundle_${now}.tar${suffix}

echo Generating bundle $file
tar -${args}cf $file info.txt /smallworld /osds_data

ls -lh $file

echo -e "\nPlease provide $file with any support tickets."
