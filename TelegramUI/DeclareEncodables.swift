import Postbox

private var telegramUIDeclaredEncodables: Void = {
    declareEncodable(InAppNotificationSettings.self, f: { InAppNotificationSettings(decoder: $0) })
    declareEncodable(ChatInterfaceState.self, f: { ChatInterfaceState(decoder: $0) })
    declareEncodable(ChatEmbeddedInterfaceState.self, f: { ChatEmbeddedInterfaceState(decoder: $0) })
    declareEncodable(VideoLibraryMediaResource.self, f: { VideoLibraryMediaResource(decoder: $0) })
    declareEncodable(LocalFileVideoMediaResource.self, f: { LocalFileVideoMediaResource(decoder: $0) })
    declareEncodable(LocalFileGifMediaResource.self, f: { LocalFileGifMediaResource(decoder: $0) })
    declareEncodable(PhotoLibraryMediaResource.self, f: { PhotoLibraryMediaResource(decoder: $0) })
    declareEncodable(PresentationPasscodeSettings.self, f: { PresentationPasscodeSettings(decoder: $0) })
    declareEncodable(AutomaticMediaDownloadSettings.self, f: { AutomaticMediaDownloadSettings(decoder: $0) })
    declareEncodable(GeneratedMediaStoreSettings.self, f: { GeneratedMediaStoreSettings(decoder: $0) })
    declareEncodable(PresentationThemeSettings.self, f: { PresentationThemeSettings(decoder: $0) })
    declareEncodable(ApplicationSpecificBoolNotice.self, f: { ApplicationSpecificBoolNotice(decoder: $0) })
    declareEncodable(ApplicationSpecificVariantNotice.self, f: { ApplicationSpecificVariantNotice(decoder: $0) })
    declareEncodable(ApplicationSpecificCounterNotice.self, f: { ApplicationSpecificCounterNotice(decoder: $0) })
    declareEncodable(ApplicationSpecificTimestampNotice.self, f: { ApplicationSpecificTimestampNotice(decoder: $0) })
    declareEncodable(CallListSettings.self, f: { CallListSettings(decoder: $0) })
    declareEncodable(VoiceCallSettings.self, f: { VoiceCallSettings(decoder: $0) })
    declareEncodable(ExperimentalSettings.self, f: { ExperimentalSettings(decoder: $0) })
    declareEncodable(ExperimentalUISettings.self, f: { ExperimentalUISettings(decoder: $0) })
    declareEncodable(MusicPlaybackSettings.self, f: { MusicPlaybackSettings(decoder: $0) })
    declareEncodable(ICloudFileResource.self, f: { ICloudFileResource(decoder: $0) })
    declareEncodable(MediaInputSettings.self, f: { MediaInputSettings(decoder: $0) })
    declareEncodable(ContactSynchronizationSettings.self, f: { ContactSynchronizationSettings(decoder: $0) })
    declareEncodable(CachedChannelAdminIds.self, f: { CachedChannelAdminIds(decoder: $0) })
    declareEncodable(StickerSettings.self, f: { StickerSettings(decoder: $0) })
    declareEncodable(InstantPagePresentationSettings.self, f: { InstantPagePresentationSettings(decoder: $0) })
    declareEncodable(InstantPageStoredState.self, f: { InstantPageStoredState(decoder: $0) })
    declareEncodable(InstantPageStoredDetailsState.self, f: { InstantPageStoredDetailsState(decoder: $0) })
    declareEncodable(WatchPresetSettings.self, f: { WatchPresetSettings(decoder: $0) })
    declareEncodable(WebSearchSettings.self, f: { WebSearchSettings(decoder: $0) })
    declareEncodable(RecentWebSearchQueryItem.self, f: { RecentWebSearchQueryItem(decoder: $0) })
    declareEncodable(VoipDerivedState.self, f: { VoipDerivedState(decoder: $0) })
    return
}()

public func telegramUIDeclareEncodables() {
    let _ = telegramUIDeclaredEncodables
}
