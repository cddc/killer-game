<?php
/**
  * wechat php test
  */

//define your token
define("TOKEN", "559532cf28e8054ad8ab654a83bbbffc"); # echo "wangjingwen" | md5sum

require 'weixin_toolkit.php';

$wechatObj = new wechatCallbackapiTest();
if(array_key_exists("signature", $_GET) && array_key_exists("timestamp", $_GET) && array_key_exists("nonce", $_GET) && array_key_exists("echostr", $_GET)) {
    $wechatObj->valid();
    exit;
}
$wechatObj->dealMsg();

?>
