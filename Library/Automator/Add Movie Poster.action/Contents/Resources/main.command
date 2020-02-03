#!/usr/bin/env sh

# main.command
# Add Movie Poster

#  Created by Robert Yamada on 10/21/09.
#  Changes:
#  1.20091118.0: Added underscore removal to $fileName
#  2.20091118.1: Added $fileExt to remove ext from $fileName
#  3.20091126.0: Added ISO88591 subroutine
#  4.20110728.0: Updated dialogs for Lion
#  5.20131108.0: Updated for tmdb api v3

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

########################################################################
# FUNCTIONS

function displayDialogGetMovieName () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$1"
		tell application "System Events" 
		activate
		display dialog "What is the movie title?" default answer theFile buttons {"Cancel", "OK"} default button 2
		if the button returned of the result is "OK" then
			return text returned of the result
		else
			return "Cancelled"
		end if
		end tell
EOF
}

function tmdbGetMovieTitles () {
	discNameNoYear=`htmlEncode "$(echo "$1" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g')"`
	# set TMDb searchTerm
	searchTerm=`urlEncode "$discNameNoYear"`
	tmdbSearch=`$curlCmd "http://api.themoviedb.org/3/search/movie?api_key=$tmdbApiKey&query=$searchTerm" | "$jqToolPath" '.results[].id'`
	for theMovieID in $tmdbSearch
	do
		# download each id to tmp.xml
		movieData=$($curlCmd "http://api.themoviedb.org/3/movie/$theMovieID?api_key=$tmdbApiKey" | "$jqToolPath" '.')
		releaseDate=`echo "$movieData" | "$jqToolPath" -r ".release_date" | sed 's|-.*||g'`
		movieTitle=`echo "$movieData" | "$jqToolPath" -r ".title"`
		moviesFound="${moviesFound}${movieTitle} (${releaseDate}) ID#:${theMovieID}+"
	done
	echo $moviesFound | sed 's|&amp;|\&|g' | tr '+' '\n'
	
	# MOST OF THIS CAN BE REPLACED WITH:
	#	tmdbSearch=`$curlCmd "http://api.themoviedb.org/3/search/movie?api_key=$tmdbApiKey&query=$searchTerm" | "$jqToolPath" '.results[] | {title, release_date, id}' | "$jqToolPath" -r 'tostring' | sed -e 's|{"title":"||g' -e 's|","release_date":"| (|g' -e 's|","id":|) ID#:|g' -e 's|}$||g'`

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

function displayChooseImageFromClipboard () {
	cat << EOF | osascript -l AppleScript
		tell application "System Events" 
		activate
		display dialog "1. Find and Select an image in Safari" & Return & "2. Copy Link to the clipboard" & Return & "3. Click OK to add the image to your file" buttons {"Skip", "OK"} default button 2 with icon 0 with floating
		copy the result as list to {button_pressed}
		if button_pressed is "OK" then
		tell application "Finder" to set visible of process "Safari" to false
		return "OK"
		end if
		if button_pressed is "Skip" then
		return "Skip"
		tell application "Finder" to set visible of process "Safari" to false
		end if
		end tell
		
EOF
}

function displayDialogChooseFile () {
	cat << EOF | osascript -l AppleScript
	tell application "System Events"
		activate
		choose file with prompt "Choose image file for: " & "$1" of type {"public.image"} default location path to downloads folder
		return Posix path of the result
	end tell
EOF
}

function getArtFromClipboard () {
	# download cover art from clipboard link
	moviePoster="${tmpFolder}/${scriptPID}.jpg"
	$curlCmd $(pbpaste) > $moviePoster &
	wait
	# embed movie poster in file
	addCoverArt "$moviePoster"
}

function searchForArt () {
	getMovieName=`displayDialogGetMovieName "$fileName"`
	if [ ! -z "$getMovieName" ]; then
		movieList=`tmdbGetMovieTitles "$getMovieName"`
		displayTitle=`echo "$movieList" | sed 's|ID\#\:[0-9]*||g'`
		chooseTitle=`displayDialogChooseTitle "$displayTitle"`
		if [[ ! "$chooseTitle" = "false" && ! "$chooseTitle" = "" ]]; then
			theMovieID=`echo "$movieList" | tr '+' '\n' | grep "$chooseTitle" | sed 's|.*ID\#\:||'`
			moviePosterURL="http://www.themoviedb.org/movie/$theMovieID/posters"
			open "$moviePosterURL"
			moviePoster="${tmpFolder}/${theMovieID}.jpg"
			displayCopyImage=`displayChooseImageFromClipboard`
			if [[ ! "$displayCopyImage" = "Skip" && ! "$displayCopyImage" = "" ]]; then
				if echo $(pbpaste) | grep "http" ; then
					$curlCmd $(pbpaste) > $moviePoster &
					wait
					# embed movie poster in file
					addCoverArt "$moviePoster"
				else
					displayAlert "Error: Add Movie Poster" "Error: Not a valid URL"
				fi
			else
				displayAlert "Error: Add Movie Poster" "No link found in clipboard"
			fi

		else
			displayAlert "Error: Add Movie Poster" "Error: No movie selected.  Movie may not be in themoviedb.org database"
#			exit 0
		fi
#	else
#		osascript -e 'tell application "System Events" to activate & display alert "Error: Add Movie Poster" message "Error: Search Term Required" & Return & "Please enter a movie title"'
#		exit 0
	fi
}

function getArtFromFile () {
	moviePoster=`displayDialogChooseFile "$fileName"`
	if [[ -e "$moviePoster" ]]; then
		imgFileName=`basename "$moviePoster"`
		cp "$moviePoster" "${tmpFolder}/$imgFileName"
		moviePosterTmp="${tmpFolder}/$imgFileName"
		addCoverArt "$moviePosterTmp"
	else
		displayAlert "Error: Add Movie Poster" "Error: No file selected"
	fi
}

function addCoverArt () {
	# add cover art
	if [ -e "$1" ]; then
		imgIntegrityTest=`sips -g pixelWidth "$1" | sed 's|.*[^0-9+]||'`
		if [ "$imgIntegrityTest" -gt 100 ]; then
			sips -Z 600W600H "$1" --out "$1"
			"$mp4artPath" --remove "$theFile" &
			wait
			"$mp4artPath" -oz --add "$1" "$theFile"
		else
			displayAlert "Error: Add Movie Poster" "Image file failed integrity test.  Try another image or link"
		fi
	fi
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

########################################################################
# MAIN SCRIPT

# Debug
set -xv

# Create Log Folder
if [ ! -d "$HOME/Library/Logs/BatchRipActions" ]; then
	mkdir "$HOME/Library/Logs/BatchRipActions"
fi

# Redirect standard output to log
exec 6>&1
exec > "$HOME/Library/Logs/BatchRipActions/addMoviePoster.log"
exec 2>> "$HOME/Library/Logs/BatchRipActions/addMoviePoster.log"

# Script Variables
scriptPID=$$
bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`
mp4artPath="${bundlePath}/MacOS/mp4art"
curlCmd=$(echo "curl -L --compressed --connect-timeout 30 --max-time 60 --retry 1")
tmdbApiKey="8d7d0edf7ec73435ea5d99d9cba9b54d"
jqToolPath="${bundlePath}/MacOS/jq"

while read theFile
do
	if [[ ! "${optionPopup}" ]]; then optionPopup=0; fi

	if [ ! -x "$mp4artPath" ]; then
		displayAlert "Error: Add Movie Poster" "The Command Line Tools needed for this action could not be found. Please reinstall Batch Rip Actions for Automator."
		exit 1
	fi

	# create tmp folder
	tmpFolder="/tmp/addMoviePoster_$scriptPID"
	if [ ! -e "$tmpFolder" ]; then
		mkdir "$tmpFolder"
	fi

	if [ -e "$theFile" ]; then
		fileExt=`basename "$theFile" | sed 's|.*\.||'`
		fileName=`basename "$theFile" .$fileExt | tr '_' ' ' | sed 's| ([0-9]*)||'`
		# Search the moviedb.org
		if [[ optionPopup -eq 0 ]]; then	
			searchForArt
		# Choose cover art from file	
		elif [[ optionPopup -eq 1 ]]; then
			getArtFromFile
		# Get art from URL in clipboard
		elif [[ optionPopup -eq 2 ]]; then
			getArtFromClipboard
		fi	

		# Tell Finder to update view
		osascript -e "set theFile to POSIX file \"$theFile\"" -e 'tell application "Finder" to update theFile'
	fi
	returnList="${returnList}${theFile}|"
	cleanUpTmpFiles
done

# Display script completed notification
displayNotificationCount=`echo "$returnList" | tr '|' '\n' | grep -v "^$" | grep -c ""`
displayNotification "Batch Rip Actions for Automator" "Add Movie Poster" "${displayNotificationCount} item(s) were processed."

# Restore standard output & return output files
exec 1>&6 6>&- 
echo "$returnList" | tr '|' '\n' | grep -v "^$"
exit 0