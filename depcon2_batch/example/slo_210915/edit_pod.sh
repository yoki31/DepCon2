#!/bin/bash
N=$1
for i in $(seq 2 $N)
do
	sed -i 's/qj-1/'"qj-$i"'/' job$i.yaml
done
