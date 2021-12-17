#!/bin/bash
for i in $(seq 1 100)
do
	kubectl $1 -f job$i.yaml
done
