## Symbolication doesn't work

In most cases the symbolication process doesn't work, since there is no dSYM uploaded to HockeyApp, or the dSYM doesn't match the application binary. So this is also about the rules of binary UUIDs and dSYMs.

**IMPORTANT:** Each time you run the build command, your app gets a new unique UUID which is placed into the crash report to idenfiy the build. You also get a new dSYM package which contains the same UUID. So if you upload a new binary to the app store, you also have to upload the new dSYM to HockeyApp!

Here are some tips on how to find out which UUID is used where:

1. Find the UUID in the crash report:

    - Scroll down the crash report until you find `Binary Images:`.
    - The first line below that shows something like the following:

            0x1000 -   0x222fff +AppName armv7  <1234567890abcdef1234567890abcdef> /var/mobile/Applications/ABCDEF01-1234-5678-9ABC-DEF012345678/AppName.app/AppName

        `1234567890abcdef1234567890abcdef` is the UUID of your binary for the `armv7` architecture. 

2. Find the UUID in the app binary (1 line for each architecture):

        dwarfdump --uuid AppName.app/AppName                

    The result will look like:
    
        UUID: 12345678-90AB-CDEF-1234-567890ABCDEF (armv7) AppName.app/AppName
    
3. Find the UUID in the dSYM (1 line for each architecture):

        dwarfdump --uuid AppName.app.dSYM
        
    The result will look like:

        UUID: 12345678-90AB-CDEF-1234-567890ABCDEF (armv7) AppName.app.dSYM/Contents/Resources/DWARF/AppName

4. Find the dSYM for a specific UUID on your computer:

        mdfind "com_apple_xcode_dsym_uuids == 12345678-90AB-CDEF-1234-567890ABCDEF"

    The string "12345678-90AB-CDEF-1234-567890ABCDEF" is the UUID string from the crash report reformatted to uppercase and 8-4-4-4-12 groups.

If you found the correct dSYM, please upload it again and HockeyApp will process the crash logs a second time.