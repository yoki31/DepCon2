#!/bin/bash
N=$1
for i in $(seq 1 $N)
do
	random_num="$(($RANDOM% 1001))"
	sed -i 's/100/'"$random_num"'/' job$i.yaml
        sleep 1
done
