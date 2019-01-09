<?php
	//// inc ////
	include_once("database.php");

	//// prepare argv ////
	if($argc < 2){
		die("missing pid");
	}
	$pid =intval($argv[1]);
	$date_str = date('Y-m-d H:i:s');
	yqlog("[$date_str]pid =$pid");

	//// init game db ////
	game_db_init("aGameMobile_101001002");
	
	//// prepare player data /////
	$accountreward =null;
	$result =game_db_query("SELECT `reward_for_accumulate_consume_gold_activity_consume`,`reward_for_accumulate_consume_gold_activity_consume_status` FROM `accountreward` WHERE `pid`=$pid");
	$row =db_fetch_row($result);
	if($row){
		$accountreward =array(
			"consume_value" => $row['reward_for_accumulate_consume_gold_activity_consume'],
			"status"        => $row['reward_for_accumulate_consume_gold_activity_consume_status'],
		);
		yqlog("$pid consume value is " . $accountreward['consume_value']);
		yqlog("$pid status is " . $accountreward['status']);
	}
	else{
		echo("$pid is not a valid player id");
		yqerror("$pid is not a valid player id");
	}

	//// prepare config data /////
	$config =array();
	$result =game_db_query("SELECT `uuid`, `flag`, `consume_value`, `type`, `id`, `value`, `begin_time`, `end_time` FROM `accumulate_consume_config`");
	$row =db_fetch_row($result);
	while($row){
		$item =array(
			"uuid"          => $row['uuid'],
			"flag"          => $row['flag'],
			"consume_value" => $row['consume_value'],
			"type"          => $row['type'],
			"id"            => $row['id'],
			"value"         => $row['value'],
			"begin_time"    => $row['begin_time'],
			"end_time"      => $row['end_time'],
		);
		array_push($config, $item);
		$row =db_fetch_row($result);
	}

	//// process ////
	for($i=0; $i<count($config); $i++){
		$status =$accountreward['status'];
		$item =$config[$i];
		if($accountreward['consume_value'] >= $item['consume_value']){
			$state =(($status >> ($i*2)) & 3);
			if($state == 0){
				echo "$i\n";
				yqlog("$pid <---> $i");
			}
			elseif($state == 1){
				yqlog("$pid <+++> $i");
			}
			elseif($state == 2){
				yqlog("$pid <***> $i");
			}
			else{
				yqlog("$pid <???> $i");
			}
		}
	}
?>
