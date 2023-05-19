#!/bin/bash

#Env variables from .env file, create him next to the gitlab-runners-start.sh
#CI_SERVER - gitlab url or host
#REGISTRATION_TOKEN - gitlab runner token
#EXTRA_HOST - Need if you deployment on local network or not using IP Masquerade

DEFAULT_RUNNER_NAME="runner"

source ./.env

#Validate token
if [ -z "$REGISTRATION_TOKEN" ]
then
  echo "Please provide a registration token."
  exit 1
fi

#Validate server url
if [ -z "$CI_SERVER" ]
then
  echo "Please provide a ci server url address."
  exit 1
fi

while getopts ":c:t:p:n" opt; do
  case $opt in
    c) count="$OPTARG"
    ;;
    t) token="$OPTARG"
    ;;
    r) runners_prefix="$OPTARG"
    ;;
    n) new=true
    ;;
    \?) echo "Not valid params: -$OPTARG" >&2
    ;;
  esac
done

echo "Gitlab Token: $REGISTRATION_TOKEN"
echo "Count : $count"
echo "Runners prefix: $runners_prefix"

if [ "$new" = true ]; then
    if [ -d "gitlab-runner" ]; then
       current_date=$(date +'%d-%m-%Y-%H')
       mv $(pwd)/gitlab-runner $(pwd)/gitlab-runner-$current_date
       echo "Directory renamed from gitlab-runner to gitlab-runner-$current_date"
    else
       echo "Directory gitlab-runner does not exist"
    fi
fi

if [ ! -d "gitlab-runner" ]; then
    mkdir $(pwd)/gitlab-runner
fi 


for (( i=0; i<$count; i++ ))
do
    # stop all started runners from remote gitlab
    docker exec -it gitlab-runner-$i gitlab-runner unregister --all-runners 
    
    # stopping and removing containers
    docker stop gitlab-runner-$i
    docker rm gitlab-runner-$i
    
    #create subdirectory for current runner configuration
    if [ ! -d "gitlab-runner/gitlab-runner-$i" ]; then
       mkdir $(pwd)/gitlab-runner/gitlab-runner-$i
    fi 
    
    NAME=${DEFAULT_RUNNER_NAME}_$runners_prefix_$i
    echo "Runner : $name"
    
    docker run  --add-host $EXTRA_HOST -d --name gitlab-runner-$i --restart on-failure \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v $(pwd)/gitlab-runner/gitlab-runner-$i:/etc/gitlab-runner \
        -e RUNNER_NAME=${DEFAULT_RUNNER_NAME}_$runners_prefix_$i \
        -e CI_SERVER_URL=${CI_SERVER} \
        -e REGISTRATION_TOKEN=${REGISTRATION_TOKEN} \
        gitlab/gitlab-runner:latest

    # Start register runner on gitlab
    docker exec -it gitlab-runner-$i gitlab-runner register --non-interactive \
        --url $CI_SERVER \
        --registration-token $REGISTRATION_TOKEN \
        --executor docker \
        --clone-url $CI_SERVER \
        --docker-image alpine:latest \
        --run-untagged="true" \
        --docker-privileged \
        --docker-extra-hosts $EXTRA_HOST \
        --locked="false" \
        --docker-disable-cache = "true" \
        --access-level="not_protected"
             
    docker exec -it gitlab-runner-$i gitlab-runner --debug verify \
    --name $NAME \
    --url $CI_SERVER

done

#        --docker-network-mode host \