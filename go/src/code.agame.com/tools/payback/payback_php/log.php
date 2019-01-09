<?php
	$log_file =null;
    function set_log_file($path){
		global $log_file;
        log_cleanup();
        $log_file =fopen($path, "a") or die("fail to open $path\n");
    }
	function yqlog($msg){
		global $log_file;
		if(!$log_file){
			$log_file =fopen("/data2/logs/pay/log.txt", "a") or die("fail to open /data2/logs/pay/log.txt\n");
		}
		if($log_file && $msg){
			fwrite($log_file, $msg . "\n");
		}
	}
	function yqerror($msg){
		yqlog($msg);
		die("system error\n");
	}

	// init & cleanup
	function log_init(){
	}
	function log_cleanup(){
		global $log_file;
		if($log_file){
			fclose($log_file);
			$log_file =null;
		}
	}
?>
