on run argv
    set volumePath to item 1 of argv
    set appName to item 2 of argv
    set appBundleName to appName & ".app"

    tell application "Finder"
        set volumeFolder to POSIX file volumePath as alias
        open volumeFolder
        delay 1

        set diskWindow to container window of volumeFolder
        try
            set current view of diskWindow to icon view
        end try
        try
            set toolbar visible of diskWindow to false
        end try
        try
            set statusbar visible of diskWindow to false
        end try
        try
            set bounds of diskWindow to {120, 120, 680, 430}
        end try

        set viewOptions to icon view options of diskWindow
        try
            set arrangement of viewOptions to not arranged
        end try
        try
            set icon size of viewOptions to 104
        end try
        try
            set text size of viewOptions to 13
        end try
        try
            set background color of viewOptions to {7710, 8481, 9252}
        end try

        try
            set position of item appBundleName of diskWindow to {165, 170}
        end try
        try
            set position of alias file "Applications" of diskWindow to {410, 170}
        end try

        try
            update without registering applications
        end try
        delay 1
        try
            close diskWindow
        end try
    end tell
end run
