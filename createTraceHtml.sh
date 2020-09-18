#!/bin/bash

#First Argument should be trace file name
#Second Argument is path of directory
#example, ./createTraceHtml.sh priv/static/trace.html traces/generated/6102B93137E4D46E4A3D5A97B0AC1AD5

# echo "First arg: $1"
# echo "Second arg: $2"

mainSVGName=$(cat $2/index.html)

mainSVGName=${mainSVGName%%\' type=*}
mainSVGName=${mainSVGName%%\' type=*}
mainSVGName=${mainSVGName#*data=\'}



mainSVGName=$(echo $mainSVGName | sed -e 's/\//\\\//g')
echo $mainSVGName


cp $1 $2/temp.html
# sed "s/mp_home.svg/\/trace\/6102B93137E4D46E4A3D5A97B0AC1AD5\/28394.svg/g" traces/generated/6102B93137E4D46E4A3D5A97B0AC1AD5/temp.html > traces/generated/6102B93137E4D46E4A3D5A97B0AC1AD5/mainTrace.html
sed "s/mp_home.svg/$mainSVGName/g" $1 > $2/mainTrace.html
rm $2/temp.html