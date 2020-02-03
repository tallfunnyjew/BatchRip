#!/usr/bin/env sh

# main.command
# Add Genre to Movie File

#  Created by Robert Yamada on 10/19/09.

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

function displayNotification () {
cat << EOF | osascript -l AppleScript
    try
        display notification "$3" with title "$1" subtitle "$2"
        delay 1
    end try
EOF
}

scriptPID=$$
bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`

# Debug
set -xv

# Create Log Folder
if [ ! -d "$HOME/Library/Logs/BatchRipActions" ]; then
	mkdir "$HOME/Library/Logs/BatchRipActions"
fi

# Redirect standard output to log
exec 6>&1
exec > "$HOME/Library/Logs/BatchRipActions/addGenreToMovieFile.log"
exec 2>> "$HOME/Library/Logs/BatchRipActions/addGenreToMovieFile.log"

while read theFile
do
	if [[ ! "${genrePopup}" ]]; then genrePopup=""; fi
	bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`
	mp4tagsPath="${bundlePath}/MacOS/mp4tags"
    fileName=`basename "$theFile"`

	if [ ! -x "$mp4tagsPath" ]; then
		displayAlert "Error: Add Genre to Movie File" "The Command Line Tools needed for this action could not be found. Please reinstall Batch Rip Actions for Automator."
		exit 1
	fi

if [ ! -z "$genrePopup" ]; then
	"$mp4tagsPath" -genre "$genrePopup" "$theFile"
else
    displayAlert "Error: Add Genre to Movie File" "Error: No genre selected.  Please choose a genre"
    displayNotification "Batch Rip Actions for Automator" "Error: Add Genre to Movie File" "No genre selected. Please choose a genre."
	exit 1
fi

returnList="${returnList}${theFile}|"
done

# Display script completed notification
displayNotificationCount=`echo "$returnList" | tr '|' '\n' | grep -v "^$" | grep -c ""`
displayNotification "Batch Rip Actions for Automator" "Add Genre to Movie File" "${displayNotificationCount} item(s) were processed."

# Restore standard output & return output files
exec 1>&6 6>&- 
echo "$returnList" | tr '|' '\n' | grep -v "^$"
exit 0