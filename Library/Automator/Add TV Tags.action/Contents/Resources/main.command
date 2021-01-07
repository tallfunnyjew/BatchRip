#!/usr/bin/env sh

# main.command
# Add TV Tags

#  Created by Robert Yamada on 10/2/09.
#  20091026-0 Added mp4tags, mp4info & mp4chaps. Added HD-Flag and Add Chaps from file
#  20091119-1 Changed rm command to -rf
#  20091119-2 Reorganized to bring it inline to changes made in add movie tags
#  20091119-3 Fixed overWrite to leave original untouched if set to 0
#  20091119-4 Moved add cover art to atomicParsley 
#  20091126-5 Added substituteISO88591 subroutine
#  20101202-6 Added preserve/set cnid
#  20111112-7 Updates for SublerCLI and Action Bundle

#  REVISIONS, by David Koff:
#  2020.02.01 - 
				# Added or updated xmllintPath and tvdbApiKey variables
				# Updated "function tvdbGetSeriesTitles ()" to account for new TVdb API functionality
				# Added a date stamp at the top of the log output
				# set episode naming preference to "default" to suit TVDB website
				# Matched /tmp folder variables and calls from main BatchRip script Pu
#  PULL REQUEST, by kuerb				
#  2021.01.07 - 
				# Fixed banner download path
				# Fixed batch tagging of multiple files

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

#####################################################################################
# FUNCTIONS
#####################################################################################

function searchForTvTags () {
	getSeriesName=`displayDialogGetTvShowName`
	if [[ ! -z "$getSeriesName" && ! "$getSeriesName" = "Quit" ]]; then
		seriesList=`tvdbGetSeriesTitles "$getSeriesName"`
		seriesName=`displayDialogChooseTitle "$seriesList"`
		if [[ ! "$seriesName" = "false" && ! "$seriesName" = "" ]]; then
			seriesName=`echo "$seriesName" | sed -e 's| - First Aired.*$||g' -e 's|\&amp;|\&|g'`
			seasonAndEpisode=`displayDialogGetSeasonEpisode "$seriesName" "$fileExt" "$fileNameWithExt"`
			if [ ! -z "$seasonAndEpisode" ]; then
				seasonNum=$(echo $seasonAndEpisode | awk -F[Ee] '{print $1}'| awk -F[Ss] '{print $2}' | sed 's|^0||')
				seasonNum=$(printf "%02d" $seasonNum)
				episodeNum=$(echo $seasonAndEpisode | awk -F[Ee] '{print $2}' | sed 's|^0||')
				episodeID=`echo $episodeNum | sed "s|^|${seasonNum}|"`
				searchTerm=$(echo "$seriesName" | sed -e 's|\ |+|g' -e 's|\ \-\ |:\ |g' -e "s|\'|%27|g")
			else
				displayAlert "Error: Rename TV Items" "Input Required.  Please enter the Season and Episode Number"
				continue
			fi
		else
			displayAlert "Error: Rename TV Items" "Series Selection Required. Please choose an item from the list. If you made a selection, the API may be down or there is a problem returning the data. Check your internet connection or try again later."
			cleanUpTmpFiles
			continue
		fi
	elif [ "$getSeriesName" = "Quit" ]; then
		cleanUpTmpFiles
		exit 0
	else
		displayAlert "Error: Rename TV Items" "Search Term Required.  Please enter a series title"
		cleanUpTmpFiles
		continue
	fi
}

function displayDialogGetTvShowName () {
	cat << EOF | osascript -l AppleScript
		tell application "System Events" 
		activate
		display dialog "What is the TV show title?" default answer "" buttons {"Cancel All", "Cancel", "OK"} default button 3
		if the button returned of the result is "OK" then
			return text returned of the result
		else if the button returned of the result is "Cancelled" then
			return "Cancelled"
		else if the button returned of the result is "Cancel All" then
			return "Quit"
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
			display dialog "Enter the Season and Episode Number for file:" & return & theFile & return & return & "Important! The episode number entered will be the start number for renaming multiple files." & return & return & "Example: " & theShow & " - S01E01." & theFileExt default answer "S01E01" buttons {"Cancel", "OK"} default button 2 with title "Rename TV Item: " & theFile
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
	
	# Find the correct TV series name
	# (1) Download a master XML file with all API search results:	
	$curlCmd "http://www.thetvdb.com/api/GetSeries.php?seriesname=$searchTerm" > "${tmpFolder}/${searchTerm}.xml"
	
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

function tvdbGetTvTags () {
	# get series data
	seriesXml="$tmpFolder/${searchTerm}-S${seasonNum}.xml"
	if [ ! -e "$tmpFolder/${searchTerm}-S${seasonNum}.xml" ]; then
		
		series_id=$($curlCmd "http://www.thetvdb.com/api/GetSeries.php?seriesname=$searchTerm" | "$xpathPath" //seriesid 2>/dev/null | awk 'NR==1 {print $1}' | awk -F\> '{print $2}' | awk -F\< '{print $1}')
		$curlCmd "http://www.thetvdb.com/api/$tvdbApiKey/series/$series_id/en.xml" | iconv -f ISO-8859-1 -t UTF-8 > "$seriesXml"
		
		# check and fix series xml
		cat "$seriesXml" | egrep -B 9999999 -m1 "</Data>" | "$xmllintPath" --recover --nsclean --format --output "$seriesXml" - 
	fi

	# get banner info		
	bannerXml="$tmpFolder/${searchTerm}-banners.xml"
	if [ ! -e "$tmpFolder/${searchTerm}-banners.xml" ]; then
		$curlCmd "http://www.thetvdb.com/api/$tvdbApiKey/series/$series_id/banners.xml" | iconv -f ISO-8859-1 -t UTF-8 > "$bannerXml"
		
		# check and fix banner xml
		cat "$bannerXml" | egrep -B 9999999 -m1 "</Banners>" | "$xmllintPath" --recover --nsclean --format --output "$episodeXml" - 
	fi

	# get episode info		
	episodeXml="$tmpFolder/${searchTerm}-${season_episode}.xml"
	if [ ! -e "$tmpFolder/${searchTerm}-${season_episode}.xml" ]; then
		if [ $sortOrder = "default" ] ; then
			$curlCmd "http://www.thetvdb.com/api/$tvdbApiKey/series/$series_id/default/$seasonNum/$episodeNum/en.xml" | iconv -f ISO-8859-1 -t UTF-8 > "$episodeXml"
		elif [ $sortOrder = "dvd" ] ; then
			$curlCmd "http://www.thetvdb.com/api/$tvdbApiKey/series/$series_id/dvd/$seasonNum/$episodeNum/en.xml" | iconv -f ISO-8859-1 -t UTF-8 > "$episodeXml"
		fi
		if grep '<title>404 Not Found</title>' < "$episodeXml" > /dev/null ; then
			$curlCmd "http://www.thetvdb.com/api/$tvdbApiKey/series/$series_id/default/$seasonNum/$episodeNum/en.xml" | iconv -f ISO-8859-1 -t UTF-8 > "$episodeXml"
		fi
		# check and fix episode xml
		cat "$episodeXml" | egrep -B 9999999 -m1 "</Data>" | "$xmllintPath" --recover --nsclean --format --output "$episodeXml" - 
	fi
}

function addiTunesTagsTV () {
	#generate tags and tag with SublerCLI
	episodeName=`"$xpathPath" "$episodeXml" "//EpisodeName/text()" 2>/dev/null`
	showName=`"$xpathPath" "$seriesXml" "//SeriesName/text()" 2>/dev/null`
	tvNetwork=`"$xpathPath" "$seriesXml" "//Network/text()" 2>/dev/null`
	tvRating=`"$xpathPath" "$seriesXml" "//ContentRating/text()" 2>/dev/null`
	releaseDate=`"$xpathPath" "$episodeXml" "//FirstAired/text()" 2>/dev/null`
	episodeDesc=`"$xpathPath" "$episodeXml" "//Overview/text()" 2>/dev/null`
	genreList=`"$xpathPath" "$seriesXml" "//Genre/text()" 2>/dev/null`
	movieActors=`"$xpathPath" "$seriesXml" "//Actors/text()" 2>/dev/null | sed -e 's_^\|__' -e 's_\|$__' -e's|\||, |g'`
	movieGuests=`"$xpathPath" "$episodeXml" "//GuestStars/text()" 2>/dev/null | sed -e 's_^\|__' -e 's_\|$__' -e's|\||, |g'`
	if [ ! "$movieGuests" = "" ]; then
		movieActors="${movieActors}, ${movieGuests}"
	fi
	movieDirector=`"$xpathPath" "$episodeXml" "//Director/text()" 2>/dev/null | sed -e 's_^\|__' -e 's_\|$__' -e's|\||, |g'`
	movieWriters=`"$xpathPath" "$episodeXml" "//Writer/text()" 2>/dev/null | sed -e 's_^\|__' -e 's_\|$__' -e's|\||, |g'`
	purchaseDate=`date "+%Y-%m-%d %H:%M:%S"`

	# parse category info and convert into iTunes genre
	if echo "$genreList" | grep 'Animation' > /dev/null ; then
		movieGenre="Kids & Family"
	elif echo "$genreList" | grep 'Science-Fiction' > /dev/null ; then
		movieGenre="Sci-Fi & Fantasy"
	elif echo "$genreList" | grep 'Fantasy' > /dev/null ; then
		movieGenre="Sci-Fi & Fantasy"
	elif echo "$genreList" | grep 'Horror' > /dev/null ; then
		movieGenre="Horror"
	elif echo "$genreList" | grep '\(Action\|Adventure\|Disaster\)' > /dev/null ; then
		movieGenre="Action & Adventure"
	elif echo "$genreList" | grep 'Musical' > /dev/null ; then
		movieGenre="Music"
	elif echo "$genreList" | grep 'Documentary' > /dev/null ; then
		movieGenre="Documentary"			
	elif echo "$genreList" | grep 'Sport' > /dev/null ; then
		movieGenre="Sports"			
	elif echo "$genreList" | grep 'Western' > /dev/null ; then
		movieGenre="Western"
	elif echo "$genreList" | grep '\(Thriller\|Suspense\)' > /dev/null ; then
		movieGenre="Thriller"
	elif echo "$genreList" | grep '\(Drama\|Historical\|Political\|Crime\|Mystery\)' > /dev/null ; then
		movieGenre="Drama"
	elif echo "$genreList" | grep '\(Comedy\|Road\)' > /dev/null ; then
		movieGenre="Comedy"
	fi 

	# get cover art
	tvPoster="$tmpFolder/${searchTerm}-${seasonNum}.jpg"
	if [ ! -e $tvPoster ] ; then
		# get season banner
		getTvPoster=`"$xpathPath" "$bannerXml" / 2>/dev/null | tr -d '\n ' | sed 's|</Banner>|</Banner>\||g' | tr '|' '\n' | egrep "Season>${seasonNum}</Season" | awk -F\<BannerPath\> '{print $2}' | awk -F\</BannerPath\> '{print $1}' | sed "s|^|http://www.thetvdb.com/banners/|"`
		for eachURL in $getTvPoster
		do
			$curlCmd "$eachURL" > $tvPoster
			imgIntegrityTest=`sips -g pixelWidth "$tvPoster" | sed 's|.*[^0-9+]||'`
			if [ "$imgIntegrityTest" -gt 100 ]; then
				resizeImage "$tvPoster"
				break 1
			else
				rm $tvPoster
			fi
		done

		if [ ! -e "$tvPoster" ]; then
			# get series banner
			getTvPoster=`"$xpathPath" "$seriesXml" //poster 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | grep -m1 "" | sed "s|^|http://www.thetvdb.com/banners/|"`
			$curlCmd "$getTvPoster" > $tvPoster
			imgIntegrityTest=`sips -g pixelWidth "$tvPoster" | sed 's|.*[^0-9+]||'`
			if [ "$imgIntegrityTest" -gt 100 ]; then
				resizeImage "$tvPoster"
			fi
		fi
	fi

	# Set the HD Flag for HD-Video
	getResolution=$("$mp4infoPath" "$theFile" | egrep "1.*video" | awk -F,\  '{print $4}' | sed 's|\ @.*||')
	pixelWidth=$(echo "$getResolution" | sed 's|x.*||')
	pixelHeight=$(echo "$getResolution" | sed 's|.*x||')
	if [[ pixelWidth -gt 1279 || pixelHeight -gt 719 ]]; then
		hdFileTest=1
	else
		hdFileTest=0
	fi

	# preserve Cnid
	cnidNum=$("$mp4infoPath" "$theFile" | grep -i "Content ID" | sed 's|.* ||')
	if [[ -z "$cnidNum" ]]; then
		cnidNum=$(echo $(( 10000+($RANDOM)%(20000-10000+1) ))$(( 1000+($RANDOM)%(9999-1000+1) )))
	fi

	sublerArgs="{Artwork:$tvPoster}{Name:$episodeName}{Artist:$showName}{Album Artist:$showName}{Album:${showName}, Season ${seasonNum}}{Grouping:}{Composer:}{Comments:}{Genre:$movieGenre}{Release Date:$releaseDate}{Track #:$episodeNum}{Disk #:1/1}{TV Show:$showName}{TV Episode #:$episodeNum}{TV Network:$tvNetwork}{TV Episode ID:$episodeID}{TV Season:$seasonNum}{Description:$episodeDesc}{Long Description:$episodeDesc}{Rating:$tvRating}{Rating Annotation:}{Studio:}{Cast:$movieActors}{Director:$movieDirector}{Codirector:$movieCoDirector}{Producers:$movieProducers}{Screenwriters:$movieWriters}{Lyrics:}{Copyright:}{contentID:$cnidNum}{HD Video:$hdFileTest}{Gapless:0}{Content Rating:}{Media Kind:TV Show}"
	sublerArgs=`substituteISO88591 "$(echo "$sublerArgs")"`

	# write tags with sublerCli
	if [[ optimizeFile -eq 0 ]]; then
		"$sublerCliPath" -o "$theFile" -t "$sublerArgs"
	else
		"$sublerCliPath" -o "$theFile" -O -t "$sublerArgs"
	fi
	if [ "$imgIntegrityTest" -lt 100 ]; then
		setLabelColor "$theFile" "1" &
		#displayAlert "Error: Add TV Tags" "Error: Cover art failed integrity test.   No artwork was added"
	fi
}

function resizeImage () {
	sips -Z 600W600H "$1" --out "$1"
}

function urlEncode () {
	escapeString=$(echo "$1" | sed "s|\'|\\\'|g" )
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

function renameTvItem () {
	if [[ ! -z "$seriesName" && ! -z "$seasonNum" && ! -z "$episodeNum" ]]; then
		seasonNum2digits=$(printf "%02d" $seasonNum)
		episodeNum2digits=$(printf "%02d" $episodeNum)
		newFileName="${seriesName} - S${seasonNum2digits}E${episodeNum2digits}.${fileExt}"
		renameFilePath="${outputDir}/${newFileName}"
		if [ ! -e "$renameFilePath" ]; then
			mv "$theFile" "$renameFilePath"
			theFile="$renameFilePath"
		else
			osascript -e "set the_File to \"$newFileName\"" -e 'tell application "System Events" to activate & display alert "Error: Add TV Tags" message "Error: Rename File Failed. Cannot rename the file." & Return & the_File & " already exists."'
			continue
		fi
	else
		displayAlert "Error: Rename TV Items" "No Season or Episode Number was returned."
		exit 0
	fi
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

function setLabelColor() {
	osascript -e "try" -e "set theFolder to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set label index of theFolder to $2" -e "end try" > /dev/null
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
scriptPID=$$
sortOrder="default" # set as default or dvd
bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`
xpathPath="/usr/bin/xpath"
xmllintPath="/usr/bin/xmllint"
atomicParsleyPath="${bundlePath}/MacOS/AtomicParsley"
mp4infoPath="${bundlePath}/MacOS/mp4info"
mp4tagsPath="${bundlePath}/MacOS/mp4tags"
mp4artPath="${bundlePath}/MacOS/mp4art"
mp4chapsPath="${bundlePath}/MacOS/mp4chaps"
sublerCliPath="${bundlePath}/MacOS/SublerCLI"
curlCmd=$(echo "curl -L --compressed --connect-timeout 30 --max-time 60 --retry 1")
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
exec > "$HOME/Library/Logs/BatchRipActions/addTvTags.log"
exec 2>> "$HOME/Library/Logs/BatchRipActions/addTvTags.log"


while read theFile
do
	if [[ ! "${optimizeFile}" ]]; then optimizeFile=0; fi
	if [[ ! "${renameFile}" ]]; then renameFile=0; fi
	if [[ ! "${backupFile}" ]]; then backupFile=0; fi
	if [[ ! "${removeTags}" ]]; then removeTags=0; fi
	if [[ ! "${useFileNameForSearch}" ]]; then useFileNameForSearch=0; fi
	if [[ ! "${addTags}" ]]; then addTags=0; fi
	if [[ ! "${sortOrder}" ]]; then sortOrder=0; fi
	if [[ sortOrder -eq 0 ]]; then sortOrder="default"; fi
	if [[ sortOrder -eq 1 ]]; then sortOrder="dvd"; fi
	
	if [[ ! -x "$mp4infoPath" || ! -x "$mp4tagsPath" || ! -x "$mp4artPath" || ! -x "$mp4chapsPath" || ! -x "$atomicParsleyPath" || ! -x "$sublerCliPath" ]]; then
		displayAlert "Error: Add TV Tags" "The Command Line Tools needed for this action could not be found. Please reinstall Batch Rip Actions for Automator."
		exit 1
	fi

	fileExt=`basename "$theFile" | sed 's|.*\.||'`
	fileName=`basename "$theFile" .${fileExt} | tr '_' ' ' | sed 's| ([0-9]*)||'`
	fileNameWithExt=`basename "$theFile"`
	movieName=`basename "$theFile" ".${fileExt}"`
	outputDir=`dirname "$theFile"`
	setLabelColor "$theFile" "0" &
	
	# Create Temp Folder
	tmpFolder="/tmp/AddTVtags_${scriptPID}"
	if [ ! -e "$tmpFolder" ]; then
		mkdir "$tmpFolder"
	fi
	# Backup File
	if [[ backupFile -eq 1 ]]; then
		cp "$theFile" "${outputDir}/${movieName}-backup-${scriptPID}.${fileExt}"
	fi

	if [[ addTags -eq 1 || renameFile -eq 1 ]]; then
		if [[ "$fileExt" = "mp4" || "$fileExt" = "m4v" ]]; then
			if [[ useFileNameForSearch -eq 1 ]]; then
				if echo "$theFile" | egrep '.* - S[0-9]{2}E[0-9]{2}\....' ; then
					season_episode=$(basename "$theFile" | sed -e 's/\./ /g' -e 's/.*\([Ss][0-9][0-9][Ee][0-9][0-9]\).*/\1/')
					seasonNum=$(echo $season_episode | awk -F[Ee] '{print $1}'| awk -F[Ss] '{print $2}' | sed 's|^0||')
					episodeNum=$(echo $season_episode | awk -F[Ee] '{print $2}' | sed 's|^0||')
					episodeID=`echo $season_episode | sed -e 's|.*[Ee]||' -e "s|^|${seasonNum}|"`
					seriesName=$(basename "$theFile" | sed -e 's/\./ /g' -e 's/ [Ss][0-9][0-9][Ee][0-9][0-9].*//' -e 's|\ \-$||')
					searchTerm=$(echo "$seriesName" | sed -e 's|\ |+|g' -e 's|\ \-\ |:\ |g' -e "s|\'|%27|g")
					tvdbGetTvTags
				else
					displayAlert "Error: Add TV Tags (Filename)" "File Naming Convention. Cannot parse the filename. Rename your file: TV Show Name - S##E##.m4v"
					cleanUpTmpFiles
					break 1
				fi
			else
				searchForTvTags
				tvdbGetTvTags
			fi
			if sed '1q;d' "$episodeXml" | grep '>' > /dev/null ; then
				if [[ renameFile -eq 1 ]]; then
					renameTvItem
				fi
				if [[ removeTags -eq 1 ]]; then
					"$atomicParsleyPath" "$theFile" --overWrite --metaEnema
				fi
				if [[ addTags -eq 1 ]]; then
					addiTunesTagsTV
				fi
				osascript -e "set theFile to POSIX file \"$theFile\"" -e 'tell application "Finder" to update theFile'
			else
				if [[ useFileNameForSearch -eq 1 ]]; then
					setLabelColor "$theFile" "1" &
					displayAlert "Error: Add TV Tags (TVDB)" "The API server did not return a correct match or the service may be down.  Verify that your file name has the correct Movie Name and Year according to themoviedb.org database. If the problem resides with the API server, try again later."
				else
					setLabelColor "$theFile" "1" &
					displayAlert "Error: Add TV Tags (TVDB)" "No results returned from database.  The API may be down or there is a problem returning the data. Check your internet connection or try again later."
				fi
				cleanUpTmpFiles
				break 1
			fi
	else
		displayAlert "Error: Add TV Tags" "File Type Extension. Cannot determine if file is mpeg-4 compatible. File extension and type must be .mp4 or .m4v."
		cleanUpTmpFiles
		break 1
	fi		
	elif [[ removeTags -eq 1 && addTags -eq 0 && renameFile -eq 0 ]]; then
		"$atomicParsleyPath" "$theFile" --overWrite --metaEnema
	else
		displayAlert "Error: Error: Add TV Tags" "No workflow options selected.  Please check your workflow options in Automator."
		cleanUpTmpFiles
		exit 1
	fi
	returnList="${returnList}${theFile}|"
	cleanUpTmpFiles
done

# Display script completed notification
displayNotificationCount=`echo "$returnList" | tr '|' '\n' | grep -v "^$" | grep -c ""`
displayNotification "Batch Rip Actions for Automator" "Add TV Tags" "${displayNotificationCount} item(s) were processed."

# Restore standard output & return output files
exec 1>&6 6>&- 
echo "$returnList" | tr '|' '\n' | grep -v "^$"
exit 0
