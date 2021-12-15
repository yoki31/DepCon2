#!/bin/bash
for i in $(seq 1 100)
do
	cat p$i.yaml | grep SLO
	#sleep 1
done
