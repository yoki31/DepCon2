#!/bin/bash

N=$2
for i in $(seq 1 $N)
do
	kubectl $1 -f job$i.yaml
done
