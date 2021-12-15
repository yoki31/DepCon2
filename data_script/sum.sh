#!/bin/bash

pkt=32

for i in $(seq 1 6)
do
	for j in $(seq 1 10)
	do
		cat p${pkt}/$j/vnstat.txt >> total_p${pkt}_vnstat.txt
		cat p${pkt}/$j/pidstat.txt >> total_p${pkt}_pidstat.txt
		cat p${pkt}/$j/mpstat.txt >> total_p${pkt}_mpstat.txt
	done
	((pkt=${pkt}*2))
done
