set -euo pipefail

ADD_PLIST="${0}.runfiles/__main__/Telegram/Telegram-iOS/AlternateIcons.plist"
ADD_PLIST_IPAD="${0}.runfiles/__main__/Telegram/Telegram-iOS/AlternateIcons-iPad.plist"

INFO_PLIST="$1/Payload/Telegram.app/Info.plist"

/usr/libexec/PlistBuddy -c "add :CFBundleIcons:CFBundleAlternateIcons dict" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "add :CFBundleIcons~ipad:CFBundleAlternateIcons dict" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "merge $ADD_PLIST :CFBundleIcons:CFBundleAlternateIcons" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "merge $ADD_PLIST_IPAD :CFBundleIcons~ipad:CFBundleAlternateIcons" "$INFO_PLIST"
