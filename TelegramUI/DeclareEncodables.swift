import Postbox

private var telegramUIDeclaredEncodables: Void = {
    declareEncodable(InAppNotificationSettings.self, f: { InAppNotificationSettings(decoder: $0) })
    declareEncodable(ChatInterfaceState.self, f: { ChatInterfaceState(decoder: $0) })
    declareEncodable(ChatEmbeddedInterfaceState.self, f: { ChatEmbeddedInterfaceState(decoder: $0) })
    declareEncodable(VideoLibraryMediaResource.self, f: { VideoLibraryMediaResource(decoder: $0) })
    declareEncodable(LocalFileVideoMediaResource.self, f: { LocalFileVideoMediaResource(decoder: $0) })
    declareEncodable(PhotoLibraryMediaResource.self, f: { PhotoLibraryMediaResource(decoder: $0) })
    declareEncodable(PresentationPasscodeSettings.self, f: { PresentationPasscodeSettings(decoder: $0) })
    declareEncodable(AutomaticMediaDownloadSettings.self, f: { AutomaticMediaDownloadSettings(decoder: $0) })
    declareEncodable(GeneratedMediaStoreSettings.self, f: { GeneratedMediaStoreSettings(decoder: $0) })
    declareEncodable(PresentationThemeSettings.self, f: { PresentationThemeSettings(decoder: $0) })
    declareEncodable(TelegramWallpaper.self, f: { TelegramWallpaper(decoder: $0) })
    declareEncodable(ApplicationSpecificBoolNotice.self, f: { ApplicationSpecificBoolNotice(decoder: $0) })
    declareEncodable(CallListSettings.self, f: { CallListSettings(decoder: $0) })
    declareEncodable(ExperimentalSettings.self, f: { ExperimentalSettings(decoder: $0) })
    declareEncodable(MusicPlaybackSettings.self, f: { MusicPlaybackSettings(decoder: $0) })
    return
}()

public func telegramUIDeclareEncodables() {
    let _ = telegramUIDeclaredEncodables
}
