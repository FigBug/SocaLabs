#!/bin/bash

ROOT=$(cd "$(dirname "$0")/.."; pwd)
cd "$ROOT"
echo "$ROOT"

cd "$ROOT/scripts"
cat plugins.txt | while read PLUGIN; do
  PLUGIN=$(echo $PLUGIN|tr -d '\n\r ')

  cd "$ROOT/modules/$PLUGIN"
  git add -A
  git commit --message "Add LV2 for Linux"
  git push

done