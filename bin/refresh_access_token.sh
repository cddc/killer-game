#!/bin/bash
WORK_DIR=$(cd $(dirname $0)/..; pwd);
DATA_DIR=$WORK_DIR/data;
TMP_DIR=$WORK_DIR/tmp;

APPID="wxb8b90fa54408bebd";
APPSECRET="31712b6649624c2c76be835ac4aa2d33";

function getAccessToken {
	wget "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=$APPID&secret=$APPSECRET" -O $TMP_DIR/access_token.json ;
	cat $TMP_DIR/access_token.json | perl -e '$line=<>; if($line =~ /"access_token":"([^"]+)"/){ print $1; };' > $DATA_DIR/access_token;
	cat $TMP_DIR/access_token.json | perl -e '$line=<>; $sec=3600; if($line =~ /"expires_in":(\d+)/){ $sec=$1; }; print $sec;';
	
}

while(true); do
	sleep_seconds=$(( $(getAccessToken) / 2 ));
	echo "done. refresh after $sleep_seconds sec";
	sleep $sleep_seconds;
done
