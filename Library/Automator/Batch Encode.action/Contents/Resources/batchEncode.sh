# !/bin/sh

# changelog v1.1.1 (280)
# 1-20131109-0 - updated for tmdb api v3
# 2-20131111-0 - removed mkvtoolnix and bdsub2sub, hb's got it handled
# 3-20131120-0 - added MakeMKV from VideoTS option

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


#########################################################################################
# globals

######### CONST GLOBAL VARIABLES #########
scriptName=`basename "$0"`
scriptVers="1.1.1 (280)"
scriptPID=$$
E_BADARGS=65
bundlePath=`dirname "$0" | sed 's|Contents.*|Contents|'`
scriptTmpPath="$HOME/Library/Application Support/Batch Rip/batchEncodeTmp.sh"

######### DEBUG #########
#set -xv

######### USER DEFINED VARIABLES #########

# SET INPUT/OUTPUT PATHS
movieSearchDir="$HOME/Movies/Batch Rip Movies" # set the movie search directory
tvSearchDir="$HOME/Movies/Batch Rip TV"		   # set the tv show search directory
outputDir="$HOME/Movies/Batch Encode"		   # set the output directory
cnidFile="$HOME/Library/Application Support/Batch Rip/cnID.txt"

# SET DEFAULT TOOL PATHS
handBrakeCliPath="/Applications/HandBrakeCLI"
libdvdcssPath="/usr/lib/libdvdcss.2.dylib"
makemkvconPath="/Applications/MakeMKV.app/Contents/MacOS/makemkvcon" # path to makemkvcon
makemkvPath="/Applications/MakeMKV.app" 				# path to MakeMKV.app
mp4infoPath="${bundlePath}/MacOS/mp4info"				# path to mp4info
mp4tagsPath="${bundlePath}/MacOS/mp4tags"				# path to mp4tags
mp4artPath="${bundlePath}/MacOS/mp4art"					# path to mp4art
mp4chapsPath="${bundlePath}/MacOS/mp4chaps"				# path to mp4chaps
sublerCliPath="${bundlePath}/MacOS/SublerCLI"			# path to SublerCLI
xpathPath="/usr/bin/xpath"								# path to xpath
xmllintPath="/usr/bin/xmllint"							# path to xmllint
atomicParsleyPath="${bundlePath}/MacOS/AtomicParsley"	# path to AtomicParsley
growlNotifyPath="/usr/local/bin/growlnotify"			# path to growlNofify
jqToolPath="${bundlePath}/MacOS/jq"

# SET PREFERRED AUDIO LANGUAGE
nativeLanguage="eng" # set as an iso639-2 code: eng, spa, fra, etc.
alternateLanguage="" # set as an iso639-2 code: eng, spa, fra, etc.
useDefaultAudioTrack="Default Audio"
addAdditionalAudioTracks="None"
useBurnedSubtitleTrack="Auto Detect"
usePassthruSubtitleTracks="None"
mixdownAltTracks="1"

# SET MIN AND MAX TRACK TIME
minTrackTimeTV="20"	    # this is in minutes
maxTrackTimeTV="120"	# this is in minutes
minTrackTimeMovie="80"	# this is in minutes
maxTrackTimeMovie="180"	# this is in minutes

######### SWITCHES & OVERRIDES (TRUE=1/FALSE=0) #########
# SET ENCODE TYPE TO OUTPUT
encode_1="1"		# if set to 1, this type of file will output
encode_2="0"		# if set to 1, this type of file will output
encode_3="0"		# if set to 0, this type of file will not output
encode_4="0"		# if set to 1, this type of file will output

# USE PRESET TOOL ARGS
preset1="Universal"     	# if set to 1, HB will use the custom settings for the source
preset2="Apple TV 2"   		# if set to 1, HB will use the custom settings for the source
preset3="Universal"      	# if set to 1, HB will use the custom settings for the source
preset4="Apple TV 2"    	# if set to 1, HB will use the custom settings for the source

# CUSTOM TOOL ARGS
customArgs1="noarrgs"		# set custom args
customArgs2="noarrgs"		# set custom args
customArgs3="noarrgs"		# set custom args
customArgs4="noarrgs"		# set custom args

# OVERRIDE SCRIPT DEFAULT SETTINGS. (Not recommended for the less advanced)
makeMKV="0"					# if set to 1, will process BDMV and VIDEO_TS sources using makeMKV
skipDuplicates="1"			# if set to 0, the new output files will overwrite existing files
ignoreOptical="1"			# if set to 0, will attempt to use any mounted optical disc as a source
growlMe="0"                 # if set to 1, will use growlNotify to send encode message
videoKindOverride="Movie"   # set to TV Show or Movie for missing variable using disc input
makeFoldersForMe="0"		# if set to 1, will create input & output folders if they don't exist
verboseLog="0"			    # increases verbosity and saves to ~/Library/Logs/BatchRipActions

######### OPTIONAL #########
# SWITCH ON AUTO-TAGGING
# if set to 1, will automatically generate and tag mp4 files using themoviedb.org api
addiTunesTags="0"
curlCmd=$(echo "curl -Ls --compressed --connect-timeout 30 --max-time 60 --retry 1")
tmdbApiKey="8d7d0edf7ec73435ea5d99d9cba9b54d"

# IF A MOVIE WITH THE SAME FILENAME ALREADY EXISTS IN YOUR LIBRARY, MOVE THE OLD FILE TO ANOTHER FOLDER
# use if you are re-encoding/replacing existing titles, ie: replacing SD files with HD files
retireExistingFile="0" 		# if set to 1, will move old file to a retired movie folder
libraryFolder="$HOME/Movies/Library" 	# path to your movie library folder
retiredFolder="$HOME/Movies/Retired"	# path to your retired movies folder

#########################################################################################
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
			( --movieSearchDir ) movieSearchDir=$2
			shift ;;
			( --tvSearchDir ) tvSearchDir=$2
			shift ;;
			( --outputDir ) outputDir=$2
			shift ;;
			( --handBrakeCliPath ) handBrakeCliPath=$2
			shift ;;
			( --makemkvPath ) makemkvPath=$2
			shift ;;
			( --minTrackTimeTV ) minTrackTimeTV=$2
			shift ;;
			( --maxTrackTimeTV ) maxTrackTimeTV=$2
			shift ;;
			( --minTrackTimeMovie ) minTrackTimeMovie=$2
			shift ;;
			( --maxTrackTimeMovie ) maxTrackTimeMovie=$2
			shift ;;
			( --nativeLanguage ) nativeLanguage=$2
			shift ;;
			( --alternateLanguage ) alternateLanguage=$2
			shift ;;
			( --useDefaultAudioTrack ) useDefaultAudioTrack=$2
			shift ;;
			( --addAdditionalAudioTracks ) addAdditionalAudioTracks=$2
			shift ;;
			( --useBurnedSubtitleTrack ) useBurnedSubtitleTrack=$2
			shift ;;
			( --usePassthruSubtitleTracks ) usePassthruSubtitleTracks=$2
			shift ;;
			( --mixdownAltTracks ) mixdownAltTracks=$2
			shift ;;
			( --encode_1 ) encode_1=$2
			shift ;;
			( --encode_2 ) encode_2=$2
			shift ;;
			( --encode_3 ) encode_3=$2
			shift ;;
			( --encode_4 ) encode_4=$2
			shift ;;
			( --ignoreOptical ) ignoreOptical=$2
			shift ;;
			( --growlMe ) growlMe=$2
			shift ;;
			( --videoKindOverride ) videoKindOverride=$2
			shift ;;
			( --addiTunesTags ) addiTunesTags=$2
			shift ;;
			( --retireExistingFile ) retireExistingFile=$2
			shift ;;
			( --libraryFolder ) libraryFolder=$2
			shift ;;
			( --retiredFolder ) retiredFolder=$2
			shift ;;
			( --customArgs1 ) customArgs1=$2
			shift ;;
			( --customArgs2 ) customArgs2=$2
			shift ;;
			( --customArgs3 ) customArgs3=$2
			shift ;;
			( --customArgs4 ) customArgs4=$2
			shift ;;
			( --preset1 ) preset1=$2
			shift ;;
			( --preset2 ) preset2=$2
			shift ;;
			( --preset3 ) preset3=$2
			shift ;;
			( --preset4 ) preset4=$2
			shift ;;
			( * ) echo "Args not recognized" ;;
		esac
		shift
	done

	# fix spaces in paths & custom tool args
	movieSearchDir=`echo "$movieSearchDir" | tr ':' ' '`
	tvSearchDir=`echo "$tvSearchDir" | tr ':' ' '`
	outputDir=`echo "$outputDir" | tr ':' ' '`
	handBrakeCliPath=`echo "$handBrakeCliPath" | tr ':' ' '`
	makemkvconPath=`echo "$makemkvPath" | tr ':' ' ' | sed 's|$|/Contents/MacOS/makemkvcon|'`
	videoKindOverride=`echo "$videoKindOverride" | tr ':' ' '`
	libraryFolder=`echo "$libraryFolder" | tr ':' ' '`
	retiredFolder=`echo "$retiredFolder" | tr ':' ' '`
	useDefaultAudioTrack=`echo "$useDefaultAudioTrack" | tr '@' ' '`
	addAdditionalAudioTracks=`echo "$addAdditionalAudioTracks" | tr '@' ' '`
	useBurnedSubtitleTrack=`echo "$useBurnedSubtitleTrack" | tr '@' ' '`
	usePassthruSubtitleTracks=`echo "$usePassthruSubtitleTracks" | tr '@' ' '`
	customArgs1=`echo "$customArgs1" | tr '@' ' '`
	customArgs2=`echo "$customArgs2" | tr '@' ' '`
	customArgs3=`echo "$customArgs3" | tr '@' ' '`
	customArgs4=`echo "$customArgs4" | tr '@' ' '`
	preset1=`echo "$preset1" | tr '@' ' '`
	preset2=`echo "$preset2" | tr '@' ' '`
	preset3=`echo "$preset3" | tr '@' ' '`
	preset4=`echo "$preset4" | tr '@' ' '`
	
	# set makeMKV to 1 if preset1 is set to makeMKV
	if [[ "$preset1" = "MakeMKV" ]]; then
		makeMKV=1
	fi
}

makeFoldersForMe() # Creates input/output folders
{
	if [[ makeFoldersForMe -eq 1 ]]; then
		if [ ! -d "$tvSearchDir" ]; then
			mkdir "$tvSearchDir"
		fi
		if [ ! -d "$movieSearchDir" ]; then
			mkdir "$movieSearchDir"
		fi
		if [ ! -d "$outputDir" ]; then
			mkdir "$outputDir"
		fi
	fi
}

sanityCheck () # Checks that apps are installed and input/output paths exist
{
	toolList="$handBrakeCliPath:HandBrakeCLI|$mp4tagsPath:mp4tags|$libdvdcssPath:libdvdcss.2.dylib"

	if [[ "$addiTunesTags" -eq 1 ]]; then
		toolList="$toolList|$xpathPath:xpath|$xmllintPath:xmllint|$atomicParsleyPath:AtomicParsley|$sublerCliPath:SublerCLI|$jqToolPath:jq"
	fi
	if [[ $needMakeMKV -eq 1 ]]; then
		toolList="$toolList|$makemkvPath:MakeMKV.app"
	fi
	if [[ $growlMe -eq 1 ]]; then
		toolList="$toolList|$growlNotifyPath:growlnotify"
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
	if [[ ! -e "$movieSearchDir" ]]; then
		echo "    ERROR: $movieSearchDir could not be found"
		echo "    Check \$movieSearchDir to set your Batch Rip Movies folder"
		echo ""
		errorLog=1
	fi
	if [[ ! -e "$tvSearchDir" ]]; then
		echo "    ERROR: $tvSearchDir could not be found"
		echo "    Check \$tvSearchDir to set your Batch Rip TV folder"
		echo ""
		errorLog=1
	fi
	if [ ! -e "$outputDir" ]; then
		echo "    ERROR: $outputDir could not be found"
		echo "    Check \$outputDir to set your output folder"
		echo ""
		errorLog=1
	fi

	# exit if sanity check failed, else set tool paths
	if [[ errorLog -eq 1 ]]; then
		exit $E_BADARGS
	else
		handBrakeCliDir=`dirname "$handBrakeCliPath"`
		handBrakeCliPath=`verifyFindCLTool "$handBrakeCliDir" "HandBrakeCLI"`
		mp4tagsDir=`dirname "$mp4tagsPath"`
		mp4tagsPath=`verifyFindCLTool "$mp4tagsDir" "mp4tags"`
		libdvdcssDir=`dirname "$libdvdcssPath"`
		libdvdcssPath=`verifyFindCLTool "$libdvdcssDir" "libdvdcss.2.dylib"`

		if [[ "$addiTunesTags" -eq 1 ]]; then
			xpathDir=`dirname "$xpathPath"`
			xpathPath=`verifyFindCLTool "$xpathDir" "xpath"`
			xmllintDir=`dirname "$xmllintPath"`
			xmllintPath=`verifyFindCLTool "$xmllintDir" "xmllint"`
			jqToolDir=`dirname "$jqToolPath"`
			jqToolPath=`verifyFindCLTool "$jqToolDir" "jq"`
			
			atomicParsleyDir=`dirname "$atomicParsleyPath"`
			atomicParsleyPath=`verifyFindCLTool "$atomicParsleyDir" "AtomicParsley"`
			sublerCliDir=`dirname "$sublerCliPath"`
			sublerCliPath=`verifyFindCLTool "$sublerCliDir" "sublerCLI"`
		fi
		if [[ $needMakeMKV -eq 1 ]]; then
			makemkvDir=`dirname "$makemkvPath"`
			makemkvPath=`verifyFindCLTool "$makemkvDir" "MakeMKV.app"`
			makemkvconPath=`verifyFindCLTool "${makemkvPath}/Contents/MacOS" "makemkvcon"`
		fi
		if [[ $growlMe -eq 1 ]]; then
			growlnotifyDir=`dirname "$growlNotifyPath"`
			growlNotifyPath=`verifyFindCLTool "$growlnotifyDir" "growlnotify"`
		fi
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
			appPathTMP=`find /Applications /usr/bin /usr/local/bin /usr/lib /usr/local/lib "${bundlePath}/MacOS" $HOME -maxdepth 1 -name "$toolName" | grep -m1 ""`
			if [[ ! -z "$appPathTMP" ]]; then
				toolPath="$appPathTMP"
			fi
		fi
	fi
	echo "$toolPath"
}

parseSourceFromInput() # Searches input from Automator for valid sources to endode
{
	for eachSource in $1
	do
		# fix spaces in paths & custom tool args
		eachSource=`echo "$eachSource" | tr ':' ' '`
		# searches for BDMV and VIDEO_TS folders
		if [[ -d "$eachSource" ]]; then
			findSource=`find "$eachSource" \( -maxdepth 1 -type d -name BDMV -o -type d -name VIDEO_TS \) | tr ' ' '\007' | tr '\000' ' '`
			if [[ -z "$findSource" ]]; then
				eachSourceBasename=`basename "$eachSource"`
				echo ""
				echo "  ERROR: No BDMV or VIDEO_TS folder found in: ${eachSourceBasename}/"
				echo "  • Selection must be the first parent item of a BDMV or VIDEO_TS folder."
				echo "    Example:"
				echo "      Batch Rip Movies"
				echo "        My Movie (2013) <--- SELECTION"
				echo "          VIDEO_TS"
				echo ""
				exit $E_BADARGS
			fi
		elif [[ -f "$eachSource" ]]; then
			findSource=`echo "$eachSource" | egrep '(m2ts|mkv|avi|mp4|m4v|mpg|mov)' | tr ' ' '\007'`
			if [[ -z "$findSource" ]]; then
				eachSourceBasename=`basename "$eachSource"`
				echo ""
				echo "  ERROR: ${eachSourceBasename} is not a valid input file."
				echo "  • Batch Encode excepts the following file types:"
				echo "      m2ts, mkv, avi, mp4, m4v, mpg, mov"
				echo ""
				exit $E_BADARGS
			fi
		fi
		discList="${discList}${findSource} "
		# Test DiscList for BD in Optical Drive; Set useMakeMKV to 1
		blurayTest=`df -T udf | grep "$1"` # all discs
		if [ -e "${blurayTest}/BDMV" ]; then
			needMakeMKV=1
		fi
	done
	discList=`echo "$discList" | grep -vE '^ $' | sort`
}

searchForFilesAndFolders() # Searches input directories for videos to encode
{
	# spaces in file path temporarily become /007 and paths are divided with spaces
	discSearch=`df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed 's|^|\/|g'` # all discs
	discString=`echo "$discSearch" | sed 's|.*|"&"|' | tr '\n' ' '`

	if [[ ignoreOptical -eq 0 && ! -z "$discSearch" ]]; then
		# searches movie/tv folders and optical discs
		# searches for folders/optical drives for BDs and DVDs; searches folders for mkv, avi, m2ts, mp4, m4v, mpg and mov files
		discListCmd="find \"$movieSearchDir\" \"$tvSearchDir\" \( -maxdepth 1 -type f -name *.mkv -or -name *.avi -or -name *.m2ts -or -name *.mp4 -or -name *.m4v -or -name *.mpg -or -name *.mov \) | tr ' ' '\007' | tr '\000' ' ' & find \"$movieSearchDir\" \"$tvSearchDir\" $discString \( -type d -name BDMV -o -type d -name VIDEO_TS \) | tr ' ' '\007' | tr '\000' ' '"
		discList=`eval $discListCmd`
		# Test DiscList for BD in Optical Drive; Set useMakeMKV to 1
		blurayTest=`eval "find $discString -type d -name BDMV | tr ' ' '\007' | tr '\000' ' '"`
		if [ ! -z "$blurayTest" ]; then
			needMakeMKV=1
		fi
	else
		# searches movie/tv folders only; ignores optical
		# searches for folders for BDs and DVDs; searches folders for mkv, avi, m2ts, mp4, m4v, mpg and mov files
		discList=`find "$movieSearchDir" "$tvSearchDir" \( -maxdepth 1 -type f -name *.mkv -or -name *.avi -or -name *.m2ts -or -name *.mp4 -or -name *.m4v -or -name *.mpg -or -name *.mov \)  | tr ' ' '\007' | tr '\000' ' ' & find "$movieSearchDir" "$tvSearchDir" \( -type d -name BDMV -o -type d -name VIDEO_TS \) | tr ' ' '\007' | tr '\000' ' '`
	fi
	discList=`echo "$discList" | sort`
}

displaySetupInfo() # Sets the display set up info
{
	# sets encode string for setup info
	if [[ "$needMakeMKV" -eq 1 || "$makeMKV" -eq 1 ]]; then
		encodeString="${encodeString} MKV:"
	fi

	if [[ "$encode_1" -eq 1 ]]; then
		encodeString="${encodeString} Encode 1/${preset1}:"
	fi

	if [[ "$encode_2" -eq 1 ]]; then
		encodeString="${encodeString} Encode 2/${preset2}:"
	fi

	if [[ "$encode_3" -eq 1 ]]; then
		encodeString="${encodeString} Encode 3/${preset3}:"
	fi

	if [[ "$encode_4" -eq 1 ]]; then
		encodeString="${encodeString} Encode 4/${preset4}:"
	fi

	encodeString=`echo $encodeString | sed -e 's|:|,|g' -e 's|,$||'`

	# get ignore optical setting for setup info
	if [[ ignoreOptical -eq 1 ]];
		then opticalStatus="No"
	else opticalStatus="Yes"
	fi

	# get skipDuplicates setting for setup info
	if [[ skipDuplicates -eq 0 ]];
		then skipDuplicatesStatus="No"
	else skipDuplicatesStatus="Yes"
	fi

	# get growlMe setting for setup info
	if [[ growlMe -eq 0 ]];
		then growlMeStatus="No"
	else growlMeStatus="Yes"
	fi

	# get useMakeMKV setting for setup info
	if [[ makeMKV -eq 0 ]];
		then useMakeMKVStatus="No"
	else useMakeMKVStatus="Yes"
	fi

	# get retireExistingFile setting for setup info
	if [[ retireExistingFile -eq 0 ]];
		then retireExistingFileStatus="No"
	else retireExistingFileStatus="Yes"
	fi

	# get use tmdb setting for setup info
	if [[ "$addiTunesTags" -eq 0 ]];
		then addTagsStatus="No"
	else addTagsStatus="Yes"
	fi

	# get useDefaultAudioTrack setting for setup info
	if [[ "$useDefaultAudioTrack" = "Default Audio" ]];
		then defaultAudioStatus="Yes"
	else defaultAudioStatus="No ($useDefaultAudioTrack)"
	fi
	
	# get addAdditionalAudioTracks setting for setup info
	if [[ "$addAdditionalAudioTracks" = "None" ]];
		then addAdditionalAudioTracksStatus="No"
	else addAdditionalAudioTracksStatus="Yes ($addAdditionalAudioTracks)"
	fi
	
	# get useBurnedSubtitleTrack setting for setup info
	if [[ "$useBurnedSubtitleTrack" = "None" ]];
		then useBurnedSubtitleTrackStatus="No"
	else useBurnedSubtitleTrackStatus="Yes ($useBurnedSubtitleTrack)"
	fi

	# get usePassthruSubtitleTracks setting for setup info
	if [[ "$usePassthruSubtitleTracks" = "None" ]];
		then usePassthruSubtitleTracksStatus="No"
	else usePassthruSubtitleTracksStatus="Yes ($usePassthruSubtitleTracks)"
	fi

	# get mixdownAltTracks setting for setup info
	if [[ "$mixdownAltTracks" -eq 0 ]];
		then mixdownAltTracksStatus="No"
	else mixdownAltTracksStatus="Yes"
	fi	
}

checkDiskSpace () # Checks output directory for free space
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

processVariables() # Sets the script variables used for each source
{
	# correct the tmp char back to spaces in the disc file paths
	pathToSource=`echo $1 | tr '\007' ' '`
	tmpDiscPath=`dirname "$pathToSource"`
	tmpDiscName=`basename "$tmpDiscPath"`

	# get discPath, discName, sourceType, etc
	discSearch=`df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed 's|^|\/|g'` # all discs
	# get device name of optical drives. Need to sort by device name to get disc:<num> for makeMKV
	deviceList=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -n "" `
	if echo "$discSearch" | grep "$tmpDiscPath" > /dev/null ; then
		sourceType="Optical"
		sourcePath=`dirname "$pathToSource"`
		discName=`basename "$sourcePath"`
		deviceName=`diskutil info "$sourcePath" | grep "Device / Media Name:" | sed 's|.* ||'`
		deviceID=`diskutil info "$sourcePath" | grep "Device Identifier:" | sed 's|.* ||'`
		deviceNum=`"$makemkvconPath" -r --directio=false info disc:list | egrep "DRV\:.*$deviceID" | sed -e 's|DRV:||' -e 's|,.*||'`
		#deviceNum=`echo "$deviceList" | grep "$deviceName" | awk -F: '{print $1-1}'`
	elif echo "$pathToSource" | egrep -i '(BDMV|VIDEO_TS)' > /dev/null; then
		sourceType="Folder"
		sourcePath=`dirname "$pathToSource"`
		discName=`basename "$sourcePath"`
	elif echo "$pathToSource" | egrep -i '(m2ts|mkv|avi|mp4|m4v|mpg|mov)' > /dev/null ; then
		fileExt=`basename "$pathToSource" | sed 's|.*\.||g'`
		discName=`basename "$pathToSource" .$fileExt`
		sourceFileName=`basename "$pathToSource"`
		#sourcePath="$pathToSource"
		sourcePathContainer=`dirname "$pathToSource"`
		sourcePath="${sourcePathContainer}/${discName}/${sourceFileName}"
		if [ ! -e "$sourcePath" ]; then
			mkdir "${sourcePathContainer}/${discName}"
			mv "$pathToSource" "$sourcePath"
		fi
		sourceType="File"
	fi

	# get video kind from spotlight finder comment: TV Show or Movie
	videoKind=""
	videoKind=$(mdls -name kMDItemFinderComment "$sourcePath" | awk -F\" '{print $2}')
	if [ -z "$videoKind" ];	then
		tvFolder=`echo "$tvSearchDir" | sed "s|\/$discName.*||"`
		movieFolder=`echo "$movieSearchDir" | sed "s|\/$discName.*||"`
		if echo "$sourcePath" | grep "$movieFolder" > /dev/null ; then
			videoKind="Movie"
		elif echo "$sourcePath" | grep "$tvFolder" > /dev/null ; then
			videoKind="TV Show"
		else
			videoKind="$videoKindOverride"
		fi
	fi

	# set source format HD or SD
	if [ "$sourceType" = "File" ]; then
		scanFileCmd="\"$handBrakeCliPath\" -i \"$sourcePath\" -t0 /dev/null 2>&1"
		scanFile=`eval $scanFileCmd`
		sourcePixelWidth=`echo "$scanFile" | egrep "\+ size" | sed -e 's|^.*+ size: ||' -e 's|x.*||'`
		sourcePixelHeight=`echo "$scanFile" | egrep "\+ size" | sed -e 's|^.*+ size: ||' -e 's|, pixel.*||' -e 's|.*x||'`
		if [[ "$sourcePixelWidth" -gt "1279" || "$sourcePixelHeight" -gt "719" ]]; then
			sourceFormat="HD"
		else
			sourceFormat="SD"
		fi
	fi

	if [ -e "$sourcePath/BDMV" ]; then
		sourceFormat="HD"
	elif [[ -e "/Volumes/${discName}/VIDEO_TS" || -e "${sourcePath}/VIDEO_TS" ]]; then
		sourceFormat="SD"
	fi

	# set useMakeMKV
	if [[ "$sourceType" = "Optical" && "$sourceFormat" = "HD" ]]; then
		useMakeMKV=1
	elif [[ $makeMKV -eq 1 ]]; then
		useMakeMKV=1
	else
		useMakeMKV=0
	fi

	# make/set output directory for bd disks
	if [[ "$sourceType" = "Optical" && "$useMakeMKV" -eq 1 ]]; then
		if [ "$videoKind" = "TV Show" ]; then
			if [ ! -e "${tvSearchDir}/${discName}" ]; then
				mkdir "${tvSearchDir}/${discName}"
			fi
			folderPath="${tvSearchDir}/${discName}"
		elif [ "$videoKind" = "Movie" ]; then
			if [ ! -e "${movieSearchDir}/${discName}" ]; then
				mkdir "${movieSearchDir}/${discName}"
			fi
			folderPath="${movieSearchDir}/${discName}"
		fi
	else
		if [ "$sourceType" = "File" ]; then
			folderPath=`dirname "$sourcePath"`
		else
			folderPath="$sourcePath"
		fi
	fi

	# set color label of movie file to green
	setLabelColor "$folderPath" "6" &

	# create tmp folder for source
	discNameALNUM=`echo "$discName" | sed 's/[^[:alnum:]^-^_]//g'`
	sourceTmpFolder="${tmpFolder}/${discNameALNUM}"
	if [ ! -e "$sourceTmpFolder" ]; then
		mkdir "$sourceTmpFolder"
	fi
}

trackFetchListSetup() # Sets the track list variables based on source/type
{
	# sets the path for info file
	if [ "$sourceType" = "File" ]; then
		outFile="${folderPath}/${discName}"
		#elif [[ "$sourceType" = "Optical" && "$sourceFormat" = "SD" ]]; then
		#outFile="${sourceTmpFolder}/${discName}"
	elif [[ "$sourceType" = "Optical" ]]; then
		outFile="${sourceTmpFolder}/${discName}"
	else
		outFile="$1"
	fi

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
	if [[ "$sourceType" = "File" || "$useMakeMKV" -eq 0 ]]; then
		scanCmd="\"$handBrakeCliPath\" -i \"$sourcePath\" -t 0 /dev/null 2>&1"
		trackInfo=`eval $scanCmd`
		# save HB scan info
		echo "$trackInfo" | egrep '[ \t]*\+' > "${outFile}_titleInfo.txt"
	elif [[ "$useMakeMKV" -eq 1 ]]; then
		trackInfoFile="${outFile}_titleInfo.txt"
		if [ "$sourceType" = "Folder" ]; then
			if [ -e "${sourcePath}/VIDEO_TS" ]; then
				"$makemkvconPath" -r --directio=false --minlength=$minTimeSecs info file:"${sourcePath}/VIDEO_TS" > "$trackInfoFile"
			else
				"$makemkvconPath" -r --directio=false --minlength=$minTimeSecs info file:"$sourcePath" > "$trackInfoFile"
			fi
		elif [ "$sourceType" = "Optical" ]; then
			"$makemkvconPath" -r --minlength=$minTimeSecs info disc:$deviceNum > "$trackInfoFile"
		fi
		trackInfo=`cat "$trackInfoFile" | egrep 'TINFO\:[0-9]{1,2},9,0'`
	fi

	# get the track number of tracks which are within the time desired
	trackFetchList=`getTrackListWithinDuration $minTrackTime $maxTrackTime "$trackInfo"`
}

getTrackListWithinDuration() # Gets the only the tracks with in the min/max duration
{
	#	Three input arguments are are needed.
	#	arg1 is the minimum time in minutes selector
	#	arg2 is the maximum time in minutes selector
	#	arg3 is the raw text stream from the track 0 call to HandBrake (DVD)
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

	#	parse track info
	#	returns a list of titles within the min/max duration
	if [[ "$sourceType" = "File" || "$useMakeMKV" -eq 0 ]] ; then
		trackList=`eval "echo \"$allTrackText\" | egrep '(^\+ title |\+ duration\:)' | sed -e 's/^[^+]*+ //'g -e 's/title \([0-9]*\):/\1-/'g -e 's/duration: //'g"`
		trackNumber=""
		for aline in $trackList
		do
			trackLineFlag=`echo $aline | sed 's/[0-9]*-$/-/'`
			if [ $trackLineFlag = "-" ];
				then
				trackNumber=`echo $aline | sed 's/\([0-9]*\)-/\1/'`
			else
				set -- `echo $aline | sed -e 's/(^[:0-9])//g' -e 's/:/ /g'`
				if [ $3 -gt 29 ];
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
			fi
		done
		#	parse track info for optical disc and folder input using makeMKV
		#	gets a list of tracks added by makemkv
	elif [[ "$useMakeMKV" -eq 1 ]]; then
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
	fi
	echo "$aReturn"
}

getTrackListAllTracks() # Creates a list of all tracks and duration
{
	allTrackText="$*"
	#	parse track info from Handbrake
	#	returns a list of titles with their duration in minutes
	if [[ "$sourceType" = "File" || "$useMakeMKV" -eq 0 ]] ; then
		getTrackList=`eval "echo \"$allTrackText\" | egrep '(^\+ title |\+ duration\:)' | sed -e 's/^[^+]*+ //'g -e 's/title \([0-9]*\):/\1-/'g -e 's/duration: //'g"`
		trackNumber=""
		for aline in $getTrackList
		do
			trackLineFlag=`echo $aline | sed 's/[0-9]*-$/-/'`
			if [ $trackLineFlag = "-" ];
				then
				trackNumber=`echo $aline | sed 's/\([0-9]*\)-/\1/'`
			else
				set -- `echo $aline | sed -e 's/(^[:0-9])//g' -e 's/:/ /g'`
				if [ $3 -gt 29 ];
					then let trackTime=(10#$1*60)+10#$2+1
				else let trackTime=(10#$1*60)+10#$2
				fi

				if [[ $trackTime -gt 1 ]]; then
					returnTitles="$returnTitles - Track ${trackNumber} Duration: $trackTime min.|"
				fi
			fi
		done
	elif [[ "$useMakeMKV" -eq 1 ]]; then
		#	parse track info from MakeMKV
		#	returns a list of titles with their duration in minutes
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
	fi
	echo "$returnTitles" | tr '|' '\n' | sed 's|^|   |g'
}

printTrackFetchList() # Prints the tracks to encode for each source
{
	if [ ! -z "$1" ]; then
		echo "  Will encode the following tracks: `echo $1 | sed 's/ /, /g'` "
	else
		trackInfoTest=$(cat "${outFile}_titleInfo.txt")
		if [[ ! -z "$trackInfoTest" ]]; then
			if [ "$videoKind" = "Movie" ];
				then minTime="$minTrackTimeMovie" && maxTime="$maxTrackTimeMovie"
			else minTime="$minTrackTimeTV" && maxTime="$maxTrackTimeTV"
			fi
			echo "  No tracks found between ${minTime}-${maxTime} minutes ($videoKind)."
			getTrackListAllTracks "$trackInfo"
		else
			if [[ "$sourceType" = "Folder" && "$useMakeMKV" -eq 1 || "$sourceType" = "Optical" && "$useMakeMKV" -eq 1 ]]; then
				# Check for MakeMKV Trial Expired & Failed Disc
				if [ "$sourceType" = "Optical" ]; then
					checkMakeMkvTrial=$("$makemkvconPath" --directio=false info disc:$deviceNum | egrep -i '(evaluation|failed)' | tr '\n' ' ')
				elif [ "$sourceType" = "Folder" && "$sourceType" = "SD" ]; then
					checkMakeMkvTrial=$("$makemkvconPath" --directio=false info file:"${sourcePath}/VIDEO_TS" | egrep -i '(evaluation|failed)' | tr '\n' ' ')
				else
					checkMakeMkvTrial=$("$makemkvconPath" --directio=false info file:"$sourcePath" | egrep -i '(evaluation|failed)' | tr '\n' ' ')
				fi
				if [ ! -z "$checkMakeMkvTrial" ]; then
					echo -e "  ERROR MakeMKV: \c"
					echo "$checkMakeMkvTrial"
				else
					echo "  ERROR: No tracks found or failed to scan source."
					echo "  Check source files and application settings in Automator."
				fi
			else
				echo "  ERROR: No tracks found or failed to scan source."
				echo "  Check source files and application settings in Automator."
			fi
		fi
		# set color label of disc folder to red
		setLabelColor "$folderPath" "2" > /dev/null
	fi
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

makeMKV() # Makes an mkv from an HD source. Extracts main audio, video, and subs.
{
	aTrackTwoDigits=$(printf "%02d" $aTrack)

	# new file name for input into handbrake
	if [[ "$sourceType" = "Folder" && "$sourceFormat" = "SD" ]]; then
		if [ "$folderPath" = "$sourcePath" ]; then
			folderPath="${folderPath}/VIDEO_TS"
			videoTsParentFolder=`dirname "$folderPath"`
		fi
		outFile="${videoTsParentFolder}/${discName}-${aTrack}.mkv"
	else
		outFile="${folderPath}/${discName}-${aTrack}.mkv"
	fi

	# sets the file path input
	# for folders and discs, the tmp file is the file created by makemkv
	tmpFileName=`cat "$trackInfoFile" | egrep "TINFO\:${aTrack},27,0" | sed -e "s|TINFO:${aTrack},27,0,||g" -e 's|"||g'`
	tmpFile="${folderPath}/${tmpFileName}"

	#	CREATE MKV FROM SOURCE FILE
	#	uses makeMKV to create mkv file from selected track
	#	makemkvcon includes all languages and subs, no way to exclude unwanted items
	echo -e "${discName}-${aTrack}.mkv" >> $tmpFolder/growlMessageHD.txt
	echo -e "\n*Creating MKV file of Track: ${aTrack}"

	if [[ ! -e "$tmpFile" && ! -e "$outFile" && ! -e "${folderPath}/${discName}.mkv" ]]; then
		echo -e "Encoded:" `date "+%l:%M %p"` "\c" >> $tmpFolder/growlMessageHD.txt
		if [[ verboseLog -eq 0 ]]; then
			if [ "$sourceType" = "Folder" ]; then
				cmd="\"$makemkvconPath\" mkv --noscan --directio=false --minlength=$minTimeSecs --messages=${sourceTmpFolder}/${aTrack}-makemkv.txt --progress=-same file:\"$folderPath\" $aTrack \"$folderPath\""
			elif [ "$sourceType" = "Optical" ]; then
				cmd="\"$makemkvconPath\" mkv --minlength=$minTimeSecs --messages=${sourceTmpFolder}/${aTrack}-makemkv.txt --progress=-same disc:$deviceNum $aTrack \"$folderPath\""
			fi
			eval $cmd &
			cmdPID=$!
			while [ `isPIDRunning $cmdPID` -eq 1 ]; do
				if [[ -e "$tmpFile" && -e "${sourceTmpFolder}/${aTrack}-makemkv.txt" ]]; then
					cmdStatusTxt="`tail -n 1 ${sourceTmpFolder}/${aTrack}-makemkv.txt | egrep -i '(current|error|failed)' | sed 's|.*progress|  Progress|'`"
					echo "$cmdStatusTxt"
					printf "\e[1A"
				else
					echo ""
					printf "\e[1A"
				fi
				sleep 0.5s
			done
			wait $cmdPID
			cat "${sourceTmpFolder}/${aTrack}-makemkv.txt" | egrep -i 'Total progress - 100' | sed 's|.*progress|  Progress|' | tail -n 1
			printf "\e[1A"
			echo ""
			checkMakeMkvPassFail=$(cat "${sourceTmpFolder}/${aTrack}-makemkv.txt" | egrep -i '(error|failed|Copy complete)' | sed 's|^|  |g')
			if [ ! -z "$checkMakeMkvPassFail" ]; then
				if echo "$checkMakeMkvPassFail" | egrep -i '(error|failed)'; then
					echo "  ERROR MakeMKV:"
				fi
				echo "$checkMakeMkvPassFail"
			fi
		elif [[ verboseLog -eq 1 ]]; then
			if [ "$sourceType" = "Folder" ]; then
				cmd="\"$makemkvconPath\" mkv --noscan --directio=false --minlength=$minTimeSecs --progress=-same file:\"$folderPath\" $aTrack \"$folderPath\""
			elif [ "$sourceType" = "Optical" ]; then
				cmd="\"$makemkvconPath\" mkv --minlength=$minTimeSecs --progress=-same disc:$deviceNum $aTrack \"$folderPath\""
			fi
			eval $cmd
		fi

		# Rename tmpFile to outFile
		if [[ -e "$tmpFile" && ! -e "$outFile" ]]; then
			mv "$tmpFile" "$outFile"
			sourcePath="$outFile"
		fi
	else
		# check to see if files exist
		if [ -e "$tmpFile" ]; then
			sourcePath="$tmpFile"
		elif [ -e "$outFile" ]; then
			sourcePath="$outFile"
		elif [ -e "${folderPath}/${discName}.mkv" ]; then
			sourcePath="${folderPath}/${discName}.mkv"
		elif [ -e "${videoTsParentFolder}/${discName}.mkv" ]; then
			sourcePath="${videoTsParentFolder}/${discName}.mkv"
		fi
		fileExistsName=`basename "$sourcePath"`
		echo "  Skipped because file already exists:"
		echo -e "    Using '${fileExistsName}' for source\n"
		#sourceType="File"
	fi
}

processFiles() # Passes the source file and encode settings for each output file
{
	sourceFile="$1"

	if [[ "$useMakeMKV" -eq 1 ]]; then
		if [[ "$sourceType" = "Folder" || "$sourceType" = "Optical" ]]; then
			#sourceFile="${folderPath}/${discName}-${aTrack}.mkv"
			sourceFile="$sourcePath"
		fi
	fi

	if [ -e "$sourceFile" ]; then
		if [[ encode_1 -eq 1 && "$videoKind" = "TV Show" && ! "$preset1" = "MakeMKV" ]] ; then
			processToolArgs "encode1" "$sourceFile"
			encodeFile "$sourceFile" "${discName}-${aTrack}.${outFileExt}"
		elif [[ encode_1 -eq 1 && "$videoKind" = "Movie" && ! "$preset1" = "MakeMKV" ]] ; then
			processToolArgs "encode1" "$sourceFile"
			encodeFile "$sourceFile" "${discName}.${outFileExt}"
		fi

		if [[ encode_2 -eq 1 && "$videoKind" = "TV Show" ]] ; then
			processToolArgs "encode2" "$sourceFile"
			encodeFile "$sourceFile" "${discName}-${aTrack} 1.${outFileExt}"
		elif [[ encode_2 -eq 1 && "$videoKind" = "Movie" ]] ; then
			processToolArgs "encode2" "$sourceFile"
			encodeFile "$sourceFile" "${discName} 2.${outFileExt}"
		fi

		if [[ encode_3 -eq 1 && "$videoKind" = "TV Show" ]] ; then
			processToolArgs "encode3" "$sourceFile"
			encodeFile "$sourceFile" "${discName}-${aTrack} 1.${outFileExt}"
		elif [[ encode_3 -eq 1 && "$videoKind" = "Movie" ]] ; then
			processToolArgs "encode3" "$sourceFile"
			encodeFile "$sourceFile" "${discName} 3.${outFileExt}"
		fi

		if [[ encode_4 -eq 1 && "$videoKind" = "TV Show" ]] ; then
			processToolArgs "encode4" "$sourceFile"
			encodeFile "$sourceFile" "${discName}-${aTrack} 1.${outFileExt}"
		elif [[ encode_4 -eq 1 && "$videoKind" = "Movie" ]] ; then
			processToolArgs "encode4" "$sourceFile"
			encodeFile "$sourceFile" "${discName} 4.${outFileExt}"
		fi

		if [[ encode_1 -eq 0 && encode_2 -eq 0 && encode_3 -eq 0 && encode_4 -eq 0 ]] ; then
			echo "  WARNING: No Encode Type Selected."
			echo "  To encode an MP4, choose an Encode Target and Preset in your worklfow settings."
		fi
	fi
}

processToolArgs() # Sets HandBrake encode settings based on input/output type
{
	# strategic echo to add space
	echo ""
	encodeType="$1"
	inputFile="$2"
	scanFileCmd="\"$handBrakeCliPath\" -i \"$inputFile\" -t $aTrack --scan /dev/null 2>&1"
	scanFile=`eval $scanFileCmd`

	# Set Encode Format for Encode Type
	if [[ "$encodeType" = "encode1" ]]; then
		encodeFormat="$preset1"
	elif [[ "$encodeType" = "encode2" ]]; then
		encodeFormat="$preset2"
	elif [[ "$encodeType" = "encode3" ]]; then
		encodeFormat="$preset3"
	elif [[ "$encodeType" = "encode4" ]]; then
		encodeFormat="$preset4"
	else
		encodeFormat="Universal"
	fi
	# Set a search string for the chosen HB preset 
	hbPresetName="$encodeFormat"
	
	# Get Selected Audio Tracks. Returns selectedAudioTracks.
	getSelectedAudioTracks
	
	# Get Selected Subtitle Tracks. selectedSubtitleTracks
	getSelectedSubtitleTracks
	
	case $encodeFormat in
		( "Custom 1" )  toolArgs=$(echo "$customArgs1" | sed -e "s|\$audioSearch|${selectedAudioTracks}|g" -e "s|\$subtitleSearch|${selectedSubtitleTracks} ${subtitleBurnArgs}|g");;
		( "Custom 2" )  toolArgs=$(echo "$customArgs2" | sed -e "s|\$audioSearch|${selectedAudioTracks}|g" -e "s|\$subtitleSearch|${selectedSubtitleTracks} ${subtitleBurnArgs}|g");;
		( "Custom 3" )  toolArgs=$(echo "$customArgs3" | sed -e "s|\$audioSearch|${selectedAudioTracks}|g" -e "s|\$subtitleSearch|${selectedSubtitleTracks} ${subtitleBurnArgs}|g");;
		( "Custom 4" )  toolArgs=$(echo "$customArgs4" | sed -e "s|\$audioSearch|${selectedAudioTracks}|g" -e "s|\$subtitleSearch|${selectedSubtitleTracks} ${subtitleBurnArgs}|g");;
		( "$preset1" | "$preset2" | "$preset3" | "$preset4" )		toolArgs=`"$handBrakeCliPath" -z | egrep -vi "legacy" | egrep -i "$hbPresetName" | egrep -m1 "" | sed -e 's|  | |g' -e "s|^.*${hbPresetName}: ||" -e "s|-a.*audio-copy-mask|${selectedAudioTracks} --audio-copy-mask|g" -e "s| -m|& ${selectedSubtitleTracks} ${subtitleBurnArgs}|g" -e 's|  *| |g'`;;
		( * )  toolArgs=`"$handBrakeCliPath" -z | egrep -vi "legacy" | egrep -i "$hbPresetName" | sed -e 's|  | |g' -e "s|^.*${hbPresetName}: ||" -e "s|-a.*audio-copy-mask|${selectedAudioTracks} --audio-copy-mask|g" -e "s| -m|& ${selectedSubtitleTracks} ${subtitleBurnArgs}|g" -e 's|  *| |g'`;;
	esac

	if echo "$toolArgs" | egrep -i 'mp4' > /dev/null; then
		outFileExt="m4v"
	elif echo "$toolArgs" | egrep -i 'mkv' > /dev/null; then
		outFileExt="mkv"
	else
		outFileExt="m4v"
	fi

	# Set track info to print to screen
	videoTrackString=$(echo "$scanFile" | grep "+ " | egrep '(\+ duration|size)' | sed -e s'|duration|Duration|' -e 's|size|Size|' -e 's|.*+||' -e 's|,.*||' | tr '\n' ', ' | sed -e 's|,$||')
	defaultAudioTrackString=$(echo $defaultAudioTrack | sed -e 's|),.*$|)|' -e 's|^.*+ ||')
	additionalAudioTracksString=$(echo "$additionalAudioTracks" | sed -e 's|),.*$|)|')
	if [[ -z "$additionalAudioTracks" ]]; then
		audioTracksNotIncludedString=$(echo "$allAudioTracks" | grep -v "$defaultAudioTrack" | tr '+' '-')
	else
		audioTracksNotIncludedString=$(echo "$allAudioTracks" | grep -v "$defaultAudioTrack" | grep -v "$additionalAudioTracks" | tr '+' '-')
	fi
	if [[ "$burnSubtitleTrack" = "scan" ]]; then
		burnSubtitleTrackString="• Foreign Audio Search"
	else
		burnSubtitleTrackString=$(echo "$burnSubtitleTrack" | sed -e 's|),.*$|)|' -e 's|^.*+ |* |')
	fi
	passthruSubtitleTracksString=$(echo "$passthruSubtitleTracks" | sed -e 's|),.*$|)|')
	if [[ -z "$burnSubtitleTrack" && -z "$passthruSubtitleTracks" ]]; then
		subtitleTracksNotIncludedString=$(echo "$allSubTracks" | tr '+' '-')
	elif [[ -z "$burnSubtitleTrack" && ! -z "$passthruSubtitleTracks" ]]; then
		subtitleTracksNotIncludedString=$(echo "$allSubTracks" | grep -v "$passthruSubtitleTracks" | tr '+' '-')
	elif [[ ! -z "$burnSubtitleTrack" && -z "$passthruSubtitleTracks" ]]; then
		subtitleTracksNotIncludedString=$(echo "$allSubTracks" | grep -v "$burnSubtitleTrack" | tr '+' '-')
	elif [[ ! -z "$burnSubtitleTrack" && ! -z "$passthruSubtitleTracks" ]]; then
		subtitleTracksNotIncludedString=$(echo "$allSubTracks" | grep -v "$burnSubtitleTrack" | grep -v "$passthruSubtitleTracks" | tr '+' '-')
	fi
}

getSelectedAudioTracks () # Get Selected Audio Tracks. Returns selectedAudioTracks.
{ 
	# get all audio tracks
	allAudioTracks=$(echo "$scanFile" | sed -n '/+ audio tracks:/,/+ subtitle tracks:/p' | grep -vE 'audio tracks:|subtitle tracks:')
	# get all native language audio tracks
	nativeLangAudioTracks=$(echo "$allAudioTracks" | grep "$nativeLanguage" | grep -v 'TrueHD')
	# get all alternate language audio tracks
	altLangAudioTracks=$(echo "$allAudioTracks" | grep "$alternateLanguage" | grep -v 'TrueHD')
	# get the language of default audio track
	defaultAudioTrackLanguage=`echo "$allAudioTracks" | egrep -m1 "" | sed -e 's|.*iso639-2: ||' -e 's|).*||g'`
	
	# Select Default Audio Track
	if [[ "$useDefaultAudioTrack" = "Default Audio" ]]; then
		defaultAudioTrack=`echo "$allAudioTracks" | grep "$defaultAudioTrackLanguage" | egrep '(DTS|AC3)' | grep "5.1" | egrep -m1 ""`
		if [[ -z "$defaultAudioTrack" ]]; then
			defaultAudioTrack=`echo "$allAudioTracks" | grep "$defaultAudioTrackLanguage" | egrep -m1 ""`
		fi
	else
		if [[ ! -z "$nativeLangAudioTracks" ]]; then
			defaultAudioTrack=`echo "$nativeLangAudioTracks" | egrep '(DTS|AC3)' | grep "5.1" | egrep -m1 ""`
			if [[ -z "$defaultAudioTrack" ]]; then
				defaultAudioTrack=`echo "$nativeLangAudioTracks" | egrep -m1 ""`
			fi
		fi
		if [[ -z "$nativeLangAudioTracks" && ! -z "$altLangAudioTracks" ]]; then
			echo "*Native Language ($nativeLanguage) Audio Track Not Found."
			echo -e "  Will encode using Alternate Language ($alternateLanguage).\n"
			defaultAudioTrack=`echo "$altLangAudioTracks" | egrep '(DTS|AC3)' | grep "5.1" | egrep -m1 ""`
			if [[ -z "$defaultAudioTrack" ]]; then
				defaultAudioTrack=`echo "$altLangAudioTracks" | egrep -m1 ""`
			fi
		elif [[ -z "$nativeLangAudioTracks" && -z "$altLangAudioTracks" ]]; then
			echo "*Native Language ($nativeLanguage) Audio Track Not Found."
			echo "  Alternate Language ($alternateLanguage) Audio Track Not Found."
			echo -e "    Will encode using Default Audio Track ($defaultAudioTrackLanguage).\n"
		fi
	fi
	# If no tracks are selected, fall back to first audio track
	if [[ -z "$defaultAudioTrack" ]]; then
		defaultAudioTrack=`echo "$scanFile" | egrep -A 1 'audio tracks' | egrep "\+ [0-9],.*iso639-2:" | sed 's|^.*+ ||'`
	fi
	
	# Select Additional Audio Tracks
	if [[ "$addAdditionalAudioTracks" = "Native Language" ]]; then
		additionalAudioTracks="$nativeLangAudioTracks"
	elif [[ "$addAdditionalAudioTracks" = "Alternate Language" ]]; then
		additionalAudioTracks="$altLangAudioTracks"
	elif [[ "$addAdditionalAudioTracks" = "Native & Alternate" ]]; then
		additionalAudioTracks=$(echo -e "${nativeLangAudioTracks}\n${altLangAudioTracks}" | egrep -v '^$')
	elif [[ "$addAdditionalAudioTracks" = "All Tracks" ]]; then
		additionalAudioTracks="$allAudioTracks"
	else
		additionalAudioTracks=""
	fi
	# Remove defaultAudioTrack from the additionalAudioTracks list
	if [[ ! -z "$additionalAudioTracks" ]]; then
		additionalAudioTracks=$(echo "$additionalAudioTracks" | grep -v "$defaultAudioTrack")
	fi
	
	# Compile list of all selected audio tracks
	selectedAudioTrackList=$(echo -e "${defaultAudioTrack}\n${additionalAudioTracks}" | sed -e 's|^.*+ ||')

	# Test selected HB preset for AC3 passthru.
	# If preset's default includes passthru, will passthru AC3. Otherwise will only encode 2 channel.
	ac3passTest=$("$handBrakeCliPath" -z /dev/null 2>&1 | egrep -vi "legacy" | egrep -i "$hbPresetName" | egrep -m1 "" | grep '1,1' > /dev/null || echo 1)

	# Set a track counter for mixdown
	aTrackCount=0
	
	# Reset args for each title
	audioEncoding=""
	audioTracks=""
	dynamicRangeCompression=""
	bitRate=""
	mixDown=""
	audioSampleRate=""
	
	# Loop thru each audio track and set its parameters
	OLDIFS=$IFS # get default IFS
	IFS=$'\n' # set IFS to lines
	for aAudioTrack in $selectedAudioTrackList
	do
		# Counter for mixdown. If mixdown is true, will not mixdown first track (default track)
		aTrackCount=$(echo "$aTrackCount + 1" | bc )
		thisAudioTrack=$(echo "$aAudioTrack" | sed 's|,.*||')
		# Get number of channels
		isMultiChannel=`echo "$aAudioTrack" | egrep -o '[0-9]\.[0-9]' || echo 0`
		# Test if track has more than 2 channels
		multiChannelTest=$(echo "$isMultiChannel > 2" | bc )
		# If statement to set parameters differently if multi-channel or 2 channel (mixdown)
		if [[ multiChannelTest -eq 0 || $mixdownAltTracks -eq 1 && $aTrackCount > 1 || "$ac3passTest" -eq 1 ]]; then
			# set parameters for 2 channel (mixdown)
			audioEncoding=$(echo ${audioEncoding},ca_aac | sed 's|^,||')
			audioTracks=$(echo ${audioTracks},${thisAudioTrack} | sed 's|^,||')
			dynamicRangeCompression=$(echo ${dynamicRangeCompression},0.0 | sed 's|^,||')
			bitRate=$(echo ${bitRate},160 | sed 's|^,||')
			mixDown=$(echo ${mixDown},dpl2 | sed 's|^,||')
			audioSampleRate=$(echo ${audioSampleRate},auto | sed 's|^,||')
		else
			# set parameters for multi-channel
			audioEncoding=$(echo ${audioEncoding},ca_aac,copy:ac3 | sed 's|^,||')
			audioTracks=$(echo ${audioTracks},${thisAudioTrack},${thisAudioTrack} | sed 's|^,||')
			dynamicRangeCompression=$(echo ${dynamicRangeCompression},0.0,0.0 | sed 's|^,||')
			bitRate=$(echo ${bitRate},160,160 | sed 's|^,||')
			mixDown=$(echo ${mixDown},dpl2,auto | sed 's|^,||')
			audioSampleRate=$(echo ${audioSampleRate},auto,auto | sed 's|^,||')
		fi
	done
	IFS=$OLDIFS # return IFS back to default
	
	# Set audio track args for handbrake
	selectedAudioTracks="-a ${audioTracks} -E ${audioEncoding} -B ${bitRate} -6 ${mixDown} -R ${audioSampleRate} -D ${dynamicRangeCompression}"	
}

getSelectedSubtitleTracks () # Get Selected Subtitle Tracks. selectedSubtitleTracks
{
	# get all subtitle tracks
	allSubTracks=$(echo "$scanFile" | sed -n '/+ subtitle tracks:/,//p' | grep '+' | grep -v 'subtitle tracks:')
	# get all native language subtitle tracks
	nativeLangSubTracks=$(echo "$allSubTracks" | grep "$nativeLanguage")
	# get all alternate language subtitle tracks
	altLangSubTracks=$(echo "$allSubTracks" | grep "$alternateLanguage")
	
	# Select Burned Subtitle Track
	if [[ "$useBurnedSubtitleTrack" = "Auto Detect" || "$useBurnedSubtitleTrack" = "Forced Only (native)" ]]; then
		if [[ `echo "$allSubTracks" | grep "$nativeLanguage"` ]]; then
			burnSubtitleTrack="scan"
			burnSubtitleTrackLanguage="$nativeLanguage"
		else
			if [[ -z "$nativeLangSubTracks" && ! -z "$altLangSubTracks" ]]; then
				echo "*Native Language ($nativeLanguage) Subtitle Track Not Found."
				echo -e "  Will scan using Alternate Language ($alternateLanguage) Subtitle Track.\n"
				burnSubtitleTrack="scan"
				burnSubtitleTrackLanguage="$alternateLanguage"
			elif [[ -z "$nativeLangSubTracks" && -z "$altLangSubTracks" ]]; then
				echo "*Native Language ($nativeLanguage) Subtitle Track Not Found."
				echo "  Alternate Language ($alternateLanguage) Subtitle Track Not Found."
				echo -e "    Disabling Foreign Audio Search.\n"
			fi
		fi
	elif [[ "$useBurnedSubtitleTrack" = "Native Language" ]]; then
		burnSubtitleTrack=$(echo "$nativeLangSubTracks" | egrep -m1 "")
		burnSubtitleTrackLanguage="$nativeLanguage"
		if [[ -z "$burnSubtitleTrack" && ! -z "$altLangSubTracks" ]]; then
			echo "*Native Language ($nativeLanguage) Subtitle Track Not Found."
			echo -e "  Will use Alternate Language ($alternateLanguage) Subtitle Track.\n"
			burnSubtitleTrack=$(echo "$altLangSubTracks" | egrep -m1 "")
			burnSubtitleTrackLanguage="$alternateLanguage"
		fi
	else
		burnSubtitleTrack=""
		burnSubtitleTrackLanguage=""	
	fi
	# Set subtitle burn args for handbrake
	if [[ ! -z "$burnSubtitleTrack" ]]; then
		subtitleBurnArgs="--subtitle-burned 1 --subtitle-forced 1 --native-language $burnSubtitleTrackLanguage"
	fi

	# Select Pass-thru Subtitle Tracks
	if [[ "$usePassthruSubtitleTracks" = "Native Language" ]]; then
		passthruSubtitleTracks="$nativeLangSubTracks"
	elif [[ "$usePassthruSubtitleTracks" = "Alternate Language" ]]; then
		passthruSubtitleTracks="$altLangSubTracks"
	elif [[ "$usePassthruSubtitleTracks" = "Native & Alternate" ]]; then
		passthruSubtitleTracks=$(echo -e "${nativeLangSubTracks}\n${altLangSubTracks}" | egrep -v '^$')
	elif [[ "$usePassthruSubtitleTracks" = "All Tracks" ]]; then
		passthruSubtitleTracks="$allSubTracks"
	else
		passthruSubtitleTracks=""
	fi
	# Filter out Subs to include only text based tracks
	if [[ ! -z "$usePassthruSubtitleTracks" ]]; then
		if [[ ! -z "$burnSubtitleTrack" ]]; then
			passthruSubtitleTracks=$(echo "$passthruSubtitleTracks" | grep 'Text' | grep -v "$burnSubtitleTrack")
		else
			passthruSubtitleTracks=$(echo "$passthruSubtitleTracks" | grep 'Text')
		fi
	fi
	
	# Set subtitle args for handbrake
	selectedSubtitleTracks=$(echo -e "${burnSubtitleTrack}\n${passthruSubtitleTracks}" | sed -e 's|^.*+ ||' -e 's|,.*||' | tr '\n' ',' | sed -e 's|,*$||' -e 's|^,||')
	if [[ ! -z "$selectedSubtitleTracks" ]]; then
		selectedSubtitleTracks=$(echo "--subtitle $selectedSubtitleTracks")
	fi
}

encodeFile() # Encodes source with HandBrake and sends output files for further processing
{
	inputPath="$1"
	movieFile="$2"

	if [[ ! -e  "$outputDir/$movieFile" || skipDuplicates -eq 0 ]] ; then
		# Print track selections to screen
		echo "*Creating $movieFile"
		echo "  Video Track: $aTrack,$videoTrackString"
		echo "  Audio Tracks:"
		echo "    • $defaultAudioTrackString ** Default **"
		if [[ ! -z "$additionalAudioTracks" ]]; then
			echo "$additionalAudioTracksString"
		fi
		if [[ ! -z "$audioTracksNotIncludedString" ]]; then
			echo "$audioTracksNotIncludedString"
		fi
		if [[ ! -z "$burnSubtitleTrack" || ! -z "$passthruSubtitleTracks" || ! -z "$subtitleTracksNotIncludedString" ]]; then
			echo "  Subtitle Tracks:"
			if [[ ! -z "$burnSubtitleTrack" ]]; then
				echo "    ${burnSubtitleTrackString} ** Burned-in **"
			fi
			if [[ ! -z "$passthruSubtitleTracks" ]]; then
				echo "$passthruSubtitleTracksString"
			fi
			if [[ ! -z "$subtitleTracksNotIncludedString" ]]; then
				echo "$subtitleTracksNotIncludedString"
			fi
		fi
		echo -e "\nUsing ${encodeFormat} Preset: ${toolArgs}\n"
		echo -en "$movieFile\nEncoded:" `date "+%l:%M %p"` "\c" >> $tmpFolder/growlMessageHD.txt &

		# encode with verbose level 0
		if [[ verboseLog -eq 0 ]]; then
			# set path to batch encode log
			batchEncodeLog="$HOME/Library/Logs/BatchRipActions/BatchEncode.log"
			# set default cursor position
			tput sc
			# encode cmd for makemkv source
			if [[ "$useMakeMKV" -eq 1 ]]; then
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -o \"${outputDir}/${movieFile}\" -v 0 $toolArgs 2>\"$batchEncodeLog\""
				# encode cmd for direct from source
			else
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -t $aTrack -o \"${outputDir}/${movieFile}\" -v 0 $toolArgs 2>\"$batchEncodeLog\""
			fi
			# encode with verbose level 1
		elif [[ verboseLog -eq 1 ]]; then
			# encode cmd for makemkv source
			if [[ "$useMakeMKV" -eq 1 ]]; then
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -o \"${outputDir}/${movieFile}\" -v $toolArgs"
				# encode cmd for direct from source
			else
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -t $aTrack -o \"${outputDir}/${movieFile}\" -v $toolArgs"
			fi
		fi

		eval $cmd &
		cmdPID=$!
		
		# return status if foreign audio search is active
		if [[ "$burnSubtitleTrack" = "scan" ]]; then
			# activate foreign audio search log status
			logStatus=1
			# wait for subtitle scan to finish
			while [[ `isPIDRunning $cmdPID` -eq 1 && "$logStatus" -eq 1 ]]; do
				if [[ -e "$batchEncodeLog" ]]; then
					# grep to see if scan finished
					jobStarted="`grep '* audio track' \"$batchEncodeLog\"`"
					# get result of subtitle scan
					subtitleNotFound="`grep 'No candidate detected during subtitle scan' \"$batchEncodeLog\" | sed 's|.*[0-9]]||'`"
					subtitleFound="`egrep 'subtitle track.*Render/Burn-in' \"$batchEncodeLog\" | sed -e 's|.*[0-9]]||' -e 's| (.*]||'`"
					if [[ ! -z "$jobStarted" ]]; then
						# return cursor to default position
						tput rc
						tput ed
						# return results of foreign audio search
						if [[ ! -z "$subtitleFound" || ! -z "$subtitleNotFound" ]]; then
							echo -e "*Foreign Audio Search:"
							if [[ -z "$subtitleFound" ]]; then
								echo -e "  ${subtitleNotFound}\n"
							else
								echo -e "  ${subtitleFound}\n"
							fi
						fi
						# set log status to 0
						logStatus=0
					fi
				fi
				sleep 0.5s
			done
		fi
		
		# wait for encoding to finish
		wait $cmdPID
		echo ""
		echo -e "-" `date "+%l:%M %p"` "\n" >> $tmpFolder/growlMessageHD.txt &

		# test output file integrity
		testOutputFile=$(testFileIntegrity "$outputDir/$movieFile")
		if [[ ! $testOutputFile -eq 1 ]]; then
			# optionally tag files, move existing file in archive and set Finder comments
			# adds iTunes style tags to mp4 files
			if echo "$movieFile" | grep -v "mkv" > /dev/null; then
				addMetaTags
				if [[ ! "$videoKind" = "TV Show" && "$addiTunesTags" -eq 1 ]]; then
					addiTunesTagsMovie
				fi
				# test output file integrity
				testOutputFile=$(testFileIntegrity "$outputDir/$movieFile")
				if [[ $testOutputFile -eq 1 ]]; then
					echo -e "\n* ERROR: $movieFile FAILED file integrity test!"
					echo -e "  Encode may have failed or File may be corrupt :( \n"
					# set color label of movie file to red
					setLabelColor "$outputDir/$movieFile" "2" &
					# set color label of disc folder to red
					setLabelColor "$folderPath" "2" &
				fi
			fi

			if [[ ! $testOutputFile -eq 1 ]]; then
				# set spotlight finder comment of m4v file to "videoKind" for hazel or another script
				setFinderComment "$outputDir/$movieFile" "$videoKind"
				# set color label of movie file to green
				currentLabelColor=$(getLabelColor "$outputDir/$movieFile")
				if [[ ! $currentLabelColor -eq 1 ]]; then
					setLabelColor "$outputDir/$movieFile" "6" &
				fi
				# if file is a movie and movie already exists in archive, move existing file to retired folder
				if [[ ! "$videoKind" = "TV Show" && retireExistingFile -eq 1 ]]; then
					retireExistingFile
				fi
			fi
		else
			echo -e "\n* ERROR: $movieFile FAILED file integrity test!"
			echo -e "  Encode may have failed or File may be corrupt :( \n"
			if [[ ! -e "$outputDir/$movieFile" ]]; then
				echo -n "  Script could not complete because $movieFile does NOT exist \n"
			else
				# set color label of movie file to red
				setLabelColor "$outputDir/$movieFile" "2" &
				# set color label of disc folder to red
				setLabelColor "$folderPath" "2" &
			fi
		fi
	else
		echo -e "$movieFile\nSkipped because it already exists\n" >> $tmpFolder/growlMessageHD.txt &
		echo -e "\n  $movieFile SKIPPED because it ALREADY EXISTS"
	fi
	echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
}

testFileIntegrity() # Validates mp4 output
{
	thisFile="$1"
	thisFileName=`basename "$thisFile"`
	testResult=""
	if echo "$thisFileName" | grep -v "mkv" > /dev/null; then
		#echo "*Testing ${thisFileName} to see if its a valid MPEG-4 file"
		testMp4File=$("$atomicParsleyPath" "$thisFile" -T)
		if [ ! -z "$testMp4File" ]; then
			testResult=0
		else
			testResult=1
		fi
		echo "$testResult"
	fi
}

retireExistingFile() # If the file already exists in movie library, move existing file to retired folder
{
	echo -e "\n*Checking if $discName exists in Movie Folder"
	# ADDED 2010-10-21
	findMovieCMD=`find "${libraryFolder}" -type d -maxdepth 1 -name "$discName*"`
	theFile=`basename "$findMovieCMD"`
	if [ -d "$findMovieCMD" ]; then
		mv "$findMovieCMD" "${retiredFolder}/${theFile}"
		if [ -d "${retiredFolder}/${theFile}" ]; then
			echo "  $discName MOVED to Retired Folder"
		else
			echo "  $discName FAILED to MOVE to Retired Folder"
		fi
	else
		echo "  $discName does NOT exist"
	fi
}

addMetaTags() # Adds HD Flag, cnid num and videoKind for iTunes
{
	# Set the HD Flag for HD-Video
	getResolution=$("$mp4infoPath" "$outputDir/$movieFile" | egrep "1.*video" | awk -F,\  '{print $4}' | sed 's|\ @.*||')
	pixelWidth=$(echo "$getResolution" | sed 's|x.*||')
	pixelHeight=$(echo "$getResolution" | sed 's|.*x||')
	if [[ pixelWidth -gt 1279 || pixelHeight -gt 719 ]]; then
		HDSD="HD"
	else
		HDSD="SD"
	fi

	cnIDnum=$( tail -1 "$cnidFile" )
	echo "*Adding Meta Tags to $movieFile"
	# write mp4 tags to files. videoKind: -i 9=movie, 10=tv show. cnid: -I <num>. HD Flag: -H 1.
	if [[ $HDSD = HD && ! "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -H 1 -I $cnIDnum -i 9 "$outputDir/$movieFile"
	elif [[ $HDSD = SD && ! "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -I $cnIDnum -i 9 "$outputDir/$movieFile"
	elif [[ $HDSD = HD && "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -H 1 -I $cnIDnum -i 10 "$outputDir/$movieFile"
	elif [[ $HDSD = SD && "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -I $cnIDnum -i 10 "$outputDir/$movieFile"
	fi
}

setFinderComment() # Sets Spotlight Comment of the output file to TV Show or Movie
{
	osascript -e "try" -e "set theFile to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set comment of theFile to \"$2\"" -e "tell application \"Finder\" to update theFile" -e "end try" > /dev/null
}

setLabelColor() # Sets the file or folder color
{
	osascript -e "try" -e "set theFolder to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set label index of theFolder to $2" -e "end try" > /dev/null
}

getLabelColor() # Gets the current file or folder color
{
	osascript -e "try" -e "set theItem to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to return label index of theItem" -e "end try"
}

addiTunesTagsMovie() # Adds iTunes style metadata to m4v files using theMovieDB.org api
{
	# variables
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
	elif [ -e "${sourceTmpFolder}/${searchTerm}_tmp.json" ]; then
		echo "Title found"
	fi

	# set metadata variables and write tags to file
	if grep "{" "$movieData" > /dev/null 2>&1 ; then
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
				imgTest=1
			fi
		fi
		
		# set subler args
		sublerArgs="{Artwork:$moviePoster}{Name:$discName}{Artist:$movieDirector}{Genre:$movieGenre}{Release Date:$releaseDate}{Description:$movieDesc}{Long Description:$movieDesc}{Rating:$movieRating}{Studio:$studioName}{Cast:$movieActors}{Director:$movieDirector}{Codirector:$movieCoDirector}{Producers:$movieProducers}{Screenwriters:$movieWriters}{Gapless:0}"
		sublerArgs=`substituteISO88591 "$(echo "$sublerArgs")"`

		# Search tagchimp for chapter names
		addChapterNamesMovie
		
		# write tags with sublerCli
		echo -e "\n*Writing tags with SublerCLI... \c"
		if [[ -e "$chapterFile" ]]; then
			"$sublerCliPath" -o "$outputDir/$movieFile" -t "$sublerArgs" -c "$chapterFile" -p -O 1>/dev/null
		else
			"$sublerCliPath" -o "$outputDir/$movieFile" -t "$sublerArgs" -p -O 1>/dev/null
		fi
		echo "Done"
		if [[ "$imgTest" -gt 0 ]]; then
			echo -e "\n  ERROR: Cover art failed integrity test... No artwork was added"
			# set color label of movie file to orange
			setLabelColor "$outputDir/$movieFile" "1" &
			# set color label of disc folder to orange
			setLabelColor "$folderPath" "1" &
		fi
	else
		echo "Could not find a match"
		# set color label of movie file to orange
		setLabelColor "$outputDir/$movieFile" "1" &
		# set color label of disc folder to orange
		setLabelColor "$folderPath" "1" &
	fi
}

addChapterNamesMovie () # Adds chapter names to m4v files using the tagchimp api
{
	tagChimpToken=1803782295499EE85E56181
	discNameNoYear=`htmlEncode "$(echo "$discName" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g')"`
	searchTerm=`urlEncode "$discNameNoYear"`
	movieYear=`echo "$discName" | awk -F\( '{print $2}' | awk -F\) '{print $1}'`
	chapterFile="${outputDir}/${discName}.chapters.txt"
	#	Copy chapter file if it's a second encode
	if [[ "$movieFile" = "${discName} 1.m4v" && -e "$chapterFile" ]]; then
		cp "$chapterFile" "${outputDir}/${discName} 1.chapters.txt"
		chapterFile="${outputDir}/${discName} 1.chapters.txt"
	elif [[ "$movieFile" = "${discName} 1.m4v" && ! -e "$chapterFile" ]]; then
		chapterFile="${outputDir}/${discName} 1.chapters.txt"
	fi
	if [ ! -e "$chapterFile" ]; then
		echo -e "  Searching TagChimp for chapter names... \c"
		#	Get chaps from m4v
		"$mp4chapsPath" -qxC "$outputDir/$movieFile"
		if [ -e "$chapterFile" ]; then
			#	Get count of chaps
			chapterCount=$(grep -cv "NAME" "$chapterFile")
			#	Search tagchimp
			tagChimpIdXml="${sourceTmpFolder}/${searchTerm}-chimp.xml"
			tagChimpXml="${sourceTmpFolder}/${searchTerm}-info-chimp.xml"
			$curlCmd "https://www.tagchimp.com/ape/search.php?token=$tagChimpToken&type=search&title=$searchTerm&videoKind=Movie&limit=5&totalChapters=$chapterCount" > "$tagChimpIdXml"
			searchTagChimp=`"$xpathPath" "$tagChimpIdXml" //tagChimpID 2>/dev/null | sed -e 's|\/tagChimpID>|\||g'| tr '|' '\n' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
			# test chapters for each id
			for tagChimpID in $searchTagChimp
			do
				# download each id to tmp.xml
				tagChimpData="${sourceTmpFolder}/${tagChimpID}-chimp.xml"
				if [ ! -e "$tagChimpData" ]; then
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
				movieTitle=`"$xpathPath" "$tagChimpData" "//movieTitle/text()" 2>/dev/null | sed 's|[ \t]*$||' | egrep -ix "$discNameNoYearWildcard"`
				#	Test id for chap count
				titleCount=`"$xpathPath" "$tagChimpData" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' | tr '|' '\n' | grep -c ""`
				#	Test chapter titles for uniqueness
				chapterTest=`"$xpathPath" "$tagChimpData" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' | tr '|' '\n' | sed '3q;d' | grep "3"`
				chapterNameTest=`"$xpathPath" "$tagChimpData" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' | tr '|' '\n' | egrep -ic "chapter"`
				# 	verify data match, delete if not a match
				if [[ ! "$releaseDate" = "" && ! "$movieTitle" = "" && -z "$chapterTest" && chapterNameTest -eq 0 ]]; then
					if [ "$titleCount" = "$chapterCount" ]; then
						echo "Chapters found"
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
					echo "Chapters found (not exact match)"
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
				# Create a csv file for later use with hb; save to source folder
				cat "$titleFile" | grep -n "" | sed -e 's|,|\\,|g' -e 's|:|, |' > "${outFile}.chapters.csv"
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
				echo "Could not find a match"
				rm -f "$chapterFile"
				# set color label of movie file to orange
				setLabelColor "$outputDir/$movieFile" "1" &
			fi
		else
			# set color label of movie file to orange
			setLabelColor "$outputDir/$movieFile" "1" &
		fi
	fi
}

resizeImage () # Resizes large cover art to max 600px
{
	sips -Z 600W600H "$1" --out "$1"  > /dev/null 2>&1
}

getKeyValue () # Gets JSON value for specified key using jq tool
{
	cat $1 | "$jqToolPath" -r "$2"
}

urlEncode () # Converts strings to uri safe
{
	escapeString=$(echo "$1" | sed "s|\'|\\\'|g" )
	#php -r "echo urlEncode('$1');"
	#php -r "echo urlEncode(iconv('UTF-8-MAC', 'UTF-8', '$1'));"
	php -r "echo urlEncode(iconv('ISO-8859-1', 'UTF-8', '$escapeString'));"
}

htmlEncode () # Converts strings to html entities
{
	escapeString=$(echo "$1" | sed "s|\'|\\\'|g" )
	php -r "echo htmlspecialchars(iconv('UTF-8-MAC', 'ISO-8859-1', '$escapeString'));"
}

substituteISO88591 () # Converts html entitiy strings to ISO8859-1 in metadata
{
	escapeString=$(echo "$1" | sed "s|\'|\\\'|g" )
	php -r "echo mb_convert_encoding('$escapeString', 'UTF-8', 'HTML-ENTITIES');"
}

get_log () # Gets Terminal Log
{
cat << EOF | osascript -l AppleScript
	try
		tell application "Terminal"
			set theText to history of tab 1 of window 1
			return theText
		end tell
	end try
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

	#########################################################################################
	# MAIN SCRIPT

	# initialization functions

	# get window id of Terminal session and change settings set to Pro
	windowID=$(osascript -e 'try' -e 'tell application "Terminal" to set Window_Id to id of first window as string' -e 'end try')
	osascript -e 'try' -e "tell application \"Terminal\" to set current settings of window id $windowID to settings set named \"Pro\"" -e 'end try'

	# process args passed from main.command
	parseVariablesInArgs $1
	if [[ verboseLog -eq 1 ]]; then
		echo -e "\nProcessing Args passed from Batch Encode (Service).workflow\n$*\n"
	fi

	#makeFoldersForMe

	# create tmp folder for script
	tmpFolder="/tmp/batchEncode_$scriptPID"
	if [ ! -e "$tmpFolder" ]; then
		mkdir "$tmpFolder"
	fi

	# display the basic setup information
	displaySetupInfo
	echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	echo -e "$scriptName v$scriptVers\n"
	echo "  Start: `date`"
	echo "  Input directory 1: $movieSearchDir"
	echo "  Input directory 2: $tvSearchDir"
	echo "  Output directory: $outputDir"
	echo "  Use optical Drive: $opticalStatus"
	echo "  Use MakeMKV: $useMakeMKVStatus"
	echo "  Auto-add movie tags: $addTagsStatus"
	echo "  Retire Existing File: $retireExistingFileStatus"
	echo "  Growl me when complete: $growlMeStatus"
	echo "  Encode TV Shows between: ${minTrackTimeTV}-${maxTrackTimeTV} mins"
	echo "  Encode Movies between: ${minTrackTimeMovie}-${maxTrackTimeMovie} mins"
	echo "  Native Language: $nativeLanguage"
	echo "  Alternate Language: $alternateLanguage"
	echo "  Use Disc's Default Audio Language: $defaultAudioStatus"
	echo "  Add Additional Audio Tracks: $addAdditionalAudioTracksStatus"
	echo "  Mixdown Additional Audio Tracks to 2CH: $mixdownAltTracksStatus"
	echo "  Burn-in Subtitle Track: $useBurnedSubtitleTrackStatus"
	echo "  Pass-thru Subtitle Tracks: $usePassthruSubtitleTracksStatus"
	echo "  Will Encode: $encodeString"
	
	if [[ verboseLog -eq 1 ]]; then
		echo -e "\n  - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
		echo "  VERBOSE MODE"
		echo "  - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	fi
	echo ""
	
	if [ ! -z "$2" ]; then
		# parse all the source files passed from Automator input
		parseSourceFromInput "$2"
	else
		# find all the BD/DVD videos in the input search directory tree
		searchForFilesAndFolders
	fi

	sanityCheck
	
	# display the list of videos found
	if [ ! "$discList" = "" ]; then
		echo "  WILL PROCESS THE FOLLOWING VIDEOS:"
		for eachVideoFound in $discList
		do
			processVariables "$eachVideoFound"
			echo "  ${discName} : (${videoKind})"
		done
	else
		# return no source found error for the input search directory tree
		echo "  ERROR: No videos found"
		echo "  Check input search directories (\$movieSearchDir, \$tvSearchDir)"
		exit $E_BADARGS
	fi
	echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"

	# process each BD/DVD video found
	for eachVideoFound in $discList
	do
		processVariables "$eachVideoFound"

		# display: start of processing video
		echo -e "\nPROCESSING: $discName \n"

		# display: start of scan
		echo "*Scanning $sourceType: '$discName'"

		# check disk space
		checkDiskSpace "$sourcePath" "$outputDir"
		if [[ $? -eq 1 ]]; then
			echo "  WARNING: There is not enough free space on destination volume."
			echo "  Will try to continue with next video…"
			echo -e "$discName\nSkipped because hard drive is full.\n" >> "${tmpFolder}/growlMessageHD.txt"
			setLabelColor "$folderPath" "2" &
			continue
		fi

		# sets the variables and scan commands based on source type
		trackFetchListSetup "${sourcePath}/${discName}"

		# counts the number of tracks in the trackFetchList
		trackCount=`echo $trackFetchList | wc -w`

		if [[ $verboseLog -eq 1 ]]; then
			cat "${outFile}_titleInfo.txt"
			echo ""
		fi

		# display the track numbers of tracks which are within the time desired
		printTrackFetchList "$trackFetchList"
				
		# process each track in the track list
		for aTrack in $trackFetchList
		do
			# makes an mkv file from the HD source
			if [[ "$useMakeMKV" -eq 1 ]]; then
				if [[ "$sourceType" = "Folder" || "$sourceType" = "Optical" ]]; then
					makeMKV "$nativeLanguage"
				fi
			fi

			# cnID - Generate Random Number
			nextcnID=$(echo $(( 10000+($RANDOM)%(20000-10000+1) ))$(( 1000+($RANDOM)%(9999-1000+1) )) >> "$cnidFile")
			
			# evaluates the input/output variables, selects the output setting and encodes with HandBrake
			processFiles "$sourcePath"

			# moves chapter files to source folder
			if [ -e "${outputDir}/${discName}.chapters.txt" ]; then
				mv "${outputDir}/${discName}.chapters.txt" "${outFile}.chapters.txt"
			fi
			if [[ -e "${outputDir}/${discName} 1.chapters.txt" && ! -e "${outFile}.chapters.txt" ]]; then
				mv "${outputDir}/${discName} 1.chapters.txt" "${outFile}.chapters.txt"
			else
				rm -f "${outputDir}/${discName} 1.chapters.txt"
			fi

			# set color label of mkv files; rename movie file to discName
			if [[ -e "${folderPath}/${discName}-${aTrack}.mkv" && "$videoKind" = "TV Show" ]]; then
				#mv "${folderPath}/${discName}-${aTrack}.mkv" "${outputDir}/${discName}-${aTrack}.mkv"
				setFinderComment "${folderPath}/${discName}-${aTrack}.mkv" "$videoKind"
			elif [[ -e "${folderPath}/${discName}-${aTrack}.mkv" && "$videoKind" = "Movie" ]]; then
				mv "${folderPath}/${discName}-${aTrack}.mkv" "${folderPath}/${discName}.mkv"
				setFinderComment "${folderPath}/${discName}.mkv" "$videoKind"
			fi

		done

		# set color label of disc folder to gray
		currentLabelColor=$(getLabelColor "$folderPath")
		if [[ ! $currentLabelColor -eq 2 ]]; then
			setLabelColor "$folderPath" "7" &
		else
			echo -e "* ERROR: $discName FAILED during processing!\n"
			echo -e "$discName FAILED during processing\n" >> "${tmpFolder}/growlMessageHD.txt" && sleep 2
		fi

		echo "PROCESSING COMPLETE: $discName"
		echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"

		# delete source temp files
		if [ -e "$sourceTmpFolder" ]; then
			rm -rf $sourceTmpFolder
		fi
		#if [ -e "${outFile}_titleInfo.txt" ]; then
			#rm -f "${outFile}_titleInfo.txt"
		#fi

	done
	
	echo "-- End summary for $scriptName" >> "${tmpFolder}/growlMessageHD.txt"

	########  GROWL NOTIFICATION  ########
	if [[ "$growlMe" -eq 1 ]]; then
		test -x "$growlNotifyPath"
		#open -a GrowlHelperApp && sleep 5
		growlMessage=$(cat ${tmpFolder}/growlMessageHD.txt)
		"$growlNotifyPath" "Batch Encode" -m "$growlMessage" && sleep 5
	fi

    # Display script completed notification
    displayNotification "Batch Rip Actions for Automator" "Batch Encode" "Encoding complete!"

	echo -e "\nEnd: $(date)\n"

	# delete script temp files
	if [ -e "$tmpFolder" ]; then
		rm -rfd $tmpFolder
	fi

	# delete bash script tmp file
	if [ -e "$scriptTmpPath" ]; then
		rm -f "$scriptTmpPath"
	fi

	# save terminal session log
	#theLog=`get_log`
	#if [ ! -z "$theLog" ]; then
	test -d "$HOME/Library/Logs/BatchRipActions" || mkdir "$HOME/Library/Logs/BatchRipActions"
	get_log >> "$HOME/Library/Logs/BatchRipActions/BatchEncode.log"
	#fi

	exit 0