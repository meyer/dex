#!/bin/sh
while [ 1 ]; do
	wget --no-check-certificate https://127.0.0.1:3131/memtest.com.css 2>&1 >/dev/null
	sleep 1
done