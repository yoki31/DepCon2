#!/bin/bash
N=$1
for i in $(seq 21 $N)
do
	sed -i "s/p41/p$i/g" p$i.yaml
done
