# darkmode

Set macOS dark mode and Alfred dark theme at sunset.

This shell script pulls sunrise and sunset data from the Yahoo weather API and automates the setting up of two user launch agents for sunrise and sunset, which then take over running the script thereafter. If your mac was asleep/off during the solar times, launchd will run the script when you're next logged in!

Compatible with macOS Mojave beta Dark Mode.

### Usage
```
$ ./darkmode.sh
```
 
### Notes

Be sure to **_not_** move the script file after first run, as the script path is set in the launch agents.

This script pulls your location from ipinfo.io. If you would not like the script to gather your location, hard code your location in the solar function in variables 'loc' (city) and 'nat' (nation) e.g. loc=seattle nat=usa

If you have a custom Alfred theme, you can change the name of the theme in the darkMode function. Change the second quote in the osascript commands.

A log file is stored in ~/Library/Logs which logs solar time changes and script errors.