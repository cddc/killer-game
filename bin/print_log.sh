#!/bin/bash
WORK_DIR=$(cd $(dirname $0)/..; pwd);
DATA_DIR=$WORK_DIR/data;

st=$(date +"%Y-%m-%d %H:%M:%S")
msg="$(echo "$1" | sed 's/__ESCAPED_QUOT__/\"/g')";
echo -e "$st $msg"
