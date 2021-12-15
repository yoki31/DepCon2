#!/bin/bash

pkt=32

mkdir $1

for i in $(seq 1 6)
do	
	echo $pkt
	mkdir $1/p${pkt}
	
	for j in $(seq 1 10)
	do
		mkdir $1/p${pkt}/$j
		kubectl exec -it p1 --namespace=default -- netperf -H 10.0.0.25 -p 1 -l 123 -- -m ${pkt}&
		sleep 1
		kubectl exec -it p1 --namespace=default -- vnstat -tr 120 > $1/p${pkt}/$j/vnstat.txt&
		pidstat -G netperf 120 1 > $1/p${pkt}/$j/pidstat.txt & mpstat -P ALL 120 1 > $1/p${pkt}/$j/mpstat.txt
		sleep 3
	done
	
	((pkt=${pkt}*2))
done
