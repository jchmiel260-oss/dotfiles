#!/bin/bash

IP="witek.tail"
DELAY=5
STATE="unknown" # can be: unknown, online, offline

while true; do
	if ping -c 1 -W 1 "$IP" > /dev/null 2>&1; then
		if [ "$STATE" != "online" ]; then
			notify-send "Online" "$IP IS FINALLY ONLINE"
			STATE="online"
		fi
	else
		if [ "$STATE" != "offline" ]; then
			notify-send "Offline" "$IP IS DOWN"
			STATE="offline"
		fi
	fi

	sleep "$DELAY"
done
