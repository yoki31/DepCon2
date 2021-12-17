#!/bin/bash
value=$(<b.txt)
cnt=1

for i in ${value[@]}
do
	sed -i 's/SLO: \"100\"/'"SLO: \"$i\""'/' job$cnt.yaml
	cnt=$((cnt+1))
done
