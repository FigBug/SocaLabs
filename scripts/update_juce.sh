#!/bin/bash

ROOT=$(cd "$(dirname "$0")/.."; pwd)
cd "$ROOT"
echo "$ROOT"

cd "$ROOT/scripts"
cat plugins.txt | while read PLUGIN; do
  PLUGIN=$(echo $PLUGIN|tr -d '\n\r ')

  echo ""
  echo "*** Updating JUCE for $PLUGIN***"
  echo ""

  cd "$ROOT/modules/$PLUGIN/modules/juce"
  git reset --hard
  git checkout develop
  git pull
  cd ../..
  git add -A
  git commit --message "Update JUCE"
  git push
done