#!/usr/bin/env bash

# defaults
url='https://nexus.k8s.local:30443'
username='admin'
password='dummy'
repo='bsf-docker-virtual'
args=''

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -U|--url)
      url=$2
      shift; shift
      ;;
    -u|--username)
      username=$2
      shift; shift
      ;;
    -p|--password)
      password=$2
      shift; shift
      ;;
    -R|--repo)
      repo=$2
      shift; shift
      ;;
    # -D|--debug)
    #   debug=true
    #   shift
    #   ;;
    # -x|--set-x)
    #   set_x=true
    #   shift
    #   ;;
    *)
      args+="$key"
      shift
  esac
done

host=$(echo "$url" | awk -F[/:] '{print $4}')

if [[ $(which jq | wc -l) -eq 0 ]]; then
    echo -e "Missing jq. Cannot continue.\nPlease install jq from a repo or https://stedolan.github.io/jq/download/"
    exit 1
fi

touch /tmp/$$.txt

loop=true
while($loop); do
    curl -sX GET "$url/service/rest/v1/components?repository=$repo$args" -H  "accept: application/json" --insecure -o /tmp/$$.json --noproxy $host -u $username:$password

    if [[ ! -f /tmp/$$.json ]]; then
        echo "Possible credential or nexus repository name error"
        loop=false
    else 
        jq '.items[] | "\(.name):\(.version)"' /tmp/$$.json >> /tmp/$$.txt

        token=$(jq '.["continuationToken"]' /tmp/$$.json | sed -e 's/^"//' -e 's/"$//')

        if [[ $token == null ]]; then
            loop=false
        else
            args="&continuationToken=$token"
        fi
    fi
done

sort /tmp/$$.txt | sed -e 's/^"//' -e 's/"$//' | cat

rm -f /tmp/$$.json /tmp/$$.txt