#!/bin/bash
WORK_DIR=$(cd $(dirname $0)/..; pwd);
DATA_DIR=$WORK_DIR/data;
BIN_DIR=$WORK_DIR/bin;
LOG_DIR=$WORK_DIR/log;

[[ $# -ne 2 ]] && { echo "Usage: $0 <toUser> <text>">&2; exit 1; }
openId="$1";
text="$2";
type="text";
st=$(date +"%Y-%m-%d %H:%M:%S");
partId=$(date +%N | awk '{print substr($0,4,1);}');

echo "$text" | while read line; do
	echo $st;
	cat $DATA_DIR/sendMsg.tpl | awk -F'\t' '$1=="TEXT"{
		msg = "'"$line"'";
		gsub(" \\| ", "\n", msg);
		cont = $2;
		sub("____OPENID____", "'"$openId"'", cont);
		sub("____TYPE____",   "'"$type"'", cont);
		sub("____CONTENT____", msg, cont);
		print cont;
	}' | sh $BIN_DIR/sendKfMsg.sh;
	sleep 0.7;
done >>$LOG_DIR/sendTextMsg.log 2>&1 & 
