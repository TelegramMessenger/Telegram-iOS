
public enum Api {
    public enum account {}
    public enum auth {}
    public enum bots {}
    public enum channels {}
    public enum chatlists {}
    public enum contacts {}
    public enum fragment {}
    public enum help {}
    public enum messages {}
    public enum payments {}
    public enum phone {}
    public enum photos {}
    public enum premium {}
    public enum smsjobs {}
    public enum stats {}
    public enum stickers {}
    public enum storage {}
    public enum stories {}
    public enum updates {}
    public enum upload {}
    public enum users {}
    public enum functions {
        public enum account {}
        public enum auth {}
        public enum bots {}
        public enum channels {}
        public enum chatlists {}
        public enum contacts {}
        public enum folders {}
        public enum fragment {}
        public enum help {}
        public enum langpack {}
        public enum messages {}
        public enum payments {}
        public enum phone {}
        public enum photos {}
        public enum premium {}
        public enum smsjobs {}
        public enum stats {}
        public enum stickers {}
        public enum stories {}
        public enum updates {}
        public enum upload {}
        public enum users {}
    }
}

fileprivate let parsers: [Int32 : (BufferReader) -> Any?] = {
    var dict: [Int32 : (BufferReader) -> Any?] = [:]
    dict[-1471112230] = { return $0.readInt32() }
    dict[570911930] = { return $0.readInt64() }
    dict[571523412] = { return $0.readDouble() }
    dict[0x0929C32F] = { return parseInt256($0) }
    dict[-1255641564] = { return parseString($0) }
    dict[-1194283041] = { return Api.AccountDaysTTL.parse_accountDaysTTL($0) }
    dict[-653423106] = { return Api.AttachMenuBot.parse_attachMenuBot($0) }
    dict[-1297663893] = { return Api.AttachMenuBotIcon.parse_attachMenuBotIcon($0) }
    dict[1165423600] = { return Api.AttachMenuBotIconColor.parse_attachMenuBotIconColor($0) }
    dict[1011024320] = { return Api.AttachMenuBots.parse_attachMenuBots($0) }
    dict[-237467044] = { return Api.AttachMenuBots.parse_attachMenuBotsNotModified($0) }
    dict[-1816172929] = { return Api.AttachMenuBotsBot.parse_attachMenuBotsBot($0) }
    dict[-1020528102] = { return Api.AttachMenuPeerType.parse_attachMenuPeerTypeBotPM($0) }
    dict[2080104188] = { return Api.AttachMenuPeerType.parse_attachMenuPeerTypeBroadcast($0) }
    dict[84480319] = { return Api.AttachMenuPeerType.parse_attachMenuPeerTypeChat($0) }
    dict[-247016673] = { return Api.AttachMenuPeerType.parse_attachMenuPeerTypePM($0) }
    dict[2104224014] = { return Api.AttachMenuPeerType.parse_attachMenuPeerTypeSameBotPM($0) }
    dict[-1392388579] = { return Api.Authorization.parse_authorization($0) }
    dict[-1163561432] = { return Api.AutoDownloadSettings.parse_autoDownloadSettings($0) }
    dict[-2124403385] = { return Api.AutoSaveException.parse_autoSaveException($0) }
    dict[-934791986] = { return Api.AutoSaveSettings.parse_autoSaveSettings($0) }
    dict[-1815879042] = { return Api.AvailableEffect.parse_availableEffect($0) }
    dict[-1065882623] = { return Api.AvailableReaction.parse_availableReaction($0) }
    dict[-177732982] = { return Api.BankCardOpenUrl.parse_bankCardOpenUrl($0) }
    dict[1527845466] = { return Api.BaseTheme.parse_baseThemeArctic($0) }
    dict[-1012849566] = { return Api.BaseTheme.parse_baseThemeClassic($0) }
    dict[-69724536] = { return Api.BaseTheme.parse_baseThemeDay($0) }
    dict[-1212997976] = { return Api.BaseTheme.parse_baseThemeNight($0) }
    dict[1834973166] = { return Api.BaseTheme.parse_baseThemeTinted($0) }
    dict[1821253126] = { return Api.Birthday.parse_birthday($0) }
    dict[-1132882121] = { return Api.Bool.parse_boolFalse($0) }
    dict[-1720552011] = { return Api.Bool.parse_boolTrue($0) }
    dict[1262359766] = { return Api.Boost.parse_boost($0) }
    dict[-1778593322] = { return Api.BotApp.parse_botApp($0) }
    dict[1571189943] = { return Api.BotApp.parse_botAppNotModified($0) }
    dict[-912582320] = { return Api.BotAppSettings.parse_botAppSettings($0) }
    dict[-1892371723] = { return Api.BotBusinessConnection.parse_botBusinessConnection($0) }
    dict[-1032140601] = { return Api.BotCommand.parse_botCommand($0) }
    dict[-1180016534] = { return Api.BotCommandScope.parse_botCommandScopeChatAdmins($0) }
    dict[1877059713] = { return Api.BotCommandScope.parse_botCommandScopeChats($0) }
    dict[795652779] = { return Api.BotCommandScope.parse_botCommandScopeDefault($0) }
    dict[-610432643] = { return Api.BotCommandScope.parse_botCommandScopePeer($0) }
    dict[1071145937] = { return Api.BotCommandScope.parse_botCommandScopePeerAdmins($0) }
    dict[169026035] = { return Api.BotCommandScope.parse_botCommandScopePeerUser($0) }
    dict[1011811544] = { return Api.BotCommandScope.parse_botCommandScopeUsers($0) }
    dict[1300890265] = { return Api.BotInfo.parse_botInfo($0) }
    dict[1984755728] = { return Api.BotInlineMessage.parse_botInlineMessageMediaAuto($0) }
    dict[416402882] = { return Api.BotInlineMessage.parse_botInlineMessageMediaContact($0) }
    dict[85477117] = { return Api.BotInlineMessage.parse_botInlineMessageMediaGeo($0) }
    dict[894081801] = { return Api.BotInlineMessage.parse_botInlineMessageMediaInvoice($0) }
    dict[-1970903652] = { return Api.BotInlineMessage.parse_botInlineMessageMediaVenue($0) }
    dict[-2137335386] = { return Api.BotInlineMessage.parse_botInlineMessageMediaWebPage($0) }
    dict[-1937807902] = { return Api.BotInlineMessage.parse_botInlineMessageText($0) }
    dict[400266251] = { return Api.BotInlineResult.parse_botInlineMediaResult($0) }
    dict[295067450] = { return Api.BotInlineResult.parse_botInlineResult($0) }
    dict[-944407322] = { return Api.BotMenuButton.parse_botMenuButton($0) }
    dict[1113113093] = { return Api.BotMenuButton.parse_botMenuButtonCommands($0) }
    dict[1966318984] = { return Api.BotMenuButton.parse_botMenuButtonDefault($0) }
    dict[602479523] = { return Api.BotPreviewMedia.parse_botPreviewMedia($0) }
    dict[-113453988] = { return Api.BotVerification.parse_botVerification($0) }
    dict[-1328716265] = { return Api.BotVerifierSettings.parse_botVerifierSettings($0) }
    dict[-1006669337] = { return Api.BroadcastRevenueBalances.parse_broadcastRevenueBalances($0) }
    dict[1434332356] = { return Api.BroadcastRevenueTransaction.parse_broadcastRevenueTransactionProceeds($0) }
    dict[1121127726] = { return Api.BroadcastRevenueTransaction.parse_broadcastRevenueTransactionRefund($0) }
    dict[1515784568] = { return Api.BroadcastRevenueTransaction.parse_broadcastRevenueTransactionWithdrawal($0) }
    dict[-283809188] = { return Api.BusinessAwayMessage.parse_businessAwayMessage($0) }
    dict[-910564679] = { return Api.BusinessAwayMessageSchedule.parse_businessAwayMessageScheduleAlways($0) }
    dict[-867328308] = { return Api.BusinessAwayMessageSchedule.parse_businessAwayMessageScheduleCustom($0) }
    dict[-1007487743] = { return Api.BusinessAwayMessageSchedule.parse_businessAwayMessageScheduleOutsideWorkHours($0) }
    dict[-1198722189] = { return Api.BusinessBotRecipients.parse_businessBotRecipients($0) }
    dict[-1604170505] = { return Api.BusinessBotRights.parse_businessBotRights($0) }
    dict[-1263638929] = { return Api.BusinessChatLink.parse_businessChatLink($0) }
    dict[-451302485] = { return Api.BusinessGreetingMessage.parse_businessGreetingMessage($0) }
    dict[1510606445] = { return Api.BusinessIntro.parse_businessIntro($0) }
    dict[-1403249929] = { return Api.BusinessLocation.parse_businessLocation($0) }
    dict[554733559] = { return Api.BusinessRecipients.parse_businessRecipients($0) }
    dict[302717625] = { return Api.BusinessWeeklyOpen.parse_businessWeeklyOpen($0) }
    dict[-1936543592] = { return Api.BusinessWorkHours.parse_businessWorkHours($0) }
    dict[1462101002] = { return Api.CdnConfig.parse_cdnConfig($0) }
    dict[-914167110] = { return Api.CdnPublicKey.parse_cdnPublicKey($0) }
    dict[531458253] = { return Api.ChannelAdminLogEvent.parse_channelAdminLogEvent($0) }
    dict[1427671598] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeAbout($0) }
    dict[-1102180616] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeAvailableReactions($0) }
    dict[1051328177] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeEmojiStatus($0) }
    dict[1188577451] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeEmojiStickerSet($0) }
    dict[1855199800] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeHistoryTTL($0) }
    dict[84703944] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeLinkedChat($0) }
    dict[241923758] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeLocation($0) }
    dict[1469507456] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangePeerColor($0) }
    dict[1129042607] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangePhoto($0) }
    dict[1581742885] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeProfilePeerColor($0) }
    dict[-1312568665] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeStickerSet($0) }
    dict[-421545947] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeTitle($0) }
    dict[1783299128] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeUsername($0) }
    dict[-263212119] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeUsernames($0) }
    dict[834362706] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionChangeWallpaper($0) }
    dict[1483767080] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionCreateTopic($0) }
    dict[771095562] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionDefaultBannedRights($0) }
    dict[1121994683] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionDeleteMessage($0) }
    dict[-1374254839] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionDeleteTopic($0) }
    dict[-610299584] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionDiscardGroupCall($0) }
    dict[1889215493] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionEditMessage($0) }
    dict[-261103096] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionEditTopic($0) }
    dict[1515256996] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionExportedInviteDelete($0) }
    dict[-384910503] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionExportedInviteEdit($0) }
    dict[1091179342] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionExportedInviteRevoke($0) }
    dict[-484690728] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantInvite($0) }
    dict[405815507] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantJoin($0) }
    dict[-23084712] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantJoinByInvite($0) }
    dict[-1347021750] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantJoinByRequest($0) }
    dict[-124291086] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantLeave($0) }
    dict[-115071790] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantMute($0) }
    dict[1684286899] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantSubExtend($0) }
    dict[-714643696] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantToggleAdmin($0) }
    dict[-422036098] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantToggleBan($0) }
    dict[-431740480] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantUnmute($0) }
    dict[1048537159] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionParticipantVolume($0) }
    dict[1569535291] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionPinTopic($0) }
    dict[663693416] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionSendMessage($0) }
    dict[589338437] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionStartGroupCall($0) }
    dict[-1895328189] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionStopPoll($0) }
    dict[1693675004] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionToggleAntiSpam($0) }
    dict[-988285058] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionToggleAutotranslation($0) }
    dict[46949251] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionToggleForum($0) }
    dict[1456906823] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionToggleGroupCallSetting($0) }
    dict[460916654] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionToggleInvites($0) }
    dict[-886388890] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionToggleNoForwards($0) }
    dict[1599903217] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionTogglePreHistoryHidden($0) }
    dict[1621597305] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionToggleSignatureProfiles($0) }
    dict[648939889] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionToggleSignatures($0) }
    dict[1401984889] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionToggleSlowMode($0) }
    dict[-370660328] = { return Api.ChannelAdminLogEventAction.parse_channelAdminLogEventActionUpdatePinned($0) }
    dict[-368018716] = { return Api.ChannelAdminLogEventsFilter.parse_channelAdminLogEventsFilter($0) }
    dict[547062491] = { return Api.ChannelLocation.parse_channelLocation($0) }
    dict[-1078612597] = { return Api.ChannelLocation.parse_channelLocationEmpty($0) }
    dict[-847783593] = { return Api.ChannelMessagesFilter.parse_channelMessagesFilter($0) }
    dict[-1798033689] = { return Api.ChannelMessagesFilter.parse_channelMessagesFilterEmpty($0) }
    dict[-885426663] = { return Api.ChannelParticipant.parse_channelParticipant($0) }
    dict[885242707] = { return Api.ChannelParticipant.parse_channelParticipantAdmin($0) }
    dict[1844969806] = { return Api.ChannelParticipant.parse_channelParticipantBanned($0) }
    dict[803602899] = { return Api.ChannelParticipant.parse_channelParticipantCreator($0) }
    dict[453242886] = { return Api.ChannelParticipant.parse_channelParticipantLeft($0) }
    dict[1331723247] = { return Api.ChannelParticipant.parse_channelParticipantSelf($0) }
    dict[-1268741783] = { return Api.ChannelParticipantsFilter.parse_channelParticipantsAdmins($0) }
    dict[338142689] = { return Api.ChannelParticipantsFilter.parse_channelParticipantsBanned($0) }
    dict[-1328445861] = { return Api.ChannelParticipantsFilter.parse_channelParticipantsBots($0) }
    dict[-1150621555] = { return Api.ChannelParticipantsFilter.parse_channelParticipantsContacts($0) }
    dict[-1548400251] = { return Api.ChannelParticipantsFilter.parse_channelParticipantsKicked($0) }
    dict[-531931925] = { return Api.ChannelParticipantsFilter.parse_channelParticipantsMentions($0) }
    dict[-566281095] = { return Api.ChannelParticipantsFilter.parse_channelParticipantsRecent($0) }
    dict[106343499] = { return Api.ChannelParticipantsFilter.parse_channelParticipantsSearch($0) }
    dict[-26717355] = { return Api.Chat.parse_channel($0) }
    dict[399807445] = { return Api.Chat.parse_channelForbidden($0) }
    dict[1103884886] = { return Api.Chat.parse_chat($0) }
    dict[693512293] = { return Api.Chat.parse_chatEmpty($0) }
    dict[1704108455] = { return Api.Chat.parse_chatForbidden($0) }
    dict[1605510357] = { return Api.ChatAdminRights.parse_chatAdminRights($0) }
    dict[-219353309] = { return Api.ChatAdminWithInvites.parse_chatAdminWithInvites($0) }
    dict[-1626209256] = { return Api.ChatBannedRights.parse_chatBannedRights($0) }
    dict[1389789291] = { return Api.ChatFull.parse_channelFull($0) }
    dict[640893467] = { return Api.ChatFull.parse_chatFull($0) }
    dict[1553807106] = { return Api.ChatInvite.parse_chatInvite($0) }
    dict[1516793212] = { return Api.ChatInvite.parse_chatInviteAlready($0) }
    dict[1634294960] = { return Api.ChatInvite.parse_chatInvitePeek($0) }
    dict[-1940201511] = { return Api.ChatInviteImporter.parse_chatInviteImporter($0) }
    dict[-264117680] = { return Api.ChatOnlines.parse_chatOnlines($0) }
    dict[-1070776313] = { return Api.ChatParticipant.parse_chatParticipant($0) }
    dict[-1600962725] = { return Api.ChatParticipant.parse_chatParticipantAdmin($0) }
    dict[-462696732] = { return Api.ChatParticipant.parse_chatParticipantCreator($0) }
    dict[1018991608] = { return Api.ChatParticipants.parse_chatParticipants($0) }
    dict[-2023500831] = { return Api.ChatParticipants.parse_chatParticipantsForbidden($0) }
    dict[476978193] = { return Api.ChatPhoto.parse_chatPhoto($0) }
    dict[935395612] = { return Api.ChatPhoto.parse_chatPhotoEmpty($0) }
    dict[1385335754] = { return Api.ChatReactions.parse_chatReactionsAll($0) }
    dict[-352570692] = { return Api.ChatReactions.parse_chatReactionsNone($0) }
    dict[1713193015] = { return Api.ChatReactions.parse_chatReactionsSome($0) }
    dict[-1390068360] = { return Api.CodeSettings.parse_codeSettings($0) }
    dict[-870702050] = { return Api.Config.parse_config($0) }
    dict[-849058964] = { return Api.ConnectedBot.parse_connectedBot($0) }
    dict[429997937] = { return Api.ConnectedBotStarRef.parse_connectedBotStarRef($0) }
    dict[341499403] = { return Api.Contact.parse_contact($0) }
    dict[496600883] = { return Api.ContactBirthday.parse_contactBirthday($0) }
    dict[383348795] = { return Api.ContactStatus.parse_contactStatus($0) }
    dict[2104790276] = { return Api.DataJSON.parse_dataJSON($0) }
    dict[414687501] = { return Api.DcOption.parse_dcOption($0) }
    dict[1135897376] = { return Api.DefaultHistoryTTL.parse_defaultHistoryTTL($0) }
    dict[-712374074] = { return Api.Dialog.parse_dialog($0) }
    dict[1908216652] = { return Api.Dialog.parse_dialogFolder($0) }
    dict[-1438177711] = { return Api.DialogFilter.parse_dialogFilter($0) }
    dict[-1772913705] = { return Api.DialogFilter.parse_dialogFilterChatlist($0) }
    dict[909284270] = { return Api.DialogFilter.parse_dialogFilterDefault($0) }
    dict[2004110666] = { return Api.DialogFilterSuggested.parse_dialogFilterSuggested($0) }
    dict[-445792507] = { return Api.DialogPeer.parse_dialogPeer($0) }
    dict[1363483106] = { return Api.DialogPeer.parse_dialogPeerFolder($0) }
    dict[1911715524] = { return Api.DisallowedGiftsSettings.parse_disallowedGiftsSettings($0) }
    dict[-1881881384] = { return Api.Document.parse_document($0) }
    dict[922273905] = { return Api.Document.parse_documentEmpty($0) }
    dict[297109817] = { return Api.DocumentAttribute.parse_documentAttributeAnimated($0) }
    dict[-1739392570] = { return Api.DocumentAttribute.parse_documentAttributeAudio($0) }
    dict[-48981863] = { return Api.DocumentAttribute.parse_documentAttributeCustomEmoji($0) }
    dict[358154344] = { return Api.DocumentAttribute.parse_documentAttributeFilename($0) }
    dict[-1744710921] = { return Api.DocumentAttribute.parse_documentAttributeHasStickers($0) }
    dict[1815593308] = { return Api.DocumentAttribute.parse_documentAttributeImageSize($0) }
    dict[1662637586] = { return Api.DocumentAttribute.parse_documentAttributeSticker($0) }
    dict[1137015880] = { return Api.DocumentAttribute.parse_documentAttributeVideo($0) }
    dict[761606687] = { return Api.DraftMessage.parse_draftMessage($0) }
    dict[453805082] = { return Api.DraftMessage.parse_draftMessageEmpty($0) }
    dict[-1764723459] = { return Api.EmailVerification.parse_emailVerificationApple($0) }
    dict[-1842457175] = { return Api.EmailVerification.parse_emailVerificationCode($0) }
    dict[-611279166] = { return Api.EmailVerification.parse_emailVerificationGoogle($0) }
    dict[1383932651] = { return Api.EmailVerifyPurpose.parse_emailVerifyPurposeLoginChange($0) }
    dict[1128644211] = { return Api.EmailVerifyPurpose.parse_emailVerifyPurposeLoginSetup($0) }
    dict[-1141565819] = { return Api.EmailVerifyPurpose.parse_emailVerifyPurposePassport($0) }
    dict[2056961449] = { return Api.EmojiGroup.parse_emojiGroup($0) }
    dict[-2133693241] = { return Api.EmojiGroup.parse_emojiGroupGreeting($0) }
    dict[154914612] = { return Api.EmojiGroup.parse_emojiGroupPremium($0) }
    dict[-709641735] = { return Api.EmojiKeyword.parse_emojiKeyword($0) }
    dict[594408994] = { return Api.EmojiKeyword.parse_emojiKeywordDeleted($0) }
    dict[1556570557] = { return Api.EmojiKeywordsDifference.parse_emojiKeywordsDifference($0) }
    dict[-1275374751] = { return Api.EmojiLanguage.parse_emojiLanguage($0) }
    dict[2048790993] = { return Api.EmojiList.parse_emojiList($0) }
    dict[1209970170] = { return Api.EmojiList.parse_emojiListNotModified($0) }
    dict[-402717046] = { return Api.EmojiStatus.parse_emojiStatus($0) }
    dict[1904500795] = { return Api.EmojiStatus.parse_emojiStatusCollectible($0) }
    dict[769727150] = { return Api.EmojiStatus.parse_emojiStatusEmpty($0) }
    dict[118758847] = { return Api.EmojiStatus.parse_inputEmojiStatusCollectible($0) }
    dict[-1519029347] = { return Api.EmojiURL.parse_emojiURL($0) }
    dict[1643173063] = { return Api.EncryptedChat.parse_encryptedChat($0) }
    dict[505183301] = { return Api.EncryptedChat.parse_encryptedChatDiscarded($0) }
    dict[-1417756512] = { return Api.EncryptedChat.parse_encryptedChatEmpty($0) }
    dict[1223809356] = { return Api.EncryptedChat.parse_encryptedChatRequested($0) }
    dict[1722964307] = { return Api.EncryptedChat.parse_encryptedChatWaiting($0) }
    dict[-1476358952] = { return Api.EncryptedFile.parse_encryptedFile($0) }
    dict[-1038136962] = { return Api.EncryptedFile.parse_encryptedFileEmpty($0) }
    dict[-317144808] = { return Api.EncryptedMessage.parse_encryptedMessage($0) }
    dict[594758406] = { return Api.EncryptedMessage.parse_encryptedMessageService($0) }
    dict[-1574126186] = { return Api.ExportedChatInvite.parse_chatInviteExported($0) }
    dict[-317687113] = { return Api.ExportedChatInvite.parse_chatInvitePublicJoinRequests($0) }
    dict[206668204] = { return Api.ExportedChatlistInvite.parse_exportedChatlistInvite($0) }
    dict[1103040667] = { return Api.ExportedContactToken.parse_exportedContactToken($0) }
    dict[1571494644] = { return Api.ExportedMessageLink.parse_exportedMessageLink($0) }
    dict[1070138683] = { return Api.ExportedStoryLink.parse_exportedStoryLink($0) }
    dict[-1197736753] = { return Api.FactCheck.parse_factCheck($0) }
    dict[-207944868] = { return Api.FileHash.parse_fileHash($0) }
    dict[-11252123] = { return Api.Folder.parse_folder($0) }
    dict[-373643672] = { return Api.FolderPeer.parse_folderPeer($0) }
    dict[1903173033] = { return Api.ForumTopic.parse_forumTopic($0) }
    dict[37687451] = { return Api.ForumTopic.parse_forumTopicDeleted($0) }
    dict[-394605632] = { return Api.FoundStory.parse_foundStory($0) }
    dict[-1107729093] = { return Api.Game.parse_game($0) }
    dict[-1297942941] = { return Api.GeoPoint.parse_geoPoint($0) }
    dict[286776671] = { return Api.GeoPoint.parse_geoPointEmpty($0) }
    dict[-565420653] = { return Api.GeoPointAddress.parse_geoPointAddress($0) }
    dict[-29248689] = { return Api.GlobalPrivacySettings.parse_globalPrivacySettings($0) }
    dict[1429932961] = { return Api.GroupCall.parse_groupCall($0) }
    dict[2004925620] = { return Api.GroupCall.parse_groupCallDiscarded($0) }
    dict[-341428482] = { return Api.GroupCallParticipant.parse_groupCallParticipant($0) }
    dict[1735736008] = { return Api.GroupCallParticipantVideo.parse_groupCallParticipantVideo($0) }
    dict[-592373577] = { return Api.GroupCallParticipantVideoSourceGroup.parse_groupCallParticipantVideoSourceGroup($0) }
    dict[-2132064081] = { return Api.GroupCallStreamChannel.parse_groupCallStreamChannel($0) }
    dict[1940093419] = { return Api.HighScore.parse_highScore($0) }
    dict[-1052885936] = { return Api.ImportedContact.parse_importedContact($0) }
    dict[1008755359] = { return Api.InlineBotSwitchPM.parse_inlineBotSwitchPM($0) }
    dict[-1250781739] = { return Api.InlineBotWebView.parse_inlineBotWebView($0) }
    dict[238759180] = { return Api.InlineQueryPeerType.parse_inlineQueryPeerTypeBotPM($0) }
    dict[1664413338] = { return Api.InlineQueryPeerType.parse_inlineQueryPeerTypeBroadcast($0) }
    dict[-681130742] = { return Api.InlineQueryPeerType.parse_inlineQueryPeerTypeChat($0) }
    dict[1589952067] = { return Api.InlineQueryPeerType.parse_inlineQueryPeerTypeMegagroup($0) }
    dict[-2093215828] = { return Api.InlineQueryPeerType.parse_inlineQueryPeerTypePM($0) }
    dict[813821341] = { return Api.InlineQueryPeerType.parse_inlineQueryPeerTypeSameBotPM($0) }
    dict[488313413] = { return Api.InputAppEvent.parse_inputAppEvent($0) }
    dict[-1457472134] = { return Api.InputBotApp.parse_inputBotAppID($0) }
    dict[-1869872121] = { return Api.InputBotApp.parse_inputBotAppShortName($0) }
    dict[1262639204] = { return Api.InputBotInlineMessage.parse_inputBotInlineMessageGame($0) }
    dict[864077702] = { return Api.InputBotInlineMessage.parse_inputBotInlineMessageMediaAuto($0) }
    dict[-1494368259] = { return Api.InputBotInlineMessage.parse_inputBotInlineMessageMediaContact($0) }
    dict[-1768777083] = { return Api.InputBotInlineMessage.parse_inputBotInlineMessageMediaGeo($0) }
    dict[-672693723] = { return Api.InputBotInlineMessage.parse_inputBotInlineMessageMediaInvoice($0) }
    dict[1098628881] = { return Api.InputBotInlineMessage.parse_inputBotInlineMessageMediaVenue($0) }
    dict[-1109605104] = { return Api.InputBotInlineMessage.parse_inputBotInlineMessageMediaWebPage($0) }
    dict[1036876423] = { return Api.InputBotInlineMessage.parse_inputBotInlineMessageText($0) }
    dict[-1995686519] = { return Api.InputBotInlineMessageID.parse_inputBotInlineMessageID($0) }
    dict[-1227287081] = { return Api.InputBotInlineMessageID.parse_inputBotInlineMessageID64($0) }
    dict[-2000710887] = { return Api.InputBotInlineResult.parse_inputBotInlineResult($0) }
    dict[-459324] = { return Api.InputBotInlineResult.parse_inputBotInlineResultDocument($0) }
    dict[1336154098] = { return Api.InputBotInlineResult.parse_inputBotInlineResultGame($0) }
    dict[-1462213465] = { return Api.InputBotInlineResult.parse_inputBotInlineResultPhoto($0) }
    dict[-2094959136] = { return Api.InputBusinessAwayMessage.parse_inputBusinessAwayMessage($0) }
    dict[-991587810] = { return Api.InputBusinessBotRecipients.parse_inputBusinessBotRecipients($0) }
    dict[292003751] = { return Api.InputBusinessChatLink.parse_inputBusinessChatLink($0) }
    dict[26528571] = { return Api.InputBusinessGreetingMessage.parse_inputBusinessGreetingMessage($0) }
    dict[163867085] = { return Api.InputBusinessIntro.parse_inputBusinessIntro($0) }
    dict[1871393450] = { return Api.InputBusinessRecipients.parse_inputBusinessRecipients($0) }
    dict[-212145112] = { return Api.InputChannel.parse_inputChannel($0) }
    dict[-292807034] = { return Api.InputChannel.parse_inputChannelEmpty($0) }
    dict[1536380829] = { return Api.InputChannel.parse_inputChannelFromMessage($0) }
    dict[-1991004873] = { return Api.InputChatPhoto.parse_inputChatPhoto($0) }
    dict[480546647] = { return Api.InputChatPhoto.parse_inputChatPhotoEmpty($0) }
    dict[-1110593856] = { return Api.InputChatPhoto.parse_inputChatUploadedPhoto($0) }
    dict[-203367885] = { return Api.InputChatlist.parse_inputChatlistDialogFilter($0) }
    dict[-1736378792] = { return Api.InputCheckPasswordSRP.parse_inputCheckPasswordEmpty($0) }
    dict[-763367294] = { return Api.InputCheckPasswordSRP.parse_inputCheckPasswordSRP($0) }
    dict[1968737087] = { return Api.InputClientProxy.parse_inputClientProxy($0) }
    dict[-1562241884] = { return Api.InputCollectible.parse_inputCollectiblePhone($0) }
    dict[-476815191] = { return Api.InputCollectible.parse_inputCollectibleUsername($0) }
    dict[-208488460] = { return Api.InputContact.parse_inputPhoneContact($0) }
    dict[-55902537] = { return Api.InputDialogPeer.parse_inputDialogPeer($0) }
    dict[1684014375] = { return Api.InputDialogPeer.parse_inputDialogPeerFolder($0) }
    dict[448771445] = { return Api.InputDocument.parse_inputDocument($0) }
    dict[1928391342] = { return Api.InputDocument.parse_inputDocumentEmpty($0) }
    dict[-247351839] = { return Api.InputEncryptedChat.parse_inputEncryptedChat($0) }
    dict[1511503333] = { return Api.InputEncryptedFile.parse_inputEncryptedFile($0) }
    dict[767652808] = { return Api.InputEncryptedFile.parse_inputEncryptedFileBigUploaded($0) }
    dict[406307684] = { return Api.InputEncryptedFile.parse_inputEncryptedFileEmpty($0) }
    dict[1690108678] = { return Api.InputEncryptedFile.parse_inputEncryptedFileUploaded($0) }
    dict[-181407105] = { return Api.InputFile.parse_inputFile($0) }
    dict[-95482955] = { return Api.InputFile.parse_inputFileBig($0) }
    dict[1658620744] = { return Api.InputFile.parse_inputFileStoryDocument($0) }
    dict[-1160743548] = { return Api.InputFileLocation.parse_inputDocumentFileLocation($0) }
    dict[-182231723] = { return Api.InputFileLocation.parse_inputEncryptedFileLocation($0) }
    dict[-539317279] = { return Api.InputFileLocation.parse_inputFileLocation($0) }
    dict[93890858] = { return Api.InputFileLocation.parse_inputGroupCallStream($0) }
    dict[925204121] = { return Api.InputFileLocation.parse_inputPeerPhotoFileLocation($0) }
    dict[1075322878] = { return Api.InputFileLocation.parse_inputPhotoFileLocation($0) }
    dict[-667654413] = { return Api.InputFileLocation.parse_inputPhotoLegacyFileLocation($0) }
    dict[-876089816] = { return Api.InputFileLocation.parse_inputSecureFileLocation($0) }
    dict[-1652231205] = { return Api.InputFileLocation.parse_inputStickerSetThumb($0) }
    dict[700340377] = { return Api.InputFileLocation.parse_inputTakeoutFileLocation($0) }
    dict[-70073706] = { return Api.InputFolderPeer.parse_inputFolderPeer($0) }
    dict[53231223] = { return Api.InputGame.parse_inputGameID($0) }
    dict[-1020139510] = { return Api.InputGame.parse_inputGameShortName($0) }
    dict[1210199983] = { return Api.InputGeoPoint.parse_inputGeoPoint($0) }
    dict[-457104426] = { return Api.InputGeoPoint.parse_inputGeoPointEmpty($0) }
    dict[-659913713] = { return Api.InputGroupCall.parse_inputGroupCall($0) }
    dict[-1945083841] = { return Api.InputGroupCall.parse_inputGroupCallInviteMessage($0) }
    dict[-33127873] = { return Api.InputGroupCall.parse_inputGroupCallSlug($0) }
    dict[-191267262] = { return Api.InputInvoice.parse_inputInvoiceBusinessBotTransferStars($0) }
    dict[887591921] = { return Api.InputInvoice.parse_inputInvoiceChatInviteSubscription($0) }
    dict[-977967015] = { return Api.InputInvoice.parse_inputInvoiceMessage($0) }
    dict[-1734841331] = { return Api.InputInvoice.parse_inputInvoicePremiumGiftCode($0) }
    dict[-625298705] = { return Api.InputInvoice.parse_inputInvoicePremiumGiftStars($0) }
    dict[-1020867857] = { return Api.InputInvoice.parse_inputInvoiceSlug($0) }
    dict[-396206446] = { return Api.InputInvoice.parse_inputInvoiceStarGift($0) }
    dict[1674298252] = { return Api.InputInvoice.parse_inputInvoiceStarGiftResale($0) }
    dict[1247763417] = { return Api.InputInvoice.parse_inputInvoiceStarGiftTransfer($0) }
    dict[1300335965] = { return Api.InputInvoice.parse_inputInvoiceStarGiftUpgrade($0) }
    dict[1710230755] = { return Api.InputInvoice.parse_inputInvoiceStars($0) }
    dict[-122978821] = { return Api.InputMedia.parse_inputMediaContact($0) }
    dict[-428884101] = { return Api.InputMedia.parse_inputMediaDice($0) }
    dict[-1468646731] = { return Api.InputMedia.parse_inputMediaDocument($0) }
    dict[2006319353] = { return Api.InputMedia.parse_inputMediaDocumentExternal($0) }
    dict[-1771768449] = { return Api.InputMedia.parse_inputMediaEmpty($0) }
    dict[-750828557] = { return Api.InputMedia.parse_inputMediaGame($0) }
    dict[-1759532989] = { return Api.InputMedia.parse_inputMediaGeoLive($0) }
    dict[-104578748] = { return Api.InputMedia.parse_inputMediaGeoPoint($0) }
    dict[1080028941] = { return Api.InputMedia.parse_inputMediaInvoice($0) }
    dict[-1005571194] = { return Api.InputMedia.parse_inputMediaPaidMedia($0) }
    dict[-1279654347] = { return Api.InputMedia.parse_inputMediaPhoto($0) }
    dict[-440664550] = { return Api.InputMedia.parse_inputMediaPhotoExternal($0) }
    dict[261416433] = { return Api.InputMedia.parse_inputMediaPoll($0) }
    dict[-1979852936] = { return Api.InputMedia.parse_inputMediaStory($0) }
    dict[58495792] = { return Api.InputMedia.parse_inputMediaUploadedDocument($0) }
    dict[505969924] = { return Api.InputMedia.parse_inputMediaUploadedPhoto($0) }
    dict[-1052959727] = { return Api.InputMedia.parse_inputMediaVenue($0) }
    dict[-1038383031] = { return Api.InputMedia.parse_inputMediaWebPage($0) }
    dict[-1392895362] = { return Api.InputMessage.parse_inputMessageCallbackQuery($0) }
    dict[-1502174430] = { return Api.InputMessage.parse_inputMessageID($0) }
    dict[-2037963464] = { return Api.InputMessage.parse_inputMessagePinned($0) }
    dict[-1160215659] = { return Api.InputMessage.parse_inputMessageReplyTo($0) }
    dict[-1311015810] = { return Api.InputNotifyPeer.parse_inputNotifyBroadcasts($0) }
    dict[1251338318] = { return Api.InputNotifyPeer.parse_inputNotifyChats($0) }
    dict[1548122514] = { return Api.InputNotifyPeer.parse_inputNotifyForumTopic($0) }
    dict[-1195615476] = { return Api.InputNotifyPeer.parse_inputNotifyPeer($0) }
    dict[423314455] = { return Api.InputNotifyPeer.parse_inputNotifyUsers($0) }
    dict[873977640] = { return Api.InputPaymentCredentials.parse_inputPaymentCredentials($0) }
    dict[178373535] = { return Api.InputPaymentCredentials.parse_inputPaymentCredentialsApplePay($0) }
    dict[-1966921727] = { return Api.InputPaymentCredentials.parse_inputPaymentCredentialsGooglePay($0) }
    dict[-1056001329] = { return Api.InputPaymentCredentials.parse_inputPaymentCredentialsSaved($0) }
    dict[666680316] = { return Api.InputPeer.parse_inputPeerChannel($0) }
    dict[-1121318848] = { return Api.InputPeer.parse_inputPeerChannelFromMessage($0) }
    dict[900291769] = { return Api.InputPeer.parse_inputPeerChat($0) }
    dict[2134579434] = { return Api.InputPeer.parse_inputPeerEmpty($0) }
    dict[2107670217] = { return Api.InputPeer.parse_inputPeerSelf($0) }
    dict[-571955892] = { return Api.InputPeer.parse_inputPeerUser($0) }
    dict[-1468331492] = { return Api.InputPeer.parse_inputPeerUserFromMessage($0) }
    dict[-892638494] = { return Api.InputPeerNotifySettings.parse_inputPeerNotifySettings($0) }
    dict[506920429] = { return Api.InputPhoneCall.parse_inputPhoneCall($0) }
    dict[1001634122] = { return Api.InputPhoto.parse_inputPhoto($0) }
    dict[483901197] = { return Api.InputPhoto.parse_inputPhotoEmpty($0) }
    dict[941870144] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyAbout($0) }
    dict[-786326563] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyAddedByPhone($0) }
    dict[-698740276] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyBirthday($0) }
    dict[-1107622874] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyChatInvite($0) }
    dict[-1529000952] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyForwards($0) }
    dict[-1111124044] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyNoPaidMessages($0) }
    dict[-88417185] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyPhoneCall($0) }
    dict[55761658] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyPhoneNumber($0) }
    dict[-610373422] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyPhoneP2P($0) }
    dict[1461304012] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyProfilePhoto($0) }
    dict[-512548031] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyStarGiftsAutoSave($0) }
    dict[1335282456] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyStatusTimestamp($0) }
    dict[-1360618136] = { return Api.InputPrivacyKey.parse_inputPrivacyKeyVoiceMessages($0) }
    dict[407582158] = { return Api.InputPrivacyRule.parse_inputPrivacyValueAllowAll($0) }
    dict[1515179237] = { return Api.InputPrivacyRule.parse_inputPrivacyValueAllowBots($0) }
    dict[-2079962673] = { return Api.InputPrivacyRule.parse_inputPrivacyValueAllowChatParticipants($0) }
    dict[793067081] = { return Api.InputPrivacyRule.parse_inputPrivacyValueAllowCloseFriends($0) }
    dict[218751099] = { return Api.InputPrivacyRule.parse_inputPrivacyValueAllowContacts($0) }
    dict[2009975281] = { return Api.InputPrivacyRule.parse_inputPrivacyValueAllowPremium($0) }
    dict[320652927] = { return Api.InputPrivacyRule.parse_inputPrivacyValueAllowUsers($0) }
    dict[-697604407] = { return Api.InputPrivacyRule.parse_inputPrivacyValueDisallowAll($0) }
    dict[-991594219] = { return Api.InputPrivacyRule.parse_inputPrivacyValueDisallowBots($0) }
    dict[-380694650] = { return Api.InputPrivacyRule.parse_inputPrivacyValueDisallowChatParticipants($0) }
    dict[195371015] = { return Api.InputPrivacyRule.parse_inputPrivacyValueDisallowContacts($0) }
    dict[-1877932953] = { return Api.InputPrivacyRule.parse_inputPrivacyValueDisallowUsers($0) }
    dict[609840449] = { return Api.InputQuickReplyShortcut.parse_inputQuickReplyShortcut($0) }
    dict[18418929] = { return Api.InputQuickReplyShortcut.parse_inputQuickReplyShortcutId($0) }
    dict[-1334822736] = { return Api.InputReplyTo.parse_inputReplyToMessage($0) }
    dict[1775660101] = { return Api.InputReplyTo.parse_inputReplyToMonoForum($0) }
    dict[1484862010] = { return Api.InputReplyTo.parse_inputReplyToStory($0) }
    dict[-251549057] = { return Api.InputSavedStarGift.parse_inputSavedStarGiftChat($0) }
    dict[545636920] = { return Api.InputSavedStarGift.parse_inputSavedStarGiftSlug($0) }
    dict[1764202389] = { return Api.InputSavedStarGift.parse_inputSavedStarGiftUser($0) }
    dict[1399317950] = { return Api.InputSecureFile.parse_inputSecureFile($0) }
    dict[859091184] = { return Api.InputSecureFile.parse_inputSecureFileUploaded($0) }
    dict[-618540889] = { return Api.InputSecureValue.parse_inputSecureValue($0) }
    dict[482797855] = { return Api.InputSingleMedia.parse_inputSingleMedia($0) }
    dict[543876817] = { return Api.InputStarsTransaction.parse_inputStarsTransaction($0) }
    dict[42402760] = { return Api.InputStickerSet.parse_inputStickerSetAnimatedEmoji($0) }
    dict[215889721] = { return Api.InputStickerSet.parse_inputStickerSetAnimatedEmojiAnimations($0) }
    dict[-427863538] = { return Api.InputStickerSet.parse_inputStickerSetDice($0) }
    dict[1232373075] = { return Api.InputStickerSet.parse_inputStickerSetEmojiChannelDefaultStatuses($0) }
    dict[701560302] = { return Api.InputStickerSet.parse_inputStickerSetEmojiDefaultStatuses($0) }
    dict[1153562857] = { return Api.InputStickerSet.parse_inputStickerSetEmojiDefaultTopicIcons($0) }
    dict[80008398] = { return Api.InputStickerSet.parse_inputStickerSetEmojiGenericAnimations($0) }
    dict[-4838507] = { return Api.InputStickerSet.parse_inputStickerSetEmpty($0) }
    dict[-1645763991] = { return Api.InputStickerSet.parse_inputStickerSetID($0) }
    dict[-930399486] = { return Api.InputStickerSet.parse_inputStickerSetPremiumGifts($0) }
    dict[-2044933984] = { return Api.InputStickerSet.parse_inputStickerSetShortName($0) }
    dict[853188252] = { return Api.InputStickerSetItem.parse_inputStickerSetItem($0) }
    dict[70813275] = { return Api.InputStickeredMedia.parse_inputStickeredMediaDocument($0) }
    dict[1251549527] = { return Api.InputStickeredMedia.parse_inputStickeredMediaPhoto($0) }
    dict[-1682807955] = { return Api.InputStorePaymentPurpose.parse_inputStorePaymentAuthCode($0) }
    dict[1634697192] = { return Api.InputStorePaymentPurpose.parse_inputStorePaymentGiftPremium($0) }
    dict[-75955309] = { return Api.InputStorePaymentPurpose.parse_inputStorePaymentPremiumGiftCode($0) }
    dict[369444042] = { return Api.InputStorePaymentPurpose.parse_inputStorePaymentPremiumGiveaway($0) }
    dict[-1502273946] = { return Api.InputStorePaymentPurpose.parse_inputStorePaymentPremiumSubscription($0) }
    dict[494149367] = { return Api.InputStorePaymentPurpose.parse_inputStorePaymentStarsGift($0) }
    dict[1964968186] = { return Api.InputStorePaymentPurpose.parse_inputStorePaymentStarsGiveaway($0) }
    dict[-572715178] = { return Api.InputStorePaymentPurpose.parse_inputStorePaymentStarsTopup($0) }
    dict[1012306921] = { return Api.InputTheme.parse_inputTheme($0) }
    dict[-175567375] = { return Api.InputTheme.parse_inputThemeSlug($0) }
    dict[-1881255857] = { return Api.InputThemeSettings.parse_inputThemeSettings($0) }
    dict[-233744186] = { return Api.InputUser.parse_inputUser($0) }
    dict[-1182234929] = { return Api.InputUser.parse_inputUserEmpty($0) }
    dict[497305826] = { return Api.InputUser.parse_inputUserFromMessage($0) }
    dict[-138301121] = { return Api.InputUser.parse_inputUserSelf($0) }
    dict[-433014407] = { return Api.InputWallPaper.parse_inputWallPaper($0) }
    dict[-1770371538] = { return Api.InputWallPaper.parse_inputWallPaperNoFile($0) }
    dict[1913199744] = { return Api.InputWallPaper.parse_inputWallPaperSlug($0) }
    dict[-1678949555] = { return Api.InputWebDocument.parse_inputWebDocument($0) }
    dict[-193992412] = { return Api.InputWebFileLocation.parse_inputWebFileAudioAlbumThumbLocation($0) }
    dict[-1625153079] = { return Api.InputWebFileLocation.parse_inputWebFileGeoPointLocation($0) }
    dict[-1036396922] = { return Api.InputWebFileLocation.parse_inputWebFileLocation($0) }
    dict[77522308] = { return Api.Invoice.parse_invoice($0) }
    dict[-1059185703] = { return Api.JSONObjectValue.parse_jsonObjectValue($0) }
    dict[-146520221] = { return Api.JSONValue.parse_jsonArray($0) }
    dict[-952869270] = { return Api.JSONValue.parse_jsonBool($0) }
    dict[1064139624] = { return Api.JSONValue.parse_jsonNull($0) }
    dict[736157604] = { return Api.JSONValue.parse_jsonNumber($0) }
    dict[-1715350371] = { return Api.JSONValue.parse_jsonObject($0) }
    dict[-1222740358] = { return Api.JSONValue.parse_jsonString($0) }
    dict[-916050683] = { return Api.KeyboardButton.parse_inputKeyboardButtonRequestPeer($0) }
    dict[-802258988] = { return Api.KeyboardButton.parse_inputKeyboardButtonUrlAuth($0) }
    dict[-376962181] = { return Api.KeyboardButton.parse_inputKeyboardButtonUserProfile($0) }
    dict[-1560655744] = { return Api.KeyboardButton.parse_keyboardButton($0) }
    dict[-1344716869] = { return Api.KeyboardButton.parse_keyboardButtonBuy($0) }
    dict[901503851] = { return Api.KeyboardButton.parse_keyboardButtonCallback($0) }
    dict[1976723854] = { return Api.KeyboardButton.parse_keyboardButtonCopy($0) }
    dict[1358175439] = { return Api.KeyboardButton.parse_keyboardButtonGame($0) }
    dict[-59151553] = { return Api.KeyboardButton.parse_keyboardButtonRequestGeoLocation($0) }
    dict[1406648280] = { return Api.KeyboardButton.parse_keyboardButtonRequestPeer($0) }
    dict[-1318425559] = { return Api.KeyboardButton.parse_keyboardButtonRequestPhone($0) }
    dict[-1144565411] = { return Api.KeyboardButton.parse_keyboardButtonRequestPoll($0) }
    dict[-1598009252] = { return Api.KeyboardButton.parse_keyboardButtonSimpleWebView($0) }
    dict[-1816527947] = { return Api.KeyboardButton.parse_keyboardButtonSwitchInline($0) }
    dict[629866245] = { return Api.KeyboardButton.parse_keyboardButtonUrl($0) }
    dict[280464681] = { return Api.KeyboardButton.parse_keyboardButtonUrlAuth($0) }
    dict[814112961] = { return Api.KeyboardButton.parse_keyboardButtonUserProfile($0) }
    dict[326529584] = { return Api.KeyboardButton.parse_keyboardButtonWebView($0) }
    dict[2002815875] = { return Api.KeyboardButtonRow.parse_keyboardButtonRow($0) }
    dict[-886477832] = { return Api.LabeledPrice.parse_labeledPrice($0) }
    dict[-209337866] = { return Api.LangPackDifference.parse_langPackDifference($0) }
    dict[-288727837] = { return Api.LangPackLanguage.parse_langPackLanguage($0) }
    dict[-892239370] = { return Api.LangPackString.parse_langPackString($0) }
    dict[695856818] = { return Api.LangPackString.parse_langPackStringDeleted($0) }
    dict[1816636575] = { return Api.LangPackString.parse_langPackStringPluralized($0) }
    dict[-1361650766] = { return Api.MaskCoords.parse_maskCoords($0) }
    dict[577893055] = { return Api.MediaArea.parse_inputMediaAreaChannelPost($0) }
    dict[-1300094593] = { return Api.MediaArea.parse_inputMediaAreaVenue($0) }
    dict[1996756655] = { return Api.MediaArea.parse_mediaAreaChannelPost($0) }
    dict[-891992787] = { return Api.MediaArea.parse_mediaAreaGeoPoint($0) }
    dict[1468491885] = { return Api.MediaArea.parse_mediaAreaStarGift($0) }
    dict[340088945] = { return Api.MediaArea.parse_mediaAreaSuggestedReaction($0) }
    dict[926421125] = { return Api.MediaArea.parse_mediaAreaUrl($0) }
    dict[-1098720356] = { return Api.MediaArea.parse_mediaAreaVenue($0) }
    dict[1235637404] = { return Api.MediaArea.parse_mediaAreaWeather($0) }
    dict[-808853502] = { return Api.MediaAreaCoordinates.parse_mediaAreaCoordinates($0) }
    dict[-356721331] = { return Api.Message.parse_message($0) }
    dict[-1868117372] = { return Api.Message.parse_messageEmpty($0) }
    dict[-741178048] = { return Api.Message.parse_messageService($0) }
    dict[-872240531] = { return Api.MessageAction.parse_messageActionBoostApply($0) }
    dict[-988359047] = { return Api.MessageAction.parse_messageActionBotAllowed($0) }
    dict[-1781355374] = { return Api.MessageAction.parse_messageActionChannelCreate($0) }
    dict[-365344535] = { return Api.MessageAction.parse_messageActionChannelMigrateFrom($0) }
    dict[365886720] = { return Api.MessageAction.parse_messageActionChatAddUser($0) }
    dict[-1119368275] = { return Api.MessageAction.parse_messageActionChatCreate($0) }
    dict[-1780220945] = { return Api.MessageAction.parse_messageActionChatDeletePhoto($0) }
    dict[-1539362612] = { return Api.MessageAction.parse_messageActionChatDeleteUser($0) }
    dict[2144015272] = { return Api.MessageAction.parse_messageActionChatEditPhoto($0) }
    dict[-1247687078] = { return Api.MessageAction.parse_messageActionChatEditTitle($0) }
    dict[51520707] = { return Api.MessageAction.parse_messageActionChatJoinedByLink($0) }
    dict[-339958837] = { return Api.MessageAction.parse_messageActionChatJoinedByRequest($0) }
    dict[-519864430] = { return Api.MessageAction.parse_messageActionChatMigrateTo($0) }
    dict[805187450] = { return Api.MessageAction.parse_messageActionConferenceCall($0) }
    dict[-202219658] = { return Api.MessageAction.parse_messageActionContactSignUp($0) }
    dict[-85549226] = { return Api.MessageAction.parse_messageActionCustomAction($0) }
    dict[-1230047312] = { return Api.MessageAction.parse_messageActionEmpty($0) }
    dict[-1834538890] = { return Api.MessageAction.parse_messageActionGameScore($0) }
    dict[-1730095465] = { return Api.MessageAction.parse_messageActionGeoProximityReached($0) }
    dict[1456486804] = { return Api.MessageAction.parse_messageActionGiftCode($0) }
    dict[1818391802] = { return Api.MessageAction.parse_messageActionGiftPremium($0) }
    dict[1171632161] = { return Api.MessageAction.parse_messageActionGiftStars($0) }
    dict[-1475391004] = { return Api.MessageAction.parse_messageActionGiveawayLaunch($0) }
    dict[-2015170219] = { return Api.MessageAction.parse_messageActionGiveawayResults($0) }
    dict[2047704898] = { return Api.MessageAction.parse_messageActionGroupCall($0) }
    dict[-1281329567] = { return Api.MessageAction.parse_messageActionGroupCallScheduled($0) }
    dict[-1615153660] = { return Api.MessageAction.parse_messageActionHistoryClear($0) }
    dict[1345295095] = { return Api.MessageAction.parse_messageActionInviteToGroupCall($0) }
    dict[-2068281992] = { return Api.MessageAction.parse_messageActionPaidMessagesPrice($0) }
    dict[-1407246387] = { return Api.MessageAction.parse_messageActionPaidMessagesRefunded($0) }
    dict[1102307842] = { return Api.MessageAction.parse_messageActionPaymentRefunded($0) }
    dict[-970673810] = { return Api.MessageAction.parse_messageActionPaymentSent($0) }
    dict[-6288180] = { return Api.MessageAction.parse_messageActionPaymentSentMe($0) }
    dict[-2132731265] = { return Api.MessageAction.parse_messageActionPhoneCall($0) }
    dict[-1799538451] = { return Api.MessageAction.parse_messageActionPinMessage($0) }
    dict[-1341372510] = { return Api.MessageAction.parse_messageActionPrizeStars($0) }
    dict[827428507] = { return Api.MessageAction.parse_messageActionRequestedPeer($0) }
    dict[-1816979384] = { return Api.MessageAction.parse_messageActionRequestedPeerSentMe($0) }
    dict[1200788123] = { return Api.MessageAction.parse_messageActionScreenshotTaken($0) }
    dict[-648257196] = { return Api.MessageAction.parse_messageActionSecureValuesSent($0) }
    dict[455635795] = { return Api.MessageAction.parse_messageActionSecureValuesSentMe($0) }
    dict[-1434950843] = { return Api.MessageAction.parse_messageActionSetChatTheme($0) }
    dict[1348510708] = { return Api.MessageAction.parse_messageActionSetChatWallPaper($0) }
    dict[1007897979] = { return Api.MessageAction.parse_messageActionSetMessagesTTL($0) }
    dict[1192749220] = { return Api.MessageAction.parse_messageActionStarGift($0) }
    dict[775611918] = { return Api.MessageAction.parse_messageActionStarGiftUnique($0) }
    dict[1474192222] = { return Api.MessageAction.parse_messageActionSuggestProfilePhoto($0) }
    dict[228168278] = { return Api.MessageAction.parse_messageActionTopicCreate($0) }
    dict[-1064024032] = { return Api.MessageAction.parse_messageActionTopicEdit($0) }
    dict[-1262252875] = { return Api.MessageAction.parse_messageActionWebViewDataSent($0) }
    dict[1205698681] = { return Api.MessageAction.parse_messageActionWebViewDataSentMe($0) }
    dict[546203849] = { return Api.MessageEntity.parse_inputMessageEntityMentionName($0) }
    dict[1981704948] = { return Api.MessageEntity.parse_messageEntityBankCard($0) }
    dict[-238245204] = { return Api.MessageEntity.parse_messageEntityBlockquote($0) }
    dict[-1117713463] = { return Api.MessageEntity.parse_messageEntityBold($0) }
    dict[1827637959] = { return Api.MessageEntity.parse_messageEntityBotCommand($0) }
    dict[1280209983] = { return Api.MessageEntity.parse_messageEntityCashtag($0) }
    dict[681706865] = { return Api.MessageEntity.parse_messageEntityCode($0) }
    dict[-925956616] = { return Api.MessageEntity.parse_messageEntityCustomEmoji($0) }
    dict[1692693954] = { return Api.MessageEntity.parse_messageEntityEmail($0) }
    dict[1868782349] = { return Api.MessageEntity.parse_messageEntityHashtag($0) }
    dict[-2106619040] = { return Api.MessageEntity.parse_messageEntityItalic($0) }
    dict[-100378723] = { return Api.MessageEntity.parse_messageEntityMention($0) }
    dict[-595914432] = { return Api.MessageEntity.parse_messageEntityMentionName($0) }
    dict[-1687559349] = { return Api.MessageEntity.parse_messageEntityPhone($0) }
    dict[1938967520] = { return Api.MessageEntity.parse_messageEntityPre($0) }
    dict[852137487] = { return Api.MessageEntity.parse_messageEntitySpoiler($0) }
    dict[-1090087980] = { return Api.MessageEntity.parse_messageEntityStrike($0) }
    dict[1990644519] = { return Api.MessageEntity.parse_messageEntityTextUrl($0) }
    dict[-1672577397] = { return Api.MessageEntity.parse_messageEntityUnderline($0) }
    dict[-1148011883] = { return Api.MessageEntity.parse_messageEntityUnknown($0) }
    dict[1859134776] = { return Api.MessageEntity.parse_messageEntityUrl($0) }
    dict[-297296796] = { return Api.MessageExtendedMedia.parse_messageExtendedMedia($0) }
    dict[-1386050360] = { return Api.MessageExtendedMedia.parse_messageExtendedMediaPreview($0) }
    dict[1313731771] = { return Api.MessageFwdHeader.parse_messageFwdHeader($0) }
    dict[1882335561] = { return Api.MessageMedia.parse_messageMediaContact($0) }
    dict[1065280907] = { return Api.MessageMedia.parse_messageMediaDice($0) }
    dict[1389939929] = { return Api.MessageMedia.parse_messageMediaDocument($0) }
    dict[1038967584] = { return Api.MessageMedia.parse_messageMediaEmpty($0) }
    dict[-38694904] = { return Api.MessageMedia.parse_messageMediaGame($0) }
    dict[1457575028] = { return Api.MessageMedia.parse_messageMediaGeo($0) }
    dict[-1186937242] = { return Api.MessageMedia.parse_messageMediaGeoLive($0) }
    dict[-1442366485] = { return Api.MessageMedia.parse_messageMediaGiveaway($0) }
    dict[-827703647] = { return Api.MessageMedia.parse_messageMediaGiveawayResults($0) }
    dict[-156940077] = { return Api.MessageMedia.parse_messageMediaInvoice($0) }
    dict[-1467669359] = { return Api.MessageMedia.parse_messageMediaPaidMedia($0) }
    dict[1766936791] = { return Api.MessageMedia.parse_messageMediaPhoto($0) }
    dict[1272375192] = { return Api.MessageMedia.parse_messageMediaPoll($0) }
    dict[1758159491] = { return Api.MessageMedia.parse_messageMediaStory($0) }
    dict[-1618676578] = { return Api.MessageMedia.parse_messageMediaUnsupported($0) }
    dict[784356159] = { return Api.MessageMedia.parse_messageMediaVenue($0) }
    dict[-571405253] = { return Api.MessageMedia.parse_messageMediaWebPage($0) }
    dict[-1938180548] = { return Api.MessagePeerReaction.parse_messagePeerReaction($0) }
    dict[-1228133028] = { return Api.MessagePeerVote.parse_messagePeerVote($0) }
    dict[1959634180] = { return Api.MessagePeerVote.parse_messagePeerVoteInputOption($0) }
    dict[1177089766] = { return Api.MessagePeerVote.parse_messagePeerVoteMultiple($0) }
    dict[182649427] = { return Api.MessageRange.parse_messageRange($0) }
    dict[171155211] = { return Api.MessageReactions.parse_messageReactions($0) }
    dict[1269016922] = { return Api.MessageReactor.parse_messageReactor($0) }
    dict[-2083123262] = { return Api.MessageReplies.parse_messageReplies($0) }
    dict[-1346631205] = { return Api.MessageReplyHeader.parse_messageReplyHeader($0) }
    dict[240843065] = { return Api.MessageReplyHeader.parse_messageReplyStoryHeader($0) }
    dict[2030298073] = { return Api.MessageReportOption.parse_messageReportOption($0) }
    dict[1163625789] = { return Api.MessageViews.parse_messageViews($0) }
    dict[975236280] = { return Api.MessagesFilter.parse_inputMessagesFilterChatPhotos($0) }
    dict[-530392189] = { return Api.MessagesFilter.parse_inputMessagesFilterContacts($0) }
    dict[-1629621880] = { return Api.MessagesFilter.parse_inputMessagesFilterDocument($0) }
    dict[1474492012] = { return Api.MessagesFilter.parse_inputMessagesFilterEmpty($0) }
    dict[-419271411] = { return Api.MessagesFilter.parse_inputMessagesFilterGeo($0) }
    dict[-3644025] = { return Api.MessagesFilter.parse_inputMessagesFilterGif($0) }
    dict[928101534] = { return Api.MessagesFilter.parse_inputMessagesFilterMusic($0) }
    dict[-1040652646] = { return Api.MessagesFilter.parse_inputMessagesFilterMyMentions($0) }
    dict[-2134272152] = { return Api.MessagesFilter.parse_inputMessagesFilterPhoneCalls($0) }
    dict[1458172132] = { return Api.MessagesFilter.parse_inputMessagesFilterPhotoVideo($0) }
    dict[-1777752804] = { return Api.MessagesFilter.parse_inputMessagesFilterPhotos($0) }
    dict[464520273] = { return Api.MessagesFilter.parse_inputMessagesFilterPinned($0) }
    dict[-1253451181] = { return Api.MessagesFilter.parse_inputMessagesFilterRoundVideo($0) }
    dict[2054952868] = { return Api.MessagesFilter.parse_inputMessagesFilterRoundVoice($0) }
    dict[2129714567] = { return Api.MessagesFilter.parse_inputMessagesFilterUrl($0) }
    dict[-1614803355] = { return Api.MessagesFilter.parse_inputMessagesFilterVideo($0) }
    dict[1358283666] = { return Api.MessagesFilter.parse_inputMessagesFilterVoice($0) }
    dict[1653379620] = { return Api.MissingInvitee.parse_missingInvitee($0) }
    dict[-1001897636] = { return Api.MyBoost.parse_myBoost($0) }
    dict[-1910892683] = { return Api.NearestDc.parse_nearestDc($0) }
    dict[-1746354498] = { return Api.NotificationSound.parse_notificationSoundDefault($0) }
    dict[-2096391452] = { return Api.NotificationSound.parse_notificationSoundLocal($0) }
    dict[1863070943] = { return Api.NotificationSound.parse_notificationSoundNone($0) }
    dict[-9666487] = { return Api.NotificationSound.parse_notificationSoundRingtone($0) }
    dict[-703403793] = { return Api.NotifyPeer.parse_notifyBroadcasts($0) }
    dict[-1073230141] = { return Api.NotifyPeer.parse_notifyChats($0) }
    dict[577659656] = { return Api.NotifyPeer.parse_notifyForumTopic($0) }
    dict[-1613493288] = { return Api.NotifyPeer.parse_notifyPeer($0) }
    dict[-1261946036] = { return Api.NotifyPeer.parse_notifyUsers($0) }
    dict[1001931436] = { return Api.OutboxReadDate.parse_outboxReadDate($0) }
    dict[-1738178803] = { return Api.Page.parse_page($0) }
    dict[-837994576] = { return Api.PageBlock.parse_pageBlockAnchor($0) }
    dict[-2143067670] = { return Api.PageBlock.parse_pageBlockAudio($0) }
    dict[-1162877472] = { return Api.PageBlock.parse_pageBlockAuthorDate($0) }
    dict[641563686] = { return Api.PageBlock.parse_pageBlockBlockquote($0) }
    dict[-283684427] = { return Api.PageBlock.parse_pageBlockChannel($0) }
    dict[1705048653] = { return Api.PageBlock.parse_pageBlockCollage($0) }
    dict[972174080] = { return Api.PageBlock.parse_pageBlockCover($0) }
    dict[1987480557] = { return Api.PageBlock.parse_pageBlockDetails($0) }
    dict[-618614392] = { return Api.PageBlock.parse_pageBlockDivider($0) }
    dict[-1468953147] = { return Api.PageBlock.parse_pageBlockEmbed($0) }
    dict[-229005301] = { return Api.PageBlock.parse_pageBlockEmbedPost($0) }
    dict[1216809369] = { return Api.PageBlock.parse_pageBlockFooter($0) }
    dict[-1076861716] = { return Api.PageBlock.parse_pageBlockHeader($0) }
    dict[504660880] = { return Api.PageBlock.parse_pageBlockKicker($0) }
    dict[-454524911] = { return Api.PageBlock.parse_pageBlockList($0) }
    dict[-1538310410] = { return Api.PageBlock.parse_pageBlockMap($0) }
    dict[-1702174239] = { return Api.PageBlock.parse_pageBlockOrderedList($0) }
    dict[1182402406] = { return Api.PageBlock.parse_pageBlockParagraph($0) }
    dict[391759200] = { return Api.PageBlock.parse_pageBlockPhoto($0) }
    dict[-1066346178] = { return Api.PageBlock.parse_pageBlockPreformatted($0) }
    dict[1329878739] = { return Api.PageBlock.parse_pageBlockPullquote($0) }
    dict[370236054] = { return Api.PageBlock.parse_pageBlockRelatedArticles($0) }
    dict[52401552] = { return Api.PageBlock.parse_pageBlockSlideshow($0) }
    dict[-248793375] = { return Api.PageBlock.parse_pageBlockSubheader($0) }
    dict[-1879401953] = { return Api.PageBlock.parse_pageBlockSubtitle($0) }
    dict[-1085412734] = { return Api.PageBlock.parse_pageBlockTable($0) }
    dict[1890305021] = { return Api.PageBlock.parse_pageBlockTitle($0) }
    dict[324435594] = { return Api.PageBlock.parse_pageBlockUnsupported($0) }
    dict[2089805750] = { return Api.PageBlock.parse_pageBlockVideo($0) }
    dict[1869903447] = { return Api.PageCaption.parse_pageCaption($0) }
    dict[635466748] = { return Api.PageListItem.parse_pageListItemBlocks($0) }
    dict[-1188055347] = { return Api.PageListItem.parse_pageListItemText($0) }
    dict[-1730311882] = { return Api.PageListOrderedItem.parse_pageListOrderedItemBlocks($0) }
    dict[1577484359] = { return Api.PageListOrderedItem.parse_pageListOrderedItemText($0) }
    dict[-1282352120] = { return Api.PageRelatedArticle.parse_pageRelatedArticle($0) }
    dict[878078826] = { return Api.PageTableCell.parse_pageTableCell($0) }
    dict[-524237339] = { return Api.PageTableRow.parse_pageTableRow($0) }
    dict[520887001] = { return Api.PaidReactionPrivacy.parse_paidReactionPrivacyAnonymous($0) }
    dict[543872158] = { return Api.PaidReactionPrivacy.parse_paidReactionPrivacyDefault($0) }
    dict[-596837136] = { return Api.PaidReactionPrivacy.parse_paidReactionPrivacyPeer($0) }
    dict[982592842] = { return Api.PasswordKdfAlgo.parse_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow($0) }
    dict[-732254058] = { return Api.PasswordKdfAlgo.parse_passwordKdfAlgoUnknown($0) }
    dict[-368917890] = { return Api.PaymentCharge.parse_paymentCharge($0) }
    dict[-1996951013] = { return Api.PaymentFormMethod.parse_paymentFormMethod($0) }
    dict[-1868808300] = { return Api.PaymentRequestedInfo.parse_paymentRequestedInfo($0) }
    dict[-842892769] = { return Api.PaymentSavedCredentials.parse_paymentSavedCredentialsCard($0) }
    dict[-1566230754] = { return Api.Peer.parse_peerChannel($0) }
    dict[918946202] = { return Api.Peer.parse_peerChat($0) }
    dict[1498486562] = { return Api.Peer.parse_peerUser($0) }
    dict[-386039788] = { return Api.PeerBlocked.parse_peerBlocked($0) }
    dict[-1253352753] = { return Api.PeerColor.parse_peerColor($0) }
    dict[-901375139] = { return Api.PeerLocated.parse_peerLocated($0) }
    dict[-118740917] = { return Api.PeerLocated.parse_peerSelfLocated($0) }
    dict[-1721619444] = { return Api.PeerNotifySettings.parse_peerNotifySettings($0) }
    dict[-193510921] = { return Api.PeerSettings.parse_peerSettings($0) }
    dict[-1707742823] = { return Api.PeerStories.parse_peerStories($0) }
    dict[-404214254] = { return Api.PendingSuggestion.parse_pendingSuggestion($0) }
    dict[810769141] = { return Api.PhoneCall.parse_phoneCall($0) }
    dict[912311057] = { return Api.PhoneCall.parse_phoneCallAccepted($0) }
    dict[1355435489] = { return Api.PhoneCall.parse_phoneCallDiscarded($0) }
    dict[1399245077] = { return Api.PhoneCall.parse_phoneCallEmpty($0) }
    dict[347139340] = { return Api.PhoneCall.parse_phoneCallRequested($0) }
    dict[-987599081] = { return Api.PhoneCall.parse_phoneCallWaiting($0) }
    dict[-84416311] = { return Api.PhoneCallDiscardReason.parse_phoneCallDiscardReasonBusy($0) }
    dict[-527056480] = { return Api.PhoneCallDiscardReason.parse_phoneCallDiscardReasonDisconnect($0) }
    dict[1471006352] = { return Api.PhoneCallDiscardReason.parse_phoneCallDiscardReasonHangup($0) }
    dict[-1615072777] = { return Api.PhoneCallDiscardReason.parse_phoneCallDiscardReasonMigrateConferenceCall($0) }
    dict[-2048646399] = { return Api.PhoneCallDiscardReason.parse_phoneCallDiscardReasonMissed($0) }
    dict[-58224696] = { return Api.PhoneCallProtocol.parse_phoneCallProtocol($0) }
    dict[-1665063993] = { return Api.PhoneConnection.parse_phoneConnection($0) }
    dict[1667228533] = { return Api.PhoneConnection.parse_phoneConnectionWebrtc($0) }
    dict[-82216347] = { return Api.Photo.parse_photo($0) }
    dict[590459437] = { return Api.Photo.parse_photoEmpty($0) }
    dict[35527382] = { return Api.PhotoSize.parse_photoCachedSize($0) }
    dict[-668906175] = { return Api.PhotoSize.parse_photoPathSize($0) }
    dict[1976012384] = { return Api.PhotoSize.parse_photoSize($0) }
    dict[236446268] = { return Api.PhotoSize.parse_photoSizeEmpty($0) }
    dict[-96535659] = { return Api.PhotoSize.parse_photoSizeProgressive($0) }
    dict[-525288402] = { return Api.PhotoSize.parse_photoStrippedSize($0) }
    dict[1484026161] = { return Api.Poll.parse_poll($0) }
    dict[-15277366] = { return Api.PollAnswer.parse_pollAnswer($0) }
    dict[997055186] = { return Api.PollAnswerVoters.parse_pollAnswerVoters($0) }
    dict[2061444128] = { return Api.PollResults.parse_pollResults($0) }
    dict[1558266229] = { return Api.PopularContact.parse_popularContact($0) }
    dict[512535275] = { return Api.PostAddress.parse_postAddress($0) }
    dict[-419066241] = { return Api.PostInteractionCounters.parse_postInteractionCountersMessage($0) }
    dict[-1974989273] = { return Api.PostInteractionCounters.parse_postInteractionCountersStory($0) }
    dict[629052971] = { return Api.PremiumGiftCodeOption.parse_premiumGiftCodeOption($0) }
    dict[1596792306] = { return Api.PremiumSubscriptionOption.parse_premiumSubscriptionOption($0) }
    dict[-1303143084] = { return Api.PrepaidGiveaway.parse_prepaidGiveaway($0) }
    dict[-1700956192] = { return Api.PrepaidGiveaway.parse_prepaidStarsGiveaway($0) }
    dict[-1534675103] = { return Api.PrivacyKey.parse_privacyKeyAbout($0) }
    dict[1124062251] = { return Api.PrivacyKey.parse_privacyKeyAddedByPhone($0) }
    dict[536913176] = { return Api.PrivacyKey.parse_privacyKeyBirthday($0) }
    dict[1343122938] = { return Api.PrivacyKey.parse_privacyKeyChatInvite($0) }
    dict[1777096355] = { return Api.PrivacyKey.parse_privacyKeyForwards($0) }
    dict[399722706] = { return Api.PrivacyKey.parse_privacyKeyNoPaidMessages($0) }
    dict[1030105979] = { return Api.PrivacyKey.parse_privacyKeyPhoneCall($0) }
    dict[-778378131] = { return Api.PrivacyKey.parse_privacyKeyPhoneNumber($0) }
    dict[961092808] = { return Api.PrivacyKey.parse_privacyKeyPhoneP2P($0) }
    dict[-1777000467] = { return Api.PrivacyKey.parse_privacyKeyProfilePhoto($0) }
    dict[749010424] = { return Api.PrivacyKey.parse_privacyKeyStarGiftsAutoSave($0) }
    dict[-1137792208] = { return Api.PrivacyKey.parse_privacyKeyStatusTimestamp($0) }
    dict[110621716] = { return Api.PrivacyKey.parse_privacyKeyVoiceMessages($0) }
    dict[1698855810] = { return Api.PrivacyRule.parse_privacyValueAllowAll($0) }
    dict[558242653] = { return Api.PrivacyRule.parse_privacyValueAllowBots($0) }
    dict[1796427406] = { return Api.PrivacyRule.parse_privacyValueAllowChatParticipants($0) }
    dict[-135735141] = { return Api.PrivacyRule.parse_privacyValueAllowCloseFriends($0) }
    dict[-123988] = { return Api.PrivacyRule.parse_privacyValueAllowContacts($0) }
    dict[-320241333] = { return Api.PrivacyRule.parse_privacyValueAllowPremium($0) }
    dict[-1198497870] = { return Api.PrivacyRule.parse_privacyValueAllowUsers($0) }
    dict[-1955338397] = { return Api.PrivacyRule.parse_privacyValueDisallowAll($0) }
    dict[-156895185] = { return Api.PrivacyRule.parse_privacyValueDisallowBots($0) }
    dict[1103656293] = { return Api.PrivacyRule.parse_privacyValueDisallowChatParticipants($0) }
    dict[-125240806] = { return Api.PrivacyRule.parse_privacyValueDisallowContacts($0) }
    dict[-463335103] = { return Api.PrivacyRule.parse_privacyValueDisallowUsers($0) }
    dict[32685898] = { return Api.PublicForward.parse_publicForwardMessage($0) }
    dict[-302797360] = { return Api.PublicForward.parse_publicForwardStory($0) }
    dict[110563371] = { return Api.QuickReply.parse_quickReply($0) }
    dict[-1992950669] = { return Api.Reaction.parse_reactionCustomEmoji($0) }
    dict[455247544] = { return Api.Reaction.parse_reactionEmoji($0) }
    dict[2046153753] = { return Api.Reaction.parse_reactionEmpty($0) }
    dict[1379771627] = { return Api.Reaction.parse_reactionPaid($0) }
    dict[-1546531968] = { return Api.ReactionCount.parse_reactionCount($0) }
    dict[1268654752] = { return Api.ReactionNotificationsFrom.parse_reactionNotificationsFromAll($0) }
    dict[-1161583078] = { return Api.ReactionNotificationsFrom.parse_reactionNotificationsFromContacts($0) }
    dict[1457736048] = { return Api.ReactionsNotifySettings.parse_reactionsNotifySettings($0) }
    dict[1246753138] = { return Api.ReadParticipantDate.parse_readParticipantDate($0) }
    dict[-1551583367] = { return Api.ReceivedNotifyMessage.parse_receivedNotifyMessage($0) }
    dict[-1294306862] = { return Api.RecentMeUrl.parse_recentMeUrlChat($0) }
    dict[-347535331] = { return Api.RecentMeUrl.parse_recentMeUrlChatInvite($0) }
    dict[-1140172836] = { return Api.RecentMeUrl.parse_recentMeUrlStickerSet($0) }
    dict[1189204285] = { return Api.RecentMeUrl.parse_recentMeUrlUnknown($0) }
    dict[-1188296222] = { return Api.RecentMeUrl.parse_recentMeUrlUser($0) }
    dict[1218642516] = { return Api.ReplyMarkup.parse_replyInlineMarkup($0) }
    dict[-2035021048] = { return Api.ReplyMarkup.parse_replyKeyboardForceReply($0) }
    dict[-1606526075] = { return Api.ReplyMarkup.parse_replyKeyboardHide($0) }
    dict[-2049074735] = { return Api.ReplyMarkup.parse_replyKeyboardMarkup($0) }
    dict[-1376497949] = { return Api.ReportReason.parse_inputReportReasonChildAbuse($0) }
    dict[-1685456582] = { return Api.ReportReason.parse_inputReportReasonCopyright($0) }
    dict[-170010905] = { return Api.ReportReason.parse_inputReportReasonFake($0) }
    dict[-606798099] = { return Api.ReportReason.parse_inputReportReasonGeoIrrelevant($0) }
    dict[177124030] = { return Api.ReportReason.parse_inputReportReasonIllegalDrugs($0) }
    dict[-1041980751] = { return Api.ReportReason.parse_inputReportReasonOther($0) }
    dict[-1631091139] = { return Api.ReportReason.parse_inputReportReasonPersonalDetails($0) }
    dict[777640226] = { return Api.ReportReason.parse_inputReportReasonPornography($0) }
    dict[1490799288] = { return Api.ReportReason.parse_inputReportReasonSpam($0) }
    dict[505595789] = { return Api.ReportReason.parse_inputReportReasonViolence($0) }
    dict[1862904881] = { return Api.ReportResult.parse_reportResultAddComment($0) }
    dict[-253435722] = { return Api.ReportResult.parse_reportResultChooseOption($0) }
    dict[-1917633461] = { return Api.ReportResult.parse_reportResultReported($0) }
    dict[865857388] = { return Api.RequestPeerType.parse_requestPeerTypeBroadcast($0) }
    dict[-906990053] = { return Api.RequestPeerType.parse_requestPeerTypeChat($0) }
    dict[1597737472] = { return Api.RequestPeerType.parse_requestPeerTypeUser($0) }
    dict[-1952185372] = { return Api.RequestedPeer.parse_requestedPeerChannel($0) }
    dict[1929860175] = { return Api.RequestedPeer.parse_requestedPeerChat($0) }
    dict[-701500310] = { return Api.RequestedPeer.parse_requestedPeerUser($0) }
    dict[84580409] = { return Api.RequirementToContact.parse_requirementToContactEmpty($0) }
    dict[-1258914157] = { return Api.RequirementToContact.parse_requirementToContactPaidMessages($0) }
    dict[-444472087] = { return Api.RequirementToContact.parse_requirementToContactPremium($0) }
    dict[-797791052] = { return Api.RestrictionReason.parse_restrictionReason($0) }
    dict[894777186] = { return Api.RichText.parse_textAnchor($0) }
    dict[1730456516] = { return Api.RichText.parse_textBold($0) }
    dict[2120376535] = { return Api.RichText.parse_textConcat($0) }
    dict[-564523562] = { return Api.RichText.parse_textEmail($0) }
    dict[-599948721] = { return Api.RichText.parse_textEmpty($0) }
    dict[1816074681] = { return Api.RichText.parse_textFixed($0) }
    dict[136105807] = { return Api.RichText.parse_textImage($0) }
    dict[-653089380] = { return Api.RichText.parse_textItalic($0) }
    dict[55281185] = { return Api.RichText.parse_textMarked($0) }
    dict[483104362] = { return Api.RichText.parse_textPhone($0) }
    dict[1950782688] = { return Api.RichText.parse_textPlain($0) }
    dict[-1678197867] = { return Api.RichText.parse_textStrike($0) }
    dict[-311786236] = { return Api.RichText.parse_textSubscript($0) }
    dict[-939827711] = { return Api.RichText.parse_textSuperscript($0) }
    dict[-1054465340] = { return Api.RichText.parse_textUnderline($0) }
    dict[1009288385] = { return Api.RichText.parse_textUrl($0) }
    dict[289586518] = { return Api.SavedContact.parse_savedPhoneContact($0) }
    dict[1681948327] = { return Api.SavedDialog.parse_monoForumDialog($0) }
    dict[-1115174036] = { return Api.SavedDialog.parse_savedDialog($0) }
    dict[-881854424] = { return Api.SavedReactionTag.parse_savedReactionTag($0) }
    dict[-539360103] = { return Api.SavedStarGift.parse_savedStarGift($0) }
    dict[-911191137] = { return Api.SearchResultsCalendarPeriod.parse_searchResultsCalendarPeriod($0) }
    dict[2137295719] = { return Api.SearchResultsPosition.parse_searchResultPosition($0) }
    dict[871426631] = { return Api.SecureCredentialsEncrypted.parse_secureCredentialsEncrypted($0) }
    dict[-1964327229] = { return Api.SecureData.parse_secureData($0) }
    dict[2097791614] = { return Api.SecureFile.parse_secureFile($0) }
    dict[1679398724] = { return Api.SecureFile.parse_secureFileEmpty($0) }
    dict[-1141711456] = { return Api.SecurePasswordKdfAlgo.parse_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000($0) }
    dict[-2042159726] = { return Api.SecurePasswordKdfAlgo.parse_securePasswordKdfAlgoSHA512($0) }
    dict[4883767] = { return Api.SecurePasswordKdfAlgo.parse_securePasswordKdfAlgoUnknown($0) }
    dict[569137759] = { return Api.SecurePlainData.parse_securePlainEmail($0) }
    dict[2103482845] = { return Api.SecurePlainData.parse_securePlainPhone($0) }
    dict[-2103600678] = { return Api.SecureRequiredType.parse_secureRequiredType($0) }
    dict[41187252] = { return Api.SecureRequiredType.parse_secureRequiredTypeOneOf($0) }
    dict[354925740] = { return Api.SecureSecretSettings.parse_secureSecretSettings($0) }
    dict[411017418] = { return Api.SecureValue.parse_secureValue($0) }
    dict[-2036501105] = { return Api.SecureValueError.parse_secureValueError($0) }
    dict[-391902247] = { return Api.SecureValueError.parse_secureValueErrorData($0) }
    dict[2054162547] = { return Api.SecureValueError.parse_secureValueErrorFile($0) }
    dict[1717706985] = { return Api.SecureValueError.parse_secureValueErrorFiles($0) }
    dict[12467706] = { return Api.SecureValueError.parse_secureValueErrorFrontSide($0) }
    dict[-2037765467] = { return Api.SecureValueError.parse_secureValueErrorReverseSide($0) }
    dict[-449327402] = { return Api.SecureValueError.parse_secureValueErrorSelfie($0) }
    dict[-1592506512] = { return Api.SecureValueError.parse_secureValueErrorTranslationFile($0) }
    dict[878931416] = { return Api.SecureValueError.parse_secureValueErrorTranslationFiles($0) }
    dict[-316748368] = { return Api.SecureValueHash.parse_secureValueHash($0) }
    dict[-874308058] = { return Api.SecureValueType.parse_secureValueTypeAddress($0) }
    dict[-1995211763] = { return Api.SecureValueType.parse_secureValueTypeBankStatement($0) }
    dict[115615172] = { return Api.SecureValueType.parse_secureValueTypeDriverLicense($0) }
    dict[-1908627474] = { return Api.SecureValueType.parse_secureValueTypeEmail($0) }
    dict[-1596951477] = { return Api.SecureValueType.parse_secureValueTypeIdentityCard($0) }
    dict[-1717268701] = { return Api.SecureValueType.parse_secureValueTypeInternalPassport($0) }
    dict[1034709504] = { return Api.SecureValueType.parse_secureValueTypePassport($0) }
    dict[-1713143702] = { return Api.SecureValueType.parse_secureValueTypePassportRegistration($0) }
    dict[-1658158621] = { return Api.SecureValueType.parse_secureValueTypePersonalDetails($0) }
    dict[-1289704741] = { return Api.SecureValueType.parse_secureValueTypePhone($0) }
    dict[-1954007928] = { return Api.SecureValueType.parse_secureValueTypeRentalAgreement($0) }
    dict[-368907213] = { return Api.SecureValueType.parse_secureValueTypeTemporaryRegistration($0) }
    dict[-63531698] = { return Api.SecureValueType.parse_secureValueTypeUtilityBill($0) }
    dict[-1206095820] = { return Api.SendAsPeer.parse_sendAsPeer($0) }
    dict[-44119819] = { return Api.SendMessageAction.parse_sendMessageCancelAction($0) }
    dict[1653390447] = { return Api.SendMessageAction.parse_sendMessageChooseContactAction($0) }
    dict[-1336228175] = { return Api.SendMessageAction.parse_sendMessageChooseStickerAction($0) }
    dict[630664139] = { return Api.SendMessageAction.parse_sendMessageEmojiInteraction($0) }
    dict[-1234857938] = { return Api.SendMessageAction.parse_sendMessageEmojiInteractionSeen($0) }
    dict[-580219064] = { return Api.SendMessageAction.parse_sendMessageGamePlayAction($0) }
    dict[393186209] = { return Api.SendMessageAction.parse_sendMessageGeoLocationAction($0) }
    dict[-606432698] = { return Api.SendMessageAction.parse_sendMessageHistoryImportAction($0) }
    dict[-718310409] = { return Api.SendMessageAction.parse_sendMessageRecordAudioAction($0) }
    dict[-1997373508] = { return Api.SendMessageAction.parse_sendMessageRecordRoundAction($0) }
    dict[-1584933265] = { return Api.SendMessageAction.parse_sendMessageRecordVideoAction($0) }
    dict[381645902] = { return Api.SendMessageAction.parse_sendMessageTypingAction($0) }
    dict[-212740181] = { return Api.SendMessageAction.parse_sendMessageUploadAudioAction($0) }
    dict[-1441998364] = { return Api.SendMessageAction.parse_sendMessageUploadDocumentAction($0) }
    dict[-774682074] = { return Api.SendMessageAction.parse_sendMessageUploadPhotoAction($0) }
    dict[608050278] = { return Api.SendMessageAction.parse_sendMessageUploadRoundAction($0) }
    dict[-378127636] = { return Api.SendMessageAction.parse_sendMessageUploadVideoAction($0) }
    dict[-651419003] = { return Api.SendMessageAction.parse_speakingInGroupCallAction($0) }
    dict[-1239335713] = { return Api.ShippingOption.parse_shippingOption($0) }
    dict[-425595208] = { return Api.SmsJob.parse_smsJob($0) }
    dict[1301522832] = { return Api.SponsoredMessage.parse_sponsoredMessage($0) }
    dict[1124938064] = { return Api.SponsoredMessageReportOption.parse_sponsoredMessageReportOption($0) }
    dict[-963180333] = { return Api.SponsoredPeer.parse_sponsoredPeer($0) }
    dict[-970274264] = { return Api.StarGift.parse_starGift($0) }
    dict[1678891913] = { return Api.StarGift.parse_starGiftUnique($0) }
    dict[-650279524] = { return Api.StarGiftAttribute.parse_starGiftAttributeBackdrop($0) }
    dict[970559507] = { return Api.StarGiftAttribute.parse_starGiftAttributeModel($0) }
    dict[-524291476] = { return Api.StarGiftAttribute.parse_starGiftAttributeOriginalDetails($0) }
    dict[330104601] = { return Api.StarGiftAttribute.parse_starGiftAttributePattern($0) }
    dict[783398488] = { return Api.StarGiftAttributeCounter.parse_starGiftAttributeCounter($0) }
    dict[520210263] = { return Api.StarGiftAttributeId.parse_starGiftAttributeIdBackdrop($0) }
    dict[1219145276] = { return Api.StarGiftAttributeId.parse_starGiftAttributeIdModel($0) }
    dict[1242965043] = { return Api.StarGiftAttributeId.parse_starGiftAttributeIdPattern($0) }
    dict[-586389774] = { return Api.StarRefProgram.parse_starRefProgram($0) }
    dict[-1145654109] = { return Api.StarsAmount.parse_starsAmount($0) }
    dict[1577421297] = { return Api.StarsGiftOption.parse_starsGiftOption($0) }
    dict[-1798404822] = { return Api.StarsGiveawayOption.parse_starsGiveawayOption($0) }
    dict[1411605001] = { return Api.StarsGiveawayWinnersOption.parse_starsGiveawayWinnersOption($0) }
    dict[-21080943] = { return Api.StarsRevenueStatus.parse_starsRevenueStatus($0) }
    dict[779004698] = { return Api.StarsSubscription.parse_starsSubscription($0) }
    dict[88173912] = { return Api.StarsSubscriptionPricing.parse_starsSubscriptionPricing($0) }
    dict[198776256] = { return Api.StarsTopupOption.parse_starsTopupOption($0) }
    dict[-1549805238] = { return Api.StarsTransaction.parse_starsTransaction($0) }
    dict[-670195363] = { return Api.StarsTransactionPeer.parse_starsTransactionPeer($0) }
    dict[-110658899] = { return Api.StarsTransactionPeer.parse_starsTransactionPeerAPI($0) }
    dict[1617438738] = { return Api.StarsTransactionPeer.parse_starsTransactionPeerAds($0) }
    dict[-1269320843] = { return Api.StarsTransactionPeer.parse_starsTransactionPeerAppStore($0) }
    dict[-382740222] = { return Api.StarsTransactionPeer.parse_starsTransactionPeerFragment($0) }
    dict[2069236235] = { return Api.StarsTransactionPeer.parse_starsTransactionPeerPlayMarket($0) }
    dict[621656824] = { return Api.StarsTransactionPeer.parse_starsTransactionPeerPremiumBot($0) }
    dict[-1779253276] = { return Api.StarsTransactionPeer.parse_starsTransactionPeerUnsupported($0) }
    dict[-884757282] = { return Api.StatsAbsValueAndPrev.parse_statsAbsValueAndPrev($0) }
    dict[-1237848657] = { return Api.StatsDateRangeDays.parse_statsDateRangeDays($0) }
    dict[-1901828938] = { return Api.StatsGraph.parse_statsGraph($0) }
    dict[1244130093] = { return Api.StatsGraph.parse_statsGraphAsync($0) }
    dict[-1092839390] = { return Api.StatsGraph.parse_statsGraphError($0) }
    dict[-682079097] = { return Api.StatsGroupTopAdmin.parse_statsGroupTopAdmin($0) }
    dict[1398765469] = { return Api.StatsGroupTopInviter.parse_statsGroupTopInviter($0) }
    dict[-1660637285] = { return Api.StatsGroupTopPoster.parse_statsGroupTopPoster($0) }
    dict[-875679776] = { return Api.StatsPercentValue.parse_statsPercentValue($0) }
    dict[1202287072] = { return Api.StatsURL.parse_statsURL($0) }
    dict[-50416996] = { return Api.StickerKeyword.parse_stickerKeyword($0) }
    dict[313694676] = { return Api.StickerPack.parse_stickerPack($0) }
    dict[768691932] = { return Api.StickerSet.parse_stickerSet($0) }
    dict[1678812626] = { return Api.StickerSetCovered.parse_stickerSetCovered($0) }
    dict[1087454222] = { return Api.StickerSetCovered.parse_stickerSetFullCovered($0) }
    dict[872932635] = { return Api.StickerSetCovered.parse_stickerSetMultiCovered($0) }
    dict[2008112412] = { return Api.StickerSetCovered.parse_stickerSetNoCovered($0) }
    dict[1898850301] = { return Api.StoriesStealthMode.parse_storiesStealthMode($0) }
    dict[-1205411504] = { return Api.StoryFwdHeader.parse_storyFwdHeader($0) }
    dict[2041735716] = { return Api.StoryItem.parse_storyItem($0) }
    dict[1374088783] = { return Api.StoryItem.parse_storyItemDeleted($0) }
    dict[-5388013] = { return Api.StoryItem.parse_storyItemSkipped($0) }
    dict[1620104917] = { return Api.StoryReaction.parse_storyReaction($0) }
    dict[-1146411453] = { return Api.StoryReaction.parse_storyReactionPublicForward($0) }
    dict[-808644845] = { return Api.StoryReaction.parse_storyReactionPublicRepost($0) }
    dict[-1329730875] = { return Api.StoryView.parse_storyView($0) }
    dict[-1870436597] = { return Api.StoryView.parse_storyViewPublicForward($0) }
    dict[-1116418231] = { return Api.StoryView.parse_storyViewPublicRepost($0) }
    dict[-1923523370] = { return Api.StoryViews.parse_storyViews($0) }
    dict[1964978502] = { return Api.TextWithEntities.parse_textWithEntities($0) }
    dict[-1609668650] = { return Api.Theme.parse_theme($0) }
    dict[-94849324] = { return Api.ThemeSettings.parse_themeSettings($0) }
    dict[-7173643] = { return Api.Timezone.parse_timezone($0) }
    dict[-305282981] = { return Api.TopPeer.parse_topPeer($0) }
    dict[-39945236] = { return Api.TopPeerCategory.parse_topPeerCategoryBotsApp($0) }
    dict[344356834] = { return Api.TopPeerCategory.parse_topPeerCategoryBotsInline($0) }
    dict[-1419371685] = { return Api.TopPeerCategory.parse_topPeerCategoryBotsPM($0) }
    dict[371037736] = { return Api.TopPeerCategory.parse_topPeerCategoryChannels($0) }
    dict[104314861] = { return Api.TopPeerCategory.parse_topPeerCategoryCorrespondents($0) }
    dict[-68239120] = { return Api.TopPeerCategory.parse_topPeerCategoryForwardChats($0) }
    dict[-1472172887] = { return Api.TopPeerCategory.parse_topPeerCategoryForwardUsers($0) }
    dict[-1122524854] = { return Api.TopPeerCategory.parse_topPeerCategoryGroups($0) }
    dict[511092620] = { return Api.TopPeerCategory.parse_topPeerCategoryPhoneCalls($0) }
    dict[-75283823] = { return Api.TopPeerCategoryPeers.parse_topPeerCategoryPeers($0) }
    dict[397910539] = { return Api.Update.parse_updateAttachMenuBots($0) }
    dict[-335171433] = { return Api.Update.parse_updateAutoSaveSettings($0) }
    dict[-1964652166] = { return Api.Update.parse_updateBotBusinessConnect($0) }
    dict[-1177566067] = { return Api.Update.parse_updateBotCallbackQuery($0) }
    dict[-1873947492] = { return Api.Update.parse_updateBotChatBoost($0) }
    dict[299870598] = { return Api.Update.parse_updateBotChatInviteRequester($0) }
    dict[1299263278] = { return Api.Update.parse_updateBotCommands($0) }
    dict[-1607821266] = { return Api.Update.parse_updateBotDeleteBusinessMessage($0) }
    dict[132077692] = { return Api.Update.parse_updateBotEditBusinessMessage($0) }
    dict[1232025500] = { return Api.Update.parse_updateBotInlineQuery($0) }
    dict[317794823] = { return Api.Update.parse_updateBotInlineSend($0) }
    dict[347625491] = { return Api.Update.parse_updateBotMenuButton($0) }
    dict[-1407069234] = { return Api.Update.parse_updateBotMessageReaction($0) }
    dict[164329305] = { return Api.Update.parse_updateBotMessageReactions($0) }
    dict[-1646578564] = { return Api.Update.parse_updateBotNewBusinessMessage($0) }
    dict[-1934976362] = { return Api.Update.parse_updateBotPrecheckoutQuery($0) }
    dict[675009298] = { return Api.Update.parse_updateBotPurchasedPaidMedia($0) }
    dict[-1246823043] = { return Api.Update.parse_updateBotShippingQuery($0) }
    dict[-997782967] = { return Api.Update.parse_updateBotStopped($0) }
    dict[-2095595325] = { return Api.Update.parse_updateBotWebhookJSON($0) }
    dict[-1684914010] = { return Api.Update.parse_updateBotWebhookJSONQuery($0) }
    dict[-539401739] = { return Api.Update.parse_updateBroadcastRevenueTransactions($0) }
    dict[513998247] = { return Api.Update.parse_updateBusinessBotCallbackQuery($0) }
    dict[1666927625] = { return Api.Update.parse_updateChannel($0) }
    dict[-1304443240] = { return Api.Update.parse_updateChannelAvailableMessages($0) }
    dict[-761649164] = { return Api.Update.parse_updateChannelMessageForwards($0) }
    dict[-232346616] = { return Api.Update.parse_updateChannelMessageViews($0) }
    dict[-1738720581] = { return Api.Update.parse_updateChannelParticipant($0) }
    dict[422509539] = { return Api.Update.parse_updateChannelPinnedTopic($0) }
    dict[-31881726] = { return Api.Update.parse_updateChannelPinnedTopics($0) }
    dict[636691703] = { return Api.Update.parse_updateChannelReadMessagesContents($0) }
    dict[277713951] = { return Api.Update.parse_updateChannelTooLong($0) }
    dict[-1937192669] = { return Api.Update.parse_updateChannelUserTyping($0) }
    dict[129403168] = { return Api.Update.parse_updateChannelViewForumAsMessages($0) }
    dict[791390623] = { return Api.Update.parse_updateChannelWebPage($0) }
    dict[-124097970] = { return Api.Update.parse_updateChat($0) }
    dict[1421875280] = { return Api.Update.parse_updateChatDefaultBannedRights($0) }
    dict[-796432838] = { return Api.Update.parse_updateChatParticipant($0) }
    dict[1037718609] = { return Api.Update.parse_updateChatParticipantAdd($0) }
    dict[-674602590] = { return Api.Update.parse_updateChatParticipantAdmin($0) }
    dict[-483443337] = { return Api.Update.parse_updateChatParticipantDelete($0) }
    dict[125178264] = { return Api.Update.parse_updateChatParticipants($0) }
    dict[-2092401936] = { return Api.Update.parse_updateChatUserTyping($0) }
    dict[-1574314746] = { return Api.Update.parse_updateConfig($0) }
    dict[1887741886] = { return Api.Update.parse_updateContactsReset($0) }
    dict[-1906403213] = { return Api.Update.parse_updateDcOptions($0) }
    dict[-1020437742] = { return Api.Update.parse_updateDeleteChannelMessages($0) }
    dict[-1576161051] = { return Api.Update.parse_updateDeleteMessages($0) }
    dict[1407644140] = { return Api.Update.parse_updateDeleteQuickReply($0) }
    dict[1450174413] = { return Api.Update.parse_updateDeleteQuickReplyMessages($0) }
    dict[-223929981] = { return Api.Update.parse_updateDeleteScheduledMessages($0) }
    dict[654302845] = { return Api.Update.parse_updateDialogFilter($0) }
    dict[-1512627963] = { return Api.Update.parse_updateDialogFilterOrder($0) }
    dict[889491791] = { return Api.Update.parse_updateDialogFilters($0) }
    dict[1852826908] = { return Api.Update.parse_updateDialogPinned($0) }
    dict[-1235684802] = { return Api.Update.parse_updateDialogUnreadMark($0) }
    dict[-302247650] = { return Api.Update.parse_updateDraftMessage($0) }
    dict[457133559] = { return Api.Update.parse_updateEditChannelMessage($0) }
    dict[-469536605] = { return Api.Update.parse_updateEditMessage($0) }
    dict[386986326] = { return Api.Update.parse_updateEncryptedChatTyping($0) }
    dict[956179895] = { return Api.Update.parse_updateEncryptedMessagesRead($0) }
    dict[-1264392051] = { return Api.Update.parse_updateEncryption($0) }
    dict[-451831443] = { return Api.Update.parse_updateFavedStickers($0) }
    dict[422972864] = { return Api.Update.parse_updateFolderPeers($0) }
    dict[-2027964103] = { return Api.Update.parse_updateGeoLiveViewed($0) }
    dict[-1747565759] = { return Api.Update.parse_updateGroupCall($0) }
    dict[-1535694705] = { return Api.Update.parse_updateGroupCallChainBlocks($0) }
    dict[192428418] = { return Api.Update.parse_updateGroupCallConnection($0) }
    dict[-219423922] = { return Api.Update.parse_updateGroupCallParticipants($0) }
    dict[1763610706] = { return Api.Update.parse_updateInlineBotCallbackQuery($0) }
    dict[1442983757] = { return Api.Update.parse_updateLangPack($0) }
    dict[1180041828] = { return Api.Update.parse_updateLangPackTooLong($0) }
    dict[1448076945] = { return Api.Update.parse_updateLoginToken($0) }
    dict[-710666460] = { return Api.Update.parse_updateMessageExtendedMedia($0) }
    dict[1318109142] = { return Api.Update.parse_updateMessageID($0) }
    dict[-1398708869] = { return Api.Update.parse_updateMessagePoll($0) }
    dict[619974263] = { return Api.Update.parse_updateMessagePollVote($0) }
    dict[506035194] = { return Api.Update.parse_updateMessageReactions($0) }
    dict[-2030252155] = { return Api.Update.parse_updateMoveStickerSetToTop($0) }
    dict[-1991136273] = { return Api.Update.parse_updateNewAuthorization($0) }
    dict[1656358105] = { return Api.Update.parse_updateNewChannelMessage($0) }
    dict[314359194] = { return Api.Update.parse_updateNewEncryptedMessage($0) }
    dict[522914557] = { return Api.Update.parse_updateNewMessage($0) }
    dict[-180508905] = { return Api.Update.parse_updateNewQuickReply($0) }
    dict[967122427] = { return Api.Update.parse_updateNewScheduledMessage($0) }
    dict[1753886890] = { return Api.Update.parse_updateNewStickerSet($0) }
    dict[405070859] = { return Api.Update.parse_updateNewStoryReaction($0) }
    dict[-1094555409] = { return Api.Update.parse_updateNotifySettings($0) }
    dict[-1955438642] = { return Api.Update.parse_updatePaidReactionPrivacy($0) }
    dict[-337610926] = { return Api.Update.parse_updatePeerBlocked($0) }
    dict[-1147422299] = { return Api.Update.parse_updatePeerHistoryTTL($0) }
    dict[-1263546448] = { return Api.Update.parse_updatePeerLocated($0) }
    dict[1786671974] = { return Api.Update.parse_updatePeerSettings($0) }
    dict[-1371598819] = { return Api.Update.parse_updatePeerWallpaper($0) }
    dict[1885586395] = { return Api.Update.parse_updatePendingJoinRequests($0) }
    dict[-1425052898] = { return Api.Update.parse_updatePhoneCall($0) }
    dict[643940105] = { return Api.Update.parse_updatePhoneCallSignalingData($0) }
    dict[1538885128] = { return Api.Update.parse_updatePinnedChannelMessages($0) }
    dict[-99664734] = { return Api.Update.parse_updatePinnedDialogs($0) }
    dict[-309990731] = { return Api.Update.parse_updatePinnedMessages($0) }
    dict[1751942566] = { return Api.Update.parse_updatePinnedSavedDialogs($0) }
    dict[-298113238] = { return Api.Update.parse_updatePrivacy($0) }
    dict[861169551] = { return Api.Update.parse_updatePtsChanged($0) }
    dict[-112784718] = { return Api.Update.parse_updateQuickReplies($0) }
    dict[1040518415] = { return Api.Update.parse_updateQuickReplyMessage($0) }
    dict[-693004986] = { return Api.Update.parse_updateReadChannelDiscussionInbox($0) }
    dict[1767677564] = { return Api.Update.parse_updateReadChannelDiscussionOutbox($0) }
    dict[-1842450928] = { return Api.Update.parse_updateReadChannelInbox($0) }
    dict[-1218471511] = { return Api.Update.parse_updateReadChannelOutbox($0) }
    dict[-78886548] = { return Api.Update.parse_updateReadFeaturedEmojiStickers($0) }
    dict[1461528386] = { return Api.Update.parse_updateReadFeaturedStickers($0) }
    dict[-1667805217] = { return Api.Update.parse_updateReadHistoryInbox($0) }
    dict[791617983] = { return Api.Update.parse_updateReadHistoryOutbox($0) }
    dict[-131960447] = { return Api.Update.parse_updateReadMessagesContents($0) }
    dict[2008081266] = { return Api.Update.parse_updateReadMonoForumInbox($0) }
    dict[-1532521610] = { return Api.Update.parse_updateReadMonoForumOutbox($0) }
    dict[-145845461] = { return Api.Update.parse_updateReadStories($0) }
    dict[821314523] = { return Api.Update.parse_updateRecentEmojiStatuses($0) }
    dict[1870160884] = { return Api.Update.parse_updateRecentReactions($0) }
    dict[-1706939360] = { return Api.Update.parse_updateRecentStickers($0) }
    dict[-1364222348] = { return Api.Update.parse_updateSavedDialogPinned($0) }
    dict[-1821035490] = { return Api.Update.parse_updateSavedGifs($0) }
    dict[969307186] = { return Api.Update.parse_updateSavedReactionTags($0) }
    dict[1960361625] = { return Api.Update.parse_updateSavedRingtones($0) }
    dict[1347068303] = { return Api.Update.parse_updateSentPhoneCode($0) }
    dict[2103604867] = { return Api.Update.parse_updateSentStoryReaction($0) }
    dict[-337352679] = { return Api.Update.parse_updateServiceNotification($0) }
    dict[-245208620] = { return Api.Update.parse_updateSmsJob($0) }
    dict[1317053305] = { return Api.Update.parse_updateStarsBalance($0) }
    dict[-1518030823] = { return Api.Update.parse_updateStarsRevenueStatus($0) }
    dict[834816008] = { return Api.Update.parse_updateStickerSets($0) }
    dict[196268545] = { return Api.Update.parse_updateStickerSetsOrder($0) }
    dict[738741697] = { return Api.Update.parse_updateStoriesStealthMode($0) }
    dict[1974712216] = { return Api.Update.parse_updateStory($0) }
    dict[468923833] = { return Api.Update.parse_updateStoryID($0) }
    dict[-2112423005] = { return Api.Update.parse_updateTheme($0) }
    dict[8703322] = { return Api.Update.parse_updateTranscribedAudio($0) }
    dict[542282808] = { return Api.Update.parse_updateUser($0) }
    dict[674706841] = { return Api.Update.parse_updateUserEmojiStatus($0) }
    dict[-1484486364] = { return Api.Update.parse_updateUserName($0) }
    dict[88680979] = { return Api.Update.parse_updateUserPhone($0) }
    dict[-440534818] = { return Api.Update.parse_updateUserStatus($0) }
    dict[-1071741569] = { return Api.Update.parse_updateUserTyping($0) }
    dict[2139689491] = { return Api.Update.parse_updateWebPage($0) }
    dict[361936797] = { return Api.Update.parse_updateWebViewResultSent($0) }
    dict[2027216577] = { return Api.Updates.parse_updateShort($0) }
    dict[1299050149] = { return Api.Updates.parse_updateShortChatMessage($0) }
    dict[826001400] = { return Api.Updates.parse_updateShortMessage($0) }
    dict[-1877614335] = { return Api.Updates.parse_updateShortSentMessage($0) }
    dict[1957577280] = { return Api.Updates.parse_updates($0) }
    dict[1918567619] = { return Api.Updates.parse_updatesCombined($0) }
    dict[-484987010] = { return Api.Updates.parse_updatesTooLong($0) }
    dict[-1886646706] = { return Api.UrlAuthResult.parse_urlAuthResultAccepted($0) }
    dict[-1445536993] = { return Api.UrlAuthResult.parse_urlAuthResultDefault($0) }
    dict[-1831650802] = { return Api.UrlAuthResult.parse_urlAuthResultRequest($0) }
    dict[34280482] = { return Api.User.parse_user($0) }
    dict[-742634630] = { return Api.User.parse_userEmpty($0) }
    dict[-1712881595] = { return Api.UserFull.parse_userFull($0) }
    dict[-2100168954] = { return Api.UserProfilePhoto.parse_userProfilePhoto($0) }
    dict[1326562017] = { return Api.UserProfilePhoto.parse_userProfilePhotoEmpty($0) }
    dict[164646985] = { return Api.UserStatus.parse_userStatusEmpty($0) }
    dict[1703516023] = { return Api.UserStatus.parse_userStatusLastMonth($0) }
    dict[1410997530] = { return Api.UserStatus.parse_userStatusLastWeek($0) }
    dict[9203775] = { return Api.UserStatus.parse_userStatusOffline($0) }
    dict[-306628279] = { return Api.UserStatus.parse_userStatusOnline($0) }
    dict[2065268168] = { return Api.UserStatus.parse_userStatusRecently($0) }
    dict[-1274595769] = { return Api.Username.parse_username($0) }
    dict[-567037804] = { return Api.VideoSize.parse_videoSize($0) }
    dict[-128171716] = { return Api.VideoSize.parse_videoSizeEmojiMarkup($0) }
    dict[228623102] = { return Api.VideoSize.parse_videoSizeStickerMarkup($0) }
    dict[-1539849235] = { return Api.WallPaper.parse_wallPaper($0) }
    dict[-528465642] = { return Api.WallPaper.parse_wallPaperNoFile($0) }
    dict[925826256] = { return Api.WallPaperSettings.parse_wallPaperSettings($0) }
    dict[-1493633966] = { return Api.WebAuthorization.parse_webAuthorization($0) }
    dict[475467473] = { return Api.WebDocument.parse_webDocument($0) }
    dict[-104284986] = { return Api.WebDocument.parse_webDocumentNoProxy($0) }
    dict[-392411726] = { return Api.WebPage.parse_webPage($0) }
    dict[555358088] = { return Api.WebPage.parse_webPageEmpty($0) }
    dict[1930545681] = { return Api.WebPage.parse_webPageNotModified($0) }
    dict[-1328464313] = { return Api.WebPage.parse_webPagePending($0) }
    dict[1355547603] = { return Api.WebPageAttribute.parse_webPageAttributeStickerSet($0) }
    dict[781501415] = { return Api.WebPageAttribute.parse_webPageAttributeStory($0) }
    dict[1421174295] = { return Api.WebPageAttribute.parse_webPageAttributeTheme($0) }
    dict[-814781000] = { return Api.WebPageAttribute.parse_webPageAttributeUniqueStarGift($0) }
    dict[211046684] = { return Api.WebViewMessageSent.parse_webViewMessageSent($0) }
    dict[1294139288] = { return Api.WebViewResult.parse_webViewResultUrl($0) }
    dict[-1389486888] = { return Api.account.AuthorizationForm.parse_authorizationForm($0) }
    dict[1275039392] = { return Api.account.Authorizations.parse_authorizations($0) }
    dict[1674235686] = { return Api.account.AutoDownloadSettings.parse_autoDownloadSettings($0) }
    dict[1279133341] = { return Api.account.AutoSaveSettings.parse_autoSaveSettings($0) }
    dict[-331111727] = { return Api.account.BusinessChatLinks.parse_businessChatLinks($0) }
    dict[400029819] = { return Api.account.ConnectedBots.parse_connectedBots($0) }
    dict[1474462241] = { return Api.account.ContentSettings.parse_contentSettings($0) }
    dict[731303195] = { return Api.account.EmailVerified.parse_emailVerified($0) }
    dict[-507835039] = { return Api.account.EmailVerified.parse_emailVerifiedLogin($0) }
    dict[-1866176559] = { return Api.account.EmojiStatuses.parse_emojiStatuses($0) }
    dict[-796072379] = { return Api.account.EmojiStatuses.parse_emojiStatusesNotModified($0) }
    dict[504403720] = { return Api.account.PaidMessagesRevenue.parse_paidMessagesRevenue($0) }
    dict[-1787080453] = { return Api.account.Password.parse_password($0) }
    dict[-1036572727] = { return Api.account.PasswordInputSettings.parse_passwordInputSettings($0) }
    dict[-1705233435] = { return Api.account.PasswordSettings.parse_passwordSettings($0) }
    dict[1352683077] = { return Api.account.PrivacyRules.parse_privacyRules($0) }
    dict[-478701471] = { return Api.account.ResetPasswordResult.parse_resetPasswordFailedWait($0) }
    dict[-383330754] = { return Api.account.ResetPasswordResult.parse_resetPasswordOk($0) }
    dict[-370148227] = { return Api.account.ResetPasswordResult.parse_resetPasswordRequestedWait($0) }
    dict[-1708937439] = { return Api.account.ResolvedBusinessChatLinks.parse_resolvedBusinessChatLinks($0) }
    dict[-1222230163] = { return Api.account.SavedRingtone.parse_savedRingtone($0) }
    dict[523271863] = { return Api.account.SavedRingtone.parse_savedRingtoneConverted($0) }
    dict[-1041683259] = { return Api.account.SavedRingtones.parse_savedRingtones($0) }
    dict[-67704655] = { return Api.account.SavedRingtones.parse_savedRingtonesNotModified($0) }
    dict[-2128640689] = { return Api.account.SentEmailCode.parse_sentEmailCode($0) }
    dict[1304052993] = { return Api.account.Takeout.parse_takeout($0) }
    dict[-1707242387] = { return Api.account.Themes.parse_themes($0) }
    dict[-199313886] = { return Api.account.Themes.parse_themesNotModified($0) }
    dict[-614138572] = { return Api.account.TmpPassword.parse_tmpPassword($0) }
    dict[-842824308] = { return Api.account.WallPapers.parse_wallPapers($0) }
    dict[471437699] = { return Api.account.WallPapers.parse_wallPapersNotModified($0) }
    dict[-313079300] = { return Api.account.WebAuthorizations.parse_webAuthorizations($0) }
    dict[782418132] = { return Api.auth.Authorization.parse_authorization($0) }
    dict[1148485274] = { return Api.auth.Authorization.parse_authorizationSignUpRequired($0) }
    dict[1948046307] = { return Api.auth.CodeType.parse_codeTypeCall($0) }
    dict[577556219] = { return Api.auth.CodeType.parse_codeTypeFlashCall($0) }
    dict[116234636] = { return Api.auth.CodeType.parse_codeTypeFragmentSms($0) }
    dict[-702884114] = { return Api.auth.CodeType.parse_codeTypeMissedCall($0) }
    dict[1923290508] = { return Api.auth.CodeType.parse_codeTypeSms($0) }
    dict[-1271602504] = { return Api.auth.ExportedAuthorization.parse_exportedAuthorization($0) }
    dict[-1012759713] = { return Api.auth.LoggedOut.parse_loggedOut($0) }
    dict[1654593920] = { return Api.auth.LoginToken.parse_loginToken($0) }
    dict[110008598] = { return Api.auth.LoginToken.parse_loginTokenMigrateTo($0) }
    dict[957176926] = { return Api.auth.LoginToken.parse_loginTokenSuccess($0) }
    dict[326715557] = { return Api.auth.PasswordRecovery.parse_passwordRecovery($0) }
    dict[1577067778] = { return Api.auth.SentCode.parse_sentCode($0) }
    dict[-674301568] = { return Api.auth.SentCode.parse_sentCodePaymentRequired($0) }
    dict[596704836] = { return Api.auth.SentCode.parse_sentCodeSuccess($0) }
    dict[1035688326] = { return Api.auth.SentCodeType.parse_sentCodeTypeApp($0) }
    dict[1398007207] = { return Api.auth.SentCodeType.parse_sentCodeTypeCall($0) }
    dict[-196020837] = { return Api.auth.SentCodeType.parse_sentCodeTypeEmailCode($0) }
    dict[10475318] = { return Api.auth.SentCodeType.parse_sentCodeTypeFirebaseSms($0) }
    dict[-1425815847] = { return Api.auth.SentCodeType.parse_sentCodeTypeFlashCall($0) }
    dict[-648651719] = { return Api.auth.SentCodeType.parse_sentCodeTypeFragmentSms($0) }
    dict[-2113903484] = { return Api.auth.SentCodeType.parse_sentCodeTypeMissedCall($0) }
    dict[-1521934870] = { return Api.auth.SentCodeType.parse_sentCodeTypeSetUpEmailRequired($0) }
    dict[-1073693790] = { return Api.auth.SentCodeType.parse_sentCodeTypeSms($0) }
    dict[-1284008785] = { return Api.auth.SentCodeType.parse_sentCodeTypeSmsPhrase($0) }
    dict[-1542017919] = { return Api.auth.SentCodeType.parse_sentCodeTypeSmsWord($0) }
    dict[-391678544] = { return Api.bots.BotInfo.parse_botInfo($0) }
    dict[428978491] = { return Api.bots.PopularAppBots.parse_popularAppBots($0) }
    dict[212278628] = { return Api.bots.PreviewInfo.parse_previewInfo($0) }
    dict[-309659827] = { return Api.channels.AdminLogResults.parse_adminLogResults($0) }
    dict[-541588713] = { return Api.channels.ChannelParticipant.parse_channelParticipant($0) }
    dict[-1699676497] = { return Api.channels.ChannelParticipants.parse_channelParticipants($0) }
    dict[-266911767] = { return Api.channels.ChannelParticipants.parse_channelParticipantsNotModified($0) }
    dict[-191450938] = { return Api.channels.SendAsPeers.parse_sendAsPeers($0) }
    dict[1044107055] = { return Api.channels.SponsoredMessageReportResult.parse_sponsoredMessageReportResultAdsHidden($0) }
    dict[-2073059774] = { return Api.channels.SponsoredMessageReportResult.parse_sponsoredMessageReportResultChooseOption($0) }
    dict[-1384544183] = { return Api.channels.SponsoredMessageReportResult.parse_sponsoredMessageReportResultReported($0) }
    dict[-250687953] = { return Api.chatlists.ChatlistInvite.parse_chatlistInvite($0) }
    dict[-91752871] = { return Api.chatlists.ChatlistInvite.parse_chatlistInviteAlready($0) }
    dict[-1816295539] = { return Api.chatlists.ChatlistUpdates.parse_chatlistUpdates($0) }
    dict[283567014] = { return Api.chatlists.ExportedChatlistInvite.parse_exportedChatlistInvite($0) }
    dict[279670215] = { return Api.chatlists.ExportedInvites.parse_exportedInvites($0) }
    dict[182326673] = { return Api.contacts.Blocked.parse_blocked($0) }
    dict[-513392236] = { return Api.contacts.Blocked.parse_blockedSlice($0) }
    dict[290452237] = { return Api.contacts.ContactBirthdays.parse_contactBirthdays($0) }
    dict[-353862078] = { return Api.contacts.Contacts.parse_contacts($0) }
    dict[-1219778094] = { return Api.contacts.Contacts.parse_contactsNotModified($0) }
    dict[-1290580579] = { return Api.contacts.Found.parse_found($0) }
    dict[2010127419] = { return Api.contacts.ImportedContacts.parse_importedContacts($0) }
    dict[2131196633] = { return Api.contacts.ResolvedPeer.parse_resolvedPeer($0) }
    dict[-352114556] = { return Api.contacts.SponsoredPeers.parse_sponsoredPeers($0) }
    dict[-365775695] = { return Api.contacts.SponsoredPeers.parse_sponsoredPeersEmpty($0) }
    dict[1891070632] = { return Api.contacts.TopPeers.parse_topPeers($0) }
    dict[-1255369827] = { return Api.contacts.TopPeers.parse_topPeersDisabled($0) }
    dict[-567906571] = { return Api.contacts.TopPeers.parse_topPeersNotModified($0) }
    dict[1857945489] = { return Api.fragment.CollectibleInfo.parse_collectibleInfo($0) }
    dict[-585598930] = { return Api.help.AppConfig.parse_appConfig($0) }
    dict[2094949405] = { return Api.help.AppConfig.parse_appConfigNotModified($0) }
    dict[-860107216] = { return Api.help.AppUpdate.parse_appUpdate($0) }
    dict[-1000708810] = { return Api.help.AppUpdate.parse_noAppUpdate($0) }
    dict[-2016381538] = { return Api.help.CountriesList.parse_countriesList($0) }
    dict[-1815339214] = { return Api.help.CountriesList.parse_countriesListNotModified($0) }
    dict[-1014526429] = { return Api.help.Country.parse_country($0) }
    dict[1107543535] = { return Api.help.CountryCode.parse_countryCode($0) }
    dict[1783556146] = { return Api.help.DeepLinkInfo.parse_deepLinkInfo($0) }
    dict[1722786150] = { return Api.help.DeepLinkInfo.parse_deepLinkInfoEmpty($0) }
    dict[415997816] = { return Api.help.InviteText.parse_inviteText($0) }
    dict[-1600596305] = { return Api.help.PassportConfig.parse_passportConfig($0) }
    dict[-1078332329] = { return Api.help.PassportConfig.parse_passportConfigNotModified($0) }
    dict[-1377014082] = { return Api.help.PeerColorOption.parse_peerColorOption($0) }
    dict[1987928555] = { return Api.help.PeerColorSet.parse_peerColorProfileSet($0) }
    dict[639736408] = { return Api.help.PeerColorSet.parse_peerColorSet($0) }
    dict[16313608] = { return Api.help.PeerColors.parse_peerColors($0) }
    dict[732034510] = { return Api.help.PeerColors.parse_peerColorsNotModified($0) }
    dict[1395946908] = { return Api.help.PremiumPromo.parse_premiumPromo($0) }
    dict[145021050] = { return Api.help.PromoData.parse_promoData($0) }
    dict[-1728664459] = { return Api.help.PromoData.parse_promoDataEmpty($0) }
    dict[235081943] = { return Api.help.RecentMeUrls.parse_recentMeUrls($0) }
    dict[398898678] = { return Api.help.Support.parse_support($0) }
    dict[-1945767479] = { return Api.help.SupportName.parse_supportName($0) }
    dict[2013922064] = { return Api.help.TermsOfService.parse_termsOfService($0) }
    dict[686618977] = { return Api.help.TermsOfServiceUpdate.parse_termsOfServiceUpdate($0) }
    dict[-483352705] = { return Api.help.TermsOfServiceUpdate.parse_termsOfServiceUpdateEmpty($0) }
    dict[2071260529] = { return Api.help.TimezonesList.parse_timezonesList($0) }
    dict[-1761146676] = { return Api.help.TimezonesList.parse_timezonesListNotModified($0) }
    dict[32192344] = { return Api.help.UserInfo.parse_userInfo($0) }
    dict[-206688531] = { return Api.help.UserInfo.parse_userInfoEmpty($0) }
    dict[-275956116] = { return Api.messages.AffectedFoundMessages.parse_affectedFoundMessages($0) }
    dict[-1269012015] = { return Api.messages.AffectedHistory.parse_affectedHistory($0) }
    dict[-2066640507] = { return Api.messages.AffectedMessages.parse_affectedMessages($0) }
    dict[-843329861] = { return Api.messages.AllStickers.parse_allStickers($0) }
    dict[-395967805] = { return Api.messages.AllStickers.parse_allStickersNotModified($0) }
    dict[1338747336] = { return Api.messages.ArchivedStickers.parse_archivedStickers($0) }
    dict[-1109696146] = { return Api.messages.AvailableEffects.parse_availableEffects($0) }
    dict[-772957605] = { return Api.messages.AvailableEffects.parse_availableEffectsNotModified($0) }
    dict[1989032621] = { return Api.messages.AvailableReactions.parse_availableReactions($0) }
    dict[-1626924713] = { return Api.messages.AvailableReactions.parse_availableReactionsNotModified($0) }
    dict[-347034123] = { return Api.messages.BotApp.parse_botApp($0) }
    dict[911761060] = { return Api.messages.BotCallbackAnswer.parse_botCallbackAnswer($0) }
    dict[-1899035375] = { return Api.messages.BotPreparedInlineMessage.parse_botPreparedInlineMessage($0) }
    dict[-534646026] = { return Api.messages.BotResults.parse_botResults($0) }
    dict[-1231326505] = { return Api.messages.ChatAdminsWithInvites.parse_chatAdminsWithInvites($0) }
    dict[-438840932] = { return Api.messages.ChatFull.parse_chatFull($0) }
    dict[-2118733814] = { return Api.messages.ChatInviteImporters.parse_chatInviteImporters($0) }
    dict[1694474197] = { return Api.messages.Chats.parse_chats($0) }
    dict[-1663561404] = { return Api.messages.Chats.parse_chatsSlice($0) }
    dict[-1571952873] = { return Api.messages.CheckedHistoryImportPeer.parse_checkedHistoryImportPeer($0) }
    dict[740433629] = { return Api.messages.DhConfig.parse_dhConfig($0) }
    dict[-1058912715] = { return Api.messages.DhConfig.parse_dhConfigNotModified($0) }
    dict[718878489] = { return Api.messages.DialogFilters.parse_dialogFilters($0) }
    dict[364538944] = { return Api.messages.Dialogs.parse_dialogs($0) }
    dict[-253500010] = { return Api.messages.Dialogs.parse_dialogsNotModified($0) }
    dict[1910543603] = { return Api.messages.Dialogs.parse_dialogsSlice($0) }
    dict[-1506535550] = { return Api.messages.DiscussionMessage.parse_discussionMessage($0) }
    dict[-2011186869] = { return Api.messages.EmojiGroups.parse_emojiGroups($0) }
    dict[1874111879] = { return Api.messages.EmojiGroups.parse_emojiGroupsNotModified($0) }
    dict[410107472] = { return Api.messages.ExportedChatInvite.parse_exportedChatInvite($0) }
    dict[572915951] = { return Api.messages.ExportedChatInvite.parse_exportedChatInviteReplaced($0) }
    dict[-1111085620] = { return Api.messages.ExportedChatInvites.parse_exportedChatInvites($0) }
    dict[750063767] = { return Api.messages.FavedStickers.parse_favedStickers($0) }
    dict[-1634752813] = { return Api.messages.FavedStickers.parse_favedStickersNotModified($0) }
    dict[-1103615738] = { return Api.messages.FeaturedStickers.parse_featuredStickers($0) }
    dict[-958657434] = { return Api.messages.FeaturedStickers.parse_featuredStickersNotModified($0) }
    dict[913709011] = { return Api.messages.ForumTopics.parse_forumTopics($0) }
    dict[-1963942446] = { return Api.messages.FoundStickerSets.parse_foundStickerSets($0) }
    dict[223655517] = { return Api.messages.FoundStickerSets.parse_foundStickerSetsNotModified($0) }
    dict[-2100698480] = { return Api.messages.FoundStickers.parse_foundStickers($0) }
    dict[1611711796] = { return Api.messages.FoundStickers.parse_foundStickersNotModified($0) }
    dict[-1707344487] = { return Api.messages.HighScores.parse_highScores($0) }
    dict[375566091] = { return Api.messages.HistoryImport.parse_historyImport($0) }
    dict[1578088377] = { return Api.messages.HistoryImportParsed.parse_historyImportParsed($0) }
    dict[-1456996667] = { return Api.messages.InactiveChats.parse_inactiveChats($0) }
    dict[2136862630] = { return Api.messages.InvitedUsers.parse_invitedUsers($0) }
    dict[649453030] = { return Api.messages.MessageEditData.parse_messageEditData($0) }
    dict[834488621] = { return Api.messages.MessageReactionsList.parse_messageReactionsList($0) }
    dict[-1228606141] = { return Api.messages.MessageViews.parse_messageViews($0) }
    dict[-948520370] = { return Api.messages.Messages.parse_channelMessages($0) }
    dict[-1938715001] = { return Api.messages.Messages.parse_messages($0) }
    dict[1951620897] = { return Api.messages.Messages.parse_messagesNotModified($0) }
    dict[978610270] = { return Api.messages.Messages.parse_messagesSlice($0) }
    dict[-83926371] = { return Api.messages.MyStickers.parse_myStickers($0) }
    dict[863093588] = { return Api.messages.PeerDialogs.parse_peerDialogs($0) }
    dict[1753266509] = { return Api.messages.PeerSettings.parse_peerSettings($0) }
    dict[-11046771] = { return Api.messages.PreparedInlineMessage.parse_preparedInlineMessage($0) }
    dict[-963811691] = { return Api.messages.QuickReplies.parse_quickReplies($0) }
    dict[1603398491] = { return Api.messages.QuickReplies.parse_quickRepliesNotModified($0) }
    dict[-352454890] = { return Api.messages.Reactions.parse_reactions($0) }
    dict[-1334846497] = { return Api.messages.Reactions.parse_reactionsNotModified($0) }
    dict[-1999405994] = { return Api.messages.RecentStickers.parse_recentStickers($0) }
    dict[186120336] = { return Api.messages.RecentStickers.parse_recentStickersNotModified($0) }
    dict[-130358751] = { return Api.messages.SavedDialogs.parse_savedDialogs($0) }
    dict[-1071681560] = { return Api.messages.SavedDialogs.parse_savedDialogsNotModified($0) }
    dict[1153080793] = { return Api.messages.SavedDialogs.parse_savedDialogsSlice($0) }
    dict[-2069878259] = { return Api.messages.SavedGifs.parse_savedGifs($0) }
    dict[-402498398] = { return Api.messages.SavedGifs.parse_savedGifsNotModified($0) }
    dict[844731658] = { return Api.messages.SavedReactionTags.parse_savedReactionTags($0) }
    dict[-2003084817] = { return Api.messages.SavedReactionTags.parse_savedReactionTagsNotModified($0) }
    dict[-398136321] = { return Api.messages.SearchCounter.parse_searchCounter($0) }
    dict[343859772] = { return Api.messages.SearchResultsCalendar.parse_searchResultsCalendar($0) }
    dict[1404185519] = { return Api.messages.SearchResultsPositions.parse_searchResultsPositions($0) }
    dict[-1802240206] = { return Api.messages.SentEncryptedMessage.parse_sentEncryptedFile($0) }
    dict[1443858741] = { return Api.messages.SentEncryptedMessage.parse_sentEncryptedMessage($0) }
    dict[-907141753] = { return Api.messages.SponsoredMessages.parse_sponsoredMessages($0) }
    dict[406407439] = { return Api.messages.SponsoredMessages.parse_sponsoredMessagesEmpty($0) }
    dict[1846886166] = { return Api.messages.StickerSet.parse_stickerSet($0) }
    dict[-738646805] = { return Api.messages.StickerSet.parse_stickerSetNotModified($0) }
    dict[904138920] = { return Api.messages.StickerSetInstallResult.parse_stickerSetInstallResultArchive($0) }
    dict[946083368] = { return Api.messages.StickerSetInstallResult.parse_stickerSetInstallResultSuccess($0) }
    dict[816245886] = { return Api.messages.Stickers.parse_stickers($0) }
    dict[-244016606] = { return Api.messages.Stickers.parse_stickersNotModified($0) }
    dict[-809903785] = { return Api.messages.TranscribedAudio.parse_transcribedAudio($0) }
    dict[870003448] = { return Api.messages.TranslatedText.parse_translateResult($0) }
    dict[1218005070] = { return Api.messages.VotesList.parse_votesList($0) }
    dict[-44166467] = { return Api.messages.WebPage.parse_webPage($0) }
    dict[-1254192351] = { return Api.messages.WebPagePreview.parse_webPagePreview($0) }
    dict[1042605427] = { return Api.payments.BankCardData.parse_bankCardData($0) }
    dict[675942550] = { return Api.payments.CheckedGiftCode.parse_checkedGiftCode($0) }
    dict[-1730811363] = { return Api.payments.ConnectedStarRefBots.parse_connectedStarRefBots($0) }
    dict[-1362048039] = { return Api.payments.ExportedInvoice.parse_exportedInvoice($0) }
    dict[1130879648] = { return Api.payments.GiveawayInfo.parse_giveawayInfo($0) }
    dict[-512366993] = { return Api.payments.GiveawayInfo.parse_giveawayInfoResults($0) }
    dict[-1610250415] = { return Api.payments.PaymentForm.parse_paymentForm($0) }
    dict[-1272590367] = { return Api.payments.PaymentForm.parse_paymentFormStarGift($0) }
    dict[2079764828] = { return Api.payments.PaymentForm.parse_paymentFormStars($0) }
    dict[1891958275] = { return Api.payments.PaymentReceipt.parse_paymentReceipt($0) }
    dict[-625215430] = { return Api.payments.PaymentReceipt.parse_paymentReceiptStars($0) }
    dict[1314881805] = { return Api.payments.PaymentResult.parse_paymentResult($0) }
    dict[-666824391] = { return Api.payments.PaymentResult.parse_paymentVerificationNeeded($0) }
    dict[-1803939105] = { return Api.payments.ResaleStarGifts.parse_resaleStarGifts($0) }
    dict[-74456004] = { return Api.payments.SavedInfo.parse_savedInfo($0) }
    dict[-1779201615] = { return Api.payments.SavedStarGifts.parse_savedStarGifts($0) }
    dict[377215243] = { return Api.payments.StarGiftUpgradePreview.parse_starGiftUpgradePreview($0) }
    dict[-2069218660] = { return Api.payments.StarGiftWithdrawalUrl.parse_starGiftWithdrawalUrl($0) }
    dict[-1877571094] = { return Api.payments.StarGifts.parse_starGifts($0) }
    dict[-1551326360] = { return Api.payments.StarGifts.parse_starGiftsNotModified($0) }
    dict[961445665] = { return Api.payments.StarsRevenueAdsAccountUrl.parse_starsRevenueAdsAccountUrl($0) }
    dict[-919881925] = { return Api.payments.StarsRevenueStats.parse_starsRevenueStats($0) }
    dict[497778871] = { return Api.payments.StarsRevenueWithdrawalUrl.parse_starsRevenueWithdrawalUrl($0) }
    dict[1822222573] = { return Api.payments.StarsStatus.parse_starsStatus($0) }
    dict[-1261053863] = { return Api.payments.SuggestedStarRefBots.parse_suggestedStarRefBots($0) }
    dict[-895289845] = { return Api.payments.UniqueStarGift.parse_uniqueStarGift($0) }
    dict[-784000893] = { return Api.payments.ValidatedRequestedInfo.parse_validatedRequestedInfo($0) }
    dict[541839704] = { return Api.phone.ExportedGroupCallInvite.parse_exportedGroupCallInvite($0) }
    dict[-1636664659] = { return Api.phone.GroupCall.parse_groupCall($0) }
    dict[-790330702] = { return Api.phone.GroupCallStreamChannels.parse_groupCallStreamChannels($0) }
    dict[767505458] = { return Api.phone.GroupCallStreamRtmpUrl.parse_groupCallStreamRtmpUrl($0) }
    dict[-193506890] = { return Api.phone.GroupParticipants.parse_groupParticipants($0) }
    dict[-1343921601] = { return Api.phone.JoinAsPeers.parse_joinAsPeers($0) }
    dict[-326966976] = { return Api.phone.PhoneCall.parse_phoneCall($0) }
    dict[539045032] = { return Api.photos.Photo.parse_photo($0) }
    dict[-1916114267] = { return Api.photos.Photos.parse_photos($0) }
    dict[352657236] = { return Api.photos.Photos.parse_photosSlice($0) }
    dict[-2030542532] = { return Api.premium.BoostsList.parse_boostsList($0) }
    dict[1230586490] = { return Api.premium.BoostsStatus.parse_boostsStatus($0) }
    dict[-1696454430] = { return Api.premium.MyBoosts.parse_myBoosts($0) }
    dict[-594852657] = { return Api.smsjobs.EligibilityToJoin.parse_eligibleToJoin($0) }
    dict[720277905] = { return Api.smsjobs.Status.parse_status($0) }
    dict[1409802903] = { return Api.stats.BroadcastRevenueStats.parse_broadcastRevenueStats($0) }
    dict[-2028632986] = { return Api.stats.BroadcastRevenueTransactions.parse_broadcastRevenueTransactions($0) }
    dict[-328886473] = { return Api.stats.BroadcastRevenueWithdrawalUrl.parse_broadcastRevenueWithdrawalUrl($0) }
    dict[963421692] = { return Api.stats.BroadcastStats.parse_broadcastStats($0) }
    dict[-276825834] = { return Api.stats.MegagroupStats.parse_megagroupStats($0) }
    dict[2145983508] = { return Api.stats.MessageStats.parse_messageStats($0) }
    dict[-1828487648] = { return Api.stats.PublicForwards.parse_publicForwards($0) }
    dict[1355613820] = { return Api.stats.StoryStats.parse_storyStats($0) }
    dict[-2046910401] = { return Api.stickers.SuggestedShortName.parse_suggestedShortName($0) }
    dict[-891180321] = { return Api.storage.FileType.parse_fileGif($0) }
    dict[8322574] = { return Api.storage.FileType.parse_fileJpeg($0) }
    dict[1258941372] = { return Api.storage.FileType.parse_fileMov($0) }
    dict[1384777335] = { return Api.storage.FileType.parse_fileMp3($0) }
    dict[-1278304028] = { return Api.storage.FileType.parse_fileMp4($0) }
    dict[1086091090] = { return Api.storage.FileType.parse_filePartial($0) }
    dict[-1373745011] = { return Api.storage.FileType.parse_filePdf($0) }
    dict[172975040] = { return Api.storage.FileType.parse_filePng($0) }
    dict[-1432995067] = { return Api.storage.FileType.parse_fileUnknown($0) }
    dict[276907596] = { return Api.storage.FileType.parse_fileWebp($0) }
    dict[1862033025] = { return Api.stories.AllStories.parse_allStories($0) }
    dict[291044926] = { return Api.stories.AllStories.parse_allStoriesNotModified($0) }
    dict[-1014513586] = { return Api.stories.CanSendStoryCount.parse_canSendStoryCount($0) }
    dict[-488736969] = { return Api.stories.FoundStories.parse_foundStories($0) }
    dict[-890861720] = { return Api.stories.PeerStories.parse_peerStories($0) }
    dict[1673780490] = { return Api.stories.Stories.parse_stories($0) }
    dict[-1436583780] = { return Api.stories.StoryReactionsList.parse_storyReactionsList($0) }
    dict[-560009955] = { return Api.stories.StoryViews.parse_storyViews($0) }
    dict[1507299269] = { return Api.stories.StoryViewsList.parse_storyViewsList($0) }
    dict[543450958] = { return Api.updates.ChannelDifference.parse_channelDifference($0) }
    dict[1041346555] = { return Api.updates.ChannelDifference.parse_channelDifferenceEmpty($0) }
    dict[-1531132162] = { return Api.updates.ChannelDifference.parse_channelDifferenceTooLong($0) }
    dict[16030880] = { return Api.updates.Difference.parse_difference($0) }
    dict[1567990072] = { return Api.updates.Difference.parse_differenceEmpty($0) }
    dict[-1459938943] = { return Api.updates.Difference.parse_differenceSlice($0) }
    dict[1258196845] = { return Api.updates.Difference.parse_differenceTooLong($0) }
    dict[-1519637954] = { return Api.updates.State.parse_state($0) }
    dict[-1449145777] = { return Api.upload.CdnFile.parse_cdnFile($0) }
    dict[-290921362] = { return Api.upload.CdnFile.parse_cdnFileReuploadNeeded($0) }
    dict[157948117] = { return Api.upload.File.parse_file($0) }
    dict[-242427324] = { return Api.upload.File.parse_fileCdnRedirect($0) }
    dict[568808380] = { return Api.upload.WebFile.parse_webFile($0) }
    dict[997004590] = { return Api.users.UserFull.parse_userFull($0) }
    dict[1658259128] = { return Api.users.Users.parse_users($0) }
    dict[828000628] = { return Api.users.Users.parse_usersSlice($0) }
    return dict
}()

public extension Api {
    static func parse(_ buffer: Buffer) -> Any? {
        let reader = BufferReader(buffer)
        if let signature = reader.readInt32() {
            return parse(reader, signature: signature)
        }
        return nil
    }
    
        static func parse(_ reader: BufferReader, signature: Int32) -> Any? {
            if let parser = parsers[signature] {
                return parser(reader)
            }
            else {
                telegramApiLog("Type constructor \(String(UInt32(bitPattern: signature), radix: 16, uppercase: false)) not found")
                return nil
            }
        }
        
        static func parseVector<T>(_ reader: BufferReader, elementSignature: Int32, elementType: T.Type) -> [T]? {
        if let count = reader.readInt32() {
            var array = [T]()
            var i: Int32 = 0
            while i < count {
                var signature = elementSignature
                if elementSignature == 0 {
                    if let unboxedSignature = reader.readInt32() {
                        signature = unboxedSignature
                    }
                    else {
                        return nil
                    }
                }
                if elementType == Buffer.self {
                    if let item = parseBytes(reader) as? T {
                        array.append(item)
                    } else {
                        return nil
                    }
                } else {
                if let item = Api.parse(reader, signature: signature) as? T {
                    array.append(item)
                }
                else {
                    return nil
                }
                }
                i += 1
            }
            return array
        }
        return nil
    }
    
    static func serializeObject(_ object: Any, buffer: Buffer, boxed: Swift.Bool) {
        switch object {
            case let _1 as Api.AccountDaysTTL:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AttachMenuBot:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AttachMenuBotIcon:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AttachMenuBotIconColor:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AttachMenuBots:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AttachMenuBotsBot:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AttachMenuPeerType:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Authorization:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AutoDownloadSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AutoSaveException:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AutoSaveSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AvailableEffect:
                _1.serialize(buffer, boxed)
            case let _1 as Api.AvailableReaction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BankCardOpenUrl:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BaseTheme:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Birthday:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Bool:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Boost:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotApp:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotAppSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotBusinessConnection:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotCommand:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotCommandScope:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotInlineMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotInlineResult:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotMenuButton:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotPreviewMedia:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotVerification:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BotVerifierSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BroadcastRevenueBalances:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BroadcastRevenueTransaction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessAwayMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessAwayMessageSchedule:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessBotRecipients:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessBotRights:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessChatLink:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessGreetingMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessIntro:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessLocation:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessRecipients:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessWeeklyOpen:
                _1.serialize(buffer, boxed)
            case let _1 as Api.BusinessWorkHours:
                _1.serialize(buffer, boxed)
            case let _1 as Api.CdnConfig:
                _1.serialize(buffer, boxed)
            case let _1 as Api.CdnPublicKey:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChannelAdminLogEvent:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChannelAdminLogEventAction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChannelAdminLogEventsFilter:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChannelLocation:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChannelMessagesFilter:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChannelParticipant:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChannelParticipantsFilter:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Chat:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatAdminRights:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatAdminWithInvites:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatBannedRights:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatFull:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatInvite:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatInviteImporter:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatOnlines:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatParticipant:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatParticipants:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatPhoto:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ChatReactions:
                _1.serialize(buffer, boxed)
            case let _1 as Api.CodeSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Config:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ConnectedBot:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ConnectedBotStarRef:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Contact:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ContactBirthday:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ContactStatus:
                _1.serialize(buffer, boxed)
            case let _1 as Api.DataJSON:
                _1.serialize(buffer, boxed)
            case let _1 as Api.DcOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.DefaultHistoryTTL:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Dialog:
                _1.serialize(buffer, boxed)
            case let _1 as Api.DialogFilter:
                _1.serialize(buffer, boxed)
            case let _1 as Api.DialogFilterSuggested:
                _1.serialize(buffer, boxed)
            case let _1 as Api.DialogPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.DisallowedGiftsSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Document:
                _1.serialize(buffer, boxed)
            case let _1 as Api.DocumentAttribute:
                _1.serialize(buffer, boxed)
            case let _1 as Api.DraftMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EmailVerification:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EmailVerifyPurpose:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EmojiGroup:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EmojiKeyword:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EmojiKeywordsDifference:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EmojiLanguage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EmojiList:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EmojiStatus:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EmojiURL:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EncryptedChat:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EncryptedFile:
                _1.serialize(buffer, boxed)
            case let _1 as Api.EncryptedMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ExportedChatInvite:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ExportedChatlistInvite:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ExportedContactToken:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ExportedMessageLink:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ExportedStoryLink:
                _1.serialize(buffer, boxed)
            case let _1 as Api.FactCheck:
                _1.serialize(buffer, boxed)
            case let _1 as Api.FileHash:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Folder:
                _1.serialize(buffer, boxed)
            case let _1 as Api.FolderPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ForumTopic:
                _1.serialize(buffer, boxed)
            case let _1 as Api.FoundStory:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Game:
                _1.serialize(buffer, boxed)
            case let _1 as Api.GeoPoint:
                _1.serialize(buffer, boxed)
            case let _1 as Api.GeoPointAddress:
                _1.serialize(buffer, boxed)
            case let _1 as Api.GlobalPrivacySettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.GroupCall:
                _1.serialize(buffer, boxed)
            case let _1 as Api.GroupCallParticipant:
                _1.serialize(buffer, boxed)
            case let _1 as Api.GroupCallParticipantVideo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.GroupCallParticipantVideoSourceGroup:
                _1.serialize(buffer, boxed)
            case let _1 as Api.GroupCallStreamChannel:
                _1.serialize(buffer, boxed)
            case let _1 as Api.HighScore:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ImportedContact:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InlineBotSwitchPM:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InlineBotWebView:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InlineQueryPeerType:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputAppEvent:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBotApp:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBotInlineMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBotInlineMessageID:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBotInlineResult:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBusinessAwayMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBusinessBotRecipients:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBusinessChatLink:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBusinessGreetingMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBusinessIntro:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputBusinessRecipients:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputChannel:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputChatPhoto:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputChatlist:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputCheckPasswordSRP:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputClientProxy:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputCollectible:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputContact:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputDialogPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputDocument:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputEncryptedChat:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputEncryptedFile:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputFile:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputFileLocation:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputFolderPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputGame:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputGeoPoint:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputGroupCall:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputInvoice:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputMedia:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputNotifyPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputPaymentCredentials:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputPeerNotifySettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputPhoneCall:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputPhoto:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputPrivacyKey:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputPrivacyRule:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputQuickReplyShortcut:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputReplyTo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputSavedStarGift:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputSecureFile:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputSecureValue:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputSingleMedia:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputStarsTransaction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputStickerSet:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputStickerSetItem:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputStickeredMedia:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputStorePaymentPurpose:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputTheme:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputThemeSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputUser:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputWallPaper:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputWebDocument:
                _1.serialize(buffer, boxed)
            case let _1 as Api.InputWebFileLocation:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Invoice:
                _1.serialize(buffer, boxed)
            case let _1 as Api.JSONObjectValue:
                _1.serialize(buffer, boxed)
            case let _1 as Api.JSONValue:
                _1.serialize(buffer, boxed)
            case let _1 as Api.KeyboardButton:
                _1.serialize(buffer, boxed)
            case let _1 as Api.KeyboardButtonRow:
                _1.serialize(buffer, boxed)
            case let _1 as Api.LabeledPrice:
                _1.serialize(buffer, boxed)
            case let _1 as Api.LangPackDifference:
                _1.serialize(buffer, boxed)
            case let _1 as Api.LangPackLanguage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.LangPackString:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MaskCoords:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MediaArea:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MediaAreaCoordinates:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Message:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageAction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageEntity:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageExtendedMedia:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageFwdHeader:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageMedia:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessagePeerReaction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessagePeerVote:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageRange:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageReactions:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageReactor:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageReplies:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageReplyHeader:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageReportOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessageViews:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MessagesFilter:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MissingInvitee:
                _1.serialize(buffer, boxed)
            case let _1 as Api.MyBoost:
                _1.serialize(buffer, boxed)
            case let _1 as Api.NearestDc:
                _1.serialize(buffer, boxed)
            case let _1 as Api.NotificationSound:
                _1.serialize(buffer, boxed)
            case let _1 as Api.NotifyPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.OutboxReadDate:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Page:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PageBlock:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PageCaption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PageListItem:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PageListOrderedItem:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PageRelatedArticle:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PageTableCell:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PageTableRow:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PaidReactionPrivacy:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PasswordKdfAlgo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PaymentCharge:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PaymentFormMethod:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PaymentRequestedInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PaymentSavedCredentials:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Peer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PeerBlocked:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PeerColor:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PeerLocated:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PeerNotifySettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PeerSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PeerStories:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PendingSuggestion:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PhoneCall:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PhoneCallDiscardReason:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PhoneCallProtocol:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PhoneConnection:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Photo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PhotoSize:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Poll:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PollAnswer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PollAnswerVoters:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PollResults:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PopularContact:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PostAddress:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PostInteractionCounters:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PremiumGiftCodeOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PremiumSubscriptionOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PrepaidGiveaway:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PrivacyKey:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PrivacyRule:
                _1.serialize(buffer, boxed)
            case let _1 as Api.PublicForward:
                _1.serialize(buffer, boxed)
            case let _1 as Api.QuickReply:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Reaction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ReactionCount:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ReactionNotificationsFrom:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ReactionsNotifySettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ReadParticipantDate:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ReceivedNotifyMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.RecentMeUrl:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ReplyMarkup:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ReportReason:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ReportResult:
                _1.serialize(buffer, boxed)
            case let _1 as Api.RequestPeerType:
                _1.serialize(buffer, boxed)
            case let _1 as Api.RequestedPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.RequirementToContact:
                _1.serialize(buffer, boxed)
            case let _1 as Api.RestrictionReason:
                _1.serialize(buffer, boxed)
            case let _1 as Api.RichText:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SavedContact:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SavedDialog:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SavedReactionTag:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SavedStarGift:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SearchResultsCalendarPeriod:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SearchResultsPosition:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecureCredentialsEncrypted:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecureData:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecureFile:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecurePasswordKdfAlgo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecurePlainData:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecureRequiredType:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecureSecretSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecureValue:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecureValueError:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecureValueHash:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SecureValueType:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SendAsPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SendMessageAction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ShippingOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SmsJob:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SponsoredMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SponsoredMessageReportOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.SponsoredPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarGift:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarGiftAttribute:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarGiftAttributeCounter:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarGiftAttributeId:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarRefProgram:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsAmount:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsGiftOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsGiveawayOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsGiveawayWinnersOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsRevenueStatus:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsSubscription:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsSubscriptionPricing:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsTopupOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsTransaction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StarsTransactionPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StatsAbsValueAndPrev:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StatsDateRangeDays:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StatsGraph:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StatsGroupTopAdmin:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StatsGroupTopInviter:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StatsGroupTopPoster:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StatsPercentValue:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StatsURL:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StickerKeyword:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StickerPack:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StickerSet:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StickerSetCovered:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StoriesStealthMode:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StoryFwdHeader:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StoryItem:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StoryReaction:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StoryView:
                _1.serialize(buffer, boxed)
            case let _1 as Api.StoryViews:
                _1.serialize(buffer, boxed)
            case let _1 as Api.TextWithEntities:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Theme:
                _1.serialize(buffer, boxed)
            case let _1 as Api.ThemeSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Timezone:
                _1.serialize(buffer, boxed)
            case let _1 as Api.TopPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.TopPeerCategory:
                _1.serialize(buffer, boxed)
            case let _1 as Api.TopPeerCategoryPeers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Update:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Updates:
                _1.serialize(buffer, boxed)
            case let _1 as Api.UrlAuthResult:
                _1.serialize(buffer, boxed)
            case let _1 as Api.User:
                _1.serialize(buffer, boxed)
            case let _1 as Api.UserFull:
                _1.serialize(buffer, boxed)
            case let _1 as Api.UserProfilePhoto:
                _1.serialize(buffer, boxed)
            case let _1 as Api.UserStatus:
                _1.serialize(buffer, boxed)
            case let _1 as Api.Username:
                _1.serialize(buffer, boxed)
            case let _1 as Api.VideoSize:
                _1.serialize(buffer, boxed)
            case let _1 as Api.WallPaper:
                _1.serialize(buffer, boxed)
            case let _1 as Api.WallPaperSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.WebAuthorization:
                _1.serialize(buffer, boxed)
            case let _1 as Api.WebDocument:
                _1.serialize(buffer, boxed)
            case let _1 as Api.WebPage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.WebPageAttribute:
                _1.serialize(buffer, boxed)
            case let _1 as Api.WebViewMessageSent:
                _1.serialize(buffer, boxed)
            case let _1 as Api.WebViewResult:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.AuthorizationForm:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.Authorizations:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.AutoDownloadSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.AutoSaveSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.BusinessChatLinks:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.ConnectedBots:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.ContentSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.EmailVerified:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.EmojiStatuses:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.PaidMessagesRevenue:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.Password:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.PasswordInputSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.PasswordSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.PrivacyRules:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.ResetPasswordResult:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.ResolvedBusinessChatLinks:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.SavedRingtone:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.SavedRingtones:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.SentEmailCode:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.Takeout:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.Themes:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.TmpPassword:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.WallPapers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.account.WebAuthorizations:
                _1.serialize(buffer, boxed)
            case let _1 as Api.auth.Authorization:
                _1.serialize(buffer, boxed)
            case let _1 as Api.auth.CodeType:
                _1.serialize(buffer, boxed)
            case let _1 as Api.auth.ExportedAuthorization:
                _1.serialize(buffer, boxed)
            case let _1 as Api.auth.LoggedOut:
                _1.serialize(buffer, boxed)
            case let _1 as Api.auth.LoginToken:
                _1.serialize(buffer, boxed)
            case let _1 as Api.auth.PasswordRecovery:
                _1.serialize(buffer, boxed)
            case let _1 as Api.auth.SentCode:
                _1.serialize(buffer, boxed)
            case let _1 as Api.auth.SentCodeType:
                _1.serialize(buffer, boxed)
            case let _1 as Api.bots.BotInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.bots.PopularAppBots:
                _1.serialize(buffer, boxed)
            case let _1 as Api.bots.PreviewInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.channels.AdminLogResults:
                _1.serialize(buffer, boxed)
            case let _1 as Api.channels.ChannelParticipant:
                _1.serialize(buffer, boxed)
            case let _1 as Api.channels.ChannelParticipants:
                _1.serialize(buffer, boxed)
            case let _1 as Api.channels.SendAsPeers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.channels.SponsoredMessageReportResult:
                _1.serialize(buffer, boxed)
            case let _1 as Api.chatlists.ChatlistInvite:
                _1.serialize(buffer, boxed)
            case let _1 as Api.chatlists.ChatlistUpdates:
                _1.serialize(buffer, boxed)
            case let _1 as Api.chatlists.ExportedChatlistInvite:
                _1.serialize(buffer, boxed)
            case let _1 as Api.chatlists.ExportedInvites:
                _1.serialize(buffer, boxed)
            case let _1 as Api.contacts.Blocked:
                _1.serialize(buffer, boxed)
            case let _1 as Api.contacts.ContactBirthdays:
                _1.serialize(buffer, boxed)
            case let _1 as Api.contacts.Contacts:
                _1.serialize(buffer, boxed)
            case let _1 as Api.contacts.Found:
                _1.serialize(buffer, boxed)
            case let _1 as Api.contacts.ImportedContacts:
                _1.serialize(buffer, boxed)
            case let _1 as Api.contacts.ResolvedPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.contacts.SponsoredPeers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.contacts.TopPeers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.fragment.CollectibleInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.AppConfig:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.AppUpdate:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.CountriesList:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.Country:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.CountryCode:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.DeepLinkInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.InviteText:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.PassportConfig:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.PeerColorOption:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.PeerColorSet:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.PeerColors:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.PremiumPromo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.PromoData:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.RecentMeUrls:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.Support:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.SupportName:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.TermsOfService:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.TermsOfServiceUpdate:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.TimezonesList:
                _1.serialize(buffer, boxed)
            case let _1 as Api.help.UserInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.AffectedFoundMessages:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.AffectedHistory:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.AffectedMessages:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.AllStickers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.ArchivedStickers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.AvailableEffects:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.AvailableReactions:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.BotApp:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.BotCallbackAnswer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.BotPreparedInlineMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.BotResults:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.ChatAdminsWithInvites:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.ChatFull:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.ChatInviteImporters:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.Chats:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.CheckedHistoryImportPeer:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.DhConfig:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.DialogFilters:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.Dialogs:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.DiscussionMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.EmojiGroups:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.ExportedChatInvite:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.ExportedChatInvites:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.FavedStickers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.FeaturedStickers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.ForumTopics:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.FoundStickerSets:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.FoundStickers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.HighScores:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.HistoryImport:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.HistoryImportParsed:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.InactiveChats:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.InvitedUsers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.MessageEditData:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.MessageReactionsList:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.MessageViews:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.Messages:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.MyStickers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.PeerDialogs:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.PeerSettings:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.PreparedInlineMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.QuickReplies:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.Reactions:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.RecentStickers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.SavedDialogs:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.SavedGifs:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.SavedReactionTags:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.SearchCounter:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.SearchResultsCalendar:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.SearchResultsPositions:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.SentEncryptedMessage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.SponsoredMessages:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.StickerSet:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.StickerSetInstallResult:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.Stickers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.TranscribedAudio:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.TranslatedText:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.VotesList:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.WebPage:
                _1.serialize(buffer, boxed)
            case let _1 as Api.messages.WebPagePreview:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.BankCardData:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.CheckedGiftCode:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.ConnectedStarRefBots:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.ExportedInvoice:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.GiveawayInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.PaymentForm:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.PaymentReceipt:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.PaymentResult:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.ResaleStarGifts:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.SavedInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.SavedStarGifts:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.StarGiftUpgradePreview:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.StarGiftWithdrawalUrl:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.StarGifts:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.StarsRevenueAdsAccountUrl:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.StarsRevenueStats:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.StarsRevenueWithdrawalUrl:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.StarsStatus:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.SuggestedStarRefBots:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.UniqueStarGift:
                _1.serialize(buffer, boxed)
            case let _1 as Api.payments.ValidatedRequestedInfo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.phone.ExportedGroupCallInvite:
                _1.serialize(buffer, boxed)
            case let _1 as Api.phone.GroupCall:
                _1.serialize(buffer, boxed)
            case let _1 as Api.phone.GroupCallStreamChannels:
                _1.serialize(buffer, boxed)
            case let _1 as Api.phone.GroupCallStreamRtmpUrl:
                _1.serialize(buffer, boxed)
            case let _1 as Api.phone.GroupParticipants:
                _1.serialize(buffer, boxed)
            case let _1 as Api.phone.JoinAsPeers:
                _1.serialize(buffer, boxed)
            case let _1 as Api.phone.PhoneCall:
                _1.serialize(buffer, boxed)
            case let _1 as Api.photos.Photo:
                _1.serialize(buffer, boxed)
            case let _1 as Api.photos.Photos:
                _1.serialize(buffer, boxed)
            case let _1 as Api.premium.BoostsList:
                _1.serialize(buffer, boxed)
            case let _1 as Api.premium.BoostsStatus:
                _1.serialize(buffer, boxed)
            case let _1 as Api.premium.MyBoosts:
                _1.serialize(buffer, boxed)
            case let _1 as Api.smsjobs.EligibilityToJoin:
                _1.serialize(buffer, boxed)
            case let _1 as Api.smsjobs.Status:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stats.BroadcastRevenueStats:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stats.BroadcastRevenueTransactions:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stats.BroadcastRevenueWithdrawalUrl:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stats.BroadcastStats:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stats.MegagroupStats:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stats.MessageStats:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stats.PublicForwards:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stats.StoryStats:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stickers.SuggestedShortName:
                _1.serialize(buffer, boxed)
            case let _1 as Api.storage.FileType:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stories.AllStories:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stories.CanSendStoryCount:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stories.FoundStories:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stories.PeerStories:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stories.Stories:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stories.StoryReactionsList:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stories.StoryViews:
                _1.serialize(buffer, boxed)
            case let _1 as Api.stories.StoryViewsList:
                _1.serialize(buffer, boxed)
            case let _1 as Api.updates.ChannelDifference:
                _1.serialize(buffer, boxed)
            case let _1 as Api.updates.Difference:
                _1.serialize(buffer, boxed)
            case let _1 as Api.updates.State:
                _1.serialize(buffer, boxed)
            case let _1 as Api.upload.CdnFile:
                _1.serialize(buffer, boxed)
            case let _1 as Api.upload.File:
                _1.serialize(buffer, boxed)
            case let _1 as Api.upload.WebFile:
                _1.serialize(buffer, boxed)
            case let _1 as Api.users.UserFull:
                _1.serialize(buffer, boxed)
            case let _1 as Api.users.Users:
                _1.serialize(buffer, boxed)
            default:
                break
        }
    }

}
