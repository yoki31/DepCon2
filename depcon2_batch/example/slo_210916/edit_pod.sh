#!/bin/bash
N=$1
for i in $(seq 22 $N)
do
	sed -i 's/qj-21/'"qj-$i"'/' job$i.yaml
done
