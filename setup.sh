#!/bin/bash

#Static array of our training namespaces
namespaces=(ant badger bear bee beetle bird bison buffalo bulldog butterfly trainer)

#Create our namespaces, sample admin policy, and token for the namespace
for i in ${namespaces[@]}; do
vault namespace create $i
vault policy write -namespace=$i admin admin.hcl
vault token create -namespace $i -type=service -policy=admin -field=token > tokens/$i-token
done
