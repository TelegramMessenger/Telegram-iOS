
apple_resource(
    name = "AppResources",
    files = glob([
        "Telegram-iOS/Resources/**/*",
	], exclude = ["Telegram-iOS/Resources/**/.*"]),
    visibility = ["PUBLIC"],
)

apple_resource(
    name = "AppStringResources",
    files = [],
    variants = glob([
        "Telegram-iOS/*.lproj/Localizable.strings",
    ]),
    visibility = ["PUBLIC"],
)

apple_asset_catalog(
  name = 'Icons',
  dirs = [
    "Telegram-iOS/Icons.xcassets",
  ],
  visibility = ["PUBLIC"],
)

apple_asset_catalog(
  name = 'AppIcons',
  dirs = [
    "Telegram-iOS/AppIcons.xcassets",
  ],
  visibility = ["PUBLIC"],
)

apple_resource(
    name = "AdditionalIcons",
    files = glob([
        "Telegram-iOS/*.png",
    ]),
    visibility = ["PUBLIC"],
)

apple_resource(
    name = 'LaunchScreen',
    files = [
        'Telegram-iOS/Base.lproj/LaunchScreen.xib',
    ],
    visibility = ["PUBLIC"],
)
