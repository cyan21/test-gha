#!/bin/bash

server_id="jfrog-platform-training"

# install CLI in the current folder
curl -fL -s https://getcli.jfrog.io/v2-jf | sh
./jf --version

./jf c s | grep $server_id > /dev/null

if [[ $? -eq 0 ]]; then 
    echo "[ERROR] an existing profile $server_id already exists." 
    exit 1
fi 

# configure CLI 
./jf c add $server_id  --interactive=false \
    --url="$1" --user="$2" --password="$3" 
./jf rt ping --server-id $server_id

# RT - CONFIG
##### Create repositories
./jf rt curl -XPATCH api/system/configuration -T rt/repositories.yml \
    
##### Generate a user
password="`echo $RANDOM | shasum | cut -d" " -f1`L@Z"
./jf rt user-create ci "${password}" "robot.doe@nobody.org" --server-id $server_id

##### Create Permission Targets
./jf rt ptu rt/ci_permissions.json --server-id $server_id

# XRAY - CONFIG
##### Create policies 
for p in `ls xr/policy*`; do  
    ./jf xr curl -H "Content-Type: application/json" -XPOST api/v2/policies -T $p --server-id $server_id
done

##### Index build info 
./jf xr curl -XPOST api/v1/binMgr/builds -H "Content-Type: application/json" -d '{"names": ["java-webapp-gha", "js-webapp-gha","python-webapp-gha","docker-java-webapp-gha","docker-js-webapp-gha","docker-python-webapp-gha"]}' --server-id $server_id

##### Create watches
for w in `ls xr/watch*`; do  
    ./jf xr curl -H "Content-Type: application/json" -XPOST api/v2/watches -T $w --server-id $server_id
done

# Configuring GHA requires to create 2 secrets : 
# A/ configure CLI
# B/ Docker registry

# A/ show the token for GHA
jf_secret=`./jf c export $server_id`

echo "*********************************"
echo "In Github, create these 2 secrets :"
echo -e "\t  - JF_SECRET : $jf_secret"

# B/ show the ci user's password
echo -e "\t  - DOCKER_SECRET : $password"
echo "*********************************"
