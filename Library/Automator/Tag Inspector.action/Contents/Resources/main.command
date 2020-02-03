#!/usr/bin/env sh

# main.command
# Tag Inspector

#  Created by Robert Yamada on 11/13/09.
#  Copyright (c) 2009-2013 Robert Yamada
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.

#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.

#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.

function displayAlert () {
cat << EOF | osascript -l AppleScript
	tell application "System Events" to activate & display alert "$1" message "$2" as warning
EOF
}


scriptPID=$$
bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`
atomicParsleyPath="${bundlePath}/MacOS/AtomicParsley"
mp4infoPath="${bundlePath}/MacOS/mp4info"
mp4chapsPath="${bundlePath}/MacOS/mp4chaps"

# Debug
set -xv

# Create Log Folder
if [ ! -d "$HOME/Library/Logs/BatchRipActions" ]; then
	mkdir "$HOME/Library/Logs/BatchRipActions"
fi

# Redirect standard output to log
exec 6>&1
exec > "$HOME/Library/Logs/BatchRipActions/tagInspector.log"
exec 2>> "$HOME/Library/Logs/BatchRipActions/tagInspector.log"

while read theFile
do

	if [[ ! -x "$mp4infoPath" || ! -x "$mp4chapsPath" || ! -x "$atomicParsleyPath" ]]; then
		displayAlert "Error: Tag Inspector" "The Command Line Tools needed for this action could not be found. Please reinstall Batch Rip Actions for Automator."
		exit 1
	fi

fileName=`basename "$theFile" | sed 's|\..*$||'`
tagInfoFile="Tag info for $fileName.txt"
echo "\n--------------------------------------------------------------------------------------------------------------" > "/tmp/${tagInfoFile}"
echo "TAG INFORMATION FROM MP4INFO:" >> "/tmp/${tagInfoFile}"
echo "--------------------------------------------------------------------------------------------------------------\n" >> "/tmp/${tagInfoFile}"
"$mp4infoPath" "$theFile" >> "/tmp/${tagInfoFile}"
echo "\n--------------------------------------------------------------------------------------------------------------" >> "/tmp/${tagInfoFile}"
echo "TAG INFORMATION FROM ATOMICPARSLEY:" >> "/tmp/${tagInfoFile}"
echo "--------------------------------------------------------------------------------------------------------------\n" >> "/tmp/${tagInfoFile}"
"$atomicParsleyPath" "$theFile" -t >> "/tmp/${tagInfoFile}"
echo "\n--------------------------------------------------------------------------------------------------------------" >> "/tmp/${tagInfoFile}"
echo "CHAPTER INFORMATION FROM MP4CHAPS:" >> "/tmp/${tagInfoFile}"
echo "--------------------------------------------------------------------------------------------------------------\n" >> "/tmp/${tagInfoFile}"
"$mp4chapsPath" -l "$theFile" >> "/tmp/${tagInfoFile}"

qlmanage -p "/tmp/${tagInfoFile}" >& /dev/null

returnList="${returnList}${theFile}|"
done

if [ -e "/tmp/${tagInfoFile}" ]; then
	rm -f "/tmp/${tagInfoFile}"
fi

# Restore standard output & return output files
exec 1>&6 6>&- 
echo "$returnList" | tr '|' '\n' | grep -v "^$"
exit 0