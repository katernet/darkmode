#!/bin/bash
#
## macOS Dark Mode at sunset
## Solar times pulled from Night Shift
## Author: katernet ## Version 1.9b3

## Global variables ##
darkdir=~/Library/Application\ Support/darkmode # darkmode directory
plistR=~/Library/LaunchAgents/io.github.katernet.darkmode.sunrise.plist # Launch Agent plist locations
plistS=~/Library/LaunchAgents/io.github.katernet.darkmode.sunset.plist

## Functions ##

# Set dark mode - Sunrise = off Sunset = on
darkMode() {
	case $1 in
		off) 
			# Disable dark mode
			osascript -e '
			tell application id "com.apple.systemevents"
				tell appearance preferences
					if dark mode is true then
						set dark mode to false
					end if
				end tell
			end tell
			'
			if ls /Applications/Alfred*.app >/dev/null 2>&1; then # If Alfred installed
				osascript -e 'tell application "Alfred 3" to set theme "Alfred"' 2> /dev/null # Set Alfred default theme
			fi
			if [ -f "$plistR" ] || [ -f "$plistS" ]; then # Prevent uninstaller from continuing
				# Run solar query on first day of week and if no static time arguments provided
				if [ "$(date +%u)" = 1 ] && [ $# -eq 1 ]; then
					solar
				fi
				# Get sunset launch agent start interval time
				plistSH=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Hour" "$plistS" 2> /dev/null)
				plistSM=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Minute" "$plistS" 2> /dev/null)
				if [ -z "$plistSH" ] && [ -z "$plistSM" ]; then # If plist solar time vars are empty
					editPlist add "$setH" "$setM" "$plistS" # Run add solar time plist function
				elif [[ "$plistSH" -ne "$setH" ]] || [[ "$plistSM" -ne "$setM" ]]; then # If launch agent times and solar times differ
					# Run update solar time plist
					if [ $# -eq 3 ]; then
						editPlist update "$setH" "$setM" "$plistS" "$2" "$3"
					else
						editPlist update "$setH" "$setM" "$plistS"
					fi
				fi
			fi
			;;
		on)
			# Enable dark mode
			osascript -e '
			tell application id "com.apple.systemevents"
				tell appearance preferences
					if dark mode is false then
						set dark mode to true
					end if
				end tell
			end tell
			'
			if ls /Applications/Alfred*.app >/dev/null 2>&1; then
				osascript -e 'tell application "Alfred 3" to set theme "Alfred Dark"' 2> /dev/null # Set Alfred dark theme
			fi
			# Get sunrise launch agent start interval
			plistRH=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Hour" "$plistR" 2> /dev/null)
			plistRM=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:Minute" "$plistR" 2> /dev/null)
			if [ -z "$plistRH" ] && [ -z "$plistRM" ]; then
				editPlist add "$riseH" "$riseM" "$plistR"
			elif [[ "$plistRH" -ne "$riseH" ]] || [[ "$plistRM" -ne "$riseM" ]]; then
				if [ $# -eq 3 ]; then
					editPlist update "$riseH" "$riseM" "$plistR" "$2" "$3"
				else
					editPlist update "$riseH" "$riseM" "$plistR"
				fi
			fi
			;;
	esac
}

# Solar query
solar() {
	# Get Night Shift solar times (UTC)
	riseT=$(/usr/bin/corebrightnessdiag nightshift-internal | grep nextSunrise | cut -d \" -f2)
	setT=$(/usr/bin/corebrightnessdiag nightshift-internal | grep nextSunset | cut -d \" -f2)
	# Convert to local time
	riseTL=$(date -jf "%Y-%m-%d %H:%M:%S %z" "$riseT" +"%H:%M")
	setTL=$(date -jf "%Y-%m-%d %H:%M:%S %z" "$setT" +"%H:%M")
	# Store times in database
	sqlite3 "$darkdir"/solar.db <<EOF
	CREATE TABLE IF NOT EXISTS solar (id INTEGER PRIMARY KEY, time VARCHAR(5));
	INSERT OR IGNORE INTO solar (id, time) VALUES (1, '$riseTL'), (2, '$setTL');
	UPDATE solar SET time='$riseTL' WHERE id=1;
	UPDATE solar SET time='$setTL' WHERE id=2;
EOF
	# Log
	echo "$(date +"%d/%m/%y %T")" darkmode: Solar query stored - Sunrise: "$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=1;' "")" Sunset: "$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=2;' "")" >> ~/Library/Logs/io.github.katernet.darkmode.log
}

# Get time
getTime() {
	if [ $# -eq 2 ]; then # If static time arguments provided
		# Get static time hr and min. Strip leading 0 with sed.
		riseH=$(echo "$1" | head -c2 | sed 's/^0//')
		riseM=$(echo "$1" | tail -c3 | sed 's/^0//')
		setH=$(echo "$2" | head -c2 | sed 's/^0//')
		setM=$(echo "$2" | tail -c3 | sed 's/^0//')
	else 
		# Get sunrise and sunset hrs and mins from database.
		riseH=$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=1;' "" | head -c2 | sed 's/^0//')
		riseM=$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=1;' "" | tail -c3 | sed 's/^0//')
		setH=$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=2;' "" | head -c2 | sed 's/^0//')
		setM=$(sqlite3 "$darkdir"/solar.db 'SELECT time FROM solar WHERE id=2;' "" | tail -c3 | sed 's/^0//')
	fi
	# Get current 24H time hr and min
	timeH=$(date +"%H" | sed 's/^0//')
	timeM=$(date +"%M" | sed 's/^0//')
}

# Deploy launch agents
launch() {
	shdir="$(cd "$(dirname "$0")" && pwd)" # Get script path
	cp -p "$shdir"/darkmode.sh "$darkdir"/ # Copy script to darkmode directory
	mkdir ~/Library/LaunchAgents 2> /dev/null; cd "$_" || return # Create LaunchAgents directory (if required) and cd there
	# Setup launch agent plists
	/usr/libexec/PlistBuddy -c "Add :Label string io.github.katernet.darkmode.sunrise" "$plistR" 1> /dev/null
	/usr/libexec/PlistBuddy -c "Add :RunAtLoad bool true" "$plistR"
	/usr/libexec/PlistBuddy -c "Add :Label string io.github.katernet.darkmode.sunset" "$plistS" 1> /dev/null
	if [ $# -eq 0 ]; then # No arguments provided - solar
		/usr/libexec/PlistBuddy -c "Add :Program string ${darkdir}/darkmode.sh" "$plistR"
		/usr/libexec/PlistBuddy -c "Add :Program string ${darkdir}/darkmode.sh" "$plistS"
	fi
	if [ $# -eq 2 ]; then # If static time arguments provided
		/usr/libexec/PlistBuddy -c "Add :ProgramArguments array" "$plistR"
		/usr/libexec/PlistBuddy -c "Add :ProgramArguments:0 string ${darkdir}/darkmode.sh" "$plistR"
		/usr/libexec/PlistBuddy -c "Add :ProgramArguments:1 string $1" "$plistR"
		/usr/libexec/PlistBuddy -c "Add :ProgramArguments:2 string $2" "$plistR"
		/usr/libexec/PlistBuddy -c "Add :ProgramArguments array" "$plistS"
		/usr/libexec/PlistBuddy -c "Add :ProgramArguments:0 string ${darkdir}/darkmode.sh" "$plistS"
		/usr/libexec/PlistBuddy -c "Add :ProgramArguments:1 string $1" "$plistS"
		/usr/libexec/PlistBuddy -c "Add :ProgramArguments:2 string $2" "$plistS"
	fi
	# Load launch agents
	launchctl load "$plistR"
	launchctl load "$plistS"
}

# Edit launch agent solar times
editPlist() {
	case $1 in
		add)
			# Unload launch agent
			launchctl unload "$4"
			# Add solar times to launch agent plist
			/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Hour integer $2" "$4"
			/usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:Minute integer $3" "$4"
			# Load launch agent
			launchctl load "$4"
			;;
		update)
			# Unload launch agent
			launchctl unload "$4"
			# Update launch agent plist solar times
			/usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Hour $2" "$4"
			/usr/libexec/PlistBuddy -c "Set :StartCalendarInterval:Minute $3" "$4"
			if [ $# -eq 6 ]; then
				/usr/libexec/PlistBuddy -c "Set :ProgramArguments:1 $5" "$4"
				/usr/libexec/PlistBuddy -c "Set :ProgramArguments:2 $6" "$4"
			fi
			# Load launch agent
			launchctl load "$4"
			;;
	esac
}

# Uninstall
unstl() {
	# Unload launch agents
	launchctl unload "$plistR"
	launchctl unload "$plistS"
	# Check if darkmode files exist and move to Trash
	if [ -d "$darkdir" ]; then
		if [ -d ~/.Trash/darkmode ]; then
			mv "$darkdir" "$(dirname "$darkdir")"/darkmode"$(date +%H%M%S)"
			darkdird=$(echo "$(dirname "$darkdir")"/darkmode*)
			mv "$darkdird" ~/.Trash
		else
			mv "$darkdir" ~/.Trash
		fi
	fi
	if [ -f "$plistR" ] || [ -f "$plistS" ]; then
		mv "$plistR" ~/.Trash
		mv "$plistS" ~/.Trash
	fi
	if [ -f ~/Library/Logs/io.github.katernet.darkmode.log ]; then
		mv ~/Library/Logs/io.github.katernet.darkmode.log ~/.Trash
	fi
	darkMode off
	echo Uninstall successful.
}

# Error logging
log() {
	while IFS='' read -r line; do
		echo "$(date +"%D %T") $line" >> ~/Library/Logs/io.github.katernet.darkmode.log
	done
}

## Config ##

# Error log
exec 2> >(log)

# Uninstall switch
if [ "$1" == '/u' ]; then # Shell parameter
	unstl
	error=$? # Get exit code from unstl()
	if [ $error -ne 0 ]; then # If exit code not equal to 0
		echo "Uninstall failed! For manual uninstall steps visit https://github.com/katernet/darkmode/issues/1"
		read -rp "Open link in your browser? [y/n] " prompt
		if [[ $prompt =~ [yY](es)* ]]; then
			open https://github.com/katernet/darkmode/issues/1
		fi
		exit $error
	fi
	exit 0
fi

# Static time arguments
if [ $# -gt 0 ]; then # If arguments provided
	# Check arguments provided are in 24H format
	if [ $# -eq 2 ] && (( $1 >= 0 && $1 <= 2400 )) && (( $2 >= 0 && $2 <= 2400 )) && [[ ${#1} -gt 3 && ${#2} -gt 3 ]]; then
		getTime "$1" "$2"
		mkdir -p "$darkdir"
		if [ ! -f "$plistR" ] || [ ! -f "$plistS" ]; then # If launch agents don't exist
			launch "$1" "$2"
		fi
	else
		echo Error: Invalid arguments. Usage: ./darkmode.sh HHMM HHMM
		echo Exiting
		exit 1
	fi
# No arguments - Solar
else
	if [ ! -d "$darkdir" ]; then # If darkmode directory doesn't exist
		mkdir "$darkdir" 
		solar
		if [ ! -f "$plistR" ] || [ ! -f "$plistS" ]; then
			launch
		fi
	fi
	getTime
fi

## Code ##

# Solar conditions
if [[ "$timeH" -ge "$riseH" && "$timeH" -lt "$setH" ]]; then
	# Sunrise
	if [[ "$timeH" -ge $((riseH+1)) || "$timeM" -ge "$riseM" ]]; then
		if [ $# -eq 0 ]; then # If no arguments provided
			darkMode off
		else 
			darkMode off "$1" "$2"
		fi
	# Sunset	
	elif [[ "$timeH" -ge "$setH" && "$timeM" -ge "$setM" ]] || [[ "$timeH" -le "$riseH" && "$timeM" -lt "$riseM" ]]; then 
		if [ $# -eq 0 ]; then
			darkMode on
		else 
			darkMode on "$1" "$2"
		fi
	fi
# Sunset		
elif [[ "$timeH" -ge 0 && "$timeH" -lt "$riseH" ]]; then
	if [ $# -eq 0 ]; then
		darkMode on
	else 
		darkMode on "$1" "$2"
	fi
# Sunrise	
elif [[ "$timeH" -eq "$setH" && "$timeM" -lt "$setM" ]]; then
	if [ $# -eq 0 ]; then
		darkMode off
	else 
		darkMode off "$1" "$2"
	fi
# Sunset	
else
	if [ $# -eq 0 ]; then
		darkMode on
	else 
		darkMode on "$1" "$2"
	fi
fi
