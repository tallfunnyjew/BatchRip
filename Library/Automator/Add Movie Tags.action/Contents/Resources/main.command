#!/usr/bin/env sh

# main.command
# Add Movie Tags

#  Created by Robert Yamada on 10/2/09.
#  Changes:
#  20091026-0 Added AP title & stik tags.
#  20091026-1 Added mp4tags, mp4info & mp4chaps. Added HD-Flag and Add Chaps from file
#  20091113-2 Added support for search and tag
#  20091118-3 Added underscore removal to $fileName
#  20101129-4 Added content rating and long description
#  20101202-5 Added preserve/set cnid number
#  20110728-6 Added test for tagchimp releaseDateY
#  20110728-7 Updated dialogs for Lion
#  20111011-8 Updates for SublerCLI and Action Bundle
#  20131108-9 Updates for tmdb api 3

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
xpathPath="/usr/bin/xpath"
jqToolPath="${bundlePath}/MacOS/jq"
atomicParsleyPath="${bundlePath}/MacOS/AtomicParsley"
mp4infoPath="${bundlePath}/MacOS/mp4info"
mp4tagsPath="${bundlePath}/MacOS/mp4tags"
mp4artPath="${bundlePath}/MacOS/mp4art"
mp4chapsPath="${bundlePath}/MacOS/mp4chaps"
sublerCliPath="${bundlePath}/MacOS/SublerCLI"
curlCmd=$(echo "curl -L --compressed --connect-timeout 30 --max-time 60 --retry 1")
tmdbApiKey="8d7d0edf7ec73435ea5d99d9cba9b54d"

function getMovieTagsFromFileName () {
	# variables	
	discName="$movieName"
	discNameNoYear=`htmlEncode "$(echo "$discName" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g')"`
	# set TMDb searchTerm
	searchTerm=`urlEncode "$discNameNoYear"`
	movieYear=`echo "$discName" | awk -F\( '{print $2}' | awk -F\) '{print $1}'`

	echo -e "  Searching TMDb for ${searchTerm}... \c"
	if [ ! -e "${sourceTmpFolder}/${searchTerm}_tmp.json" ]; then
		# get TMDb ID for all matches
		movieSearchXml="${sourceTmpFolder}/${searchTerm}_tmp.json"
		$curlCmd "http://api.themoviedb.org/3/search/movie?api_key=$tmdbApiKey&query=$searchTerm" > "$movieSearchXml"
		tmdbSearch=$(getKeyValue "$movieSearchXml" '.results[].id')

		# find the listing that matches the releses the release date, movie title and type
		for theMovieID in $tmdbSearch
		do
			# download each id to tmp.xml
			movieData="${sourceTmpFolder}/${theMovieID}_tbdb_tmp.json"
			if [ ! -e "$movieData" ]; then
				$curlCmd "http://api.themoviedb.org/3/movie/$theMovieID?api_key=$tmdbApiKey&append_to_response=releases,credits" | "$jqToolPath" '.' | iconv -f ISO-8859-1 -t UTF-8 > "$movieData"
			fi

			# get movie title and release date
			discNameNoYearWildcard=`echo "$discNameNoYear" | sed -e 's|:|.*|g' -e 's|\&|.*|g'`
			releaseDate=`getKeyValue "$movieData" ".release_date" 2>/dev/null | grep "$movieYear"`
			movieTitle=`getKeyValue "$movieData" ".title" 2>/dev/null | sed 's|[ \t]*$||' | egrep -ix "$discNameNoYearWildcard"`
			if [ "$movieTitle" = "" ]; then
				movieTitle=`$curlCmd "http://api.themoviedb.org/3/movie/$theMovieID/alternative_titles?api_key=$tmdbApiKey" | "$jqToolPath" -r '.titles[].title' | egrep -ix "$discNameNoYearWildcard"`
			fi
			
			# verify data match, delete if not a match
			if [[ ! "$releaseDate" = "" && ! "$movieTitle" = "" ]] ; then
				echo "Title found"
				mv "$movieData" "$movieSearchXml"
				movieData="$movieSearchXml"
				break 1
			else
				if [ -e "$movieData" ]; then
					rm "$movieData"
				fi
			fi
		done
		if [ ! -e "$movieSearchXml" ]; then
			echo " " > "$movieSearchXml"
		fi
	fi
}

function searchForMovieTags () {
	getMovieName=`displayDialogGetMovieName "$fileName"`
	if [[ ! -z "$getMovieName" && ! "$getMovieName" = "Quit" ]]; then
		movieList=`tmdbGetMovieTitles "$getMovieName"`
		displayTitle=`echo "$movieList" | sed 's|ID\#\:[0-9]*||g'`
		chooseTitle=`displayDialogChooseTitle "$displayTitle"`
		if [[ ! "$chooseTitle" = "false" && ! "$chooseTitle" = "" ]]; then
			theMovieID=`echo "$movieList" | tr '+' '\n' | grep "$chooseTitle" | sed 's|.*ID\#\:||'`

			# download each id to tmp.xml
			movieData="${sourceTmpFolder}/${theMovieID}_tbdb_tmp.json"
			if [ ! -e "$movieData" ]; then
				$curlCmd "http://api.themoviedb.org/3/movie/$theMovieID?api_key=$tmdbApiKey&append_to_response=releases,credits" | "$jqToolPath" '.' | iconv -f ISO-8859-1 -t UTF-8 > "$movieData"
			fi
		else
			displayAlert "Error: Add Movie Tags (TMDB)" "Error: No movie selected. Movie may not be in themoviedb.org database"
			cleanUpTmpFiles
			continue
		fi
	elif [ "$getMovieName" = "Quit" ]; then
		cleanUpTmpFiles
		exit 0
	else
		cleanUpTmpFiles
		continue
	fi
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

function displayDialogGetMovieName () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$1"
		tell application "System Events" 
		activate
		display dialog "What is the movie title?" default answer theFile buttons {"Cancel All", "Cancel", "OK"} default button 3
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

function getKeyValue () {
	cat $1 | "$jqToolPath" -r "$2"
}

function renameMovieItem () {
	movieTitle=`getKeyValue "$movieData" ".title" 2>/dev/null | sed -e 's|: | - |g' -e 's|\&amp;|\&|g' -e "s|&apos;|\'|g"`
	releaseDate=`getKeyValue "$movieData" ".release_date" 2>/dev/null`
	releaseYear=`echo "$releaseDate" | sed 's|-.*||g'`
	
	if [[ ! -z "$theMovieNameAndYear" && ! -z "$movieTitle"  ]]; then
		movieTitleAndYear="$theMovieNameAndYear"
	else
		movieTitleAndYear="${movieTitle} (${releaseYear})"
	fi

	if [ -d "$theFile" ]; then
		renameFolderPath="${outputDir}/${movieTitleAndYear}"
		if [ ! -e "$renameFolderPath" ]; then
			mv "$theFile" "$renameFolderPath"
			theFile="$renameFolderPath"
		else
			osascript -e "set the_folder to \"$movieTitleAndYear\"" -e 'tell application "System Events" to activate & display alert "Error: Add Movie Tags" message "Rename Folder Failed. Cannot rename the folder." & Return & the_folder & " already exists."'
			continue
		fi
	else
		renameFilePath="${outputDir}/${movieTitleAndYear}.${fileExt}"
		if [ ! -e "$renameFilePath" ]; then
			touch "$theFile"
			mv "$theFile" "$renameFilePath"
			theFile="$renameFilePath"
			movieName=`basename "$theFile" ".${fileExt}"`
		else
			osascript -e "set the_File to \"${movieTitleAndYear}.${fileExt}\"" -e 'tell application "System Events" to activate & display alert "Error: Add Movie Tags" message "Error: Rename File Failed. Cannot rename the file." & Return & the_File & " already exists."'
			continue
		fi
	fi
}

function addMovieTags () {
	# set metadata variables and write tags to file
	movieTitle=`getKeyValue "$movieData" ".title" | sed -e 's|[ \t]*$||' -e 's|: | - |g' -e 's|\&amp;|\&|g' -e "s|&apos;|\'|g"`
	videoType="Movie"
	movieDirector=`getKeyValue "$movieData" '.credits.crew[] | select(.department=="Directing") | .name' | tr '\n' ',' | sed -e 's|,|, |g' -e 's|, $||g'`
	movieProducers=`getKeyValue "$movieData" '.credits.crew[] | select(.department=="Production") | .name' | tr '\n' ',' | sed -e 's|,|, |g' -e 's|, $||g'`
	movieWriters=`getKeyValue "$movieData" '.credits.crew[] | select(.department=="Writing") | .name' | tr '\n' ',' | sed -e 's|,|, |g' -e 's|, $||g'`
	movieActors=`getKeyValue "$movieData" '.credits.cast[].name' | tr '\n' ',' | sed -e 's|,|, |g' -e 's|, $||g'`
	albumArtists=`getKeyValue "$movieData" '.credits.cast[].name' | tr '\n' ',' | sed -e 's|,|, |g' -e 's|, $||g'`
	releaseDate=`getKeyValue "$movieData" ".release_date"`
	movieDesc=`getKeyValue "$movieData" ".overview"`
	movieRating=`getKeyValue "$movieData" '.releases.countries[] | select(.iso_3166_1=="US") | .certification'`
	genreList=`getKeyValue "$movieData" '.genres[].name' | tr '\n' ',' | sed -e 's|,|, |g' -e 's|, $||g'`
	purchaseDate=`date "+%Y-%m-%d %H:%M:%S"`
	releaseYear=`echo "$releaseDate" | sed 's|-.*||g'`
	
	if [ ! -z "$theMovieNameAndYear" ]; then
		movieTitleAndYear="$theMovieNameAndYear"
	else
		movieTitleAndYear="${movieTitle} (${releaseYear})"
	fi

	# parse category info and convert into iTunes genre
	if echo "$genreList" | grep 'Animation' > /dev/null ; then
		movieGenre="Kids & Family"
	elif echo "$genreList" | grep '\(Fantasy\|Science\|Science Fiction\)' > /dev/null ; then
		movieGenre="Sci-Fi & Fantasy"
	elif echo "$genreList" | grep 'Horror' > /dev/null ; then
		movieGenre="Horror"
	elif echo "$genreList" | grep '\(Action\|Adventure\|Disaster\)' > /dev/null ; then
		movieGenre="Action & Adventure"
	elif echo "$genreList" | grep '\(Musical\|Music\)' > /dev/null ; then
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
	moviePoster="${sourceTmpFolder}/${theMovieID}.jpg"
	if [ ! -e $moviePoster ] ; then
		baseURL=`$curlCmd "http://api.themoviedb.org/3/configuration?api_key=$tmdbApiKey" | "$jqToolPath" -r '.images.base_url'`
		posterURL=`getKeyValue "$movieData" '.poster_path'`
		$curlCmd "${baseURL}w500${posterURL}" > $moviePoster
		imgIntegrityTest=`sips -g pixelWidth "$moviePoster" | sed 's|.*[^0-9+]||'`
		wait
		if [ "$imgIntegrityTest" -gt 100 ]; then
			resizeImage "$moviePoster"
		fi
		if [ "$imgIntegrityTest" -gt 100 ]; then
			moviePoster="$moviePoster"
		else
			moviePoster=""
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

	sublerArgs="{Artwork:$moviePoster}{Name:$movieTitleAndYear}{Artist:$movieDirector}{Album Artist:}{Album:}{Grouping:}{Composer:}{Comments:}{Genre:$movieGenre}{Release Date:$releaseDate}{Track #:}{Disk #:}{TV Show:}{TV Episode #:}{TV Network:}{TV Episode ID:}{TV Season:}{Description:$movieDesc}{Long Description:$movieDesc}{Rating:$movieRating}{Rating Annotation:}{Studio:$studioName}{Cast:$movieActors}{Director:$movieDirector}{Codirector:$movieCoDirector}{Producers:$movieProducers}{Screenwriters:$movieWriters}{Lyrics:}{Copyright:}{contentID:$cnidNum}{HD Video:$hdFileTest}{Gapless:0}{Content Rating:}{Media Kind:$videoType}"
	sublerArgs=`substituteISO88591 "$(echo "$sublerArgs")"`
	
	# write tags with sublerCli
	echo -e "\n*Writing tags with SublerCLI\c"
	if [[ optimizeFile -eq 0 ]]; then
		"$sublerCliPath" -o "$theFile" -t "$sublerArgs"
	else
		"$sublerCliPath" -o "$theFile" -O -t "$sublerArgs"
	fi
	if [ "$imgIntegrityTest" -lt 100 ]; then
		#displayAlert "Error: Add Movie Tags" "Cover art failed integrity test.  No artwork was added"
		setLabelColor "$theFile" "1" &
	fi
}

function addChapterNamesMovie () {
	movieTitle=`getKeyValue "$movieData" ".title" | sed -e 's|[ \t]*$||' -e 's|: | - |g' -e 's|\&amp;|\&|g' -e "s|&apos;|\'|g"`
	releaseDate=`getKeyValue "$movieData" ".release_date"`
	releaseYear=`echo "$releaseDate" | sed 's|-.*||g'`
	
	if [ ! -z "$theMovieNameAndYear" ]; then
		movieTitleAndYear="$theMovieNameAndYear"
	else
		movieTitleAndYear="${movieTitle} (${releaseYear})"
	fi
	
	tagChimpToken=1803782295499EE85E56181
	discNameNoYear=`echo "$movieTitleAndYear" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g'`
	searchTerm=`urlEncode "$discNameNoYear"`
	movieYear=`echo "$movieTitleAndYear" | awk -F\( '{print $2}' | awk -F\) '{print $1}'`
	chapterFile="${outputDir}/${movieName}.chapters.txt"
	if [ ! -e "$chapterFile" ]; then
		echo -e "  Searching TagChimp for chapter names... \c"
	#	Get chaps from m4v
		"$mp4chapsPath" -qxC "$theFile"

	#	Get count of chaps
		chapterCount=$(grep -cv "NAME" "$chapterFile")
	#	Search tagchimp
		tagChimpIdXml="${sourceTmpFolder}/${searchTerm}-chimp.xml"
		tagChimpXml="${sourceTmpFolder}/${searchTerm}-info-chimp.xml"
		$curlCmd "https://www.tagchimp.com/ape/search.php?token=$tagChimpToken&type=search&title=$searchTerm&videoKind=Movie&limit=10&totalChapters=$chapterCount" > "$tagChimpIdXml"
		searchTagChimp=`"$xpathPath" "$tagChimpIdXml" //tagChimpID 2>/dev/null | sed -e 's|\/tagChimpID>|\||g'| tr '|' '\n' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		# test chapters for each id
		for tagChimpID in $searchTagChimp
		do
			# download each id to tmp.xml
			tagChimpData="${sourceTmpFolder}/${tagChimpID}-chimp.xml"
			if [ ! -e "$tagChimpData" ]; then		
				#$curlCmd "https://www.tagchimp.com/ape/search.php?token=$tagChimpToken&type=lookup&id=$tagChimpID" | iconv -f utf-8 -t ASCII//TRANSLIT > "$tagChimpData"
				$curlCmd "https://www.tagchimp.com/ape/search.php?token=$tagChimpToken&type=lookup&id=$tagChimpID" | iconv -f ISO-8859-1 -t UTF-8 > "$tagChimpData"
			fi
			# 	Disc Name with wildcard for colins and ampersands
			discNameNoYearWildcard=`echo "$discNameNoYear" | sed -e 's|:|.*|g' -e 's|\&|.*|g'`
			# 	Test id for release year
			releaseDate=`"$xpathPath" "$tagChimpData" "//releaseDateY/text()" 2>/dev/null | grep "$movieYear"`
			if [ "$releaseDate" = "" ]; then
				releaseDate=`"$xpathPath" "$tagChimpData" "//releaseDate/text()" 2>/dev/null | grep "$movieYear"`
			fi
			# 	Test id for title
			#movieTitle=`"$xpathPath" "$tagChimpData" "//movieTitle/text()" 2>/dev/null | sed -e "s|&apos;|\'|g" -e 's| $||' | egrep -i "$discNameNoYearWildcard"`
			movieTitle=`"$xpathPath" "$tagChimpData" "//movieTitle/text()" 2>/dev/null | sed 's|[ \t]*$||' | egrep -ix "$discNameNoYearWildcard"`
			#	Test id for chap count
			titleCount=`"$xpathPath" "$tagChimpData" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' | tr '|' '\n' | grep -c ""`
			#	Test chapter titles for uniqueness
			chapterTest=`"$xpathPath" "$tagChimpData" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' | tr '|' '\n' | sed '3q;d' | grep "3"`
			chapterNameTest=`"$xpathPath" "$tagChimpData" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' | tr '|' '\n' | egrep -ic "chapter"`
			# 	verify data match, delete if not a match
			if [[ ! "$releaseDate" = "" && ! "$movieTitle" = "" && -z "$chapterTest" && chapterNameTest -eq 0 ]]; then
				if [ "$titleCount" = "$chapterCount" ]; then
					echo -e "Chapters found\n"
					mv "$tagChimpData" "$tagChimpXml"
					break 1
				else
					titleCountMin=$((titleCount - 1))
					titleCountMax=$((titleCount + 1))
					if [[ $titleCount -gt $titleCountMin && $titleCount -lt $titleCountMax ]]; then
						if [ ! -e "$tagChimpXml" ]; then
							notExactMatch="${sourceTmpFolder}/${searchTerm}-notExact-chimp.xml"
							mv "$tagChimpData" "$notExactMatch"
						fi
					fi
				fi	
			fi	
		done

		# if could not find exact match, fallback to notExactMatch
		if [ ! -e "$tagChimpXml" ]; then
			if [ -e "$notExactMatch" ]; then
				echo -e "Chapters found (not exact match)\n"
				mv "$notExactMatch" "$tagChimpXml"
			else
				echo " " > "$tagChimpXml"
			fi
		fi

		#	Get chapter titles
		if grep "<movieTitle>" "$tagChimpXml" > /dev/null ; then
			titleFile="${sourceTmpFolder}/${searchTerm}_titles.txt"
			# Save just titles to file
			"$xpathPath" "$tagChimpXml" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|"||g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' -e 's|&amp;amp;|\\\&|g' | tr '|' '\n' > "$titleFile"
			# Create a csv file for later use with hb
			if [[ saveCsv -eq 1 ]]; then
				cat "$titleFile" | grep -n "" | sed -e 's|,|\\,|g' -e 's|:|, |' > "${outputDir}/${movieName}.chapters.csv"		
			fi
			chapterNameLine=$(grep "NAME" "$chapterFile" | tr ' ' '\007')
			chapterMarkers=$(grep -v "NAME" "$chapterFile")
			chaptersWithTitlesTmp="${sourceTmpFolder}/${discName}_tmp.chapters.txt"
			chapterNum=0
			for eachChapter in $chapterNameLine
			do
				chapterNum=$(($chapterNum + 1))
				eachChapter=$(echo "$eachChapter" | tr '\007' ' ')
				eachMarker=$(echo "$chapterMarkers" | sed "${chapterNum}q;d")
				eachTitle=$(sed "${chapterNum}q;d" "$titleFile")
				#	Replace chapterFile name with titleFile name
				echo "$eachMarker"  >> "$chaptersWithTitlesTmp"
				echo "$eachChapter" | sed -e "s|=.*|=$eachTitle|g"  >> "$chaptersWithTitlesTmp"
			done
			if [ -e "$chaptersWithTitlesTmp" ]; then
				substituteISO88591 "$(cat "$chaptersWithTitlesTmp")" > "$chapterFile"
			fi
		else
			# set color label of movie file to orange
			setLabelColor "$theFile" "1" &
			#displayAlert "Error: Add Chapter Names" "No match found from database. The API may be down or there is a problem returning the data. Check tagchimp.com to verify chapter information."
		fi
	fi
	#	Add chaps to m4v
	if [[ -e "$theFile" && -e "$chapterFile" ]]; then
		"$mp4chapsPath" -i "$theFile"
		# Delete chapter file
		if [[ saveChaps -eq 0 ]]; then
			rm -f "$chapterFile"
		fi
	fi
}

function resizeImage () {
	sips -Z 600W600H "$1" --out "$1"
}

function htmlEncode () {
	escapeString=$(echo "$1" | sed "s|\'|\\\'|g" )
	php -r "echo htmlspecialchars(iconv('UTF-8-MAC', 'ISO-8859-1', '$escapeString'));"
}

function urlEncode () {
	escapeString=$(echo "$1" | sed -e "s|\'|\\\'|g" -e 's|&amp;|\&|g')
	#php -r "echo urlEncode('$1');"
	#php -r "echo urlEncode(iconv('UTF-8-MAC', 'UTF-8', '$1'));"
	php -r "echo urlEncode(iconv('ISO-8859-1', 'UTF-8', '$escapeString'));"
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

function setLabelColor() {
	osascript -e "try" -e "set theFolder to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set label index of theFolder to $2" -e "end try" > /dev/null
}

function getLabelColor() {
	osascript -e "try" -e "set theItem to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to return label index of theItem" -e "end try"	
}

function cleanUpTmpFiles () {
		if [ -e "$sourceTmpFolder" ]; then
			rm -rfd $sourceTmpFolder
		fi
}


#####################################################################################
# MAIN SCRIPT

# Debug
set -xv

# Create Log Folder
if [ ! -d "$HOME/Library/Logs/BatchRipActions" ]; then
	mkdir "$HOME/Library/Logs/BatchRipActions"
fi

# Redirect standard output to log
exec 6>&1
exec > "$HOME/Library/Logs/BatchRipActions/addMovieTags.log"
exec 2>> "$HOME/Library/Logs/BatchRipActions/addMovieTags.log"

while read theFile
do
	if [[ ! "${optimizeFile}" ]]; then optimizeFile=0; fi
	if [[ ! "${backupFile}" ]]; then backupFile=0; fi
	if [[ ! "${removeTags}" ]]; then removeTags=0; fi
	if [[ ! "${addTags}" ]]; then addTags=0; fi
	if [[ ! "${useFileNameForSearch}" ]]; then useFileNameForSearch=0; fi
	if [[ ! "${renameFile}" ]]; then renameFile=0; fi
	if [[ ! "${addChaps}" ]]; then addChaps=0; fi
	if [[ ! "${saveChaps}" ]]; then saveChaps=0; fi
	if [[ ! "${saveCsv}" ]]; then saveCsv=0; fi

	if [[ ! -x "$mp4infoPath" || ! -x "$mp4tagsPath" || ! -x "$mp4artPath" || ! -x "$mp4chapsPath" || ! -x "$atomicParsleyPath" || ! -x "$sublerCliPath" ]]; then
		displayAlert "Error: Add Movie Tags" "The Command Line Tools needed for this action could not be found. Please reinstall Batch Rip Actions for Automator."
		exit 1
	fi

	if [ -d "$theFile" ]; then
		fileName=`basename "$theFile" | tr '_' ' ' | sed 's| ([0-9]*)||'`
	else
		fileExt=`basename "$theFile" | sed 's|.*\.||'`
		fileName=`basename "$theFile" .${fileExt} | tr '_' ' ' | sed 's| ([0-9]*)||'`
		setLabelColor "$theFile" "0" &
	fi
	movieName=`basename "$theFile" ".${fileExt}"`
	outputDir=`dirname "$theFile"`
	
	# Create Temp Folder
	sourceTmpFolder="/tmp/addMovieTags_$scriptPID"
	mkdir $sourceTmpFolder

	# Backup File
	if [[ ! -d "$theFile" && backupFile -eq 1 ]]; then
		cp "$theFile" "${outputDir}/${movieName}-backup-${scriptPID}.${fileExt}"
	fi
	
	if [[ addTags -eq 1 || addChaps -eq 1 || renameFile -eq 1 ]]; then
		if [[ useFileNameForSearch -eq 1 ]]; then
			if echo "$theFile" | egrep '.* \([0-9]{4}\)' ; then
				getMovieTagsFromFileName
			else
				displayAlert "Error: Add Movie Tags (Filename)" "File Naming Convention. Cannot parse the filename. Rename your file: Movie Name (year)"
				cleanUpTmpFiles
				break 1
			fi
		else
			searchForMovieTags
		fi
		if sed '1q;d' "$movieData" | grep '{' > /dev/null ; then
			if [[ renameFile -eq 1 ]]; then
				renameMovieItem
			fi
			if [[ addTags -eq 1 || addChaps -eq 1 ]]; then
				if [[ "$fileExt" = "mp4" || "$fileExt" = "m4v" ]]; then
					if [ ! -d "$theFile" ]; then
						if [[ removeTags -eq 1 ]]; then
							"$atomicParsleyPath" "$theFile" --overWrite --metaEnema
						fi
						if [[ addTags -eq 1 ]]; then
							addMovieTags
						fi
						if [[ addChaps -eq 1 ]]; then
							addChapterNamesMovie
						fi
					fi
				else
					displayAlert "Error: Add Movie Tags" "File Type Extension. Cannot determine if file is mpeg-4 compatible. File extension and type must be .mp4 or .m4v."
					cleanUpTmpFiles
					break 1
				fi
			fi
			osascript -e "set theFile to POSIX file \"$theFile\"" -e 'tell application "Finder" to update theFile'
		else
			if [[ useFileNameForSearch -eq 1 ]]; then
				setLabelColor "$theFile" "1" &
				displayAlert "Error: Add Movie Tags (TMDB)" "The API server did not return a correct match or the service may be down.  Verify that your file name has the correct Movie Name and Year according to themoviedb.org database. If the problem resides with the API server, try again later."
			else
				setLabelColor "$theFile" "1" &
				displayAlert "Error: Add Movie Tags (TMDB)" "No results returned from database.  The API may be down or there is a problem returning the data. Check your internet connection or try again later."
			fi
			cleanUpTmpFiles
			break 1
		fi
	elif [[ removeTags -eq 1 && addTags -eq 0 && addChaps -eq 0 && renameFile -eq 0 ]]; then
		"$atomicParsleyPath" "$theFile" --overWrite --metaEnema
	else
		displayAlert "Error: Add Movie Tags" "No workflow options selected.  Please check your workflow options in Automator."
		cleanUpTmpFiles
		exit 1
	fi
	returnList="${returnList}${theFile}|"
	cleanUpTmpFiles
done

# Display script completed notification
displayNotificationCount=`echo "$returnList" | tr '|' '\n' | grep -v "^$" | grep -c ""`
displayNotification "Batch Rip Actions for Automator" "Add Movie Tags" "${displayNotificationCount} item(s) were processed."

# Restore standard output & return output files
exec 1>&6 6>&- 
echo "$returnList" | tr '|' '\n' | grep -v "^$"
exit 0