VER=11

ex() {

  pod=$1
  shift

  (kubectl exec $pod -- $*) 2>&1
}

swmfs() {

  message=$1
  ace=$2

  sep ${FUNCNAME[0]}

  if [ -z "$message" -o -z "$ace" ]; then
	echo "MESSAGES_DB_DIR and/or ACE_DB_DIR is unset"
	return
  fi

  pod=$(kubectl get po --no-headers | grep Running | grep "1/1" | awk '!/client-deployment|nexus|bifrost|postgres|uaa|solr|ingress|rabbitmq/ { print $1 }' | head -n 1)

  echo '----------------------------------------------------------------------'
  # this is a ping from the master not the node. 
  # our alpine image does not include ping. better than nothing
  ip=$(echo $message | awk -F: '{ print $1 }')
  echo Ping $ip
  #ex $pod ping $ip -c 3
  ping $ip -c 3

  if [[ -z "$pod" ]]; then
    echo "No running pod found to check swmfs"
    return
  fi

  swmfs_test=/Smallworld/core/bin/Linux.x86/swmfs_test
  swlm_clerk=/Smallworld/core/etc/Linux.x86/swlm_clerk

  echo '----------------------------------------------------------------------'
  echo Validate directory $message
  ex $pod $swmfs_test 22 $message *.ds
  echo '----------------------------------------------------------------------'
  echo Validate server using message.ds in $message
  ex $pod $swmfs_test 13 $message message.ds
  echo '----------------------------------------------------------------------'
  echo Validate licence
  echo "SW_LICENCE_DB=$message/message.ds $swlm_clerk -o" > /tmp/$$
  kubectl cp /tmp/$$ $pod:/tmp/$$
  #cmd="\"SW_LICENCE_DB=$message/message.ds; $swlm_clerk -o\""
  ex $pod bash /tmp/$$
  ex $pod rm /tmp/$$
  echo '----------------------------------------------------------------------'
  echo Validate directory $ace
  ex $pod $swmfs_test 22 $ace *.ds
  echo '----------------------------------------------------------------------'
  echo Validate access to $ace
  ex $pod $swmfs_test 1 $ace $$.ds
  ex $pod $swmfs_test 4 $ace $$.ds
  echo '----------------------------------------------------------------------'
  echo Validate access to ace.ds in $ace
  ex $pod $swmfs_test 23 $ace ace.ds 100
}

manifest() {

	sep ${FUNCNAME[0]}

	sep2 pdc_input_manifest.yaml ${FUNCNAME[0]}
	cat $1	
	echo

	sep2 nexus_manifest.yaml ${FUNCNAME[0]}
	cat $(dirname $1)/nexus/nexus_manifest.yaml
	echo
}

sep() {
	>&2 echo -n '.' 
	echo ''
	echo ":--- $1"
	echo ''
}

sep2() {
	echo ":------ $1 - $2"
	echo ''
}

basic() {
	sep ${FUNCNAME[0]}
	date
	TZ=UTC date +%FT%T%Z
	echo 
	uname -a
	echo
	if [[ $(which hostnamectl | wc -l ) -gt 0 ]]; then
		hostnamectl
	else
		echo "hostnamectl not present"
	fi
	echo
	uptime
	echo
}

cpu() {
	sep ${FUNCNAME[0]}
	cat /proc/cpuinfo
	echo
	sudo dmesg | grep "Hypervisor detected"
	echo
}

memory() {
	sep memory ${FUNCNAME[0]}
	cat /proc/meminfo
	echo
}

network() {
	sep ${FUNCNAME[0]}
	host=$(hostname --fqdn)
	echo "Hostname: $host ($(hostname))"
	echo "Domainname: $(domainname)"
	if [[ $(expr index $host ".") -eq 0 ]]; then
		echo "*** WARNING: Hostname is not domain qualified"
	fi
	echo "IP addresses: $(hostname -I)"
	echo "IP address (DNS resolved): $(hostname -i)"
	echo
	ip addr
	echo
	ip route
	echo
}

disks() {
	sep ${FUNCNAME[0]}
	df -h
	echo
	#parted /dev/sda print
	#echo
	fdisk -l 2>/dev/null # silence experimental warning for GPT
	echo
}

process() {	
	sep ${FUNCNAME[0]}
	if [[ $(which systemctl | wc -l ) -gt 0 ]]; then
		systemctl status
	else
		echo "systemctl not present"
	fi
	echo
	ps -efl
	echo
}

files() {
	sep ${FUNCNAME[0]}
	sep2 hosts ${FUNCNAME[0]}
	cat /etc/hosts
	echo

	sep2 exports ${FUNCNAME[0]}
	if [[ -f /etc/exports ]]; then
		cat /etc/exports
	fi
	echo

	sep2 daemon.json ${FUNCNAME[0]}
	cat /etc/docker/daemon.json
	echo
}

info() {
	sep ${FUNCNAME[0]}
	sep2 "kubectl version" ${FUNCNAME[0]}
	kubectl version
	echo
	sep2 "docker version" ${FUNCNAME[0]}
	docker version
	echo
	sep2 "docker info" ${FUNCNAME[0]}
	docker info 2>&1
	echo
	sep2 "docker images" ${FUNCNAME[0]}
	docker images
	echo
}

nodes() {
	sep ${FUNCNAME[0]}
	sep2 status ${FUNCNAME[0]}
	kubectl get node -o wide
	echo
	sep2 debug ${FUNCNAME[0]}
	kubectl describe node
	echo
}

pods() {
	sep ${FUNCNAME[0]}
	sep2 status ${FUNCNAME[0]}
	kubectl get pods -A -o wide 2>/dev/null
	echo
	sep2 debug ${FUNCNAME[0]}
	kubectl describe pods -A
	echo
}

endpoints() {
	sep ${FUNCNAME[0]}
	kubectl get endpoints -A
	echo
}

certificates() {
	sep ${FUNCNAME[0]}
	sep2 bifrost ${FUNCNAME[0]}

	if [[ ! -z $(which curl) ]]; then
		echo curl -v -k https://$(hostname):30443
		no_proxy=$(hostname),$no_proxy curl -v -k https://$(hostname):30443/ 2>&1
	else
		echo "*** WARNING: curl not installed"
	fi
}

nexus() {
	sep ${FUNCNAME[0]}

	kubectl get ingress -o yaml -n nexus
}

logs() {
	sep ${FUNCNAME[0]}

	# core-dns 
	for pod in $(kubectl get pods -o name -n kube-system -l k8s-app=kube-dns); do sep2 $pod ${FUNCNAME[0]};  kubectl logs -n kube-system $pod; done
	#flannel
	for pod in $(kubectl get pods -o name -n kube-system -l app=flannel); do sep2 $pod ${FUNCNAME[0]};  kubectl logs -n kube-system $pod; done
	#kube-proxy
	for pod in $(kubectl get pods -o name -n kube-system -l k8s-app=kube-proxy); do sep2 $pod ${FUNCNAME[0]};  kubectl logs -n kube-system $pod; done

	kubectl get pods -n nexus --no-headers 2>/dev/null | awk '{ print $1 }' | while read pod; do
		sep2 $pod ${FUNCNAME[0]}
		kubectl logs $pod -n nexus 2>&1
	done

	kubectl get pods --no-headers 2>/dev/null | awk '{ print $1 }' | while read pod; do
		sep2 $pod ${FUNCNAME[0]}
		kubectl logs $pod 2>&1
	done
}

services() {
	sep ${FUNCNAME[0]}

	kubectl get namespace --no-headers 2>/dev/null | awk '{ print $1 }' | while read ns; do
		sep2 $ns ${FUNCNAME[0]}
		kubectl get service -n $ns -o wide 2>&1
		echo ''
	done
}

gather() {
	path=$1
	shift

	manifest $path
	basic
	info
	cpu
	memory
	network
	disks
	process
	files
	nodes
	pods
	endpoints
	certificates
	nexus
	services
	logs
	swmfs $*
}

path=$1

if [[ -z $path || ! -f $path ]]; then
	echo -e "\nUsage: $0 </path/to/pdc_input_manifest.yaml>"
	exit 1
fi

message_dir_path=$(grep MESSAGES_DIR_PATH $path | cut -f2 -d"'" | cut -f1 -d"'")
ace_dir_path=$(grep ACE_DIR_PATH $path | cut -f2 -d"'" | cut -f1 -d"'")
modelit_dir_path=$(grep MODELIT_DIR_PATH $path | cut -f2 -d"'" | cut -f1 -d"'")
storage_type=$(grep STORAGE_TYPE $path | cut -f2 -d"'" | cut -f1 -d"'")
root_hostdir_path=$(grep ROOT_HOSTPATH_DIR $path | cut -f2 -d"'" | cut -f1 -d"'")
root_shared_path=$(grep ROOT_SHARED_DIR $path | cut -f2 -d"'" | cut -f1 -d"'")
osds_root_dir=$(grep OSDS_ROOT_DIR $path | cut -f2 -d"'" | cut -f1 -d"'")

ace_dir_path=${modelit_dir_path:-$ace_dir_path}

if [[ $storage_type == "nfs" ]]; then
	root_path=$root_shared_path
else
	root_path=$root_hostdir_path
fi

root_path=${root_path:-/smallworld}
osds_path=${osds_root_dir:-/osds_data}

( 
	sep 'begin bundle'
	echo "version $VER"
	gather $path $message_dir_path $ace_dir_path 
	sep 'end bundle'
) >info.txt

echo '' # terminate progress indicator line

if [[ $(which gzip | wc -l) -gt 0 ]]; then
	args=z
	suffix=.gz
else
	args=
	suffix=
fi

now=$(date --utc +%Y%m%d_%H%M%SZ)
file=bundle_${now}.tar${suffix}

files="info.txt"

if [[ -d $root_path ]]; then
	files="$files $root_path"
fi

if [[ -d $osds_path ]]; then
	files="$files $osds_path"
fi

echo Generating bundle $file
tar -${args}cf $file $files

ls -lh $file

echo -e "\nPlease provide $file with any support tickets."
