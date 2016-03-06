#!/bin/bash
WORK_DIR=$(cd $(dirname $0)/..; pwd);
DATA_DIR=$WORK_DIR/data;

wget "https://api.weixin.qq.com/cgi-bin/getcallbackip?access_token=$(cat $DATA_DIR/access_token)" -O - | cat
