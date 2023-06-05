VER=1

namespace='gss-prod' # default
dummy=''
kubeconfig=''
osds_root_dir=''
nobundle=false
use_modelit=false
include_previous=false
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
        docker version 2> /dev/null
        echo
        sep2 "docker info" ${FUNCNAME[0]}
        docker info 2> /dev/null
        echo
        sep2 "docker images" ${FUNCNAME[0]}
        docker images 2> /dev/null
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

nexus() {
        sep ${FUNCNAME[0]}

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
        nodes
        pods
        nexus
        describe
}

usage() {
        cat << EOD
Usage: $0 </path/to/pdi_input_manifest.yaml>

        -n|--namespace <namespace>
                Use alternate namespace <namespace> (deprecated - now read from manifest)
        -k|--kubeconfig </path/to/kubeconfig>
                Use alternate config file to that specified in KUBECONFIG, or where not defined
        -o|--osds_root_dir </path/to/osds_root_dir>
                Override osds_root_dir. Commonly used for older manifests where this was not defined
        -m|--use_modelit_dir_path
                Use MODELIT_DIR_PATH from manifest rather than ACE_DIR_PATH
        -p|--include-previous
                Include any previous log files, even for running pods
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

path=$1

if [[ -z $path || ! -f $path ]]; then
        usage
fi

shift

namespace=$(grep GSS_NAMESPACE $path | cut -f 2 -d : | tr -d '[:space:]' | tr -d \" | tr -d \') # cannot use "tr -d '[:punct:]'" because namespace may contain a hyphen

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -n|--namespace)
      dummy=$2
      shift; shift
      echo "--namespace option is now deprecated. Taking namespace '$namespace' from manifest"
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
    -p|--include-previous)
      include_previous=true
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

# # avoid permissions errors
# if ! $nonroot; then
#         if [[ $(id -u) -ne 0 ]]; then
#                 echo "*** Error: Running as user $USER not as root/sudo user"
#                 exit 1
#         fi
#         isroot=true
# fi

if [[ -z $KUBECONFIG ]]; then
        if [[ ! -z $kubeconfig ]]; then
                export KUBECONFIG=$kubeconfig
        else
                echo "*** Error: KUBECONFIG nor -k/--kubeconfig set"
                exit 1
        fi
fi

message_dir_path=$(grep MESSAGES_DIR_PATH $path | cut -f2 -d"'" | cut -f1 -d"'")
ace_dir_path=$(grep ACE_DIR_PATH $path | cut -f2 -d"'" | cut -f1 -d"'")
modelit_dir_path=$(grep MODELIT_DIR_PATH $path | cut -f2 -d"'" | cut -f1 -d"'")
storage_type=$(grep STORAGE_TYPE $path | cut -f2 -d"'" | cut -f1 -d"'")
root_hostdir_path=$(grep ROOT_HOSTPATH_DIR $path | cut -f2 -d"'" | cut -f1 -d"'")
root_shared_path=$(grep ROOT_SHARED_DIR $path | cut -f2 -d"'" | cut -f1 -d"'")
local_dir_mount_path=$(grep local_dir_mount_path $path | cut -f2 -d"'" | cut -f1 -d"'")
osds_root_dir=${osds_root_dir:-$local_dir_mount_path}

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
        sep 'begin minimal'
        echo "version $VER"
        echo "timestamp $ts"
        echo "time $zulu"
        echo "namespace $namespace"
        echo
        echo $script $cli
        echo
        gather $path $message_dir_path $ace_dir_path 
        sep 'end minimal'
) >minimal.txt

dir=$(dirname "$(readlink -f "$0")")

echo '' # terminate progress indicator line

args=''
files=''

echo -e "\n"