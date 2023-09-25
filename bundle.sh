VER=42

default_namespace='gss-prod'
dummy=''
kubeconfig=''
osds_root_dir=''
nobundle=false
use_modelit=false
include_previous=true
isroot=false
nonroot=false
deploy_logs=true
var_logs=true
update=true
update_ca_trust=false
update_ca_certificates=false
log_args=''
cli="$*"
script="$(readlink -f "$0")"
default_k8s_port=30443

ex3() {

  pod=$1
  cmd=$2

  (kubectl exec -n $namespace $pod -- bash -c "$cmd") 2>&1
}

ex2() {

  pod=$1
  shift

  (kubectl exec -n $namespace $pod -- $*) 2>&1
}

ex1() {

  pod=$1
  namespace=$2
  shift; shift

  id=$(kubectl get po -n $namespace $pod -o jsonpath='{.status.containerStatuses[0].containerID}' | cut -c 10-21)
  pid=$(docker inspect --format '{{ .State.Pid }}' $id)

  (nsenter -t ${pid} -n $*) 2>&1
}

swmfs() {

  message=$1
  ace=$2

  sep ${FUNCNAME[0]}

  if [[ -z $message || -z $ace ]]; then
        echo "MESSAGES_DB_DIR and/or ACE_DB_DIR is unset"
        return
  fi

  pod=$(kubectl get po -n $namespace --no-headers | grep Running | grep "1/1" | awk '!/client-deployment|nexus|bifrost|postgres|uaa|solr|ingress|rabbitmq|gdal/ { print $1 }' | head -n 1)

  echo '----------------------------------------------------------------------'
  ip=$(echo $message | awk -F: '{ print $1 }')

  echo "Ping $ip (from $(hostname))"
  ping $ip -c 3
  echo

  if [[ -z $pod ]]; then
    echo "No running pod found to check swmfs"
    return
  fi

  echo "Ping $ip (from $pod)"
  ex1 $pod $namespace ping $ip -c 3
  echo

  swmfs_test=/Smallworld/core/bin/Linux.x86/swmfs_test
  swlm_clerk=/Smallworld/core/etc/Linux.x86/swlm_clerk

  echo '----------------------------------------------------------------------'
  echo Validate directory $message
  ex2 $pod $swmfs_test 22 $message *.ds
  echo '----------------------------------------------------------------------'
  echo Validate server using message.ds in $message
  ex2 $pod $swmfs_test 13 $message message.ds
  echo '----------------------------------------------------------------------'
  echo Validate licence
  cmd="SW_LICENCE_DB=$message/message.ds $swlm_clerk -o"
  ex3 $pod "$cmd"
  echo '----------------------------------------------------------------------'
  echo Validate directory $ace
  ex2 $pod $swmfs_test 22 $ace *.ds
  echo '----------------------------------------------------------------------'
  echo Validate access to $ace
  ex2 $pod $swmfs_test 1 $ace bundle-$$.ds
  ex2 $pod $swmfs_test 4 $ace bundle-$$.ds
  echo '----------------------------------------------------------------------'
  echo Validate access to ace.ds in $ace
  ex2 $pod $swmfs_test 23 $ace ace.ds 100
}

manifest() {

        sep ${FUNCNAME[0]}

        sep2 $1 ${FUNCNAME[0]}
        cat $1
        echo

        if [[ -f $(dirname $1)/nexus/nexus_manifest.yaml ]]; then
                sep2 nexus_manifest.yaml ${FUNCNAME[0]}
                cat $(dirname $1)/nexus/nexus_manifest.yaml
                echo -e '\n\n'
        else
                echo "$(dirname $1)/nexus/nexus_manifest.yaml missing"
        fi

        if [[ -f $(dirname $1)/local_storage_provisioner_manifest.yaml ]]; then
                sep2 local_storage_provisioner_manifest.yaml ${FUNCNAME[0]}
                cat $(dirname $1)/local_storage_provisioner_manifest.yaml
                echo -e '\n\n'
        else
                echo "$(dirname $1)/local_storage_provisioner_manifest.yaml missing"
        fi

        if [[ -f $(dirname $1)/nfs_storage_provisioner_manifest.yaml ]]; then
                sep2 nfs_storage_provisioner_manifest.yaml ${FUNCNAME[0]}
                cat $(dirname $1)/nfs_storage_provisioner_manifest.yaml
                echo -e '\n\n'
        else
                echo "$(dirname $1)/nfs_storage_provisioner_manifest.yaml missing"
        fi

        if [[ -f $(dirname $1)/nginx_ingress_controller_manifest.yaml ]]; then
                sep2 nginx_ingress_controller_manifest.yaml ${FUNCNAME[0]}
                cat $(dirname $1)/nginx_ingress_controller_manifest.yaml
                echo -e '\n\n'
        else
                echo "$(dirname $1)/nginx_ingress_controller_manifest.yaml missing"
        fi
}

sep() {
        >&2 echo -n '.' 
        echo
        echo ":--- $1"
}

sep2() {
        echo
        echo ":------ $1 -- $2"
        echo
}

basic() {
        sep ${FUNCNAME[0]}
        echo ""

        date
        TZ=UTC date +%FT%T%Z
        echo 
        uname -a
        echo
        if [[ ! -z $(which hostnamectl 2> /dev/null) ]]; then
                hostnamectl
        else
                echo "*** WARNING: hostnamectl not present"
        fi
        echo
        uptime
        echo
}

cpu() {
        sep ${FUNCNAME[0]}
        echo ""

        cat /proc/cpuinfo
        echo
        sudo dmesg | grep "Hypervisor detected"
        echo
}

memory() {
        sep memory ${FUNCNAME[0]}
        echo ""

        cat /proc/meminfo
        echo
}

network() {
        sep ${FUNCNAME[0]}
        echo ""

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
        echo ""

        df -h
        echo
        #parted /dev/sda print
        #echo
        fdisk -l 2>/dev/null # silence experimental warning for GPT
        echo
}

process() {
        sep ${FUNCNAME[0]}
        echo ""

        if [[ ! -z $(which systemctl 2> /dev/null) ]]; then
                systemctl status
                systemctl status nfs 2> /dev/null
                if [[ $? -eq 0 ]]; then
                        systemctl --no-pager --full status nfs
                fi
                systemctl --no-pager --full status docker
                systemctl --no-pager --full status kubelet
        else
                echo "*** WARNING: systemctl not present"
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

        sep2 resolv.conf ${FUNCNAME[0]}
        cat /etc/resolv.conf
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
        kubectl version --output=yaml
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

journalctl_() {
        sep ${FUNCNAME[0]}

        if [[ ! -z $(which journalctl 2> /dev/null) ]]; then
                sep2 "docker" ${FUNCNAME[0]}
                journalctl -xeu docker --no-pager
                sep2 "kubelet" ${FUNCNAME[0]}
                journalctl -xeu kubelet --no-pager
                systemctl status nfs 2> /dev/null
                if [[ $? -eq 0 ]]; then
                        sep2 "nfs-server" ${FUNCNAME[0]}
                        journalctl -xeu nfs-server --no-pager
                        sep2 "nfs-client" ${FUNCNAME[0]}
                        journalctl -xeu nfs-client --no-pager
                fi
        else
                echo "*** WARNING: journalctl not present"
        fi

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
        echo ""

        kubectl get endpoints -A
        echo
}

certificates() {
        sep ${FUNCNAME[0]}
        sep2 bifrost ${FUNCNAME[0]}

        if [[ ! -z $(which curl 2> /dev/null) ]]; then
                if [[ -f $osds_root_dir/ssl/ca/ca.cert.pem ]]; then
                        echo no_proxy=$k8s_host curl -v --cacert $osds_root_dir/ssl/ca/ca.cert.pem https://$k8s_host:$k8s_port
                        no_proxy=$k8s_host curl -v --cacert $osds_root_dir/ssl/ca/ca.cert.pem https://$k8s_host:$k8s_port 2>&1
                        echo
                        echo no_proxy=$k8s_host curl -v -k https://$k8s_host:$k8s_port
                        no_proxy=$k8s_host curl -v -k https://$k8s_host:$k8s_port 2>&1
                        echo
                        echo "(speculative attempt to use $k8s_host as a plain https application gateway)"
                        echo no_proxy=$k8s_host curl -v --cacert $osds_root_dir/ssl/ca/ca.cert.pem https://$k8s_host
                        no_proxy=$k8s_host curl -v --cacert $osds_root_dir/ssl/ca/ca.cert.pem https://$k8s_host 2>&1
                        echo
                        echo no_proxy=$k8s_host curl -v -k https://$k8s_host
                        no_proxy=$k8s_host curl -v -k https://$k8s_host 2>&1
                        echo
                fi
        else
                echo "*** WARNING: curl not installed"
        fi

        if [[ ! -z $(which openssl 2> /dev/null) ]]; then
                if [[ -f $osds_root_dir/ssl/cert/ssl.cert.pem ]]; then
                        echo
                        echo openssl x509 -in $osds_root_dir/ssl/cert/ssl.cert.pem -text -noout 
                        openssl x509 -in $osds_root_dir/ssl/cert/ssl.cert.pem -text -noout 2>&1                       
                        echo
                fi

                if [[ -f  $osds_root_dir/ssl/ca/ca.cert.pem ]]; then
                        echo
                        echo openssl x509 -in $osds_root_dir/ssl/ca/ca.cert.pem -text -noout 2>&1
                        openssl x509 -in $osds_root_dir/ssl/ca/ca.cert.pem -text -noout 2>&1
                        echo
                fi

                if [[ ! -z $(which update-ca-trust 2> /dev/null) ]]; then
                        update_ca_trust=true
                fi

                if $update && $update_ca_trust; then
                        if [[ -f $osds_root_dir/ssl/ca/ca.cert.pem ]]; then
                                yum -y install ca-certificates
                                update-ca-trust force-enable
                        fi
                fi

                cp $osds_root_dir/ssl/ca/ca.cert.pem /etc/pki/ca-trust/source/anchors/

                if $update && $update_ca_trust; then
                        update-ca-trust extract
                fi

                echo openssl verify -verbose -purpose sslserver -CApath $osds_root_dir/ssl/ca $osds_root_dir/ssl/cert/ssl.cert.pem
                openssl verify -verbose -purpose sslserver -CApath $osds_root_dir/ssl/ca $osds_root_dir/ssl/cert/ssl.cert.pem
                echo

                if [[ ! -z $(which update-ca-certificates 2> /dev/null) ]]; then
                        update_ca_certificates=true
                fi

                if $update && $update_ca_certificates; then
                        if [[ -f $osds_root_dir/ssl/ca/ca.cert.pem ]]; then
                                cp $osds_root_dir/ssl/ca/ca.cert.pem /usr/local/share/ca-certificates/
                                update-ca-certificates
                                openssl verify -verbose -purpose sslserver -CApath $osds_root_dir/ssl/ca $osds_root_dir/ssl/cert/ssl.cert.pem                                
                                echo
                        fi
                fi
        else
                echo "*** WARNING: openssl not installed"
        fi
}

check_kubeconfig() {
        counter=$1
        admin_conf=$2
        file=$3
        message=${4:-"*** WARNING: file $3 does not exist"}

        echo -n "($counter of 4) "

        if [[ -f $file ]]; then
                ls -l $file
                if [[ $(diff $admin_conf $file | wc -l)  -gt 0 ]]; then
                        echo "*** WARNING: difference between $admin_conf and $file"
                fi
        else
                echo "*** WARNING: file $file does not exist"
        fi
}

kubeconfig_() {
        sep ${FUNCNAME[0]}
        echo ""

        admin_conf="/etc/kubernetes/admin.conf"
        ls -l $admin_conf

        if [[ ! -z $SUDO_USER ]]; then
                user_home=$(getent passwd $SUDO_USER | cut -d: -f6)
                pathname="$user_home/.kube/config"
                check_kubeconfig 1 $admin_conf $pathname "*** WARNING: file $pathname does not exist or cannot determine KUBECONFIG for user $SUDO_USER"
        else
                echo "*** WARNING: skipping SUDO_USER as not set"
        fi

        root_home=$(getent passwd root | cut -d: -f6)
        pathname="$root_home/.kube/config"
        check_kubeconfig 2 $admin_conf $pathname "*** WARNING: file $pathname does not exist or cannot determine KUBECONFIG for user root"

        check_kubeconfig 3 $admin_conf "$kubeconfig"
        check_kubeconfig 4 $admin_conf "$osds_root_dir/kubeconfig/config"

}

nexus() {
        sep ${FUNCNAME[0]}
        echo ""

        kubectl get ingress -o yaml -n nexus
}

logs() {
        sep ${FUNCNAME[0]}

        # kube-dns 
        for pod in $(kubectl get pods -o name -n kube-system -l k8s-app=kube-dns); do 
                sep2 $pod ${FUNCNAME[0]}
                kubectl logs -n kube-system $pod $log_args
                echo
        done

        #flannel
        for pod in $(kubectl get pods -o name -n kube-system -l app=flannel); do 
                sep2 $pod ${FUNCNAME[0]}
                kubectl logs -n kube-system $pod $log_args
                echo
        done

        #kube-proxy
        for pod in $(kubectl get pods -o name -n kube-system -l k8s-app=kube-proxy); do 
                sep2 $pod ${FUNCNAME[0]}
                kubectl logs -n kube-system $pod $log_args
                echo
        done

        # logging
        kubectl get pods -n logging --no-headers 2>/dev/null | awk '{ print $1 }' | while read pod; do
                sep2 $pod ${FUNCNAME[0]}
                kubectl logs -n logging $pod $log_args
                echo
        done

        # nexus
        kubectl get pods -n nexus --no-headers 2>/dev/null | awk '{ print $1 }' | while read pod; do
                sep2 $pod ${FUNCNAME[0]}
                kubectl logs -n nexus $pod $log_args
                echo
        done

        # given namespace
        kubectl get pods -n $namespace --no-headers 2>/dev/null | awk '{ print $1 }' | while read pod; do
                if $include_previous; then
                        sep2 $pod "${FUNCNAME[0]} -- previous"
                        kubectl logs -n $namespace $pod $log_args --previous 2>&1
                        echo
                fi                
                sep2 $pod ${FUNCNAME[0]}
                kubectl logs -n $namespace $pod $log_args
                echo
        done
}

describe() {
        sep ${FUNCNAME[0]}

                for type in deploy svc pods daemonsets pv pvc cronjobs jobs configmaps secrets ingress role rolebinding sa; do
                        kubectl get namespace --no-headers 2>/dev/null | awk '{ print $1 }' | while read ns; do
                                        sep2 "$type -- $namespace" ${FUNCNAME[0]}
                                        kubectl describe $type -n $namespace 2>/dev/null
                                        echo
                        done
                done
}

bifrost() {
  sep ${FUNCNAME[0]}

  pod=$(kubectl get po -n $namespace --no-headers | grep Running | grep "1/1" | awk '/bifrost/ { print $1 }' | head -n 1)

  if [[ -z $pod ]]; then
    echo "No running pod found to check bifrost"
    return
  fi

  sep2 "/etc/hosts on $pod" ${FUNCNAME[0]}

  ex1 $pod $namespace cat /etc/hosts
  echo
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
        journalctl_
        nodes
        pods
        endpoints
        if $isroot; then certificates; fi
        if $isroot; then kubeconfig_; fi
        nexus
        describe
        #logs
        swmfs $*
        bifrost
}

usage() {
        cat << EOD
Usage: $0 </path/to/pdi_input_manifest.yaml>

        -n|--namespace <namespace>
                Override the namespace <namespace>. Not usually required because the namespace is now derived from the manifest
        -k|--kubeconfig </path/to/kubeconfig>
                Use alternate config file to that specified in KUBECONFIG, or where not defined
        -o|--osds_root_dir </path/to/osds_root_dir>
                Override osds_root_dir. Commonly used for older manifests where this was not defined
        -m|--use_modelit_dir_path
                Use MODELIT_DIR_PATH from manifest rather than ACE_DIR_PATH
        -l|--include-latest
                Include only latest log files. Defaut is to include previous logs.
        -z|--no-bundle
                Do not create the support bundle, only info.txt and logs.txt
        -d|--debug
                Debug running script by echoing commands
        -N|--non-root
                Run as a non-root user. This may cause some information to not be captured as well as errors while running!
        -h|--help
                This help
        -s|--since <time-period>
                Limit logs. Examples of time period are --since 10m, --since 1h, --since 2023-04-25T10:46:00.000000000Z
        --no-update
                Do not update any CA certificates
        --no-deploy-logs
                Do not include volume mountpoint logs
        --no-var-logs
                Do not include /var/(container|pods)/logs

EOD
        exit 1
}

gather_deploy_logs() {

        tar_file=$1
        args=$2

        if [[ ! -z $(which jq 2> /dev/null) ]]; then
                docker volume ls | awk '/volume_stp_sw_gss_deploy/ { print $2 }' | while read volume; do
                                mp=$(docker volume inspect $volume | jq -r '.[].Mountpoint')
                                pushd $mp > /dev/null
                                tar -${args}rf $tar_file *.log
                                popd > /dev/null
                done
        else
                echo "*** WARNING: jq is missing. Cannot find deploy logs mountpoint."
                touch jq_missing
        fi
}

gather_var_logs() {

        tar_file=$1
        args=$2
        files=""

        if [[ -d /var/log/containers ]]; then
                files+="/var/log/containers "
        else
                touch var_log_containers_missing
                files+="var_log_containers_missing "
        fi

        if [[ -d /var/log/pods ]]; then 
                files+="/var/log/pods "
        else
                touch var_log_pods_missing
                files+="var_log_pods_missing "
        fi

        tar -${args}rf $tar_file $files
        rm -f var_log_containers_missing var_log_pods_missing
}

# ---

path=$1

if [[ -z $path || ! -f $path ]]; then
        usage
fi

shift

namespace=$(grep GSS_NAMESPACE $path | cut -f 2 -d : | tr -d '[:space:]' | tr -d \" | tr -d \') # cannot use "tr -d '[:punct:]'" because namespace may contain a hyphen
k8s_host=$(grep K8SHOST $path | cut -f 2 -d : | tr -d '[:space:]' | tr -d \" | tr -d \')
k8s_port=$(grep K8SPORT $path | cut -f 2 -d : | tr -d '[:space:]' | tr -d \" | tr -d \')
k8s_port=${k8s_port:-$default_k8s_port}

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -n|--namespace)
      echo "*** Warning overriding namespace '$namespace' from manifest"
      namespace=$2
      shift; shift
      ;;
    -k|--kubeconfig)
      kubeconfig=$2
      shift; shift
      ;;
    -o|--osds_root_dir)
      osds_root_dir=$2
      shift; shift
      ;;
    -m|--use_modelit_dir_path)
      use_modelit=true
      shift
      ;;
    -l|--include-latest)
      include_previous=false
      shift
      ;;
    -z|--no-bundle)
      nobundle=true
      shift
      ;;
    -d|--debug)
      set -x
      shift
      ;;
    -N|--non-root)
      nonroot=true
      shift
      ;;
    -h|--help)
      usage
      exit
      ;;
    -s|--since)
      log_args+="--since $2"
      shift; shift
      ;;
    --no-update)
      update=false
      shift
      ;;
    --no-deploy-logs)
      deploy_logs=false
      shift
      ;;
    --no-var-logs)
      var_logs=false
      shift
      ;;
    *)
      echo -e "Do not understand argument \"$key\"\n"
      usage
      exit
  esac
done

if [[ -z $namespace ]]; then
        namespace=$default_namespace
fi

# avoid permissions errors
if ! $nonroot; then
        if [[ $(id -u) -ne 0 ]]; then
                echo "*** Error: Running as user $USER not as root/sudo user"
                exit 1
        fi
        isroot=true
fi

if [[ -z $KUBECONFIG ]]; then
        if [[ ! -z $kubeconfig ]]; then
                export KUBECONFIG=$kubeconfig
        else
                echo "*** Error: KUBECONFIG nor -k/--kubeconfig set"
                exit 1
        fi
else
        kubeconfig=$KUBECONFIG
fi

message_dir_path=$(grep MESSAGES_DIR_PATH $path | cut -f2 -d"'" | cut -f1 -d"'")
ace_dir_path=$(grep ACE_DIR_PATH $path | cut -f2 -d"'" | cut -f1 -d"'")
modelit_dir_path=$(grep MODELIT_DIR_PATH $path | cut -f2 -d"'" | cut -f1 -d"'")
storage_type=$(grep STORAGE_TYPE $path | cut -f2 -d"'" | cut -f1 -d"'")
root_hostdir_path=$(grep ROOT_HOSTPATH_DIR $path | cut -f2 -d"'" | cut -f1 -d"'")
root_shared_path=$(grep ROOT_SHARED_DIR $path | cut -f2 -d"'" | cut -f1 -d"'")
local_dir_mount_path=$(grep local_dir_mount_path $path | cut -f2 -d"'" | cut -f1 -d"'")
osds_root_dir=${osds_root_dir:-$local_dir_mount_path}

if $use_modelit; then
        ace_dir_path="${modelit_dir_path}/ds_admin"
else
        ace_dir_path=${ace_dir_path:-$modelit_dir_path}
fi

if [[ $storage_type == "nfs" ]]; then
        root_path=$root_shared_path
else
        root_path=$root_hostdir_path
fi

root_path=${root_path:-/smallworld}
osds_path=${osds_root_dir:-/osds_data}

ts=$(date +%s)
zulu=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

( 
        sep 'begin bundle'
        echo "version $VER"
        echo "timestamp $ts"
        echo "time $zulu"
        echo "namespace $namespace"
        echo
        echo $script $cli
        echo
        gather $path $message_dir_path $ace_dir_path 
        sep 'end bundle'
) >info-complete.txt

( 
        sep 'begin logs'
        echo "version $VER"
        echo "timestamp $ts"
        echo "time $zulu"
        echo "namespace $namespace"
        echo
        echo $script $cli
        echo
        logs
        sep 'end logs'
) >logs.txt

dir=$(dirname "$(readlink -f "$0")")

#cat info-complete.txt | grep -Evf $dir/exclude.txt > info.txt # some observed issues with excluding text
mv info-complete.txt info.txt

echo '' # terminate progress indicator line

args=''
files=''

if ! $nobundle; then
        now=$(date --utc +%Y%m%d_%H%M%SZ)
        file=bundle_${now}.tar${suffix}

        if [[ -f info.txt ]]; then
                files+=' info.txt'
        fi

        if [[ -f logs.txt ]]; then
                files+=' logs.txt'
        fi

        if [[ -f output.txt ]]; then
                files+=' output.txt'
        fi

        if [[ -f info-complete.txt ]]; then
                files+=' info-complete.txt'
        fi

        if [[ -d $root_path ]]; then
                files+=" $root_path"
        fi

        if [[ -d $osds_path ]]; then
                files+=" $osds_path"
        fi

        if [[ -f jq_missing ]]; then
                files+=' jq_missing'
        fi

        echo Generating bundle $(pwd)/$file
        tar -${args}cf $(pwd)/$file --exclude kubeconfig $files

        if $deploy_logs; then
                gather_deploy_logs $(pwd)/$file $args
        fi

        if $var_logs; then
                gather_var_logs $(pwd)/$file $args
        fi

        if [[ ! -z $(which gzip 2> /dev/null) ]]; then
                gzip $file
                file+=".gz"
        fi

        ls -lh $(pwd)/$file

        if [[ -f jq_missing ]]; then
                rm jq_missing
        fi       
fi

echo -e "\nAlways provide a minimum of info.txt and logs.txt with any support tickets. \c"

if $nobundle; then
        echo -e "info-complete.txt is not required.\c"
else
        echo -e "$(pwd)/$file is also recommended.\c"
fi

echo -e "\n"