#!/usr/bin/env sh

# main.command
# Batch Rip

#  Created by Robert Yamada on 10/5/09.
#  Revisions: 20091024 ###
#	20091027: Added arg for Fairmount path.
#	20091028: Fixed bdRom typo in sed statement.
#   20091117: Added support for Batch Rip Dispatcher.
#   20091118: Added AS to change appearance of Terminal Session.
#   20091120: Added back support for skipping duplicates
#   20091201: Finally got around to adding subroutine to pass variables as args to shell
#   20091203: Removed "&" from end of runScript call
#   20091203: Changed runScript again batchEncode was finishing early
#   20101206: Added support for renaming disc copies
#   20101209: Changed to much to list
#   20110728: Updated dialogs for Lion
#   20111209: Updated discType for problematic usb enclosures
#   20131109: Updated for tmdb api v3
#   20131111: Removed support for Fairmount
#   20131116: Added back support for Fairmount

#  REVISIONS, by David Koff:
#  2020.02.01 - 
				# Added or updated xmllintPath and tvdbApiKey variables
				# Updated "function tvdbGetSeriesTitles ()" to account for new TVdb API functionality
				# Added a date stamp at the top of the log output

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

function appleScriptDialogVideoKind () {
	cat << EOF | osascript -l AppleScript
		-- BLU-RAY LAUNCH BATCH RIP
		-- CANCEL AFTER 30 SECONDS OF NO INPUT
		tell application "System Events"
		activate
		display Alert "$2" & " Detected: " & return & "$1" message "Device Name: " & "$3" & return & return & "Select a video kind to continue." buttons {"Ignore", "TV Show", "Movie"} default button 1 giving up after 30 as critical
		if the button returned of the result is "Ignore" then
			return "Cancel"
		else if the button returned of the result is "Movie" then
			return "Movie"
		else if the button returned of the result is "TV Show" then
			return "TV Show"
		else
			return "Cancel"
		end if
	end tell
EOF
}

function displayDialogGetMovieName () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$1"
		set theName to "$2"
		set theType to "$3"
		set theDevice to "$4"
		tell application "System Events" 
		activate
		display dialog "What is the" & space & theType & space & "title you'd like to search for?" & return & return & "Disc: " & theFile & return & "Device: " & theDevice default answer theName buttons {"Skip", "Search"} default button 2 giving up after 30
		if the button returned of the result is "Search" then
			return text returned of the result
		else
			return "Skip"
		end if
	end tell
EOF
}

function tmdbGetMovieTitles () {
	discNameNoYear=`htmlEncode "$(echo "$1" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g')"`
	
	# set TMDb searchTerm
	searchTerm=`urlEncode "$discNameNoYear"`
	tmdbSearch=`$curlCmd "http://api.themoviedb.org/3/search/movie?api_key=$tmdbApiKey&query=$searchTerm" | "$jqToolPath" '.results[].id'`

	# download each id from the database to its own tmp.xml file
	for theMovieID in $tmdbSearch
	do
		movieData=$($curlCmd "http://api.themoviedb.org/3/movie/$theMovieID?api_key=$tmdbApiKey" | "$jqToolPath" '.')
		releaseDate=`echo "$movieData" | "$jqToolPath" -r ".release_date" | sed 's|-.*||g'`
		movieTitle=$(substituteISO88591 "$(echo "$movieData" | "$jqToolPath" -r ".title" | sed -e 's|:| -|g')")
		moviesFound="${moviesFound}${movieTitle} (${releaseDate})+"
	done
	echo $moviesFound | sed 's|&amp;|\&|g' | tr '+' '\n'
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
		with timeout of 30 seconds
			tell application "System Events" 
				activate
				choose from list theList with title "Choose from List" with prompt "Please make your selection:"
				end tell
		end timeout
	on error
		tell application "System Events" to key code 53
		set result to false
	end try
EOF
}

function displayDialogGetSeasonAndDisc () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$2"
		tell application "System Events" 
		activate
		display dialog "Enter Season & Disc Number for " & theFile default answer "S1D1" buttons {"Cancel", "OK"} default button 2 giving up after 30
		if the button returned of the result is "OK" then
			return text returned of the result
		else
			return "Cancelled"
		end if
		end tell
EOF
}

function getKeyValue () {
	cat $1 | "$jqToolPath" -r "$2"
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

function runScript () {
		scriptTmpPath="$HOME/Library/Application Support/Batch Rip/batchRipTmp.sh"
		echo "\"$1\" \"$2\"" > "$scriptTmpPath"
		chmod 777 "$scriptTmpPath"
		open -a Terminal "$scriptTmpPath"
}

function appleScriptDialogContinue () {
	cat << EOF | osascript -l AppleScript
		-- BLU-RAY LAUNCH BATCH RIP
		-- CANCEL AFTER 30 SECONDS OF NO INPUT
tell application "System Events"
	activate
	display alert "Batch Rip Dispatcher: " & "Disc Detected." message "Waiting for next disc. Click Continue when ready." buttons {"Cancel", "Ignore All", "Continue"} default button 3 giving up after 120 as warning
	if the button returned of the result is "Cancel" then
		return "Cancel"
	else if the button returned of the result is "Ignore All" then
		return "Ignore"
	else if the button returned of the result is "Continue" then
		return "Continue"
	else
		return "Cancel"
	end if
end tell
EOF
}

function appleScriptError () {
	osascript -e 'tell application "System Events"' -e 'activate' -e 'display alert "Error: Batch Rip no titles found" message "Error: The API server did not return any titles matching your search term; or the API your trying to search may be down." & Return & Return & "The action will continue, but you will have to rename the copies after the action has finished." as critical' -e 'end tell'
}

function displayDialogCustomDiscName () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$1"
		set theName to "$2"
		set theType to "$3"
		set theDevice to "$4"
		tell application "System Events" 
		activate
		display dialog "Error: The API server did not return any titles matching your search term; or the API your trying to search may be down." & return & return & "Disc: " & theFile & return & "Device: " & theDevice & return & return & "Enter a custom title for this" & space & theType & space & "or choose Skip to continue with the default name." default answer theName buttons {"Skip", "OK"} default button 2 giving up after 30 with title "Error: Batch Rip no titles found" with icon 2
		if the button returned of the result is "OK" then
			return text returned of the result
		else
			return ""
		end if
	end tell
EOF
}

#####################################################################################
# MAIN SCRIPT
#####################################################################################

# Debug
set -xv

# Variables
xpathPath="/usr/bin/xpath"
xmllintPath="/usr/bin/xmllint"							## Added
scriptPID=$$
bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`
batchRipSupportPath="${HOME}/Library/Application Support/Batch Rip"
currentItemsList="${batchRipSupportPath}/currentItems.txt"
actionPath=`dirname "$0"`
curlCmd=$(echo "curl -Ls --compressed")
tmdbApiKey="8d7d0edf7ec73435ea5d99d9cba9b54d"
tvdbApiKey="02f204e6639ccc71d3270aa157f94da5"			## Updated
jqToolPath="${bundlePath}/MacOS/jq"
fairmountPath="${bundlePath}/MacOS/Fairmount.app"

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
exec > "$HOME/Library/Logs/BatchRipActions/batchRip.log"
exec 2>> "$HOME/Library/Logs/BatchRipActions/batchRip.log"

# create action temp folder
tmpFolder="/tmp/batchRipLauncher-${scriptPID}"
if [ ! -e "$tmpFolder" ]; then
	mkdir "$tmpFolder"
fi

# Make batchRip folder
if [ ! -d "$batchRipSupportPath" ]; then
	mkdir "$batchRipSupportPath"
fi

# multi-disc prompt
if [[ ! "${autoRun}" ]]; then autoRun=0; fi
	# Get current state of Batch Rip Dispatch LaunchAgent; if enabled continue.
	currentState=`launchctl list com.batchRip.BatchRipDispatcher 2> /dev/null`
	if [ ! -z "$currentState" ]; then
		# Get count of optical drives
		deviceCount=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -c ""`
		if [[ deviceCount -gt 1 && "$autoRun" -eq 0 ]]; then
		launchAction=`appleScriptDialogContinue`
		if [[ "$launchAction" = "Cancel" || -z "$launchAction" ]]; then
			if [ -d "$tmpFolder" ]; then
				rm -rf $tmpFolder
			fi
			exit 0
		elif [[ "$launchAction" = "Ignore" ]]; then
			df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed -e 's|^|\/|g' -e 's|$|:Ignore|g' > "$currentItemsList"
			if [ -d "$tmpFolder" ]; then
				rm -rf $tmpFolder
			fi
			exit 0
		fi
	fi
fi
if [ -e "$currentItemsList" ]; then
	rm -f "$currentItemsList"
fi

input=`cat`

if [ ! -z "$input" ]; then
	input=`echo "$input" | tr ' ' '\007'`
else
	input=`df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed 's|^|\/|g' | tr ' ' '\007' | sort -f`	
fi

for eachItem in $input
do
	eachItem=`echo "$eachItem" | tr '\007' ' '`
	itemCount=$((itemCount + 1))	
done

processDisc=0

for thePath in $input
do
	thePath=`echo "$thePath" | tr '\007' ' '`
	# Check disc type and set variables
	deviceName=`diskutil info "$thePath" | grep "Device / Media Name" | sed 's|.*: *||'`
	#discType=`diskutil info "$thePath" | grep "Optical Media Type" | sed 's|.*: *||'`
	deviceID=`diskutil info "$thePath" | grep "Device Identifier" | sed 's|.*: *||'`
	discType=`ioreg -rS -d 1 -c IOMedia -k Type | egrep 'class|BSD Name|Type' | tr -d '\n' | sed -e 's|-o ||g' -e 's|+||' | tr "+" '\n' | grep "$deviceID" | sed -e 's|.* "||' -e 's|"||g'`
	if [[ "$discType" = "BD-ROM" && bdRom -eq 1 || "$discType" = "DVD-ROM" && dvdRom -eq 1 ]]; then
        if [[ ! "${verboseLog}" ]]; then verboseLog=0; fi
		if [[ ! "${skipDuplicates}" ]]; then skipDuplicates=0; fi
		if [[ ! "${autoRun}" ]]; then autoRun=0; fi
		if [[ ! "${saveLog}" ]]; then saveLog=0; fi
		if [[ ! "${bdRom}" ]]; then bdRom=0; fi
		if [[ ! "${dvdRom}" ]]; then dvdRom=0; fi
		if [[ ! "${growlMe}" ]]; then growlMe=0; fi
		if [[ ! "${useOnlyMakeMKV}" ]]; then useOnlyMakeMKV=0; fi
		if [[ ! "${ejectDisc}" ]]; then ejectDisc=0; fi
		if [[ ! "${scriptPath}" ]]; then scriptPath=""; fi
		if [[ ! "${tvPath}" ]]; then tvPath=""; fi
		if [[ ! "${moviePath}" ]]; then moviePath=""; fi
		if [[ ! "${fairmountPath}" ]]; then fairmountPath=""; fi
		if [[ ! "${makemkvPath}" ]]; then makemkvPath=""; fi
		if [[ ! "${videoKind}" ]]; then videoKind="0"; fi
		if [[ videoKind -eq 0 ]]; then videoKind="Movie"; fi
		if [[ videoKind -eq 1 ]]; then videoKind="TV Show"; fi
		if [[ ! "${tvMinTime}" ]]; then tvMinTime=0; fi
		if [[ ! "${tvMaxTime}" ]]; then tvMaxTime=0; fi
		if [[ ! "${movieMinTime}" ]]; then movieMinTime=0; fi
		if [[ ! "${movieMaxTime}" ]]; then movieMaxTime=0; fi
		if [[ ! "${discDelay}" ]]; then discDelay=20; fi
		if [[ ! "${copyDelay}" ]]; then copyDelay=20; fi
		if [[ ! "${fullBdBackup}" ]]; then fullBdBackup=0; fi
		if [[ ! "${renameDisc}" ]]; then renameDisc=1; fi
		
		# Set path to batchRip.sh
		scriptPath="${actionPath}/batchRip.sh"

		# Check if this disc is currently being processed
		bashPID=`ps uxc | grep -i "Bash" | awk '{print $2}'`
		for eachPID in $bashPID
		do
			if [ -e "/tmp/batchRip-${eachPID}/currentItems.txt" ]; then
				if grep "$thePath" < /tmp/batchRip-$eachPID/currentItems.txt ; then
					continue
				fi
			fi
		done

		# Temporarily replace spaces in paths
		fairmountPath=`echo "$fairmountPath" | tr ' ' ':'`
		makemkvPath=`echo "$makemkvPath" | tr ' ' ':'`
		moviePath=`echo "$moviePath" | tr ' ' ':'`
		tvPath=`echo "$tvPath" | tr ' ' ':'`
		
		# Set scriptArgs
		scriptArgs="--verboseLog $verboseLog --skipDuplicates $skipDuplicates --encodeHdSources $bdRom --saveLog $saveLog --fairmountPath $fairmountPath --makemkvPath $makemkvPath --movieOutputDir $moviePath --tvOutputDir $tvPath --encodeDvdSources $dvdRom --growlMe $growlMe --onlyMakeMKV $useOnlyMakeMKV --ejectDisc $ejectDisc --minTrackTimeTV $tvMinTime --maxTrackTimeTV $tvMaxTime --minTrackTimeMovie $movieMinTime --maxTrackTimeMovie $movieMaxTime --discDelay $discDelay --copyDelay $copyDelay --fullBdBackup $fullBdBackup"
					
		# Process discs if set to not run automatically
		if [[ ! autoRun -eq 1 ]]; then
			
			# Get user input for action
			getVideoKind=`appleScriptDialogVideoKind "$thePath" "$discType"`

			# If video kind is returned, setup and launch batchRip. If ignore is returned, set to ignore.
			if [[ ! "$getVideoKind" = "Cancel" && ! -z "$getVideoKind" ]]; then
				videoKind="$getVideoKind"
				processDisc=1
				# If renameDisc is set to yes, get disc name from user input
				if [[ $renameDisc -eq 1 ]]; then
					# reset variables
					newDiscName=""
					theTitle=""
					theSeriesName=""
					nameWithSeasonAndDisc=""
					discName=`basename "$thePath" | tr '_' ' ' | sed 's| ([0-9]*)||'`
					getDiscName=`displayDialogGetMovieName "$thePath" "$discName" "$videoKind"`
					if [[ ! -z "$getDiscName" && ! "$getDiscName" = "Skip" ]]; then
						if [ "$videoKind" = "Movie" ]; then
							titleList=`tmdbGetMovieTitles "$getDiscName"`
							if [ ! "$titleList" = "" ]; then
								theTitle=`displayDialogChooseTitle "$titleList"`
								if [[ ! "$theTitle" = "false" && ! "$theTitle" = "" ]]; then
									newDiscName=`echo "$theTitle" | sed 's|\&amp;|\&|g'`
								fi
							else
								theTitle=`displayDialogCustomDiscName "$thePath" "$getDiscName" "$videoKind"`
								if [[ ! "$theTitle" = "false" && ! "$theTitle" = "" ]]; then
									newDiscName=`echo "$theTitle" | sed 's|\&amp;|\&|g'`
								else
									newDiscName="$discName"
								fi
							fi
						elif [ "$videoKind" = "TV Show" ]; then
							titleList=`tvdbGetSeriesTitles "$getDiscName"`
							if [ ! "$titleList" = "" ]; then
								theSeriesName=`displayDialogChooseTitle "$titleList"`
								if [[ ! "$theSeriesName" = "false" && ! "$theSeriesName" = "" ]]; then
									theSeriesName=`echo "$theSeriesName" | sed -e 's| - First Aired.*$||g' -e 's|\&amp;|\&|g'`
									nameWithSeasonAndDisc=`displayDialogGetSeasonAndDisc "$theSeriesName" "$thePath"`
									if [ ! -z "$nameWithSeasonAndDisc" ]; then
										newDiscName="${theSeriesName} - ${nameWithSeasonAndDisc}"
									fi
								fi
							else
								theSeriesName=`displayDialogCustomDiscName "$thePath" "$getDiscName" "$videoKind"`
								if [[ ! "$theSeriesName" = "false" && ! "$theSeriesName" = "" ]]; then
									nameWithSeasonAndDisc=`displayDialogGetSeasonAndDisc "$theSeriesName" "$thePath"`
									if [ ! -z "$nameWithSeasonAndDisc" ]; then
										newDiscName="${theSeriesName} - ${nameWithSeasonAndDisc}"
									else
										newDiscName="$discName"
									fi
								else
									newDiscName="$discName"
								fi
							fi
						fi
					else
						newDiscName="$discName"
					fi
				fi
				
				if [ ! "$newDiscName" = "" ]; then
					echo "${thePath}:${videoKind}:${discType}:${newDiscName}" >> "$currentItemsList"
				else
					echo "${thePath}:${videoKind}:${discType}" >> "$currentItemsList"
				fi
			else
				echo "${thePath}:Ignore" >> "$currentItemsList"
			fi
			if [[ $itemCount -eq 1 && $processDisc -eq 1 ]]; then
				#osascript -e "tell application \"System Events\" to display dialog \"$itemCount\""
				runScript "$scriptPath" "$scriptArgs"
			fi
		else
			# Process discs if set to run automatically
			echo "${thePath}:${videoKind}:${discType}" >> "$currentItemsList"			
			if [[ $itemCount -eq 1 ]]; then
				#osascript -e "tell application \"System Events\" to display dialog \"RUN SCRIPT\""
				runScript "$scriptPath" "$scriptArgs"
			fi
		fi	
	else
		exit 0
	fi
	itemCount=$((itemCount - 1))
done

if [ -d "$tmpFolder" ]; then
	rm -rf $tmpFolder
fi
# Restore standard output & return output files
exec 1>&6 6>&- 

exit 0
