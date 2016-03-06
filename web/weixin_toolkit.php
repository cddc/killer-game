<?php
function print_log($msg)
{
    $work_dir = dirname(__FILE__)."/../bin";
    $log_dir = dirname(__FILE__)."/../log";
    $msg = str_replace("\n", "\N", $msg);
    $msg = str_replace("\t", "\T", $msg);
	$escapeStr = str_replace("\"", "__ESCAPED_QUOT__", $msg);
    system("sh $work_dir/print_log.sh \"$escapeStr\" >> $log_dir/weixin_gateway.log");
}

class wechatCallbackapiTest
{
    public function valid()
    {
        //valid signature , option
        if($this->checkSignature()){
            $echoStr = $_GET["echostr"];
            echo $echoStr;
            print_log("INFO weixin_handshake success");
        }else{
            print_log("INFO weixin_handshake failed' (".$_GET["signature"].", ".$_GET["timestamp"].", ".$_GET["nonce"].")");
        }
    }
        
    private function checkSignature()
    {
        // you must define TOKEN by yourself
        if (!defined("TOKEN")) {
            throw new Exception('TOKEN is not defined!');
        }
       
            $signature = $_GET["signature"];
            $timestamp = $_GET["timestamp"];
            $nonce = $_GET["nonce"];
                
            $token = TOKEN;
            $tmpArr = array($token, $timestamp, $nonce);
            // use SORT_STRING rule
            sort($tmpArr, SORT_STRING);
            $tmpStr = implode( $tmpArr );
            $tmpStr = sha1( $tmpStr );
        
            if( $tmpStr == $signature ){
                return true;
            }
    
        return false;
    }

	public function getReply($fromUserName, $content)
	{
        $work_dir = dirname(__FILE__)."/../bin";
		$cmd = sprintf("echo -e \"%s\t%s\" | nc -w2 127.0.0.1 20300", $fromUserName, $content);
		exec($cmd, $lines);
		if(count($lines)>0){
			$msgsToUser = array();
			// 把相同接收者的消息都聚到一起，$msgToUser[$toUserId]
			foreach($lines as $line){
				$kv = explode("\t", $line);
				if(count($kv)>=2) {
					$toUserId = $kv[0];
					$toMsg = $kv[1];
					if(!array_key_exists($toUserId, $msgsToUser)) $msgsToUser[$toUserId] = array();
					array_push($msgsToUser[$toUserId], $toMsg);
				}
			}
			// 按接收者依次发送消息
			foreach($msgsToUser as $toUserId => $msgs){
				$cmd = "sh $work_dir/sendTextMsg.sh '$toUserId' \"".join("\n",$msgs)."\"";
				`$cmd`;
				foreach($msgs as $toMsg){
					print_log("INFO RESP : ".implode(" ", array(time(),'text',$toUserId,$toMsg)));
				}
			}
		}
	}

	public function dealMsg()
	{
		if(array_key_exists("HTTP_RAW_POST_DATA", $GLOBALS)) {
			$postStr = $GLOBALS["HTTP_RAW_POST_DATA"];
            if (!empty($postStr)){
                libxml_disable_entity_loader(true);
				$postObj = simplexml_load_string($postStr, 'SimpleXMLElement', LIBXML_NOCDATA);

				$time = time();
				$content = trim($postObj->Content);
				if($postObj->MsgType == "text" && 0!=strcmp($content, "【收到不支持的消息类型，暂无法显示】")){
					print_log("INFO RECV : ".implode(" ", array($postObj->CreateTime,$postObj->MsgType,$postObj->FromUserName,$content)));
					$this->getReply($postObj->FromUserName, $content);
				}elseif($postObj->MsgType == "event" && $postObj->Event == "subscribe"){
					print_log("INFO RECV : ".implode(" ", array($postObj->CreateTime,$postObj->MsgType,$postObj->FromUserName,$postObj->Event)));
					$textTpl = "<xml> <ToUserName><![CDATA[%s]]></ToUserName> <FromUserName><![CDATA[%s]]></FromUserName> <CreateTime>%s</CreateTime> <MsgType><![CDATA[%s]]></MsgType> <Content><![CDATA[%s]]></Content> <FuncFlag>0</FuncFlag> </xml>";             
					$replyStr = "蜗牛驿站，欢迎您!\n回复'当前状态', 查询游戏.\n回复您姓名, 给系统存档 :)";
					$time = time();
					echo sprintf($textTpl, $postObj->FromUserName, $postObj->ToUserName, $time, 'text', $replyStr);
					print_log("INFO RESP : ".implode(" ", array($time,'text',$postObj->FromUserName,$replyStr)));
				}else{
					print_log("INFO RECV : ".implode(" ", array($postObj->CreateTime,$postObj->MsgType,$postObj->FromUserName,$content)));
					$repy_type = array("link"=>"链接","location"=>"地理位置","shortvideo"=>"小视频","video"=>"视频","voice"=>"语音","image"=>"图片","text"=>"自定义表情");
					$textTpl = "<xml> <ToUserName><![CDATA[%s]]></ToUserName> <FromUserName><![CDATA[%s]]></FromUserName> <CreateTime>%s</CreateTime> <MsgType><![CDATA[%s]]></MsgType> <Content><![CDATA[%s]]></Content> <FuncFlag>0</FuncFlag> </xml>";             
					$replyStr = "[系统]: 暂不接收".$repy_type["$postObj->MsgType"].".\n请说人话,敲人字 ...";
					$time = time();
					echo sprintf($textTpl, $postObj->FromUserName, $postObj->ToUserName, $time, 'text', $replyStr);
					print_log("INFO RESP : ".implode(" ", array($time,'text',$postObj->FromUserName,$replyStr)));
				}
            }else {
                print_log("INFO POST : empty HTTP_RAW_POST_DATA");
            }
        } else {
            print_log("INFO POST : no HTTP_RAW_POST_DATA");
        }
	}
    
    public function responseMsg()
    {
        //get post data, May be due to the different environments
        if(array_key_exists("HTTP_RAW_POST_DATA", $GLOBALS)) {
            $postStr = $GLOBALS["HTTP_RAW_POST_DATA"];

              //extract post data
            if (!empty($postStr)){
                /* libxml_disable_entity_loader is to prevent XML eXternal Entity Injection,
                   the best way is to check the validity of xml by yourself */
                libxml_disable_entity_loader(true);
                  $postObj = simplexml_load_string($postStr, 'SimpleXMLElement', LIBXML_NOCDATA);
                $fromUserName = $postObj->FromUserName;
                $toUsername = $postObj->ToUserName;
                $keyword = trim($postObj->Content);
                print_log("INFO RECV : ".implode(" ", array($postObj->CreateTime,$postObj->MsgType,$fromUserName,$keyword)));
                $this->response($msgType, $contentStr, $time, $postObj);
                print_log("INFO RESP : ".implode(" ", array($time,$msgType,$fromUserName,$contentStr)));
            }else {
                print_log("INFO POST : empty HTTP_RAW_POST_DATA");
            }
        } else {
            print_log("INFO POST : no HTTP_RAW_POST_DATA");
        }
    }

    private function response(&$msgType, &$contentStr, &$time, $postObj){
        $time = time();
        $work_dir = dirname(__FILE__)."/../bin";
        $repy_type = array("link"=>"链接","location"=>"地理位置","shortvideo"=>"小视频","video"=>"视频","voice"=>"语音","image"=>"图片","text"=>"文本");
        $textTpl = "<xml> <ToUserName><![CDATA[%s]]></ToUserName> <FromUserName><![CDATA[%s]]></FromUserName> <CreateTime>%s</CreateTime> <MsgType><![CDATA[%s]]></MsgType> <Content><![CDATA[%s]]></Content> <FuncFlag>0</FuncFlag> </xml>";             
        if($postObj->MsgType == "text"){
			$escapeStr = str_replace("\"", "__ESCAPED_QUOT__", json_encode($postObj));
			$cmd = "echo \"$escapeStr\" | sh $work_dir/getResponse.sh";
            $resp_obj=json_decode(`$cmd`);
            $msgType = "text"; // $resp_obj->{"MsgType"};
            $contentStr = $resp_obj->{"Content"};

            echo sprintf($textTpl, $postObj->FromUserName, $postObj->ToUserName, $time, $msgType, $contentStr);
        } else {
            $msgType = "text";
            $contentStr = "[法官]: 暂不接收".$repy_type["$postObj->MsgType"].", 请 说人话 敲文字 ...";
            echo sprintf($textTpl, $postObj->FromUserName, $postObj->ToUserName, $time, $msgType, $contentStr);
        }
    }
}

?>
