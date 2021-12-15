#!/bin/bash

quota=100

mkdir q10
kubectl create -f p1.yaml

a=''
while [ "$a" != "Running" ]
do
a=`kubectl get pods | awk '{print $3}' |tail -1`;
sleep 1
done

sh netperf_pod.sh q10 
sleep 2
kubectl delete -f p1.yaml
sed -i "s/10m/100m/g" p1.yaml

for i in $(seq 1 10)
do
	mkdir q${quota}
	kubectl create -f p1.yaml

	a=''
	while [ "$a" != "Running" ]
	do
	a=`kubectl get pods | awk '{print $3}' |tail -1`;
	sleep 1
	done
	
	sh netperf_pod.sh q${quota}
	sleep 2
	kubectl delete -f p1.yaml
	((tmp=${quota}+100))
	sed -i "s/${quota}m/${tmp}m/g" p1.yaml
	quota=$tmp
done

