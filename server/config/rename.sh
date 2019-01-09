#!/bin/bash

if [ "$2" == "" ]
then
	exit;
fi

mv $1.xml $2.xml
mv $1.sh $2.sh
mv $1.txt $2.txt
