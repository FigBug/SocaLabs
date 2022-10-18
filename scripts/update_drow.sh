#!/bin/bash

ROOT=$(cd "$(dirname "$0")/.."; pwd)
cd "$ROOT"
echo "$ROOT"

cd "$ROOT/scripts"
cat plugins.txt | while read PLUGIN; do
  PLUGIN=$(echo $PLUGIN|tr -d '\n\r ')

  echo ""
  echo "*** Updating dRowAudio for $PLUGIN***"
  echo ""

  cd "$ROOT/modules/$PLUGIN"
  git reset --hard
  git checkout master
  git pull

  if [ -d "$ROOT/modules/$PLUGIN/modules/dRowAudio" ] 
  then
    cd "$ROOT/modules/$PLUGIN/modules/dRowAudio"
    git reset --hard
    git checkout master
    git pull
    cd ../..
    git add -A
    git commit --message "Update dRowAudio"
    git push
  fi
done