#!/usr/bin/env sh

# main.command
# Rename TV Items

#  Created by Robert Yamada on 12/2/10.

#  CHANGES:
#  2010.12.02-0 - Initial Release
#  2011.07.28-0 - Updated dialogs for Lion

#  REVISIONS, by David Koff:
#  2020.02.01 - 
				# Added or updated xmllintPath and tvdbApiKey variables
				# Updated "function tvdbGetSeriesTitles ()" to account for new TVdb API functionality
				# Added a date stamp at the top of the log output
				# Matched /tmp folder variables and calls from main BatchRip script 

#   Copyright (c) 2009-2013 Robert Yamada
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

#####################################################################################
# FUNCTIONS
#####################################################################################

function displayDialogGetTvShowName () {
	cat << EOF | osascript -l AppleScript
		tell application "System Events" 
		activate
		display dialog "What is the TV show title?" default answer "" buttons {"Cancel", "OK"} default button 2
		if the button returned of the result is "OK" then
			return text returned of the result
		else
			return "Cancelled"
		end if
		end tell
EOF
}

function displayDialogGetSeasonAndDisc () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$2"
		tell application "System Events" 
		activate
		display dialog "Enter Season & Disc Number for " & theFile default answer "S1D1" buttons {"Cancel", "OK"} default button 2
		if the button returned of the result is "OK" then
			return text returned of the result
		else
			return "Cancelled"
		end if
		end tell
EOF
}

function tvdbGetSeriesTitles () {
	searchString=`htmlEncode "$(echo "$1" | sed 's|\ \-\ |:\ |g')"`
	
	# Set the TVdb searchTerm
	searchTerm=`urlEncode "$searchString"`
	
	# get mirror URL - the TVDB has deprecated use of mirrors, so this line of code is now commented out
	# tvdbMirror=`$curlCmd "http://www.thetvdb.com/api/$tvdbApiKey/mirrors.xml" | "$xpathPath" "//mirrorpath/text()" 2>/dev/null`
	
	# Find the correct TV series name
	# (1) Download a master XML file with all API search results:	
	$curlCmd "http://www.thetvdb.com/api/GetSeries.php?seriesname=$searchTerm" > "${tmpFolder}/${searchTerm}.xml"
	
	# this is the old XML parser that fails because the XML search itself has changed above:
	# tvdbSearch=`cat "${tmpFolder}/${searchTerm}.xml" | grep '<id>' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	
	# (2) Parse out every "seriesid" tag from our XML data search results
	tvdbSearch=`awk -F '>' '/^seriesid/ {print $2}' RS='<' "${tmpFolder}/${searchTerm}.xml"`
	
	# (3) Prep data and present to end user
	for tvdbID in $tvdbSearch
	do
		# (a) Download each TV show to a separate xml file
		$curlCmd "http://www.thetvdb.com/api/$tvdbApiKey/series/$tvdbID/en.xml" > "${tmpFolder}/$tvdbID.xml"
		seriesData="${tmpFolder}/${tvdbID}.xml"
		
		# (b) Check/fix each show's xml data
		cat "$seriesData" | egrep -B 9999999 -m1 "</Data>" | "$xmllintPath" --recover --nsclean --format --output "$seriesData" - 
		dateAired=`cat "$seriesData" | grep -m1 '<FirstAired>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed 's|-.*||g'`
		
		# (c) Isolate TV Series title from rest of xml data
		seriesTitle=$(substituteISO88591 "$(cat "$seriesData" | grep -m1 '<SeriesName>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed 's|:| -|g')")

		if [ ! -z "$seriesTitle" ]; then
			seriesFound="${seriesFound}${seriesTitle} - First Aired: ${dateAired}+"
		fi
	done
		echo $seriesFound | tr '+' '\n'
}

function displayDialogChooseTitle () {
	cat << EOF | osascript -l AppleScript
	try
	set theList to paragraphs of "$1"
	tell application "System Events" 
	activate
	choose from list theList with title "Choose from List" with prompt "Please make your selection:"
	end tell
	end try
EOF
}

function displayDialogGetSeasonEpisode () {
	cat << EOF | osascript -l AppleScript
		set theShow to "$1"
		set theFileExt to "$2"
		set theFile to "$3"
		tell application "System Events"
			activate
			display dialog "Enter the Season and Episode Number for file:" & return & theFile & return & return & "Important!  When renaming multiple files, each file will be renamed sequentially starting with the episode number entered below." & return & return & "Example:" & return & "  " & theShow & " - S01E01." & theFileExt & return & "  " & theShow & " - S01E02." & theFileExt & return & "  " & theShow & " - S01E03." & theFileExt default answer "S01E01" buttons {"Cancel", "OK"} default button 2 with title "Enter the Season and Episode Number"
			if the button returned of the result is "OK" then
				return text returned of the result
			else
				return "Cancelled"
			end if
		end tell
EOF
}

function urlEncode () {
	escapeString=$(echo "$1" | sed -e "s|\'|\\\'|g" -e 's|&amp;|\&|g')
	#php -r "echo urlEncode('$1');"
	#php -r "echo urlEncode(iconv('UTF-8-MAC', 'UTF-8', '$1'));"
	php -r "echo urlEncode(iconv('ISO-8859-1', 'UTF-8', '$escapeString'));"
}

function htmlEncode () {
	escapeString=$(echo "$1" | sed "s|\'|\\\'|g" )
	php -r "echo htmlspecialchars(iconv('UTF-8-MAC', 'ISO-8859-1', '$escapeString'));"
}

function substituteISO88591 () {
	escapeString=$(echo "$1" | sed "s|\'|\\\'|g" )
	php -r "echo mb_convert_encoding('$escapeString', 'UTF-8', 'HTML-ENTITIES');"
}

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

function cleanUpTmpFiles () {
		if [ -e "$tmpFolder" ]; then
			rm -rfd $tmpFolder
		fi
}

#####################################################################################
# MAIN SCRIPT
#####################################################################################

# Debug
set -xv

# Variables
xpathPath="/usr/bin/xpath"
xmllintPath="/usr/bin/xmllint"								## Added
scriptPID=$$
bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`
curlCmd=$(echo "curl -Ls --compressed")
tvdbApiKey="02f204e6639ccc71d3270aa157f94da5"				## Updated

# Log the date
echo "------------------------------------"
echo `date`
echo "------------------------------------"

# Create Log Folder
if [ ! -d "$HOME/Library/Logs/BatchRipActions" ]; then
	mkdir "$HOME/Library/Logs/BatchRipActions"
fi

# Redirect standard output to log
exec 6>&1
exec > "$HOME/Library/Logs/BatchRipActions/renameTvItems.log"
exec 2>> "$HOME/Library/Logs/BatchRipActions/renameTvItems.log"

# Create Temp Folder
tmpFolder="/tmp/RenameTVitems_${scriptPID}"
if [ ! -e "$tmpFolder" ]; then
	mkdir "$tmpFolder"
fi

getSeriesName=`displayDialogGetTvShowName`
if [ ! -z "$getSeriesName" ]; then
	seriesList=`tvdbGetSeriesTitles "$getSeriesName"`
	seriesName=`displayDialogChooseTitle "$seriesList"`
	if [[ ! "$seriesName" = "false" && ! "$seriesName" = "" ]]; then
		seriesName=`echo "$seriesName" | sed -e 's| - First Aired.*$||g' -e 's|\&amp;|\&|g'`
	else
		displayAlert "Error: Rename TV Items" "Series Selection Required. Please choose an item from the list. If you made a selection, the API may be down or there is a problem returning the data. Check your internet connection or try again later."
		cleanUpTmpFiles
		exit 0
	fi
else
	displayAlert "Error: Rename TV Items" "Search Term Required.  Please enter a series title"
	cleanUpTmpFiles
	exit 0
fi

input=`cat`
input=`echo "$input" | tr ' ' '\007'`

# Get File/Folder Count
for eachItem in $input
do
	eachItem=`echo "$eachItem" | tr '\007' ' '`
	itemCount=$((itemCount + 1))
done

if [ ! -d "$eachItem" ]; then
	firstItem=`echo "$input" | tr '\007' ' ' | egrep -m1 ""`
	fileExt=`basename "$firstItem" | sed 's|.*\.||'`
	fileName=`basename "$firstItem" .${fileExt} | tr '_' ' ' | sed 's| ([0-9]*)||'`
	fileNameWithExt=`basename "$firstItem"`
	seasonAndEpisode=`displayDialogGetSeasonEpisode "$seriesName" "$fileExt" "$fileNameWithExt"`
	if [ ! -z "$seasonAndEpisode" ]; then
		seasonNum=$(echo $seasonAndEpisode | awk -F[Ee] '{print $1}'| awk -F[Ss] '{print $2}' | sed 's|^0||')
		seasonNum=$(printf "%02d" $seasonNum)
		startEpisodeNum=$(echo $seasonAndEpisode | awk -F[Ee] '{print $2}' | sed 's|^0||')
		episodeCount=$((startEpisodeNum - 1))
	else
		displayAlert "Error: Rename TV Items" "Input Required.  Please enter the Season and Episode Number"
		exit 0
	fi
fi	

# Process each file or folder
for theFile in $input
do
	theFile=`echo "$theFile" | tr '\007' ' '`
	outputDir=`dirname "$theFile"`
	if [ -d "$theFile" ]; then
		folderName=`basename "$theFile" | tr '_' ' ' | sed 's| ([0-9]*)||'`
		nameWithSeasonAndDisc=`displayDialogGetSeasonAndDisc "$seriesName" "$folderName"`
		if [ ! -z "$nameWithSeasonAndDisc" ]; then
			newFolderName="${seriesName} - ${nameWithSeasonAndDisc}"
			mv "$theFile" "${outputDir}/${newFolderName}"
		else
			displayAlert "Error: Rename TV Items" "Input Required.  Please enter the Season and Disc Number"
			continue
		fi
	else
		fileExt=`basename "$theFile" | sed 's|.*\.||'`
		fileName=`basename "$theFile" .${fileExt} | tr '_' ' ' | sed 's| ([0-9]*)||'`
		fileNameWithExt=`basename "$theFile"`
		if [[ ! -z "$seasonNum" && ! -z "$startEpisodeNum" ]]; then
			episodeCount=$((episodeCount + 1))
			episodeNum=$(printf "%02d" $episodeCount)
			newFileName="${seriesName} - S${seasonNum}E${episodeNum}.${fileExt}"
			newFilePath="${outputDir}/${newFileName}"
			mv "$theFile" "$newFilePath"
		else
			displayAlert "Error: Rename TV Items" "No Season or Episode Number was returned."
			exit 0
		fi
		returnList="${returnList}${outputDir}/${newFileName}|"
	fi
done
cleanUpTmpFiles

# Display script completed notification
displayNotificationCount=`echo "$returnList" | tr '|' '\n' | grep -v "^$" | grep -c ""`
displayNotification "Batch Rip Actions for Automator" "Rename TV Items" "${displayNotificationCount} item(s) were processed."

# Restore standard output & return output files
exec 1>&6 6>&- 
echo "$returnList" | tr '|' '\n' | grep -v "^$"
exit 0
