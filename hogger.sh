#!/bin/sh

CGPWD="/sys/fs/cgroup/memory"
MAX_SUB_CG=30
MAX_CG=20
MAX_ITER=20
VERBOSE=0

remove_cg()
{
	local i=0
	local num=$1
	local path="$CGPWD/rootcg/memcg$num"

	#
	# This is deliberately: issue rmdir of
	# a parent dir first and then go down
	# the path issuing rmdir for every
	# child
	#
	for i in `seq $MAX_SUB_CG`; do
		if [ $VERBOSE -eq 1 ]; then
			echo "Remove $path"
		fi
		rmdir -p $path > /dev/null 2>&1
		path="$path/memcg$num"
	done
}

teardown()
{
	local i=0
	local num=0
	local retry=1

	while [ $retry -eq 1 ]; do
		# issue rmdir for root (children nodes most likely still
		# present and busy)
		rmdir -p $CGPWD/rootcg
		if [ $? -ne 0 ]; then
			echo "Attempt to delete memory/rootcg in 1s"
			sleep 1s
		fi
		let num=$num+1

		if [ $num -gt 3 ]; then
			echo "Start sub-groups cleanups"
			for i in `seq $MAX_CG`; do
				remove_cg $i
			done
		fi

		if [ ! -e $CGPWD/rootcg ]; then
			let retry=0;
		fi
	done

	echo "*************************************************"
	echo "*                   REMOVED                     *"
	echo "*************************************************"
}

create_cg()
{
	local i=0
	local num=$1
	local path="$CGPWD/rootcg/memcg$num"

	for i in `seq $MAX_SUB_CG`; do
		mkdir $path
		if [ $? -ne 0 ]; then
			echo "Error while creating a cgroup $path"
			teardown
			exit 0
		fi

		path="$path/memcg$num"
	done
}

setup()
{
	local i=0
	echo 1 > $CGPWD/use_hierarchy

	mkdir $CGPWD/rootcg
	if [ $? -ne 0 ]; then
		echo "Cannot create rootcg"
		exit 1
	fi

	for i in `seq $MAX_CG`; do
		create_cg $i
	done
}

tick()
{
	local i=0
	for i in `seq $MAX_CG`; do
		./worker.sh $CGPWD/rootcg/memcg$i 0.1 10 &
		./worker.sh $CGPWD/rootcg/memcg$i/memcg$i 0.1 10 &
	done

	for i in `seq $MAX_CG`; do
		rmdir $CGPWD/rootcg/memcg$i
	done

	# just to smoke-test. attempt to delete the root
	rmdir -p $CGPWD/rootcg

	wait
}

if [ "z$1" == "zcleanup" ]; then
	teardown
	exit 1
fi

for iter in `seq $MAX_ITER`; do
	setup
	tick
	teardown
done

echo "*************************************************"
echo "*                 TEST PASSED                   *"
echo "*************************************************"
