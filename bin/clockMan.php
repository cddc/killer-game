<?php

$work_dir = dirname(__FILE__);
require "$work_dir/../web/weixin_toolkit.php";

$wechatObj = new wechatCallbackapiTest();
$sleep_time = 3;
for($i=0; $i>=0; $i+=$sleep_time){
	$wechatObj->getReply('p0', 'NONE'); 
	sleep($sleep_time);
}
?>
