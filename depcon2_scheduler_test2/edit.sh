#!/bin/bash

value=$(<b.txt)
cnt=1

for i in {21..40}
do
	sed -i "s/300/200/g" p$i.yaml
done
