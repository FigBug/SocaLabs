#!/bin/bash

ROOT=$(cd "$(dirname "$0")/.."; pwd)
cd "$ROOT"
echo "$ROOT"

cd "$ROOT/scripts"
cat plugins.txt | while read PLUGIN; do
  PLUGIN=$(echo $PLUGIN|tr -d '\n\r ')

  echo ""
  echo "*** Updating Gin for $PLUGIN***"
  echo ""

  cd "$ROOT/modules/$PLUGIN/modules/gin"
  git reset --hard
  git checkout master
  git pull
  cd ../..
  git add -A
  git commit --message "Update Gin"
  git push
done