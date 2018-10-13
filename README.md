# darkmode beta

Set macOS dark mode and Alfred dark theme at sunset.

This shell script gets the sunrise and sunset times from Night Shift and automates the setting up of two user launch agents for sunrise and sunset, which then take over running the script thereafter. If your mac was asleep/off during the solar times, launchd will run the script when you're next logged in!

Or you can supply your own sunrise and sunset 24H times by passing arguments. Example: 0600 1800

##### High Sierra and below
![HighSierra](resources/highsierra.gif "High Sierra dark menu bar and dock")

##### Mojave
![Mojave](resources/mojave.gif "Mojave Dark Mode")

### Usage
```
$ ./darkmode.sh
```

OR

```
$ ./darkmode.sh HHMM HHMM
```
 
### Notes

Compatible with macOS Mojave Dark Mode. Press OK to the security dialogs to allow control to System Events that appear when first running the script.

If your Mac does not support Night Shift, please use the previous version [1.7.2](https://github.com/katernet/darkmode/releases/tag/1.7.2) which uses the Yahoo Weather API.

If you have a custom Alfred theme, you can change the name of the theme in the darkMode function. Change the second quote in the osascript commands.

A log file is stored in ~/Library/Logs which logs solar time changes and script errors.

To uninstall: $ ./darkmode.sh /u