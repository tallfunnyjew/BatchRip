#!/usr/bin/env sh

# main.command
# Get Source Info from HandBrake

#  Created by Robert Yamada on 11/30/09.
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

scriptPID=$$
bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`

function displayNotification () {
cat << EOF | osascript -l AppleScript
    try
        display notification "$3" with title "$1" subtitle "$2"
        delay 1
    end try
EOF
}

# Debug
set -xv

# Create Log Folder
if [ ! -d "$HOME/Library/Logs/BatchRipActions" ]; then
	mkdir "$HOME/Library/Logs/BatchRipActions"
fi

# Redirect standard output to log
exec 6>&1
exec > "$HOME/Library/Logs/BatchRipActions/getSourceInfoFromHandBrake.log"
exec 2>> "$HOME/Library/Logs/BatchRipActions/getSourceInfoFromHandBrake.log"

while read theFile
do

	if [[ ! "${hbPath}" ]]; then hbPath="no selection"; fi
	if [[ ! "${savePath}" ]]; then savePath="no selection"; fi

		if [[ ! -x "$hbPath" ]]; then
			displayAlert "Error: Get Source Info from HandBrake" "HandBrakeCLI could not be found. Please check your workflow in Automator."
			exit 1
		fi

	fileExt=`echo "$theFile" | sed 's|.*\.||'`
	fileName=`basename "$theFile" .${fileExt}`
	"$hbPath" -i "$theFile" -t0 > "${savePath}/${fileName}-hbInfo.txt" 2>&1

	returnList="${returnList}${theFile}|"
done

# Display script completed notification
displayNotificationCount=`echo "$returnList" | tr '|' '\n' | grep -v "^$" | grep -c ""`
displayNotification "Batch Rip Actions for Automator" "Get Source Info from HandBrake" "${displayNotificationCount} item(s) were processed."

# Restore standard output & return output files
exec 1>&6 6>&- 
echo "$returnList" | tr '|' '\n' | grep -v "^$"
exit 0