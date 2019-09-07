
def appConfig():
    apiId = native.read_config("custom", "apiId")
    apiHash = native.read_config("custom", "apiHash")
    hockeyAppId = native.read_config("custom", "hockeyAppId")
    isInternalBuild = native.read_config("custom", "isInternalBuild")
    isAppStoreBuild = native.read_config("custom", "isAppStoreBuild")
    appStoreId = native.read_config("custom", "appStoreId")
    appSpecificUrlScheme = native.read_config("custom", "appSpecificUrlScheme")
    buildNumber = native.read_config("custom", "buildNumber")
    return {
        "apiId": apiId,
        "apiHash": apiHash,
        "hockeyAppId": hockeyAppId,
        "isInternalBuild": isInternalBuild,
        "isAppStoreBuild": isAppStoreBuild,
        "appStoreId": appStoreId,
        "appSpecificUrlScheme": appSpecificUrlScheme,
        "buildNumber": buildNumber,
    }
