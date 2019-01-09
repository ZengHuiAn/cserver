#!/bin/bash

VER=`git show | grep '^commit' | awk '{print $2}'`;

for dir in ../{world,gateway,server}
do
	echo $dir
	cat version.h.template | sed "s/GIT_VERSION/$VER/g" > $dir/version.h
done
