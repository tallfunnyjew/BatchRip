# !/bin/sh

# batchRip.sh is a script to batch rip dvds with Fairmount or MakeMKV
# Copyright (C) 2009-2013  Robert Yamada

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

# Change Log:
# 0.20090606.0 - inital release
# 2.20090719.0 - added test for discs with same name
# 3.20090720.0 - changed output dir to arg
# 4.20090922.0 - added test to quit if no discs are found
# 5.20090924.0 - adding makemkv ripping functions
# 6.20091006.0 - adding args for automator
# 7.20091023.0 - adding back append discs with same name
# 8.20091118.0 - added support for batch rip dispatcher
# 9.20091119.0 - added discCount to minimize wait time
#10.20091120.1 - added back support for skipping duplicates
#11.20091201.0 - Finally got around to adding subroutine to parse variables as args
#12.20091204.0 - added discIdent Query to identify titles
#13.20101113.0 - updated makemkv routine
#14.20101128.0 - added loop to wait for Fairmount to mount discs as images
#15.20101128.1 - added an adjustable sleep for multiple discs
#16.20101202.0 - MakeMKV drive access update
#17.20101202.1 - added Multi-disc wait time
#18.20101202.2 - added a Fairmount timeout
#19.20101202.3 - added skip if Fairmount can't mount
#20.20101202.4 - sanity check update
#21.20101202.5 - added option for MakeMKV Full BD backup
#22.20101202.6 - added support for folder colors
#23.20101202.7 - added a error test for copying
#24.20101202.8 - added a test to Check Disk Free Space
#16.20101202.0 - added test for quarantined apps
#17.20101202.1 - added test for vlc.app
#18.20101206.0 - added user defined discName
#19.20111209.0 - Updated discType for problematic usb enclosures
#20.20131111.0 - Removed support for Fairmount
#21.20131116.0 - Added back support for Fairmount

#############################################################################
# globals

######### CONST GLOBAL VARIABLES #########
scriptName=`basename "$0"`
scriptVers="1.1.1 (281)"
scriptPID=$$
E_BADARGS=65

######### DEBUG #########
debugScript=0
if [[ $debugScript -eq 1 ]]; then
	set -xv
fi

######### USER DEFINED VARIABLES #########
# APPLICATION SUPPORT
batchRipSupportPath="$HOME/Library/Application Support/Batch Rip"
currentItemsList="${batchRipSupportPath}/currentItems.txt"
scriptTmpPath="${batchRipSupportPath}/batchRipTmp.sh"

# SET OUTPUT PATHS
movieOutputDir="/Volumes" # set the movie search directory 
tvOutputDir="/Volumes"    # set the tv show search directory 

######### SWITCHES & OVERRIDES (TRUE=1/FALSE=0) #########
encodeHdSources="1"    # if set to 0, will only encode VIDEO_TS (DVDs)
encodeDvdSources="1"
onlyMakeMKV="0"        # if set to 1, will use MakeMKV for DVDs and BDs
growlMe="0"            # if set to 1, will use growlNotify to send encode message
ejectDisc="0"          # Eject disk/s when done (yes/no)
videoKind="TV Show"    # Sets Default Video Kind
makeFoldersForMe=0     # if set to 1, will create input & output folders if they don't exist
saveLog="1"            # saves session log to ~/Library/Logs/BatchRipActions
skipDuplicates="1"     # if set to 0, if folder with same name exists, will copy disc and append pid # to name
discDelay="20"
copyDelay="20"
fullBdBackup="0"
verboseLog=0

# SET DEFAULT TOOL PATHS
bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`
fairmountPath="${bundlePath}/MacOS/Fairmount.app" # path to Fairmount.app
libdvdcssPath="/usr/lib/libdvdcss.2.dylib" # path to libdvdcss
makemkvPath="/Applications/MakeMKV.app"     # path to MakeMKV.app
growlNotify="/usr/local/bin/growlnotify"    # Path to growlNotify tool

# SET MIN AND MAX TRACK TIME
minTrackTimeTV="20"     # this is in minutes
maxTrackTimeTV="120"    # this is in minutes
minTrackTimeMovie="80"  # this is in minutes
maxTrackTimeMovie="180" # this is in minutes

# SET PREFERRED AUDIO LANGUAGE
audioLanguage="English" # set to English, Espanol, Francais, etc.

#############################################################################
# functions

parseVariablesInArgs() # Parses args passed from main.command
{
	if [ -z "$1" ]; then
		return
	fi

	while [ ! -z "$1" ]
	do
		case "$1" in
			( --verboseLog ) verboseLog=$2
			shift ;;
			( --skipDuplicates ) skipDuplicates=$2
			shift ;;
			( --encodeHdSources ) encodeHdSources=$2
			shift ;;
			( --saveLog ) saveLog=$2
			shift ;;
			( --fairmountPath ) fairmountPath=$2
			shift ;;
			( --makemkvPath ) makemkvPath=$2
			shift ;;
			( --movieOutputDir ) movieOutputDir=$2
			shift ;;
			( --tvOutputDir ) tvOutputDir=$2
			shift ;;
			( --encodeDvdSources ) encodeDvdSources=$2
			shift ;;
			( --growlMe ) growlMe=$2
			shift ;;
			( --onlyMakeMKV ) onlyMakeMKV=$2
			shift ;;
			( --ejectDisc ) ejectDisc=$2
			shift ;;
			( --minTrackTimeTV ) minTrackTimeTV=$2
			shift ;;
			( --maxTrackTimeTV ) maxTrackTimeTV=$2
			shift ;;
			( --minTrackTimeMovie ) minTrackTimeMovie=$2
			shift ;;
			( --maxTrackTimeMovie ) maxTrackTimeMovie=$2
			shift ;;
			( --discDelay ) discDelay=$2
			shift ;;
			( --copyDelay ) copyDelay=$2
			shift ;;
			( --fullBdBackup ) fullBdBackup=$2
			shift ;;
			( * ) echo "Args not recognized" ;;
		esac
		shift
	done

	# fix spaces in paths
	fairmountPath=`echo "$fairmountPath" | tr ':' ' '`
	makemkvconPath=`echo "$makemkvPath" | tr ':' ' ' | sed 's|$|/Contents/MacOS/makemkvcon|'`
	movieOutputDir=`echo "$movieOutputDir" | tr ':' ' '`
	tvOutputDir=`echo "$tvOutputDir" | tr ':' ' '`
}

makeFoldersForMe() # Creates the output folders when makeFoldersForMe is set to 1
{
	if [[ makeFoldersForMe -eq 1 ]]; then
		if [ ! -d "$movieOutputDir" ]; then
			mkdir "$movieOutputDir"
		fi
		if [ ! -d "$tvOutputDir" ]; then
			mkdir "$tvOutputDir"
		fi
	fi
}

sanityCheck () # Checks that apps are installed and input/output paths exist
{
	
	toolList="$fairmountPath:Fairmount.app|$libdvdcssPath:libdvdcss.2.dylib"

	if [[ encodeHdSources -eq 1 || onlyMakeMKV -eq 1 ]]; then
		toolList="$toolList|$makemkvPath:MakeMKV.app"
	fi
	if [[ growlMe -eq 1 ]]; then
		toolList="$toolList|$growlNotifyPath"
	fi
	
	toolList=`echo $toolList | tr ' ' '\007' | tr '|' '\n'`
	for eachTool in $toolList
	do
		toolPath=`echo $eachTool | sed 's|:.*||' | tr '\007' ' '`
		toolNameUser=`echo "$toolPath" | sed -e 's|.*/||'`
		toolName=`echo "$eachTool" | sed -e 's|.*:||' | tr '\007' ' '`
		if [ ! "$toolNameUser" = "$toolName" ]; then
			echo -e "\n    ERROR: $toolNameUser; was expecting $toolName command tool"
			toolDir=`dirname "$toolPath"`
			toolPath=`verifyFindCLTool "$toolPath" "$toolName"`
			echo "    ERROR: attempting to use tool at $toolPath"
			echo ""
		fi
		if [[ ! -x "$toolPath" && ! -e "$toolPath" ]]; then
				echo -e "\n    ERROR: $toolName command tool is not setup to execute"
				toolDir=`dirname "$toolPath"`
				toolPath=`verifyFindCLTool "$toolDir" "$toolName"`
				echo "    ERROR: attempting to use tool at $toolPath"
				echo ""
			if [[ ! -x "$toolPath" && ! -e "$toolPath" ]]; then
				echo "    ERROR: $toolName command tool could not be found"
				echo "    ERROR: $toolName can be installed in ./ /usr/local/bin/ /usr/bin/ ~/ or /Applications/"
				echo ""
				errorLog=1
			fi
		fi
		isQuarantined=`xattr -p com.apple.quarantine "$toolPath" 2> /dev/null`
		if [[ -e "$toolPath" && ! -z "$isQuarantined" ]]; then
			xattr -d com.apple.quarantine "$toolPath"
			echo -e "\nWARNING: $toolName is currently listed as QUARANTINED because it's an application downloaded from the Internet. Will attempt to authorize, but Action may fail if the OS prevents the app from launching."
			echo ""
		fi
	done
	
	# see if the input/output directories exist
	if [[ ! -e "$movieOutputDir" ]]; then
		echo "    ERROR: $movieOutputDir could not be found"
		echo "    Check \$movieOutputDir to set your Batch Rip Movies folder"
		echo ""
		errorLog=1
	fi
	if [[ ! -e "$tvOutputDir" ]]; then
		echo "    ERROR: $tvOutputDir could not be found"
		echo "    Check \$tvOutputDir to set your Batch Rip TV folder"
		echo ""
		errorLog=1
	fi

	# exit if sanity check failed
	if [[ errorLog -eq 1 ]]; then
		exit $E_BADARGS
	else
		fairmountDir=`dirname "$fairmountPath"`
		fairmountPath=`verifyFindCLTool "$fairmountDir" "Fairmount.app"`
		libdvdcssDir=`dirname "$libdvdcssPath"`
		libdvdcssPath=`verifyFindCLTool "$libdvdcssDir" "libdvdcss.2.dylib"`
		if [[ encodeHdSources -eq 1 || onlyMakeMKV -eq 1 ]]; then
			makemkvDir=`dirname "$makemkvPath"`
			makemkvPath=`verifyFindCLTool "$makemkvDir" "MakeMKV.app"`
			makemkvconPath=`verifyFindCLTool "${makemkvPath}/Contents/MacOS" "makemkvcon"`
		fi
		if [[ growlMe -eq 1 ]]; then
			growlnotifyDir=`dirname "$growlNotifyPath"`
			growlNotifyPath=`verifyFindCLTool "$growlnotifyDir" "growlnotify"`
		fi
	fi
	
	# check for libdvdcss install
	if [ ! -e "$libdvdcssPath" ]; then
		echo -e "\nWARNING: libdvdcss was not found. This Action assumes libdvdcss is installed in /usr/lib/ or /usr/local/lib. Will continue, but Action may fail if libdvdcss is not installed."
	fi
	
	# get onlyMakeMKV setting for setup info
	if [[ onlyMakeMKV -eq 0 ]]; 
		then onlyMakeMKVStatus="No"
		else onlyMakeMKVStatus="Yes"	
	fi

	# get growlMe setting for setup info
	if [[ growlMe -eq 0 ]]; 
		then growlMeStatus="No"
		else growlMeStatus="Yes"	
	fi

	# get encodeHdSources setting for setup info
	if [[ encodeHdSources -eq 0 ]]; 
		then encodeHdStatus="No"
		else encodeHdStatus="Yes"	
	fi

	# get ejectdisk setting for setup info
	if [[ ejectDisc -eq 0 ]]; 
		then ejectDiscStatus="No"
		else ejectDiscStatus="Yes"	
	fi

	# get fullBdBackup setting for setup info
	if [[ fullBdBackup -eq 0 ]]; 
		then backupBdStatus="No"
		else backupBdStatus="Yes"	
	fi	
}	

verifyFindCLTool() # Attempt to find tool path when default path fails
{
	toolDir="$1"
	toolName="$2"
	toolPath="${1}/${2}"
	if [ ! -x "$toolPath" ];
	then
		toolPathTMP=`PATH=.:/Applications:/:/usr/bin:/usr/local/bin:/usr/lib:/usr/local/lib:${bundlePath}/MacOS:$HOME:$PATH which $toolName | sed '/^[^\/]/d' | sed 's/\S//g'`
		
		if [ ! -z $toolPathTMP ]; then 
			toolPath=$toolPathTMP
		else
			appPathTMP=`find /Applications /usr/bin /usr/local/bin/ $HOME -maxdepth 1 -name "$toolName" | grep -m1 ""`
			if [[ ! -z "$appPathTMP" ]]; then
				toolPath="$appPathTMP"
			fi
		fi
	fi
	echo "$toolPath"
}

checkDiskSpace () 
{
	theSource="$1"
	theDestination="$2"
	sourceSize=$(du -c "$theSource" | grep "total" | sed -e 's|^ *||g' -e 's|	total||g')
	freeSpace=$(df "$theDestination" | grep "/" | awk -F\  '{print $4}')
	if [[ $sourceSize -gt $freeSpace ]]; then
		return 1
	else
		return 0
	fi
}

processVariables () 
{
	deviceName=`diskutil info "$1" | grep "Device / Media Name:" | sed 's|.* ||'`
	discType=`grep "$1" < $tmpFolder/currentItems.txt | awk -F: '{print $3}'`
	#discType=`diskutil info "$1" | grep "Optical Media Type" | sed 's|.*: *||'`
	discName=`diskutil info "$1" | grep "Volume Name:" | sed 's|.*: *||'`
	#deviceNum=`echo "$deviceList" | grep "$deviceName" | awk -F: '{print $1-1}'`
	if [ "$discType" = "DVD-ROM" ]; then
			thisDisc=`echo "$1" | tr ' ' '\007' | tr '\000' ' '`
			dvdList="$dvdList $thisDisc"
			dvdList=`echo "$dvdList" | sed 's|^ ||'`
	fi
	if [ "$discType" = "BD-ROM" ]; then
			thisDisc=`echo "$1" | tr ' ' '\007' | tr '\000' ' '`
			bdList="$bdList $thisDisc"
			bdList=`echo "$bdList" | sed 's|^ ||'`
	fi	
}

processDiscs () 
{
	sourcePath="$1"
	deviceName=`diskutil info "$1" | grep "Device / Media Name:" | sed 's|.* ||'`
	discType=`grep "$1" < $tmpFolder/currentItems.txt | awk -F: '{print $3}'`
	#discType=`diskutil info "$1" | grep "Optical Media Type" | sed 's|.*: *||'`
	discName=`diskutil info "$1" | grep "Volume Name:" | sed 's|.*: *||'`
	sourceName=`diskutil info "$1" | grep "Volume Name:" | sed 's|.*: *||'`	
	deviceID=`diskutil info "$1" | grep "Device Identifier:" | sed 's|.* ||'`
	deviceNum=`"$makemkvconPath" -r --directio=false info disc:list | egrep "DRV\:.*$deviceID" | sed -e 's|DRV:||' -e 's|,.*||'`
	#deviceNum=`"$makemkvconPath" -r --directio=false info disc:list | egrep "DRV\:.*$deviceName.*$deviceID" | sed -e 's|DRV:||' -e 's|,.*||'`
	#deviceNum=`echo "$deviceList" | grep "$deviceName" | awk -F: '{print $1-1}'`
	userVideoKind=`grep "$1" < $tmpFolder/currentItems.txt | awk -F: '{print $2}'`
	userDiscName=`grep "$1" < $tmpFolder/currentItems.txt | awk -F: '{print $4}'`
	discCount=`echo "$dvdList" | grep -c ""`
	if [ ! -z "$userVideoKind" ]; then
		videoKind="$userVideoKind"
	fi
	if [ "$videoKind" = "Movie" ]; then
		outputDir="$movieOutputDir"
	elif [ "$videoKind" = "TV Show" ]; then
		outputDir="$tvOutputDir"
	fi
	
	if [[ -d "/Volumes/${sourceName}/VIDEO_TS" && ! onlyMakeMKV -eq 1 ]]; then

		# set disc name to user's disc name
		if [ ! -z "$userDiscName" ]; then
			discName="$userDiscName"
		else
			# get name from discIdent
			getNameFromDiscIdent=$(discIdentQuery "$sourcePath")
			if [ ! -z "$getNameFromDiscIdent" ]; then
				discName="$getNameFromDiscIdent"
			fi
		fi

		# copy DVDs with Fairmount
		echo ""
		echo "*Processing ${discType}: $sourceName "
		if [[ -d "$outputDir"/"$discName" && skipDuplicates -eq 0 ]]; then
			echo "  WARNING: $discName already exists in output directory…"
			discName="${discName}-${scriptPID}"
			echo "  Will RENAME this copy: ${discName}"
		fi
		
		if [[ ! -d "$outputDir"/"$discName" || skipDuplicates -eq 0 ]]; then
		# get Fairmount PID
		#PID=`ps uxc | grep -i "Fairmount" | awk '{print $2}'`

		# launch Fairmount
		#if [ -z "$PID" ]; then
		#	open "$fairmountPath"
		#	echo "  Waiting $copyDelay seconds for Fairmount to launch…"
		#	sleep "$copyDelay"
		#fi
		
			ditto --noacl -v "$sourcePath" "$outputDir"/"$discName"
			if [ $? -gt 0 ]; then
				echo "  ERROR: $sourceName failed during copying"
				# set color label of disc folder to red
				setLabelColor "$outputDir"/"$discName" "2" &
			else
				chmod -R 755 "$outputDir"/"$discName"
				setFinderComment "$outputDir"/"$discName" "$videoKind"
				# set color label of disc folder to yellow
				setLabelColor "$outputDir"/"$discName" "3" &
				echo -e "$discName\nFinished:" `date "+%l:%M %p"` "\n" >> ${tmpFolder}/growlMessageRIP.txt &
			fi
		else
			echo -e "$discName\nSkipped because it already exists\n" >> $tmpFolder/growlMessageRIP.txt &
			echo "  Skipped because folder already exists"
			echo "  Note: Rename existing folder if this is a new disc with the same name"
		fi
	fi	

	if [[ "$discType" = "BD-ROM" || onlyMakeMKV -eq 1  ]]; then
		
		if [ ! "$discType" = "BD-ROM" ]; then
			# set disc name to user's disc name
			if [ ! -z "$userDiscName" ]; then
				discName="$userDiscName"
			else
				# get name from discIdent
				getNameFromDiscIdent=$(discIdentQuery "$sourcePath")
				if [ ! -z "$getNameFromDiscIdent" ]; then
					discName="$getNameFromDiscIdent"
				fi
			fi
		else
			# set disc name to user's disc name
			if [ ! -z "$userDiscName" ]; then
				discName="$userDiscName"
			fi
		fi
		
		if [[ fullBdBackup -eq 0 || "$discType" = "DVD-ROM" && fullBdBackup -eq 1 ]]; then
			# make an MKV for each title of a BD, or DVD with makeMKV (if onlyMakeMKV is set to 1)
			echo -e "\n*Processing ${discType}: $sourceName "

			# set the min/max track time based on video kind
			if [ "$videoKind" = "TV Show" ]; then
				minTrackTime="$minTrackTimeTV"
				maxTrackTime="$maxTrackTimeTV"
			elif [ "$videoKind" = "Movie" ]; then
				minTrackTime="$minTrackTimeMovie"
				maxTrackTime="$maxTrackTimeMovie"
			fi
			
			# set the minTrackTime in seconds for makemkv
			minTimeSecs=$[$minTrackTime*60]
			
			# Set scan command and track info
			if [[ $debugScript -eq 1 ]]; then
				echo "  DEBUG: SCAN INFO COMMAND"
				"$makemkvconPath" -r --directio=false --minlength=$minTimeSecs info disc:$deviceNum | tee "${tmpFolder}/${deviceNum}_titleDebug.txt"
				cat "${tmpFolder}/${deviceNum}_titleDebug.txt" > "${tmpFolder}/${deviceNum}_titleInfo.txt"
			else
				"$makemkvconPath" -r --directio=false --minlength=$minTimeSecs info disc:$deviceNum > "${tmpFolder}/${deviceNum}_titleInfo.txt"
			fi			
			trackInfo=`cat "${tmpFolder}/${deviceNum}_titleInfo.txt" | egrep 'TINFO\:[0-9]{1,2},9,0'`
			
			# get the track number of tracks which are within the time desired
			trackFetchList=`getTrackListMakeMKV $minTrackTime $maxTrackTime "$trackInfo"`
			if [[ $verboseLog -eq 1 ]]; then
				cat "${tmpFolder}/${deviceNum}_titleInfo.txt"
				echo ""
			fi
			printTrackFetchList "$trackFetchList"

			# process each track in the track list
			for aTrack in $trackFetchList
			do
				# set the output file name based on video kind
				if [ "$videoKind" = "TV Show" ]; then
					outFile="${outputDir}/${discName}-${aTrack}.mkv"
				elif [ "$videoKind" = "Movie" ]; then
					outFile="${outputDir}/${discName}.mkv"
				fi
				outFileName=`basename "$outFile"`
				if [ ! -e "$outFile" ]; then
					# create tmp folder for source
					discNameALNUM=`echo "$discName" | sed 's/[^[:alnum:]^-^_]//g'`
					sourceTmpFolder="${tmpFolder}/${discNameALNUM}"
					if [ ! -e "$sourceTmpFolder" ]; then
						mkdir "$sourceTmpFolder"
					fi
					# makes an mkv file from the HD source
					makeMKV &
					if [ $? -gt 0 ]; then
						echo "  ERROR: $sourceName failed during copying"
						# set color label of output file to red
						setLabelColor "$outFile" "2" &
					fi
					wait
					setFinderComment "$outFile" "$videoKind"
					# set color label of output file to yellow
					setLabelColor "$outFile" "3" &
					echo -e "${outFileName}\nFinished:" `date "+%l:%M %p"` "\n" >> $tmpFolder/growlMessageRIP.txt &
				else
					echo ""
					echo "  ${outFileName} Skipped because file already exists"
					echo "  Note: Rename existing file if this is a new disc with the same name"
				fi
			done
		else
			if [ ! -e "${outputDir}/${discName}" ]; then
				mkdir "${outputDir}/${discName}"
				makeMKV &
				if [ $? -gt 0 ]; then
					echo "  ERROR: $sourceName failed during copying"
					# set color label of disc folder to red
					setLabelColor "${outputDir}/${discName}" "2" &
				fi
				wait
				setFinderComment "${outputDir}/${discName}" "$videoKind"
				# set color label of disc folder to yellow
				setLabelColor "${outputDir}/${discName}" "3" &
				echo -e "${discName}\nFinished:" `date "+%l:%M %p"` "\n" >> $tmpFolder/growlMessageRIP.txt &
			else
				echo "  ${discName} Skipped because it already exists"
				echo "  Note: Rename existing file if this is a new disc with the same name"
			fi
		fi		
		echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"		
	fi
}

discIdentQuery () 
{
	getFolderContents=`ls "${1}/VIDEO_TS"`

	for theDiscItem in $getFolderContents
	do
		filePath=`echo "$theDiscItem" | sed "s|^|${1}/VIDEO_TS/|"`
		fileString=`mdls -name kMDItemFSSize -raw "$filePath" | sed "s|^|/VIDEO_TS/${theDiscItem}:|"`
		theString="$theString:$fileString"
	done

	# get hash code
	generateHash=$(md5 -s "$theString" 2> /dev/null | sed -e 's|.*= ||' -e 's|^\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)|\1-\2-\3-\4-|' | tr 'a-z' 'A-Z')

	# DiscIdent Fingerprint Query
	fingerprintQuery=`curl -Ls --compressed "http://discident.com/v1/$generateHash/"`
	discGnid=`echo "$fingerprintQuery" | sed -e 's|.*gtin": \"||' -e 's|".*||'`

	# DiscIdent GTIN Query
	gnidQuery=`curl -Ls --compressed "http://discident.com/v1/$discGnid/"`

	discName=`echo "$fingerprintQuery" | sed -e 's|.*title": "||' -e 's|".*||'`
	if [ ! -z "$discName" ]; then
		discYear=`echo "$gnidQuery" | sed -e 's|.*productionYear": ||' -e 's|[^0-9*].*||'`
		if [ ! -z "$discYear" ]; then
			discName="$discName ($discYear)"
		fi
	fi

	echo "$discName"
}

getTrackListMakeMKV() # Gets the only the tracks with in the min/max duration
{
	#	Three input arguments are are needed. 
	#	arg1 is the minimum time in minutes selector
	#	arg2 is the maximum time in minutes selector
	#	arg3 is the raw text stream from the info call to makemkvcon
	#	returns: a list of track numbers of tracks within the selectors
	
	if [ $# -lt 2 ]; then
		return ""
	fi

	minTime="$1"
	maxTime="$2"
	shift
	allTrackText="$*"
	aReturn=""
	duplicateList=""
	#minTimeSecs=$[$minTime*60]

	#	parse track info for BD optical disc
	#   gets a list of tracks added by makemkv
	trackList=`eval "echo \"$allTrackText\""`
	trackNumber=""
	for aline in $trackList
	do
		trackNumber=`echo $aline | sed 's|TINFO:||' | sed 's|,.*||'`
		set -- `echo $aline | sed -e 's|.*,||g' -e 's|"||g' -e 's/:/ /g'`
		if [[ $((10#$3)) -gt 29 ]];
			then let trackTime=(10#$1*60)+10#$2+1
		else let trackTime=(10#$1*60)+10#$2
		fi
		if [[ $trackTime -gt $minTime && $trackTime -lt $maxTime ]];
			then titleList="$titleList $trackNumber"
		fi
		if [ "$videoKind" = "Movie" ]; then
			aReturn=`echo "$titleList" | awk -F\  '{print $1}'`
		elif [ "$videoKind" = "TV Show" ]; then
			aReturn="$titleList"
		fi
	done
	echo "$aReturn"
}

getTrackListAllTracks() # Creates a list of all tracks and duration
{
	allTrackText="$*"
	#returnTitles=""
	getTrackList=""
	trackTime=""
	#	parse track info for BD optical disc and folder input
	#	gets a list of tracks added by makemkv
	getTrackList=`eval "echo \"$allTrackText\""`
	trackNumber=""
	for aline in $getTrackList
	do
		trackNumber=`echo $aline | sed 's|TINFO:||' | sed 's|,.*||'`
		set -- `echo $aline | sed -e 's|.*,||g' -e 's|"||g' -e 's/:/ /g'`
		if [[ $((10#$3)) -gt 29 ]];
			then let trackTime=(10#$1*60)+10#$2+1
		else let trackTime=(10#$1*60)+10#$2
		fi
		if [[ $trackTime -gt 1 ]]; then
			returnTitles="$returnTitles - Track ${trackNumber} Duration: $trackTime min.|"
		fi
	done
	echo "$returnTitles" | tr '|' '\n' | sed 's|^|   |g'
}

printTrackFetchList() # Prints the tracks to extract for each source
{
	if [ ! -z "$1" ]; then
		echo "  Will copy the following tracks: `echo $1 | sed 's/ /, /g'` "
	else
		trackInfoTest=$(cat "${tmpFolder}/${deviceNum}_titleInfo.txt")
		if [[ ! -z "$trackInfoTest" ]]; then
			if [ "$videoKind" = "Movie" ]; 
				then minTime="$minTrackTimeMovie" && maxTime="$maxTrackTimeMovie"
				else minTime="$minTrackTimeTV" && maxTime="$maxTrackTimeTV"
			fi
			echo "  No tracks found between ${minTime}-${maxTime} minutes ($videoKind)."
			getTrackListAllTracks "$trackInfo"
		else
			# Check for MakeMKV Trial Expired & Failed Disc
			checkMakeMkvTrial=$("$makemkvconPath" --directio=false info disc:$deviceNum | egrep -i '(evaluation|failed)' | tr '\n' ' ')
			if [ ! -z "$checkMakeMkvTrial" ]; then
				echo -e "  ERROR MakeMKV: \c"
				echo "$checkMakeMkvTrial"
			else
				echo "  ERROR: No tracks found or failed to scan source."
				echo "  Check disc, application, and settings in Automator."
			fi			
		fi
		# set color label of disc folder to red
		setLabelColor "$folderPath" "2" > /dev/null
	fi
	echo ""
}

isPIDRunning() # Checks on the status of background processes
{
	aResult=0

	if [ $# -gt 0 ]; then
		txtResult="`ps ax | egrep \"^[ \t]*$1\" | sed -e 's/.*/1/'`"
		if [ -z "$txtResult" ];
			then aResult=0
		else aResult=1
		fi
	fi

	echo $aResult
}

makeMKV() # Makes an mkv from a title using a disc as source. Extracts main audio/video, no subs.
{
	aTrackTwoDigits=$(printf "%02d" $aTrack)
	#tmpFile="${outputDir}/title${aTrackTwoDigits}.mkv"
	tmpFileName=`cat "${tmpFolder}/${deviceNum}_titleInfo.txt" | egrep "TINFO\:${aTrack},27,0" | sed -e "s|TINFO:${aTrack},27,0,||g" -e 's|"||g'`
	tmpFile="${outputDir}/${tmpFileName}"
	# uses makeMKV to create mkv file from selected track
	# makemkvcon includes all languages and subs, no way to exclude unwanted items
	if [[ verboseLog -eq 0 ]]; then
		if [[ fullBdBackup -eq 0 || "$discType" = "DVD-ROM" && fullBdBackup -eq 1 ]]; then
			echo "*Creating ${outFileName} from Track: ${aTrack}"
			progressFile="${sourceTmpFolder}/${aTrack}-makemkv.txt"
			cmd="\"$makemkvconPath\" mkv --minlength=$minTimeSecs --messages=-null --progress=\"$progressFile\" disc:$deviceNum $aTrack \"$outputDir\" > /dev/null 2>&1"
		else
			echo "*Copying: ${discName}"
			progressFile="${outputDir}/${discName}/${discName}-makemkv.txt"
			cmd="\"$makemkvconPath\" backup --decrypt --messages=-null --progress=\"$progressFile\" disc:$deviceNum \"${outputDir}/${discName}\" > /dev/null 2>&1"
		fi
		eval $cmd &
		cmdPID=$!
		while [ `isPIDRunning $cmdPID` -eq 1 ]; do
			if [[ -e "$progressFile" ]]; then
				cmdStatusTxt="`tail -n 1 \"$progressFile\" | grep 'Total progress' | sed 's|.*Total progress|  Progress|'`"
				echo "$cmdStatusTxt"
				printf "\e[1A"
			else
				echo ""
				printf "\e[1A"
			fi
			sleep 0.5s
		done
		echo ""
		wait $cmdPID
	elif [[ verboseLog -eq 1 ]]; then
		if [[ fullBdBackup -eq 0 || "$discType" = "DVD-ROM" && fullBdBackup -eq 1 ]]; then
			echo "*Creating ${outFile} from Track: ${aTrack}"
			progressFile="${sourceTmpFolder}/${aTrack}-makemkv.txt"
			cmd="\"$makemkvconPath\" mkv --minlength=$minTimeSecs --progress=-same disc:$deviceNum $aTrack \"$outputDir\""
		else
			echo "*Copying: ${discName}"
			progressFile="${outputDir}/${discName}/${discName}-makemkv.txt"
			cmd="\"$makemkvconPath\" backup --decrypt --progress=\-same disc:$deviceNum \"${outputDir}/${discName}\""
		fi
		eval $cmd
	fi
	if [[ -e "$tmpFile" && ! -e "$outFile" ]]; then
		mv "$tmpFile" "$outFile"
	fi
}

setFinderComment() # Sets the output file's Spotlight Comment to TV Show or Movie
{
	osascript -e "try" -e "set theFile to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set comment of theFile to \"$2\"" -e "end try" > /dev/null
}

setLabelColor() # Sets the source folder color
{
	osascript -e "try" -e "set theFolder to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set label index of theFolder to $2" -e "end try" > /dev/null
}

get_log () 
{
	cat << EOF | osascript -l AppleScript
	tell application "Terminal"
		set theText to history of tab 1 of window 1
		return theText
	end tell
EOF
}

displayNotification () {
cat << EOF | osascript -l AppleScript
    try
        display notification "$3" with title "$1" subtitle "$2"
        delay 1
    end try
EOF
}
ejectDisc() # Ejects the discs
{
	if [[ ejectDisc -eq 1 && -d "$1" ]]; then
		diskutil eject "$1"
	fi
}

#############################################################################
# Main Script

# initialization functions

# get window id of Terminal session and change settings set to Pro
windowID=$(osascript -e 'try' -e 'tell application "Terminal" to set Window_Id to id of first window as string' -e 'end try')
osascript -e 'try' -e "tell application \"Terminal\" to set current settings of window id $windowID to settings set named \"Pro\"" -e 'end try'

# process args passed from main.command
parseVariablesInArgs $*

# create tmp folder for script
tmpFolder="/tmp/batchRip_${scriptPID}"
if [ ! -e "$tmpFolder" ]; then
	mkdir "$tmpFolder"
fi

# copy current items list
if [ -e "$currentItemsList" ]; then
	grep -v "Ignore" "$currentItemsList" > $tmpFolder/currentItems.txt
fi

# perform sanity check and display errors
sanityCheck

# create a list of mounted BDs/DVDs in optical drives (up to 3)
discSearch=`cat $tmpFolder/currentItems.txt | awk -F: '{print $1}' | tr ' ' '\007' | tr '\000' ' '`
# get device name of optical drives. Need to sort by device name to get disc:<num> for makeMKV 
deviceList=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -n "" `

# display the basic setup information
echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo -e "$scriptName v$scriptVers\n"
echo "  Start: `date`"
echo "  TV Show Output directory: $tvOutputDir"
echo "  Movie Output directory: $movieOutputDir"
echo "  Use only MakeMKV: $onlyMakeMKVStatus"
echo "  Encode HD Sources: $encodeHdStatus"
echo "  Full BD Backup: $backupBdStatus"
echo "  Growl me when complete: $growlMeStatus"
echo "  Eject discs when complete: $ejectDiscStatus"
echo "  Skip disc if not decrypted in: $copyDelay seconds"
echo "  Copy TV Shows between: ${minTrackTimeTV}-${maxTrackTimeTV} mins (for MakeMKV)"
echo "  Copy Movies between: ${minTrackTimeMovie}-${maxTrackTimeMovie} mins (for MakeMKV)"
if [[ verboseLog -eq 1 ]]; then
	echo -e "\n  - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	echo "  VERBOSE MODE"
	echo "  - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
fi
echo ""

if [ ! -z "$discSearch" ]; then

	# display the list of discs found
	echo "  WILL COPY THE FOLLOWING DISCS:"
	for eachdisc in $discSearch
	do
		eachdisc=`echo "$eachdisc" | tr '\007' ' '`
		processVariables "$eachdisc"
		thisVideoKind=`grep "$eachdisc" < $tmpFolder/currentItems.txt | awk -F: '{print $2}'`
		echo "    $discName ($discType : $thisVideoKind)"
	done
	echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"

	# begin encode log for growlNotify
	echo "BATCH RIP SUMMARY" > ${tmpFolder}/growlMessageRIP.txt
	echo -e "Started:" `date "+%l:%M %p"` "\n" >> ${tmpFolder}/growlMessageRIP.txt
	
	# process each DVD video found
	if [[ encodeDvdSources -eq 1 ]]; then
		for eachdvd in $dvdList
		do
			eachdvd=`echo "$eachdvd" | tr '\007' ' '`
			# DISABLED-check disk space
			#getVideoKind=`grep "$eachdvd" < $tmpFolder/currentItems.txt | awk -F: '{print $2}'`
			#if [ "$videoKind" = "Movie" ]; then
				#destVolume="$movieOutputDir"
			#elif [ "$videoKind" = "TV Show" ]; then
				#destVolume="$tvOutputDir"
			#fi
			#checkDiskSpace "$eachdvd" "$destVolume"
			#if [[ $? -eq 1 ]]; then
				#echo -e "\n  WARNING: $eachdvd SKIPPED because hard drive is full."
				#echo "  Will try to continue with next disc…"
				#echo -e "$eachdvd\nSkipped because hard drive is full.\n" >> "${tmpFolder}/growlMessageRIP.txt"
				#continue
			#fi

			if [[ onlyMakeMKV -eq 0 ]]; then
				# get Fairmount PID
				PID=`ps uxc | grep -i "Fairmount" | awk '{print $2}'`

				# launch Fairmount
				if [ -z "$PID" ]; then
					open "$fairmountPath"
				#	echo "  Waiting $copyDelay seconds for Fairmount to launch…"
				#	sleep "$copyDelay"
				fi
				while [[ `hdiutil info | grep "$eachdvd"` = "" ]]; do
					sleep 1s
					loop=$((loop + 1))
					if [[ $loop -gt $copyDelay ]]; then
						break 1
					fi
				done
				if hdiutil info | grep "$sourcePath" > /dev/null; then
					processDiscs "$eachdvd" &
				else
					echo "ERROR: Fairmount STALLED while reading $eachdvd"
					echo "  Skipping $eachdvd"
				fi
			else
				processDiscs "$eachdvd" &
				wait
			fi
			if [[ onlyMakeMKV -eq 0 ]]; then
				loop=0
				dittoPID=`ps uxc | grep -i "Ditto" | awk '{print $2}'`
				while [ `isPIDRunning $dittoPID` -eq 0 ]; do
					sleep 1s
					dittoPID=`ps uxc | grep -i "Ditto" | awk '{print $2}'`
					loop=$((loop + 1))
					if [[ $loop -gt 120 ]]; then
						break 1
					fi
				done
			fi
		done
		if [[ onlyMakeMKV -eq 0 ]]; then
			fairMountPID=`ps uxc | grep -i "Fairmount" | awk '{print $2}'`
			while [ `isPIDRunning $dittoPID` -eq 1 ]; do
				sleep 1s
				dittoPID=`ps uxc | grep -i "Ditto" | awk '{print $2}'`
			done
			if [[ -z "$dittoPID" && ! -z "$fairMountPID" ]]; then
				# quit Fairmount
				kill $fairMountPID
				echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
			fi
		fi
	fi
	
	# process each BD video found
	if [[ encodeHdSources -eq 1 ]]; then	
		for eachbd in $bdList
		do
			eachbd=`echo "$eachbd" | tr '\007' ' '`
			# check disk space
			getVideoKind=`grep "$eachbd" < $tmpFolder/currentItems.txt | awk -F: '{print $2}'`
			if [ "$videoKind" = "Movie" ]; then
				destVolume="$movieOutputDir"
			elif [ "$videoKind" = "TV Show" ]; then
				destVolume="$tvOutputDir"
			fi
			checkDiskSpace "$eachbd" "$destVolume"
			if [[ $? -eq 1 ]]; then
				echo -e "\n  WARNING: $eachbd SKIPPED because hard drive is full."
				echo "  Will try to continue with next disc…"
				echo -e "${eachbd}\nSkipped because hard drive is full.\n" >> "${tmpFolder}/growlMessageRIP.txt"
				continue
			fi
			processDiscs "$eachbd"
		done
		#wait
	fi
		
	# display: processing complete
	echo ""
	echo -e "\nPROCESSING COMPLETE"

	########  GROWL NOTIFICATION  ########
	echo "-- End summary for $scriptName" >> ${tmpFolder}/growlMessageRIP.txt
	if [[ growlMe -eq 1 ]]; then
		#open -a GrowlHelperApp && sleep 5
		growlMessage=$(cat ${tmpFolder}/growlMessageRIP.txt)
		growlnotify "Batch Rip" -m "$growlMessage" && sleep 5
	fi

    # Display script completed notification
    displayNotification "Batch Rip Actions for Automator" "Batch Rip" "Processing complete."

else
	echo "  ERROR: No discs found"
	echo "  Check optical drive, discs and settings"
	exit $E_BADARGS
fi

# delete script temp files
if [ -e "$tmpFolder" ]; then
	rm -rf $tmpFolder
fi

# delete current items textfile
if [ -e "$currentItemsList" ]; then
	rm -f "$currentItemsList"
fi

# delete bash script tmp file
if [ -e "$scriptTmpPath" ]; then
	rm -f "$scriptTmpPath"
fi

# if ejectDisc is set to 1, ejects the discs
for eachdisc in $discSearch
do
	sleep 3
	ejectDisc "$eachdisc"
done

echo "End: `date`"
echo -e "- - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n"

if [[ saveLog -eq 1 ]]; then
	theLog=`get_log`
	test -d "$HOME/Library/Logs/BatchRipActions" || mkdir "$HOME/Library/Logs/BatchRipActions"
	echo "$theLog" >> "$HOME/Library/Logs/BatchRipActions/BatchRip.log"
fi

exit 0
