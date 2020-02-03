#!/usr/bin/env sh

# main.command
# Batch Encode

# changes
# 20131111-0 Updated for Mavericks
# 20131111-1 Removed references to mkvtoolnix & bdsup2sub

#  Created by Robert Yamada on 10/7/09.

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

#################### BEGIN MAIN SCRIPT ####################

# Debug
set -xv

# Create Log Folder
if [ ! -d "$HOME/Library/Logs/BatchRipActions" ]; then
	mkdir "$HOME/Library/Logs/BatchRipActions"
fi

# Redirect standard output to log
exec 6>&1
exec > "$HOME/Library/Logs/BatchRipActions/batchEncode.log"
exec 2>> "$HOME/Library/Logs/BatchRipActions/batchEncode.log"

# create application support folder
batchRipSupport="$HOME/Library/Application Support/Batch Rip"
if [ ! -d "$batchRipSupport" ]; then
	mkdir "$batchRipSupport"
fi

while read thePath
do
	thePathNoSpace=$(echo "$thePath" | tr ' ' ':' | sed -e 's|(|\(|g' -e 's|)|\)|g')
	sourceList=$(echo "$sourceList$thePathNoSpace ")
done
# set the variables
if [[ ! "${verboseLog}" ]]; then verboseLog=0; fi
if [[ ! "${runBackgroundProcess}" ]]; then runBackgroundProcess=0; fi
if [[ ! "${ignoreOptical}" ]]; then ignoreOptical=0; fi
if [[ ! "${minTrackTimeTV}" ]]; then minTrackTimeTV=0; fi
if [[ ! "${maxTrackTimeTV}" ]]; then maxTrackTimeTV=0; fi
if [[ ! "${minTrackTimeMovie}" ]]; then minTrackTimeMovie=0; fi
if [[ ! "${maxTrackTimeMovie}" ]]; then maxTrackTimeMovie=0; fi
if [[ ! "${handBrakeCliPath}" ]]; then handBrakeCliPath="no selection"; fi
if [[ ! "${makemkvPath}" ]]; then makemkvPath="no selection"; fi
if [[ ! "${tvSearchDir}" ]]; then tvSearchDir="no selection"; fi
if [[ ! "${movieSearchDir}" ]]; then movieSearchDir="no selection"; fi
if [[ ! "${outputDir}" ]]; then outputDir="no selection"; fi

if [[ ! "${encode1}" ]]; then encode1=0; fi
if [[ ! "${encode2}" ]]; then encode2=0; fi
if [[ ! "${encode3}" ]]; then encode3=0; fi
if [[ ! "${encode4}" ]]; then encode4=0; fi

if [[ ! "${preset1}" ]]; then preset1="no selection"; fi
if [[ ! "${preset2}" ]]; then preset2="no selection"; fi
if [[ ! "${preset3}" ]]; then preset3="no selection"; fi
if [[ ! "${preset4}" ]]; then preset4="no selection"; fi

if [[ ! "${customArgs1}" ]]; then customArgs1="no selection"; fi
if [[ ! "${customArgs2}" ]]; then customArgs2="no selection"; fi
if [[ ! "${customArgs3}" ]]; then customArgs3="no selection"; fi
if [[ ! "${customArgs4}" ]]; then customArgs4="no selection"; fi

if [[ ! "${retireExistingFile}" ]]; then retireExistingFile=0; fi
if [[ ! "${libraryFolder}" ]]; then libraryFolder="no selection"; fi
if [[ ! "${retiredFolder}" ]]; then retiredFolder="no selection"; fi

if [[ ! "${addiTunesTags}" ]]; then addiTunesTags=0; fi
if [[ ! "${growlMe}" ]]; then growlMe=0; fi
if [[ ! "${nativeLanguage}" ]]; then nativeLanguage="eng"; fi
if [[ ! "${alternateLanguage}" ]]; then alternateLanguage="none"; fi
if [[ ! "${useDefaultAudioTrack}" ]]; then useDefaultAudioTrack="Default Audio"; fi
if [[ ! "${addAdditionalAudioTracks}" ]]; then addAdditionalAudioTracks="None"; fi
if [[ ! "${useBurnedSubtitleTrack}" ]]; then useBurnedSubtitleTrack="None"; fi
if [[ ! "${usePassthruSubtitleTracks}" ]]; then usePassthruSubtitleTracks="None"; fi
if [[ ! "${mixdownAltTracks}" ]]; then mixdownAltTracks="0"; fi

if [[ ! "${videoKind}" ]]; then videoKind="0"; fi
if [[ videoKind -eq 0 ]]; then videoKind="Movie"; fi
if [[ videoKind -eq 1 ]]; then videoKind="TV Show"; fi

bundlePath=`dirname "$0"`
scriptPath="$bundlePath/batchEncode.sh"
scriptTmpPath="$HOME/Library/Application Support/Batch Rip/batchEncodeTmp.sh"

# Temporarily replace spaces in paths
movieSearchDir=`echo "$movieSearchDir" | tr ' ' ':'`
tvSearchDir=`echo "$tvSearchDir" | tr ' ' ':'`
outputDir=`echo "$outputDir" | tr ' ' ':'`
handBrakeCliPath=`echo "$handBrakeCliPath" | tr ' ' ':'`
makemkvPath=`echo "$makemkvPath" | tr ' ' ':'`
videoKindOverride=`echo "$videoKind" | tr ' ' ':'`
libraryFolder=`echo "$libraryFolder" | tr ' ' ':'`
retiredFolder=`echo "$retiredFolder" | tr ' ' ':'`
customArgs1=`echo "$customArgs1" | tr ' ' '@'`
customArgs2=`echo "$customArgs2" | tr ' ' '@'`
customArgs3=`echo "$customArgs3" | tr ' ' '@'`
customArgs4=`echo "$customArgs4" | tr ' ' '@'`
preset1=`echo "$preset1" | tr ' ' '@'`
preset2=`echo "$preset2" | tr ' ' '@'`
preset3=`echo "$preset3" | tr ' ' '@'`
preset4=`echo "$preset4" | tr ' ' '@'`
useDefaultAudioTrack=`echo "$useDefaultAudioTrack" | tr ' ' '@'`
addAdditionalAudioTracks=`echo "$addAdditionalAudioTracks" | tr ' ' '@'`
useBurnedSubtitleTrack=`echo "$useBurnedSubtitleTrack" | tr ' ' '@'`
usePassthruSubtitleTracks=`echo "$usePassthruSubtitleTracks" | tr ' ' '@'`

scriptArgs="--verboseLog $verboseLog --movieSearchDir $movieSearchDir --tvSearchDir $tvSearchDir --outputDir $outputDir --handBrakeCliPath $handBrakeCliPath --makemkvPath $makemkvPath --minTrackTimeTV $minTrackTimeTV --maxTrackTimeTV $maxTrackTimeTV --minTrackTimeMovie $minTrackTimeMovie --maxTrackTimeMovie $maxTrackTimeMovie --nativeLanguage $nativeLanguage --alternateLanguage $alternateLanguage --useDefaultAudioTrack $useDefaultAudioTrack --addAdditionalAudioTracks $addAdditionalAudioTracks --useBurnedSubtitleTrack $useBurnedSubtitleTrack --usePassthruSubtitleTracks $usePassthruSubtitleTracks --mixdownAltTracks $mixdownAltTracks --encode_1 $encode1 --encode_2 $encode2 --encode_3 $encode3 --encode_4 $encode4 --ignoreOptical $ignoreOptical --growlMe $growlMe --videoKindOverride $videoKindOverride --addiTunesTags $addiTunesTags --retireExistingFile $retireExistingFile --libraryFolder $libraryFolder --retiredFolder $retiredFolder --customArgs1 $customArgs1 --customArgs2 $customArgs2 --customArgs3 $customArgs3 --customArgs4 $customArgs4 --preset1 $preset1 --preset2 $preset2 --preset3 $preset3 --preset4 $preset4"

if [[ runBackgroundProcess -eq 1 ]]; then
	echo "\"$scriptPath\" \"$scriptArgs\" \"$sourceList\"" > "$scriptTmpPath"
	chmod 777 "$scriptTmpPath"
	"$scriptTmpPath"
else
	echo "\"$scriptPath\" \"$scriptArgs\" \"$sourceList\"" > "$scriptTmpPath"
	chmod 777 "$scriptTmpPath"
	open -a Terminal "$scriptTmpPath"
fi

# Restore standard output & return output files
exec 1>&6 6>&- 

exit 0
