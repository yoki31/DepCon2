#!/bin/bash
for i in $(seq 2 100)
do
        cp job1.yaml job$i.yaml
done
