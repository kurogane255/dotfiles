#!/usr/bin/env bash
cpu=$(top -bn1 | awk -F'[,: ]+' '/%Cpu/{print 100-$8"%"}')
mem=$(free | awk '/Mem:/{printf "%.0f%%", $3/$2*100}')
printf 'CPU %s  MEM %s' "$cpu" "$mem"
