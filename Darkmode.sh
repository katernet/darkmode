#!/bin/bash
#
## Dark mode at sunrise
## Solar times pulled from Yahoo Weather API
## Author: /u/katernet ## Version 1.1

## Global variables ##
darkdir=~/Documents/Darkmode
hostname=$(hostname | sed "s/'//;s/ //") # Store hostname. Remove apostrophe and spaces if exist.
plistR=~/Library/LaunchAgents/local.$hostname.Darkmode.sunrise.plist # Launch Agent plist locations
plistS=~/Library/LaunchAgents/local.$hostname.Darkmode.sunset.plist

## Functions ##

# Set dark mode - Sunrise = off Sunset = on
darkMode() {
	case $1 in
		off) 
			# Disable dark mode
			osascript -e '
			tell application "System Events"
				tell appearance preferences
					if dark mode is true then
						set dark mode to false
						do shell script "echo $(date +\"%D %T\") Sunrise: Dark mode off >> '"$darkdir"'/log.txt"
					end if
				end tell
			end tell
			'
			if ls /Applications/Alfred*.app >/dev/null 2>&1; then # If Alfred installed
				osascript -e 'tell application "Alfred 3" to set theme "Alfred"' 2> /dev/null # Set Alfred default theme
			fi
			# Get sunset launch agent start interval time
			plistSH=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Hour" "$plistS" 2> /dev/null)
			plistSM=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Minute" "$plistS" 2> /dev/null)
			if [ -z "$plistSH" ] && [ -z "$plistSM" ]; then # If plist solar times don't exist
				editPlist add "$setH" "$setM" "$plistS" # Run add solar time plist function
			elif [[ "$plistSH" -ne "$setH" ]] || [[ "$plistSM" -ne "$setM" ]]; then # If launch agent and solar times differ
				editPlist update "$setH" "$setM" "$plistS" # Run update solar time plist function
			fi
			;;
		on)
			# Enable dark mode
			osascript -e '
			tell application "System Events"
				tell appearance preferences
					if dark mode is false then
						set dark mode to true
						do shell script "echo $(date +\"%D %T\") Sunrise: Dark mode on >> '"$darkdir"'/log.txt"
					end if
				end tell
			end tell
			'
			if ls /Applications/Alfred*.app >/dev/null 2>&1; then # If Alfred installed
				osascript -e 'tell application "Alfred 3" to set theme "Alfred Dark"' 2> /dev/null # Set Alfred default theme
			fi
			# Get sunrise launch agent start interval
			plistRH=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Hour" "$plistR" 2> /dev/null)
			plistRM=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Minute" "$plistR" 2> /dev/null)
			if [ -z "$plistRH" ] && [ -z "$plistRM" ]; then
				editPlist add "$riseH" "$riseM" "$plistR"
			elif [[ "$plistRH" -ne "$riseH" ]] || [[ "$plistRM" -ne "$riseM" ]]; then
				editPlist update "$riseH" "$riseM" "$plistR"
			fi
			;;
	esac
}

# Solar query
solar() {
	# Set location
	# Get city and country from http://ipinfo.io
	loc=$(curl -s ipinfo.io/geo | awk -F: '{print $2}' | awk 'FNR ==3 {print}' | sed 's/[", ]//g')
	nat=$(curl -s ipinfo.io/geo | awk -F: '{print $2}' | awk 'FNR ==5 {print}' | sed 's/[", ]//g')
	# Get solar times in 12H
	riseT=$(curl -s "https://query.yahooapis.com/v1/public/yql?q=select%20astronomy.sunrise%20from%20weather.forecast%20where%20woeid%20in%20(select%20woeid%20from%20geo.places(1)%20where%20text%3D%22${loc}%2C%20${nat}%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys" | awk -F\" '{print $22}')
	setT=$(curl -s "https://query.yahooapis.com/v1/public/yql?q=select%20astronomy.sunset%20from%20weather.forecast%20where%20woeid%20in%20(select%20woeid%20from%20geo.places(1)%20where%20text%3D%22${loc}%2C%20${nat}%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys" | awk -F\" '{print $22}')
	# Export times in 24H
	date -jf "%I:%M %p" "${riseT}" +"%H:%M" 2> /dev/null > "$darkdir"/riseT
	date -jf "%I:%M %p" "${setT}" +"%H:%M" 2> /dev/null > "$darkdir"/setT
	echo "$(date +"%D %T")" Darkmode: Solar query exported >> "$darkdir"/log.txt
}

# Deploy launch agent
launch() {
	shdir="$(cd "$(dirname "$0")" && pwd)" # Get script path
	mkdir ~/Library/LaunchAgents 2> /dev/null; cd "$_" || return # Create LaunchAgents directory (if required) and cd there
	# Setup plist
	/usr/libexec/PlistBuddy -c "Add :Label string local.$hostname.Darkmode.sunrise" "$plistR" 1> /dev/null
	/usr/libexec/PlistBuddy -c "Add :Program string ${shdir}/Darkmode.sh" "$plistR"
	/usr/libexec/PlistBuddy -c "Add :Label string local.$hostname.Darkmode.sunset" "$plistS" 1> /dev/null
	/usr/libexec/PlistBuddy -c "Add :Program string ${shdir}/Darkmode.sh" "$plistS"
	# Load launch agents
	launchctl load "$plistR"
	launchctl load "$plistS"
}

# Edit launch agent solar times
editPlist() {
	case $1 in
		add)
			# Add solar times to launch agent plist
			/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Hour integer $2" "$4"
			/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Minute integer $3" "$4"
			# Reload launchd job
			launchctl unload "$4"
			launchctl load "$4"
			;;
		update)
			# Update launch agent plist solar times
			/usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Hour $2" "$4"
			/usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Minute $3" "$4"
			# Reload launchd job
			launchctl unload "$4"
			launchctl load "$4"
			;;
	esac
}

# Logging
log() {
	while IFS='' read -r line; do
		echo "$(date +"%D %T") $line" >> "$darkdir"/log.txt
	done
}

## Config ##

# If Darkmode directory doesn't exist
if [ ! -d "$darkdir" ]; then
	mkdir $darkdir
	solar
fi

# Error log
exec 2> >(log)

# If launch agents don't exist
if [ ! -f "$plistR" ] || [ ! -f "$plistS" ]; then
	launch
fi

# Run solar query on first day of week
if [ "$(date +%u)" = 1 ]; then
	solar
fi

# Get sunrise and sunset hrs and mins. Remove leading 0s with sed.
riseH=$(< "$darkdir"/riseT head -c2 | sed 's/^0*//')
riseM=$(< "$darkdir"/riseT tail -c3 | sed 's/^0*//')
setH=$(< "$darkdir"/setT head -c2 | sed 's/^0*//')
setM=$(< "$darkdir"/setT tail -c3 | sed 's/^0*//')

# Current 24H time hr and min
timeH=$(date +"%H" | sed 's/^0*//')
timeM=$(date +"%M" | sed 's/^0*//')

## Code ##

# Solar conditions
if [[ "$timeH" -ge "$riseH" && "$timeH" -lt "$setH" ]]; then
	# Sunrise
	if [[ "$timeH" -ge $((riseH+1)) || "$timeM" -ge "$riseM" ]]; then
		darkMode off
	# Sunset	
	elif [[ "$timeH" -ge "$setH" && "$timeM" -ge "$setM" ]] || [[ "$timeH" -le "$riseH" && "$timeM" -lt "$riseM" ]]; then 
		darkMode on
	fi
# Sunset		
elif [[ "$timeH" -ge 0 && "$timeH" -lt "$riseH" ]]; then
	darkMode on
# Sunrise	
elif [[ "$timeH" -eq "$setH" && "$timeM" -lt "$setM" ]]; then
	darkMode off
# Sunset	
else
	darkMode on
fi
