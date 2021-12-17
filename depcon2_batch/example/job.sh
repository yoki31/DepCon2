#!/bin/bash
N=$1
for i in $(seq 1 $N)
do
	sed -i 's/qj-1/qj-'"$i"'/' job$i.yaml
        sleep 1
done
