<?php
	//// inc ////
	include_once("log.php");
	set_log_file("./payback.log");
	
	//// game db ////
	$game_db_conn =null;
	function game_db_init($db){
		global $game_db_conn;
		if(!$game_db_conn){
			$game_db_conn =mysql_connect("localhost", "agame", "agame@123") or yqerror("Unable connect to game database");
			mysql_select_db($db, $game_db_conn) or yqerror( "Unable to select game database:" . mysql_error($game_db_conn));
		}
		return $game_db_conn;
	}
	function game_db_query($str){
		global $game_db_conn;
		if(!$game_db_conn){
			yqerror("fail to exec $str, game_db_conn is null");
		}
		$result =mysql_query($str, $game_db_conn);
		if(!$result){
			yqerror("mysql exec $str error:" . mysql_error($game_db_conn));
		}
		return $result;
	}
	function game_db_close(){
		global $game_db_conn;
		if(!$game_db_conn){
			mysql_close($game_db_conn);
			$game_db_conn =null;
		}
	}
	function db_num_rows($result){
		return mysql_num_rows($result);
	}
	function db_fetch_row($result){
		return mysql_fetch_array($result);
	}
?>
