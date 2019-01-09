# prepare db name
branch=`git branch | awk -F " " 'NF==2{print($2)}'`
echo "branch is $branch"

db_name="aGameMobileConfig_sgk"

# export
echo "exporting ......"
mysqldump -uagame -pagame@123 -h10.1.2.79 --skip-lock-tables $db_name \
			  product \
			  lucky_draw \
			  sweepstakeconfig \
			  config_manor_energy \
			  manor_manufacture_product \
			  config_manor_line_cfg \
			  pray_config \
			  GuildExploreConfig \
			  timeControl \
			  gift_bag \
			  item_package_config \
			  config_manor_property \
			  config_mine_event \
			  config_shop_event \
			  config_pub_event \
			  config_pub_event_pool \
			  sweepstakepoolconfig \
			  config_manor_line_open \
			  config_manor_level_up \
			  ai_name | sed 's/),/),\n/g' > import_runtime_data.sql

# import
if [ -f "import_local.sh" ]
then
	echo "importing ......"
	bash import_local.sh
fi

# arena ai 
cd ../arena
echo "gen arena random ai"
bash gen.sh

# finish
echo "finish."

