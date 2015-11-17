#!/bin/sh

echo "Start $$ worker under $1 with sleep interval of $2s and max $3 iterations"

i=0

echo $$ > $1/tasks
if [ $? -ne 0 ]; then
	exit 1
fi

while [ 1 ]; do
	let i=$i+1;

	if [ $i -gt $3 ]; then
		exit 0
	fi

	sleep $2s
done
