#!/bin/bash

ROOT=$(cd "$(dirname "$0")/.."; pwd)
cd "$ROOT"
echo "$ROOT"

cat ./scripts/jucer.txt | while read JUCER; do
  JUCER=$(echo $JUCER|tr -d '\n\r ')

  echo ""
  echo "*** Updating deps for $JUCER***"
  echo ""

  /Applications/Projucer.app/Contents/MacOS/Projucer --resave $JUCER --fix-missing-dependencies 
done