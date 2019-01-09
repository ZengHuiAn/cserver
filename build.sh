#!/bin/bash

branch=`git branch | awk -F " " 'NF==2{print($2)}'`
echo "branch is $branch"

GIT_VERSION=`git log -1 --pretty=format:%h`

if [ $branch = "master" ]; then
	# 生成建库脚本
	echo "export sql"
	( cd "db_script" && \
		   echo '#!/bin/bash' > new_game_db.sh && \
		   chmod +x new_game_db.sh && \
		   echo 'if [ "$1" == "" ]; then echo "Usage $0 serverid"; exit; fi' >> new_game_db.sh &&  \
		   echo 'tail -n +6 "$0" | sed "s/<serverid>/$1/g" | sed "s/agame@localhost/agame/g"' >> new_game_db.sh &&  \
		   echo 'exit' >> new_game_db.sh && \
		   echo "# git version $GIT_VERSION" >> new_game_db.sh && \
		   echo '' >> new_game_db.sh && \
		   cat role_db.sql >> new_game_db.sh \
	) || exit

	( cd "db_script" && bash export_runtime.sh ) || exit
fi

echo "create version.h"
( cd "tools" && bash version.sh ) || exit 

echo "build server"
mkdir -pv lib/protobuf/
( cd "server" &&  make clean && make && make install ) || exit

echo "build data"
mkdir  -pv sock log
( cd "code_generate" && make clean && mkdir  -pv data && mkdir -pv db_config && make ) || exit

echo "build protocol"
( cd "protocol" && make clean && make ) || exit

echo "build config"
( cd "etc" && ./sql_to_xml.lua ) || exit

echo "build gateway"
( cd "gateway" &&  make clean && make ) || exit

echo "build world"
( cd "world" &&  make clean && make ) || exit

echo "build watcher"
( cd "watcher" &&  make clean && make ) || exit

echo "build gmserver authserver"
( cd "go" &&  make install ) || exit

# echo "build watcher"
# cd "watcher" &&  make clean && make || exit



( \
cd "bin" && \
./gateway       --version && \
./world         --version && \
./server        --version \
) || exit

cd ".."
