Changes in 1.8.0 (29 Dec 2021):

* Changed the type of user, basic group and supergroup identifiers from `int32` to `int53`.
* Simplified chat list loading and removed the ability to misuse the method `getChats`:
  - Renamed the method `getChats` to `loadChats`.
  - Removed the parameters `offset_order` and `offset_chat_id` from the method `loadChats`. Chats are now always loaded
    from the last known chat in the list.
  - Changed the type of the result in the method `loadChats` to `ok`. If no chats were loaded, a 404 error is returned.
    The order of chats in the list must be maintained using the updates `updateChatPosition`, `updateChatLastMessage`,
    and `updateChatDraftMessage`.
  - Added the convenience method `getChats`, which returns the requested number of chats from the beginning of a chat
    list and can be used if the list of chats doesn't need to be maintained in a consistent state.
* Added the ability to hook TDLib log messages:
  - Added the function `td_set_log_message_callback` to JSON interface.
  - Added the function `set_log_message_callback` to the class `ClientManager`.
  - Added the function `SetLogMessageCallback` to the UWP native wrapper through C++/CX.
  - Deprecated the function `td_set_log_fatal_error_callback` in JSON interface in favor of
    the function `td_set_log_message_callback`.
  - Deprecated the function `Log::set_fatal_error_callback` in favor of
    the function `ClientManager::set_log_message_callback`.
* Added support for sending messages on behalf of public channels owned by the user:
  - Added the field `message_sender_id` to the class `chat`, containing the identifier of the currently selected
    message sender.
  - Added the update `updateChatMessageSender`.
  - Added the method `getChatAvailableMessageSenders`, returning the list of available message senders for the chat.
  - Added the method `setChatMessageSender`, changing the currently selected message sender.
  - Added the field `need_another_sender` to the class `messageSendingStateFailed`. If it is true, an alert needs
    to be shown to the user that the message will be re-sent on behalf of another sender.
  - Replaced the method `deleteChatMessagesFromUser` with the method `deleteChatMessagesBySender`, expecting
    a `MessageSender` instead of a user identifier.
  - Replaced the update `updateUserChatAction` with the update `updateChatAction`, containing a `MessageSender`
    instead of a user identifier as a source of the chat action.
* Added the ability to ban supergroups and channels in other supergroups and channels:
  - Replaced the fields `user_id` with the fields `member_id` in the classes `chatMember` and
    `chatEventMemberRestricted`.
  - Replaced the parameters `user_id` with the parameters `member_id` in the methods `setChatMemberStatus` and
    `getChatMember`.
* Improved support for animated emoji:
  - Added the class `animatedEmoji`, containing information about an animated emoji.
  - Added the class `messageAnimatedEmoji` to the types of message content.
  - Added the method `clickAnimatedEmojiMessage` to be called when an animated emoji is clicked.
  - Added the update `updateAnimatedEmojiMessageClicked`, received when a big animated sticker must be played.
  - Added the class `chatActionWatchingAnimations` to the types of chat action.
  - Added the method `getAnimatedEmoji`, returning an animated emoji corresponding to a given emoji.
  - Added the writable option "disable_animated_emoji".
  - Removed the option "animated_emoji_sticker_set_name".
* Added support for automatic message deletion in all chat types:
  - Added the field `message_ttl` to the class `chat`.
  - Added the update `updateChatMessageTtl`.
  - Added the method `setChatMessageTtl`.
  - Added the class `chatEventMessageTtlChanged`, representing change of the field `message_ttl` in the chat event log.
  - Removed the field `ttl` from the class `secretChat` in favor of the field `message_ttl` in the class `chat`.
  - Removed the method `sendChatSetTtlMessage` in favor of the method `setChatMessageTtl`.
* Improved names of the fields of the type `MessageSender`:
  - Renamed the fields `sender` to `sender_id` in the classes `message` and `notificationTypeNewPushMessage`.
  - Renamed the parameter `sender` to `sender_id` in the methods `searchChatMessages`, `addLocalMessage`, and
    `toggleMessageSenderIsBlocked`.
  - Renamed the field `recent_repliers` to `recent_replier_ids` in the class `messageReplyInfo`.
  - Renamed the field `traveler` to `traveler_id` in the class `messageProximityAlertTriggered`.
  - Renamed the field `watcher` to `watcher_id` in the class `messageProximityAlertTriggered`.
* The field `formatted_phone_number` in the class `phoneNumberInfo` now contains the character '-' at the places of
  expected digits.
* Added the synchronous method `getPhoneNumberInfoSync` that can be used instead of the method `getPhoneNumberInfo`
  to synchronously receive information about a phone number by its prefix.
* Replaced the field `user_id` in the class `chatEvent` with the field `member_id` of the type `MessageSender`.
* Improved support for bot payments:
  - Allowed sending invoices as results of inline queries by allowing bots to use the class `inputMessageInvoice` as
    the value of the field `input_message_content` in the classes `inputInlineQueryResultAnimation`,
    `inputInlineQueryResultArticle`, `inputInlineQueryResultAudio`, `inputInlineQueryResultContact`,
    `inputInlineQueryResultDocument`, `inputInlineQueryResultLocation`, `inputInlineQueryResultPhoto`,
    `inputInlineQueryResultSticker`, `inputInlineQueryResultVenue`, `inputInlineQueryResultVideo`, and
    `inputInlineQueryResultVoiceNote`.
  - Allowed sending invoice messages to basic group, supergroup and channel chats.
  - Allowed bots to send forwardable invoices by specifying an empty field `start_parameter` in
    the class `inputMessageInvoice`.
  - Added the field `invoice_chat_id` to the class `messagePaymentSuccessful`.
  - Added the field `id` to the class `paymentForm`, containing a unique payment form identifier.
  - Added the parameter `payment_form_id` to the method `sendPaymentForm`.
  - Added the field `seller_bot_user_id` to the class `paymentForm`, containing the user identifier of the seller bot.
  - Added the field `payments_provider_user_id` to the class `paymentForm`, containing the user identifier of
    the payment provider bot.
  - Added the fields `title`, `description`, `photo`, and `seller_bot_user_id` to the class `paymentReceipt`.
  - Added the fields `max_tip_amount` and `suggested_tip_amounts` to the class `invoice`.
  - Added the parameter `tip_amount` to the method `sendPaymentForm`.
  - Added the field `tip_amount` to the class `paymentReceipt`.
  - Renamed the class `inputCredentialsAndroidPay` to `inputCredentialsGooglePay`.
  - Added the class `paymentFormTheme`, containing the desired colors for a payment form.
  - Added the parameter `theme` to the method `getPaymentForm`.
  - Removed the field `invoice_message_id` from the class `messagePaymentSuccessfulBot`.
* Added the method `deleteChat`, which can be used to completely delete a chat along with all messages.
* Removed the method `deleteSupergroup` in favor of the method `deleteChat`.
* Changed the type of the result in the method `getProxyLink` to the class `httpUrl` instead of the class `text`.
* Removed support for secret chat layers before 73.
* Added support for sponsored messages:
  - Added the class `sponsoredMessage`.
  - Added the method `getChatSponsoredMessage`.
  - Added the ability to pass identifiers of sponsored messages to `viewMessages`. The method must be called when
    the entire text of the sponsored message is shown on the screen (excluding the button).
* Added support for video chats:
  - Added the class `groupCall`, representing a group call.
  - Added the method `getGroupCall` for fetching information about a group call.
  - Added the update `updateGroupCall`.
  - Added the class `videoChat`, representing a video chat, i.e. group call bound to a chat.
  - Added the field `video_chat` to the class `chat`.
  - Added the update `updateChatVideoChat`.
  - Added the classes `messageVideoChatScheduled`, `messageVideoChatStarted`, and `messageVideoChatEnded` to
    the types of message content.
  - Added the class `messageInviteVideoChatParticipants` to the types of message content.
  - Added the field `can_manage_video_chats` to the class `chatMemberStatusAdministrator`.
  - Added the class `groupCallId`.
  - Added the method `createVideoChat` for video chat creation.
  - Added the method `startScheduledGroupCall`.
  - Added the method `toggleGroupCallEnabledStartNotification`.
  - Added the method `joinGroupCall`.
  - Added the method `leaveGroupCall`.
  - Added the method `endGroupCall`.
  - Added the method `toggleGroupCallIsMyVideoEnabled`.
  - Added the method `toggleGroupCallIsMyVideoPaused`.
  - Added the methods `startGroupCallScreenSharing`, `toggleGroupCallScreenSharingIsPaused`,
    `endGroupCallScreenSharing` for managing screen sharing during group calls.
  - Added the method `setGroupCallTitle`.
  - Added the method `toggleGroupCallMuteNewParticipants`.
  - Added the classes `groupCallVideoSourceGroup` and `groupCallParticipantVideoInfo`, describing available
    video streams.
  - Added the class `groupCallParticipant`.
  - Added the update `updateGroupCallParticipant`.
  - Added the method `loadGroupCallParticipants`.
  - Added the method `toggleGroupCallParticipantIsHandRaised`.
  - Added the method `setGroupCallParticipantIsSpeaking`.
  - Added the methods `toggleGroupCallParticipantIsMuted` and `setGroupCallParticipantVolumeLevel` for managing
    the volume level of group call participants.
  - Added the method `inviteGroupCallParticipants`.
  - Added the method `getGroupCallInviteLink` and `revokeGroupCallInviteLink` for managing group call invite links.
  - Added the methods `startGroupCallRecording` and `endGroupCallRecording` for managing group call recordings.
  - Added the method `getVideoChatAvailableParticipants`, returning the list of participants, on whose behalf
    a video chat in the chat can be joined.
  - Added the method `setVideoChatDefaultParticipant` for changing the default participant on whose behalf a video chat
    will be joined.
  - Added the class `GroupCallVideoQuality` and the method `getGroupCallStreamSegment` for downloading segments of
    live streams.
  - Added the class `groupCallRecentSpeaker`, representing a group call participant that was recently speaking.
  - Added the field `video_chat_changes` to the class `chatEventLogFilters`.
  - Added the class `chatEventVideoChatCreated`, representing a video chat being created in the chat event log.
  - Added the class `chatEventVideoChatEnded`, representing a video chat being ended in the chat event log.
  - Added the class `chatEventVideoChatMuteNewParticipantsToggled`, representing changes of
    the setting `mute_new_participants` of a video chat in the chat event log.
  - Added the class `chatEventVideoChatParticipantIsMutedToggled`, representing a video chat participant being muted or
    unmuted in the chat event log.
  - Added the class `chatEventVideoChatParticipantVolumeLevelChanged`, representing a video chat participant's
    volume level being changed in the chat event log.
* Added "; pass null" documentation for all TDLib method parameters, for which null is an expected value.
* Added support for link processing:
  - Added the method `getInternalLinkType`, which can parse internal links and return the exact link type and actions
    to be done when the link is clicked.
  - Added the classes `internalLinkTypeActiveSessions`, `internalLinkTypeAuthenticationCode`,
    `internalLinkTypeBackground`, `internalLinkTypeBotStart`, `internalLinkTypeBotStartInGroup`,
    `internalLinkTypeChangePhoneNumber`, `internalLinkTypeChatInvite`, `internalLinkTypeFilterSettings`,
    `internalLinkTypeGame`, `internalLinkTypeLanguagePack`, `internalLinkTypeMessage`, `internalLinkTypeMessageDraft`,
    `internalLinkTypePassportDataRequest`, `internalLinkTypePhoneNumberConfirmation`, `internalLinkTypeProxy`,
    `internalLinkTypePublicChat`, `internalLinkTypeQrCodeAuthentication`, `internalLinkTypeSettings`,
    `internalLinkTypeStickerSet`, `internalLinkTypeTheme`, `internalLinkTypeThemeSettings`,
    `internalLinkTypeUnknownDeepLink`, `internalLinkTypeUnsupportedProxy`, and `internalLinkTypeVideoChat` to represent
    different types of internal links.
  - Added the method `getExternalLinkInfo`, which needs to be called if the clicked link wasn't recognized as
    an internal link.
  - Added the method `getExternalLink`, which needs to be called after the method `getExternalLinkInfo` if the user
    confirms automatic authorization on the website.
* Added support for expiring chat invite links:
  - Added the field `is_primary` to the class `chatInviteLink`. The primary invite link can't have a name,
    expiration date, or usage limit. There is exactly one primary invite link for each administrator with
    the can_invite_users right at any given time.
  - Added the field `name` to the class `chatInviteLink`.
  - Added the field `creator_user_id` to the class `chatInviteLink`.
  - Added the field `date` to the class `chatInviteLink`, containing the link creation date.
  - Added the field `edit_date` to the class `chatInviteLink`, containing the date the link was last edited.
  - Added the fields `expiration_date` and `member_limit` to the class `chatInviteLink`, limiting link usage.
  - Added the field `member_count` to the class `chatInviteLink`.
  - Added the field `is_revoked` to the class `chatInviteLink`.
  - Changed the type of the fields `invite_link` in the classes `basicGroupFullInfo` and `supergroupFullInfo` to
    `chatInviteLink`.
  - Added the field `description` to the class `chatInviteLinkInfo`, containing the description of the chat.
  - Replaced the method `generateChatInviteLink` with the method `replacePrimaryChatInviteLink`.
  - Added the method `createChatInviteLink` for creating new invite links.
  - Added the method `editChatInviteLink` for editing non-primary invite links.
  - Added the method `revokeChatInviteLink`.
  - Added the method `deleteRevokedChatInviteLink`.
  - Added the method `deleteAllRevokedChatInviteLink`.
  - Added the method `getChatInviteLink`.
  - Added the class `chatInviteLinks`, containing a list of chat invite links.
  - Added the method `getChatInviteLinks`.
  - Added the classes `chatInviteLinkCount` and `chatInviteLinkCounts`.
  - Added the method `getChatInviteLinkCounts`, returning the number of invite links created by chat administrators.
  - Added the classes `chatInviteLinkMember` and `chatInviteLinkMembers`.
  - Added the method `getChatInviteLinkMembers`.
  - Added the field `invite_link_changes` to the class `chatEventLogFilters`.
  - Added the class `chatEventMemberJoinedByInviteLink`, representing a user joining the chat via invite link in
    the chat event log.
  - Added the class `chatEventInviteLinkEdited` to the types of chat event.
  - Added the class `chatEventInviteLinkRevoked` to the types of chat event.
  - Added the class `chatEventInviteLinkDeleted` to the types of chat event.
  - Added the class `chatActionBarInviteMembers` to the types of chat action bar.
* Added support for chat invite links that create join requests:
  - Added the class `messageChatJoinByRequest` to the types of message content.
  - Added the class `pushMessageContentChatJoinByRequest` to the types of push message content.
  - Added the field `pending_join_requests` to the class `chat`.
  - Added the class `chatJoinRequestsInfo`, containing basic information about pending join requests for the chat.
  - Added the update `updateChatPendingJoinRequests`.
  - Added the fields `creates_join_request` to the classes `chatInviteLink` and `chatInviteLinkInfo`.
  - Added the field `pending_join_request_count` to the class `chatInviteLink`.
  - Added the class `chatJoinRequest`, describing a user that sent a join request.
  - Added the class `chatJoinRequests`, containing a list of requests to join the chat.
  - Added the method `getChatJoinRequests`.
  - Added the method `processChatJoinRequest` for processing a request to join the chat.
  - Added the method `processChatJoinRequests` for processing all requests to join the chat.
  - Added the class `chatActionBarJoinRequest` to the types of chat action bar.
  - Added the class `chatEventMemberJoinedByRequest`, representing a user approved to join the chat after
    a join request in the chat event log.
  - Added the update `updateNewChatJoinRequest` for bots.
* Added the ability to see viewers of outgoing messages in small group chats:
  - Added the method `getMessageViewers`.
  - Added the field `can_get_viewers` to the class `message`.
* Added the parameter `only_preview` to the method `forwardMessages`, which can be used to receive a preview of
  forwarded messages.
* Added the method `getRecentlyOpenedChats`, returning the list of recently opened chats.
* Increased number of recently found chats that are stored to 50.
* Added the ability to get information about chat messages, which are split by days:
  - Added the class `messageCalendarDay`, representing found messages, sent on a specific day.
  - Added the class `messageCalendar`, representing found messages, split by days.
  - Added the writable option "utc_time_offset", which contains a UTC time offset used for splitting messages by days.
    The option is reset automatically on each TDLib instance launch, so it needs to be set manually only if
    the time offset is changed during execution.
  - Added the method `getChatMessageCalendar`, returning information about chat messages, which are split by days.
* Added the ability to get messages of the specified type in sparse positions for hyper-speed scrolling implementation:
  - Added the class `messagePosition`, containing an identifier and send date of a message in
    a specific chat history position.
  - Added the class `messagePositions`, containing a list of message positions.
  - Added the method `getChatSparseMessagePositions`.
* Added the field `can_manage_chat` to the class `chatMemberStatusAdministrator` to allow promoting chat administrators
  without additional rights.
* Improved support for bot commands:
  - Bot command entities in chats without bots are now automatically hidden.
  - Added the class `botCommands`, representing a list of bot commands.
  - Added the field `commands` to the class `userFullInfo`, containing the list of commands to be used in
    the private chat with the bot.
  - Added the fields `bot_commands` to the classes `basicGroupFullInfo` and `supergroupFullInfo`.
  - Removed the class `botInfo`.
  - Removed the fields `bot_info` from the classes `userFullInfo` and `chatMember`.
  - Added the class `BotCommandScope`.
  - Added the methods `setCommands`, `deleteCommands`, `getCommands` for bots.
* Added the read-only options "suggested_video_note_length", "suggested_video_note_video_bitrate", and
  "suggested_video_note_audio_bitrate", containing suggested video note encoding parameters.
* Added the read-only option "channel_bot_user_id", containing the identifier of the bot which is shown in
  outdated clients as the sender of messages sent on behalf of channels.
* Added the ability to fetch the actual value of the option "is_location_visible" using the method `getOption` in case
  the value of the option was changed from another device.
* Added the field `minithumbnail` to the class `profilePhoto`, representing a profile photo minithumbnail.
* Added the field `minithumbnail` to the class `chatPhotoInfo`, representing a chat photo minithumbnail.
* Added support for sticker outlines:
  - Added the field `outline` to the class `sticker`.
  - Added the fields `thumbnail_outline` to the classes `stickerSet` and `stickerSetInfo`.
  - Added the class `closedVectorPath`, representing a closed vector path.
  - Added the class `VectorPathCommand`, representing one edge of a closed vector path.
  - Added the class `point`, representing a point on a Cartesian plane.
* Added support for chats and messages with protected content:
  - Added the field `has_protected_content` to the class `chat`.
  - Added the update `updateChatHasProtectedContent`.
  - Added the method `toggleChatHasProtectedContent`.
  - Added the class `chatEventHasProtectedContentToggled`, representing a change of the setting `has_protected_content`
    in the chat event log.
  - Added the field `can_be_saved` to the class `message`.
* Added support for broadcast groups, i.e. supergroups without a limit on the number of members in which
  only administrators can send messages:
  - Added the field `is_broadcast_group` to the class `supergroup`.
  - Added the method `toggleSupergroupIsBroadcastGroup`. Conversion of a supergroup to a broadcast group
    can't be undone.
  - Added the class `suggestedActionConvertToBroadcastGroup`, representing a suggestion to convert a supergroup to
    a broadcast group.
* Improved chat reports:
  - Added the parameter `text` to the method `reportChat`, allowing to add additional details to all
    chat reporting reasons.
  - Removed the field `text` from the class `chatReportReasonCustom`.
  - Added the method `reportChatPhoto` for reporting chat photos.
* Added support for users and chats reported as fake:
  - Added the field `is_fake` to the class `user`.
  - Added the field `is_fake` to the class `supergroup`.
  - Added the class `chatReportReasonFake` to the types of chat reporting reasons.
* Added the class `inlineKeyboardButtonTypeUser` to the types of inline keyboard buttons.
* Added the field `input_field_placeholder` to the classes `replyMarkupForceReply` and `replyMarkupShowKeyboard`.
* Added support for media timestamp entities in messages:
  - Added the class `textEntityTypeMediaTimestamp` to the types of text entities.
  - Added the field `has_timestamped_media` to the class `message`, describing whether media timestamp entities refer
    to the message itself or to the replied message.
  - Added the parameter `media_timestamp` to the method `getMessageLink` to support creating message links with
    a given media timestamp.
  - Added the field `can_get_media_timestamp_links` to the class `message`.
  - Added the field `media_timestamp` to the class `messageLinkInfo` for handling of message links with
    a specified media timestamp.
* Added the ability to change properties of active sessions:
  - Added the field `can_accept_secret_chats` to the class `session`.
  - Added the method `toggleSessionCanAcceptSecretChats`.
  - Added the field `can_accept_calls` to the class `session`.
  - Added the method `toggleSessionCanAcceptCalls`.
  - Added the field `inactive_session_ttl_days` to the class `sessions`.
  - Added the method `setInactiveSessionTtl`.
* Added new ways for phone number verification:
  - Added the class `authenticationCodeTypeMissedCall`, describing an authentication code delivered by
    a canceled phone call to the given number. The last digits of the phone number that calls are the code that
    must be entered manually by the user.
  - Added the field `allow_missed_call` to the class `phoneNumberAuthenticationSettings`.
  - Added the read-only option "authentication_token", which can be received when logging out and contains
    an authentication token to be used on subsequent authorizations.
  - Added the field `authentication_tokens` to the class `phoneNumberAuthenticationSettings`.
* Added support for resetting the password from an active session:
  - Added the class `ResetPasswordResult` and the method `resetPassword`.
  - Added the method `cancelPasswordReset`, which can be used to cancel a pending password reset.
  - Added the field `pending_reset_date` to the class `passwordState`.
* Added the ability to set a new 2-step verification password after recovering a lost password using
  a recovery email address:
  - Added the parameters `new_password` and `new_hint` to the methods `recoverAuthenticationPassword` and
    `recoverPassword`.
  - Added the method `checkAuthenticationPasswordRecoveryCode`.
  - Added the method `checkPasswordRecoveryCode`.
* Added the class `chatActionChoosingSticker` to the types of chat action.
* Added the class `backgroundFillFreeformGradient` to the types of background fill.
* Added the field `is_inverted` to the class `backgroundTypePattern` for inverted patterns for dark themes.
* Added support for chat themes:
  - Added the field `theme_name` to the class `chat`.
  - Added the method `setChatTheme`.
  - Added the update `updateChatTheme`, received when a theme was changed in a chat.
  - Added the class `messageChatSetTheme` to the types of message content.
  - Added the class `pushMessageContentChatSetTheme` to the types of push message content.
  - Added the class `themeSettings`, representing basic theme settings.
  - Added the class `chatTheme`, representing a chat theme.
  - Added the update `updateChatThemes`, received when the list of available chat themes changes.
* Added the ability for regular users to create sticker sets:
  - Allowed to use the methods `uploadStickerFile` and `createNewStickerSet` as regular users.
  - Replaced the parameter `png_sticker` in the method `uploadStickerFile` with the parameter `sticker` of
    the type `InputSticker`.
  - Added the parameter `source` to the method `createNewStickerSet`.
  - Added the method `getSuggestedStickerSetName`.
  - Added the class `CheckStickerSetNameResult` and the method `checkStickerSetName` for checking a sticker set name
    before creating a sticker set.
* Added support for importing chat history from an external source:
  - Added the method `importMessages`.
  - Added the method `getMessageImportConfirmationText`.
  - Added the class `MessageFileType` and the method `getMessageFileType`, which can be used to check whether
    the format of a file with exported message history is supported.
  - Added the class `messageForwardOriginMessageImport` to the types of forwarded message origins for
    imported messages.
  - Added the parameter `for_import` to the method `createNewSupergroupChat`, which needs to be set to true whenever
    the chat is created for a subsequent message history import.
* Added new types of suggested actions:
  - Added the class `suggestedActionSetPassword`, suggesting the user to set a 2-step verification password to be able
    to log in again before the specified number of days pass.
  - Added the class `suggestedActionCheckPassword`, suggesting the user to check whether they still remember
    their 2-step verification password.
  - Added the class `suggestedActionViewChecksHint`, suggesting the user to see a hint about the meaning of
    one and two check marks on sent messages.
* Added the method `getSuggestedFileName`, which returns a suggested name for saving a file in a given directory.
* Added the method `deleteAllCallMessages`.
* Added the method `deleteChatMessagesByDate`, which can be used to delete all messages between the specified dates in
  a chat.
* Added the field `unread_message_count` to the class `messageThreadInfo`.
* Added the field `has_private_forwards` to the class `userFullInfo`.
* Added the field `description` to the class `userFullInfo`, containing description of the bot.
* Added the field `emoji` to the class `inputMessageSticker`, allowing to specify the emoji that was used to choose
  the sent sticker.
* Added the method `banChatMember` that can be used to ban chat members instead of the method `setChatMemberStatus` and
  allows to revoke messages from the banned user in basic groups.
* Allowed to use the method `setChatMemberStatus` for adding chat members.
* Removed the parameter `user_id` from the method `reportSupergroupSpam`. Messages from different senders can now
  be reported simultaneously.
* Added the field `feedback_link` to the class `webPageInstantView`.
* Added the method `getApplicationDownloadLink`, returning the link for downloading official Telegram applications.
* Removed unusable search message filters `searchMessagesFilterCall` and `searchMessagesFilterMissedCall`.
* Removed the method `getChatStatisticsUrl`.
* Removed the method `getInviteText` in favor of the method `getApplicationDownloadLink`.
* Added the field `chat_type` to the update `updateNewInlineQuery` for bots.
* Added the update `updateChatMember` for bots.
* Improved the appearance of the [TDLib build instructions generator](https://tdlib.github.io/td/build.html).
* Added support for the illumos operating system.
* Added support for network access on real watchOS devices.
* Added support for OpenSSL 3.0.
* Improved the iOS/watchOS/tvOS build example to generate a universal XCFramework.
* Added support for ARM64 simulators in the iOS/watchOS/tvOS build example.
* Added the option `-release_only` to the build script for Universal Windows Platform, allowing to build
  TDLib SDK for Universal Windows Platform in release-only mode.
* Rewritten the native .NET binding using the new `ClientManager` interface:
  - Replaced the method `Client.send` with a static method that must be called exactly once in a dedicated thread.
    The callbacks `ClientResultHandler` will be called in this thread for all clients.
  - Removed the function `Client.Dispose()` from the C++/CLI native binding. The objects of the type `Client`
    don't need to be explicitly disposed anymore.
* Rewritten the C binding using the new `ClientManager` interface:
  - Renamed the fields `id` in the structs `TdRequest` and `TdResponse` to `request_id`.
  - Added the field `client_id` to the struct `TdResponse`.
  - Replaced the method `TdCClientCreate` with the method `TdCClientCreateId`.
  - Replaced the parameter `instance` with the parameter `client_id` in the function `TdCClientSend`.
  - Added the methods `TdCClientReceive` and `TdCClientExecute`.
  - Removed the methods `TdCClientSendCommandSync`, `TdCClientDestroy`, and `TdCClientSetVerbosity`.

-----------------------------------------------------------------------------------------------------------------------

Changes in 1.7.0 (28 Nov 2020):

* Added a new simplified JSON interface in which updates and responses to requests from all TDLib instances
  are received in the same thread:
  - The TDLib instance is identified by the unique `client_id` identifier, which is returned by the method
    `td_create_client_id`.
  - Use the method `td_send` to send a request to a specified client. The TDLib instance is created on the first
    request sent to it.
  - Use the method `td_receive` to receive updates and request responses from TDLib. The response will contain
    the identifier of the client from which the event was received in the field "@client_id".
  - Use the method `td_execute` to synchronously execute suitable TDLib methods.
* Added support for adding chats to more than one chat list:
  - Added the class `chatPosition`, describing the position of the chat within a chat list.
  - Replaced the fields `chat_list`, `order`, `is_sponsored` and `is_pinned` in the class `chat` with
    the field `positions`, containing a list of the chat positions in various chat list.
  - Replaced the field `order` with the field `positions` in the updates `updateChatLastMessage` and
    `updateChatDraftMessage`.
  - Added the update `updateChatPosition`.
  - Removed the superfluous updates `updateChatChatList`, `updateChatIsSponsored`, `updateChatOrder` and
    `updateChatIsPinned`.
  - Added the parameter `chat_list` to the method `toggleChatIsPinned`.
  - Added the class `chatLists`, containing a list of chat lists.
  - Added the method `getChatListsToAddChat`, returning all chat lists to which a chat can be added.
  - Added the method `addChatToList`, which can be used to add a chat to a chat list.
  - Remove the method `setChatChatList`.
* Added support for chat filters:
  - Added the new chat list type `chatListFilter`.
  - Added the classes `chatFilterInfo` and `chatFilter`, describing a filter of user chats.
  - Added the update `updateChatFilters`, which is sent when the list of chat filters is changed.
  - Added the methods `createChatFilter`, `editChatFilter` and `deleteChatFilter` for managing chat filters.
  - Added the method `reorderChatFilters` for changing the order of chat filters.
  - Added the method `getChatFilter`, returning full information about a chat filter.
  - Added the synchronous method `getChatFilterDefaultIconName`.
  - Added the classes `recommendedChatFilter` and `recommendedChatFilters`.
  - Added the method `getRecommendedChatFilters`, returning a list of recommended chat filters.
* Added support for messages sent on behalf of chats instead of users:
  - Added the class `MessageSender`, representing a user or a chat which sent a message.
  - Added the class `MessageSenders`, representing a list of message senders.
  - Replaced the field `sender_user_id` with the field `sender` of the type `MessageSender` in the classes `message`
    and `notificationTypeNewPushMessage`.
  - Added the class `messageForwardOriginChat`, which describe a chat as the original sender of a message.
  - Added the ability to search messages sent by a chat by replacing the parameter `sender_user_id` with
    the parameter `sender` of the type `MessageSender` in the method `searchChatMessages`.
  - Added the ability to specify a chat as a local message sender by replacing the parameter `sender_user_id` with
    the parameter `sender` of the type `MessageSender` in the method `addLocalMessage`.
* Added support for video calls:
  - Added the class `callServer`, describing a server for relaying call data.
  - Added the classes `callServerTypeTelegramReflector` and `callServerTypeWebrtc`, representing different types of
    supported call servers.
  - Replaced the field `connections` with the field `servers` in the class `callStateReady`.
  - Removed the class `callConnection`.
  - Added the update `updateNewCallSignalingData`.
  - Added the method `sendCallSignalingData`.
  - Added the field `supports_video_calls` to the class `userFullInfo`.
  - Added the field `is_video` to the class `messageCall`.
  - Added the field `is_video` to the class `call`.
  - Added the parameter `is_video` to the method `createCall`.
  - Added the parameter `is_video` to the method `discardCall`.
  - Added two new types of call problems `callProblemDistortedVideo` and `callProblemPixelatedVideo`.
  - Added the field `library_versions` to the class `callProtocol`, which must be used to specify all supported
    call library versions.
* Added support for multiple pinned messages and the ability to pin messages in private chats:
  - Added the ability to pin messages in all private chats.
  - Added the ability to pin mutiple messages in all chats.
  - Added the field `is_pinned` to the class `message`.
  - Added the update `updateMessageIsPinned`.
  - Added the parameter `only_for_self` to the method `pinChatMessage`, allowing to pin messages in private chats for
    one side only.
  - Added the ability to find pinned messages in a chat using the filter `searchMessagesFilterPinned`.
  - Added the parameter `message_id` to the method `unpinChatMessage`.
  - Added the field `message` to the class `chatEventMessageUnpinned`.
  - Added the method `unpinAllChatMessages`, which can be used to simultaneously unpin all pinned messages in a chat.
  - Documented that notifications about new pinned messages are always silent in channels and private chats.
  - The method `getChatPinnedMessage` now returns the newest pinned message in the chat.
  - Removed the field `pinned_message_id` from the class `chat`.
  - Removed the update `updateChatPinnedMessage`.
* Improved thumbnail representation and added support for animated MPEG4 thumbnails:
  - Added the class `ThumbnailFormat`, representing the various supported thumbnail formats.
  - Added the class `thumbnail`, containing information about a thumbnail.
  - Changed the type of all thumbnail fields from `photoSize` to `thumbnail`.
  - Added support for thumbnails in the format `thumbnailFormatMpeg4` for some animations and videos.
  - Replaced the classes `inputInlineQueryResultAnimatedGif` and `inputInlineQueryResultAnimatedMpeg4` with
    the generic class `inputInlineQueryResultAnimation`.
  - Added support for animated thumbnails in the class `inputInlineQueryResultAnimation`.
  - The class `photoSize` is now only used for JPEG images.
* Improved support for user profile photos and chat photos:
  - Added the field `photo` to the class `userFullInfo`, containing full information about the user photo.
  - Added the field `photo` to the class `basicGroupFullInfo`, containing full information about the group photo.
  - Added the field `photo` to the class `supergroupFullInfo`, containing full information about the group photo.
  - Renamed the class `chatPhoto` to `chatPhotoInfo`.
  - Added the field `has_animation` to the classes `profilePhoto` and `chatPhotoInfo`, which is set to true for
    animated chat photos.
  - Added the classes `chatPhoto` and `chatPhotos`.
  - Added minithumbnail support via the field `minithumbnail` in the class `chatPhoto`.
  - Added the class `animatedChatPhoto`.
  - Added animated chat photo support via the field `animation` in the class `chatPhoto`.
  - Removed the classes `userProfilePhoto` and `userProfilePhotos`.
  - Changed the type of the field `photo` in the class `messageChatChangePhoto` to `chatPhoto`.
  - Changed the type of the fields `old_photo` and `new_photo` in the class `chatEventPhotoChanged` to `chatPhoto`.
  - Changed the return type of the method `getUserProfilePhotos` to `chatPhotos`.
  - Added the class `InputChatPhoto`, representing a chat or a profile photo to set.
  - Changed the type of the parameter `photo` in the methods `setProfilePhoto` and `setChatPhoto` to
    the `InputChatPhoto`.
  - Added the ability to explicitly re-use previously set profile photos using the class `inputChatPhotoPrevious`.
  - Added the ability to set animated chat photos using the class `inputChatPhotoAnimated`.
* Added support for message threads in supergroups and channel comments:
  - Added the field `message_thread_id` to the class `message`.
  - Added the class `messageThreadInfo`, containing information about a message thread.
  - Added the class `messageReplyInfo`, containing information about replies to a message.
  - Added the field `reply_info` to the class `messageInteractionInfo`, containing information about message replies.
  - Added the field `can_get_message_thread` to the class `message`.
  - Added the method `getMessageThread`, returning information about the message thread to which a message belongs.
  - Added the method `getMessageThreadHistory`, returning messages belonging to a message thread.
  - Added the parameter `message_thread_id` to the methods `sendMessage`, `sendMessageAlbum` and
    `sendInlineQueryResultMessage` for sending messages within a thread.
  - Added the parameter `message_thread_id` to the method `searchChatMessages` to search messages within a thread.
  - Added the parameter `message_thread_id` to the method `viewMessages`.
  - Added the parameter `message_thread_id` to the method `setChatDraftMessage`.
  - Added the parameter `message_thread_id` to the method `sendChatAction` to send chat actions to a thread.
  - Added the field `message_thread_id` to the update `updateUserChatAction`.
* Improved support for message albums:
  - Added support for sending and receiving messages of the types `messageAudio` and `messageDocument` as albums.
  - Added automatic grouping into audio or document albums in the method `forwardMessages` if all forwarded or
    copied messages are of the same type.
  - Removed the parameter `as_album` from the method `forwardMessages`. Forwarded message albums are now determined
    automatically.
* Simplified usage of methods generating an HTTP link to a message:
  - Added the class `messageLink`, representing an HTTP link to a message.
  - Combined the methods `getPublicMessageLink` and `getMessageLink` into the method `getMessageLink`, which
    now returns a public link to the message if possible and a private link otherwise. The combined method is
    an offline method now.
  - Added the parameter `for_comment` to the method `getMessageLink`, which allows to get a message link to the message
    that opens it in a thread.
  - Removed the class `publicMessageLink`.
  - Added the field `for_comment` to the class `messageLinkInfo`.
  - Added the separate method `getMessageEmbeddingCode`, returning an HTML code for embedding a message.
* Added the ability to block private messages sent via the @replies bot from chats:
  - Added the field `is_blocked` to the class `chat`.
  - Added the update `updateChatIsBlocked`.
  - Added the method `blockMessageSenderFromReplies`.
  - Replaced the methods `blockUser` and `unblockUser` with the method `toggleMessageSenderIsBlocked`.
  - Replaced the method `getBlockedUsers` with the method `getBlockedMessageSenders`.
* Added support for incoming messages which are replies to messages in different chats:
  - Added the field `reply_in_chat_id` to the class `message`.
  - The method `getRepliedMessage` can now return the replied message in a different chat.
* Renamed the class `sendMessageOptions` to `messageSendOptions`.
* Added the new `tdapi` static library, which needs to be additionally linked in when static linking is used.
* Changed the type of the field `value` in the class `optionValueInteger` from `int32` to `int64`.
* Changed the type of the field `description` in the class `webPage` from `string` to `formattedText`.
* Improved Instant View support:
  - Added the field `view_count` to the class `webPageInstantView`.
  - Added the class `richTextAnchorLink`, containing a link to an anchor on the same page.
  - Added the class `richTextReference`, containing a reference to a text on the same page.
  - Removed the field `text` from the class `richTextAnchor`.
  - Removed the field `url` which is no longer needed from the class `webPageInstantView`.
* Allowed the update `updateServiceNotification` to be sent before authorization is completed.
* Disallowed to pass messages in non-strictly increasing order to the method `forwardMessages`.
* Improved sending copies of messages:
  - Added the class `messageCopyOptions` and the field `copy_options` to the class `inputMessageForwarded`.
  - Removed the fields `send_copy` and `remove_caption` from the class `inputMessageForwarded`.
  - Allowed to replace captions in copied messages using the fields `replace_caption` and `new_caption` in
    the class `messageCopyOptions`.
  - Allowed to specify `reply_to_message_id` when sending a copy of a message.
  - Allowed to specify `reply_markup` when sending a copy of a message.
* Allowed passing multiple input language codes to `searchEmojis` by replacing the parameter `input_language_code` with
  the parameter `input_language_codes`.
* Added support for public service announcements:
  - Added the class `ChatSource` and the field `source` to the class `chatPosition`.
  - Added the new type of chat source `chatSourcePublicServiceAnnouncement`.
  - Added the field `public_service_announcement_type` to the class `messageForwardInfo`.
* Added support for previewing of private supergroups and channels by their invite link.
  - The field `chat_id` in the class `chatInviteLinkInfo` is now non-zero for private supergroups and channels to which
    the temporary read access is granted.
  - Added the field `accessible_for` to the class `chatInviteLinkInfo`, containing the amount of time for which
    read access to the chat will remain available.
* Improved methods for message search:
  - Replaced the field `next_from_search_id` with a string field `next_offset` in the class `foundMessages`.
  - Added the field `total_count` to the class `foundMessages`; can be -1 if the total count of matching messages is
    unknown.
  - Replaced the parameter `from_search_id` with the parameter `offset` in the method `searchSecretMessages`.
  - Added the parameter `filter` to the method `searchMessages`.
  - Added the parameters `min_date` and `max_date` to the method `searchMessages` to search messages sent only within
    a particular timeframe.
* Added pkg-config file generation for all installed libraries.
* Added automatic operating system version detection. Use an empty field `system_version` in
  the class `tdlibParameters` for the automatic detection.
* Increased maximum file size from 1500 MB to 2000 MB.
* Added support for human-friendly Markdown formatting:
  - Added the synchronous method `parseMarkdown` for human-friendly parsing of text entities.
  - Added the synchronous method `getMarkdownText` for replacing text entities with a human-friendly
    Markdown formatting.
  - Added the writable option "always_parse_markdown" which enables automatic parsing of text entities in
    all `inputMessageText` objects.
* Added support for dice with random values in messages:
  - Added the class `messageDice` to the types of message content; contains a dice.
  - Added the class `DiceStickers`, containing animated stickers needed to show the dice.
  - Added the class `inputMessageDice` to the types of new input message content; can be used to send a dice.
  - Added the update `updateDiceEmojis`, containing information about supported dice emojis.
* Added support for chat statistics in channels and supergroups:
  - Added the field `can_get_statistics` to the class `supergroupFullInfo`.
  - Added the class `ChatStatistics`, which represents a supergroup or a channel statistics.
  - Added the method `getChatStatistics` returning detailed statistics about a chat.
  - Added the classes `chatStatisticsMessageInteractionInfo`, `chatStatisticsAdministratorActionsInfo`,
    `chatStatisticsMessageSenderInfo` and `chatStatisticsInviterInfo` representing various parts of chat statistics.
  - Added the class `statisticalValue` describing recent changes of a statistical value.
  - Added the class `StatisticalGraph` describing a statistical graph.
  - Added the method `getStatisticalGraph`, which can be used for loading asynchronous or zoomed in statistical graphs.
  - Added the class `dateRange` representing a date range for which statistics are available.
  - Removed the field `can_view_statistics` from the class `supergroupFullInfo` and marked
    the method `getChatStatisticsUrl` as disabled and not working.
* Added support for detailed statistics about interactions with messages:
  - Added the class `messageInteractionInfo`, containing information about message views, forwards and replies.
  - Added the field `interaction_info` to the class `message`.
  - Added the update `updateMessageInteractionInfo`.
  - Added the field `can_get_statistics` to the class `message`.
  - Added the class `messageStatistics`.
  - Added the method `getMessageStatistics`.
  - Added the method `getMessagePublicForwards`, returning all forwards of a message to public channels.
  - Removed the now superfluous field `views` from the class `message`.
  - Removed the now superfluous update `updateMessageViews`.
* Improved support for native polls:
  - Added the field `explanation` to the class `pollTypeQuiz`.
  - Added the fields `close_date` and `open_period` to the class `poll`.
  - Added the fields `close_date` and `open_period` to the class `inputMessagePoll`; for bots only.
  - Increased maximum poll question length to 300 characters for bots.
* Added support for anonymous administrators in supergroups:
  - Added the field `is_anonymous` to the classes `chatMemberStatusCreator` and `chatMemberStatusAdministrator`.
  - The field `author_signature` in the class `message` can now contain a custom title of the anonymous administrator
    that sent the message.
* Added support for a new type of inline keyboard buttons, requiring user password entry:
  - Added the class `inlineKeyboardButtonTypeCallbackWithPassword`, representing a button requiring password entry from
    a user.
  - Added the class `callbackQueryPayloadDataWithPassword`, representing new type of callback button payload,
    which must be used for the buttons of the type `inlineKeyboardButtonTypeCallbackWithPassword`.
* Added support for making the location of the user public:
  - Added the writable option "is_location_visible" to allow other users see location of the current user.
  - Added the method `setLocation`, which should be called if `getOption("is_location_visible")` is true and location
    changes by more than 1 kilometer.
* Improved Notification API:
  - Added the field `sender_name` to the class `notificationTypeNewPushMessage`.
  - Added the writable option "disable_sent_scheduled_message_notifications" for disabling notifications about
    outgoing scheduled messages that were sent.
  - Added the field `is_outgoing` to the class `notificationTypeNewPushMessage` for recognizing
    outgoing scheduled messages that were sent.
  - Added the fields `has_audios` and `has_documents` to the class `pushMessageContentMediaAlbum`.
* Added the field `date` to the class `draftMessage`.
* Added the update `updateStickerSet`, which is sent after a sticker set is changed.
* Added support for pagination in trending sticker sets:
  - Added the parameters `offset` and `limit` to the method `getTrendingStickerSets`.
  - Changed the field `sticker_sets` in the update `updateTrendingStickerSets` to contain only the prefix of
    trending sticker sets.
* Messages that failed to send can now be found using the filter `searchMessagesFilterFailedToSend`.
* Added the ability to disable automatic server-side file type detection using the new field
  `disable_content_type_detection` of the class `inputMessageDocument`.
* Improved chat action bar:
  - Added the field `can_unarchive` to the classes `chatActionBarReportSpam` and `chatActionBarReportAddBlock`,
    which is true whenever the chat was automatically archived.
  - Added the field `distance` to the class `chatActionBarReportAddBlock`,
    which denotes the distance between the users.
* Added support for actions suggested to the user by the server:
  - Added the class `SuggestedAction`, representing possible actions suggested by the server.
  - Added the update `updateSuggestedActions`.
  - Added the method `hideSuggestedAction`, which can be used to dismiss a suggested action.
* Supported attaching stickers to animations:
  - Added the field `has_stickers` to the class `animation`.
  - Added the field `added_sticker_file_ids` to the class `inputMessageAnimation`.
* Added methods for phone number formatting:
  - Added the class `countryInfo`, describing a country.
  - Added the class `countries`, containing a list of countries.
  - Added the method `getCountries`, returning a list of all existing countries.
  - Added the class `phonenumberinfo` and the method `getPhoneNumberInfo`, which can be used to format a phone number
    according to local rules.
* Improved location support:
  - Added the field `horizontal_accuracy` to the class `location`.
  - Added the field `heading` to the classes `messageLocation` and `inputMessageLocation` for live locations.
  - Added the parameter `heading` to the methods `editMessageLiveLocation` and `editInlineMessageLiveLocation`.
* Added support for proximity alerts in live locations:
  - Added the field `proximity_alert_radius` to the classes `messageLocation` and `inputMessageLocation`.
  - Added the parameter `proximity_alert_radius` to the methods `editMessageLiveLocation` and
    `editInlineMessageLiveLocation`.
  - Added the new message content `messageProximityAlertTriggered`, received whenever a proximity alert is triggered.
* Added `CentOS 7` and `CentOS 8` operating systems to the
  [TDLib build instructions generator](https://tdlib.github.io/td/build.html).
* Added the CMake configuration option TD_ENABLE_MULTI_PROCESSOR_COMPILATION, which can be used to enable parallel
  build with MSVC.
* Added support for sending and receiving messages in secret chats with silent notifications.
* Added the field `progressive_sizes` to the class `photo` to allow partial progressive JPEG photo download.
* Added the field `redirect_stderr` to the class `logStreamFile` to allow explicit control over stderr redirection to
  the log file.
* Added the read-only option "can_archive_and_mute_new_chats_from_unknown_users", which can be used to check, whether
  the option "archive_and_mute_new_chats_from_unknown_users" can be changed.
* Added the writable option "archive_and_mute_new_chats_from_unknown_users", which can be used to automatically archive
  and mute new chats from non-contacts. The option can be set only if the option
  "can_archive_and_mute_new_chats_from_unknown_users" is true.
* Added the writable option "message_unload_delay", which can be used to change the minimum delay before messages are
  unloaded from the memory.
* Added the writable option "disable_persistent_network_statistics", which can be used to disable persistent
  network usage statistics, significantly reducing disk usage.
* Added the writable option "disable_time_adjustment_protection", which can be used to disable protection from
  external time adjustment, significantly reducing disk usage.
* Added the writable option "ignore_default_disable_notification" to allow the application to manually specify the
  `disable_notification` option each time when sending messages instead of following the default per-chat settings.
* Added the read-only option "telegram_service_notifications_chat_id", containing the identifier of
  the Telegram service notifications chat.
* Added the read-only option "replies_bot_chat_id", containing the identifier of the @replies bot.
* Added the read-only option "group_anonymous_bot_user_id", containing the identifier of the bot which is shown as
  the sender of anonymous group messages when viewed from an outdated client.
* Added the new venue provider value "gplaces" for Google Places.
* Added the parameter `return_deleted_file_statistics` to the method `optimizeStorage` to return information about
  the files that were deleted instead of the ones that were not.
* Added the ability to search for supergroup members to mention by their name and username:
  - Added the new filter `supergroupMembersFilterMention` for the method `getSupergroupMembers`.
  - Added the new filter `chatMembersFilterMention` for the method `searchChatMembers`.
* Added support for highlighting bank card numbers:
  - Added the new text entity `textEntityTypeBankCardNumber`.
  - Added the classes `bankCardInfo` and `bankCardActionOpenUrl`, containing information about a bank card.
  - Added the method `getBankCardInfo`, returning information about a bank card.
* Improved methods for managing sticker sets by bots:
  - Added the method `setStickerSetThumbnail`.
  - Added the ability to create new animated sticker sets and add new stickers to them by adding
    the class `inputStickerAnimated`.
  - Renamed the class `inputSticker` to `inputStickerStatic`.
  - Renamed the field `png_sticker` to `sticker` in the class `inputStickerStatic`.
* Added the method `setCommands` for bots.
* Added the method `getCallbackQueryMessage` for bots.
* Added support for starting bots in private chats through `sendBotStartMessage`.
* Added the field `total_count` to the class `chats`. The field should have a precise value for the responses of
  the methods `getChats`, `searchChats` and `getGroupsInCommon`.
* Added the update `updateAnimationSearchParameters`, containing information about animation search parameters.
* Documented that `getRepliedMessage` can be used to get a pinned message, a game message, or an invoice message for
  messages of the types `messagePinMessage`, `messageGameScore`, and `messagePaymentSuccessful` respectively.
* Added guarantees that the field `member_count` in the class `supergroup` is known if the supergroup was received from
  the methods `searchChatsNearby`, `getInactiveSupergroupChats`, `getSuitableDiscussionChats`, `getGroupsInCommon`, or
  `getUserPrivacySettingRules`.
* Updated SQLCipher to 4.4.0.
* Updated dependencies in the prebuilt TDLib for Android:
  - Updated SDK to SDK 30.
  - Updated NDK to r21d, which dropped support for 32-bit ARM devices without Neon support.
* Updated recommended `emsdk` version for `tdweb` building to the 2.0.6.
* Removed the ability to change the update handler after client creation in native .NET binding, Java example and
  prebuilt library for Android.
* Removed the ability to change the default exception handler after client creation in Java example and
  prebuilt library for Android.
* Removed the ability to close Client using close() method in Java example and prebuilt library for Android.
  Use the method TdApi.close() instead.
* Changed license of source code in prebuilt library for Android to Boost Software License, Version 1.0.

-----------------------------------------------------------------------------------------------------------------------

Changes in 1.6.0 (31 Jan 2020):

* Added support for multiple chat lists. Currently, only two chat lists Main and Archive are supported:
  - Added the class `ChatList`, which represents a chat list and could be `chatListMain` or `chatListArchive`.
  - Added the field `chat_list` to the class `chat`, denoting the chat list to which the chat belongs.
  - Added the parameter `chat_list` to the methods `getChats`, `searchMessages` and `setPinnedChats`.
  - Added the field `chat_list` to the updates `updateUnreadMessageCount` and `updateUnreadChatCount`.
  - Added the field `total_count` to the update `updateUnreadChatCount`, containing the total number of chats in
    the list.
  - Added the update `updateChatChatList`, which is sent after a chat is moved to or from a chat list.
  - Added the method `setChatChatList`, which can be used to move a chat between chat lists.
  - Added the option `pinned_archived_chat_count_max` for the maximum number of pinned chats in the Archive chat list.
* Added support for scheduled messages:
  - Added the classes `messageSchedulingStateSendAtDate` and `messageSchedulingStateSendWhenOnline`,
    representing the scheduling state of a message.
  - Added the field `scheduling_state` to the class `message`, which allows to distinguish between scheduled and
    ordinary messages.
  - The update `updateNewMessage` can now contain a scheduled message and must be handled appropriately.
  - The updates `updateMessageContent`, `updateDeleteMessages`, `updateMessageViews`, `updateMessageSendSucceeded`,
    `updateMessageSendFailed`, and `updateMessageSendAcknowledged` can now contain identifiers of scheduled messages.
  - Added the class `sendMessageOptions`, which contains options for sending messages,
    including the scheduling state of the messages.
  - Replaced the parameters `disable_notification` and `from_background` in the methods `sendMessage`,
    `sendMessageAlbum`, `sendInlineQueryResultMessage`, and `forwardMessages` with the new field `options` of
    the type `sendMessageOptions`.
  - Added the method `editMessageSchedulingState`, which can be used to reschedule a message or send it immediately.
  - Added the method `getChatScheduledMessages`, which returns all scheduled messages in a chat.
  - Added the field `has_scheduled_messages` to the class `chat`.
  - Added the update `updateChatHasScheduledMessages`, which is sent whenever the field `has_scheduled_messages`
    changes in a chat.
  - Added support for reminders in Saved Messages and notifications about other sent scheduled messages in
    the [Notification API](https://core.telegram.org/tdlib/notification-api/).
* Added support for adding users without a known phone number to the list of contacts:
  - Added the method `addContact` for adding or renaming contacts without a known phone number.
  - Added the field `need_phone_number_privacy_exception` to the class `userFullInfo`, containing the default value for
    the second parameter of the method `addContact`.
  - Added the fields `is_contact` and `is_mutual_contact` to the class `user`.
  - Removed the class `LinkState` and the fields `outgoing_link` and `incoming_link` from the class `user`.
* Improved support for the top chat action bar:
  - Added the class `ChatActionBar`, representing all possible types of the action bar.
  - Added the field `action_bar` to the class `chat`.
  - Removed the legacy class `chatReportSpamState`.
  - Removed the legacy methods `getChatReportSpamState` and `changeChatReportSpamState`.
  - Added the update `updateChatActionBar`.
  - Added the method `removeChatActionBar`, which allows to dismiss the action bar.
  - Added the method `sharePhoneNumber`, allowing to share the phone number of the current user with a mutual contact.
  - Added the new reason `chatReportReasonUnrelatedLocation` for reporting location-based groups unrelated to
    their stated location.
* Improved support for text entities:
  - Added the new types of text entities `textEntityTypeUnderline` and `textEntityTypeStrikethrough`.
  - Added support for nested entities. Entities can be nested, but must not mutually intersect with each other.
    Pre, Code and PreCode entities can't contain other entities. Bold, Italic, Underline and Strikethrough entities can
    contain and be contained in all other entities. All other entities can't contain each other.
  - Added the field `version` to the method `textParseModeMarkdown`. Versions 0 and 1 correspond to Bot API Markdown
    parse mode, version 2 to Bot API MarkdownV2 parse mode with underline, strikethrough and nested entities support.
  - The new entity types and nested entities are supported in secret chats also if its layer is at least 101.
* Added support for native non-anonymous, multiple answer, and quiz-style polls:
  - Added support for quiz-style polls, which has exactly one correct answer option and can be answered only once.
  - Added support for regular polls, which allows multiple answers.
  - Added the classes `pollTypeRegular` and `pollTypeQuiz`, representing the possible types of a poll.
  - Added the field `type` to the classes `poll` and `inputMessagePoll`.
  - Added support for non-anonymous polls with visible votes by adding the field `is_anonymous` to the classes `poll`
    and `inputMessagePoll`.
  - Added the method `getPollVoters` returning users that voted for the specified option in a non-anonymous poll.
  - Added the new reply markup keyboard button `keyboardButtonTypeRequestPoll`.
  - Added the field `is_regular` to the class `pushMessageContentPoll`.
  - Added the update `updatePollAnswer` for bots only.
  - Added the field `is_closed` to the class `inputMessagePoll`, which can be used by bots to send a closed poll.
* Clarified in the documentation that file remote ID is guaranteed to be usable only if the corresponding file is
  still accessible to the user and is known to TDLib. For example, if the file is from a message, then the message
  must be not deleted and accessible to the user. If the file database is disabled, then the corresponding object with
  the file must be preloaded by the client.
* Added support for administrator custom titles:
  - Added the field `custom_title` to `chatMemberStatusCreator` and `chatMemberStatusAdministrator` classes.
  - Added the classes `chatAdministrator` and `chatAdministrators`, containing user identifiers along with
    their custom administrator title and owner status.
  - Replaced the result type of the method `getChatAdministrators` with `chatAdministrators`.
* Improved Instant View support:
  - Added the new web page block `pageBlockVoiceNote`.
  - Changed value of invisible cells in `pageBlockTableCell` to null.
  - Added the field `is_cached` to the class `richTextUrl`.
* Improved support for chat backgrounds:
  - Added the classes `backgroundFillSolid` for solid color backgrounds and `backgroundFillGradient` for
    gradient backgrounds.
  - Added support for TGV (gzipped subset of SVG with MIME type "application/x-tgwallpattern") background patterns
    in addition to PNG patterns. Background pattern thumbnails are still always in PNG format.
  - Replaced the field `color` in the class `backgroundTypePattern` with the field `fill` of type `BackgroundFill`.
  - Replaced the class `backgroundTypeSolid` with the class `backgroundTypeFill`.
* Added support for discussion groups for channel chats:
  - Added the field `linked_chat_id` to the class `supergroupFullInfo` containing the identifier of a discussion
    supergroup for the channel, or a channel, for which the supergroup is the designated discussion supergroup.
  - Added the field `has_linked_chat` to the class `supergroup`.
  - Added the method `getSuitableDiscussionChats`, which returns a list of chats which can be assigned as
    a discussion group for a channel by the current user.
  - Added the method `setChatDiscussionGroup`, which can be used to add or remove a discussion group from a channel.
  - Added the class `chatEventLinkedChatChanged` representing a change of the linked chat in the chat event log.
* Added support for slow mode in supergroups:
  - Added the field `is_slow_mode_enabled` to the class `supergroup`.
  - Added the field `slow_mode_delay` to the class `supergroupFullInfo`.
  - Added the method `setChatSlowModeDelay`, which can be used to change the slow mode delay setting in a supergroup.
  - Added the class `chatEventSlowModeDelayChanged` representing a change of the slow mode delay setting in
    the chat event log.
* Improved privacy settings support:
  - Added the classes `userPrivacySettingRuleAllowChatMembers` and `userPrivacySettingRuleRestrictChatMembers`
    to include or exclude all group members in a privacy setting rule.
  - Added the class `userPrivacySettingShowPhoneNumber` for managing the visibility of the user's phone number.
  - Added the class `userPrivacySettingAllowFindingByPhoneNumber` for managing whether the user can be found by
    their phone number.
* Added the method `checkCreatedPublicChatsLimit` for checking whether the maximum number of owned public chats
  has been reached.
* Added support for transferring ownership of supergroup and channel chats:
  - Added the method `transferChatOwnership`.
  - Added the class `CanTransferOwnershipResult` and the method `canTransferOwnership` for checking
    whether chat ownership can be transferred from the current session.
* Added support for location-based supergroups:
  - Added the class `chatLocation`, which contains the location to which the supergroup is connected.
  - Added the field `has_location` to the class `supergroup`.
  - Added the field `location` to the class `supergroupFullInfo`.
  - Added the ability to create location-based supergroups via the new field `location` in
    the method `createNewSupergroupChat`.
  - Added the method `setChatLocation`, which allows to change location of location-based supergroups.
  - Added the field `can_set_location` to the class `supergroupFullInfo`.
  - Added the class `PublicChatType`, which can be one of `publicChatTypeHasUsername` or
    `publicChatTypeIsLocationBased`.
  - Added the parameter `type` to the method `getCreatedPublicChats`, which allows to get location-based supergroups
    owned by the user.
  - Supported location-based supergroups as public chats where appropriate.
  - Added the class `chatEventLocationChanged` representing a change of the location of a chat in the chat event log.
* Added support for searching chats and users nearby:
  - Added the classes `chatNearby` and `chatsNearby`, containing information about chats along with
    the distance to them.
  - Added the method `searchChatsNearby`, which returns chats and users nearby.
  - Added the update `updateUsersNearby`, which is sent 60 seconds after a successful `searchChatsNearby` request.
* Improved support for inline keyboard buttons of the type `inlineKeyboardButtonTypeLoginUrl`:
  - Added the class `LoginUrlInfo` and the method `getLoginUrlInfo`, which allows to get information about
    an inline button of the type `inlineKeyboardButtonTypeLoginUrl`.
  - Added the method `getLoginUrl` for automatic authorization on the target website.
* Improved support for content restrictions:
  - The field `restriction_reason` in the classes `user` and `channel` now contains only a human-readable description
    why access must be restricted. It is non-empty if and only if access to the chat needs to be restricted.
  - Added the field `restriction_reason` to the class `message`. It is non-empty if and only if access to the message
    needs to be restricted.
  - Added the writable option `ignore_platform_restrictions`, which can be set in non-store apps to ignore restrictions
    specific to the currently used operating system.
  - Added the writable option `ignore_sensitive_content_restrictions`, which can be set to show sensitive content on
    all user devices. `getOption("ignore_sensitive_content_restrictions")` can be used to fetch the actual value of
    the option, the option will not be immediately updated after a change from another device.
  - Added the read-only option `can_ignore_sensitive_content_restrictions`, which can be used to check, whether
    the option `ignore_sensitive_content_restrictions` can be changed.
* Added support for QR code authentication for already registered users:
  - Added the authorization state `authorizationStateWaitOtherDeviceConfirmation`.
  - Added the method `requestQrCodeAuthentication`, which can be used in the `authorizationStateWaitPhoneNumber` state
    instead of the method `setAuthenticationPhoneNumber` to request QR code authentication.
  - Added the method `confirmQrCodeAuthentication` for authentication confirmation from another device.
* Added the update `updateMessageLiveLocationViewed`, which is supposed to trigger an edit of the corresponding
  live location.
* Added the parameter `input_language_code` to the method `searchEmojis`.
* Added the method `getInactiveSupergroupChats`, to be used when the user receives a CHANNELS_TOO_MUCH error after
  reaching the limit on the number of joined supergroup and channel chats.
* Added the field `unique_id` to the class `remoteFile`, which can be used to identify the same file for
  different users.
* Added the new category of top chat list `topChatCategoryForwardChats`.
* Added the read-only option `animated_emoji_sticker_set_name`, containing name of a sticker set with animated emojis.
* Added the read-only option `unix_time`, containing an estimation of the current Unix timestamp.
  The option will not be updated automatically unless the difference between the previous estimation and
  the locally available monotonic clocks changes significantly.
* Added the field `is_silent` to the class `notification`, so silent notifications can be shown with
  the appropriate mark.
* Added the field `video_upload_bitrate` to the class `autoDownloadSettings`.
* Disallowed to call `setChatNotificationSettings` method on the chat with self, which never worked.
* Added support for `ton://` URLs in messages and inline keyboard buttons.

-----------------------------------------------------------------------------------------------------------------------

Changes in 1.5.0 (9 Sep 2019):

* Changed authorization workflow:
  - Added the state `authorizationStateWaitRegistration`, which will be received after `authorizationStateWaitCode` for
    users who are not registered yet.
  - Added the method `registerUser`, which must be used in the `authorizationStateWaitRegistration` state to finish
    registration of the user.
  - Removed the fields `is_registered` and `terms_of_service` from the class `authorizationStateWaitCode`.
  - Removed the parameters `first_name` and `last_name` from the method `checkAuthenticationCode`.
* Added support for messages with an unknown sender (zero `sender_user_id`) in private chats, basic groups and
  supergroups. Currently, the sender is unknown for posts in channels and for channel posts automatically forwarded to
  the discussion group.
* Added support for the new permission system for non-administrator users in groups:
  - Added the class `chatPermissions` containing all supported permissions, including new permissions `can_send_polls`,
    `can_change_info`, `can_invite_users` and `can_pin_messages`.
  - Added the field `permissions` to the class `chat`, describing actions that non-administrator chat members are
    allowed to take in the chat.
  - Added the update `updateChatPermissions`.
  - Added the method `setChatPermissions` for changing chat permissions.
  - Added the class `chatEventPermissionsChanged` representing a change of chat permissions in the chat event log.
  - Replaced the fields `can_send_messages`, `can_send_media_messages`, `can_send_other_messages`,
    `can_add_web_page_previews` in the class `chatMemberStatusRestricted` with the field `permissions` of
    the type `chatPermissions`.
  - Removed the field `everyone_is_administrator` from the `basicGroup` class in favor of the field `permissions` of
    the class `chat`.
  - Removed the field `anyone_can_invite` from the `supergroup` class in favor of the field `permissions` of
    the class `chat`.
  - Removed the method `toggleBasicGroupAdministrators` in favor of `setChatPermissions`.
  - Removed the method `toggleSupergroupInvites` in favor of `setChatPermissions`.
  - Renamed the field `anyone_can_invite` to `can_invite_users` in the class `chatEventInvitesToggled`.
  - The permissions `can_send_other_messages` and `can_add_web_page_previews` now imply only `can_send_messages`
    instead of `can_send_media_messages`.
  - Allowed administrators in basic groups to use the method `generateChatInviteLink`.
* Added out of the box `OpenBSD` and `NetBSD` operating systems support.
* Added possibility to use `LibreSSL` >= 2.7.0 instead of `OpenSSL` to build TDLib.
* Added instructions for building TDLib on `Debian 10`, `OpenBSD` and `NetBSD` to
  the [TDLib build instructions generator](https://tdlib.github.io/td/build.html).
* Added support for Backgrounds 2.0:
  - Added the classes `BackgroundType`, `background`, `backgrounds` and `InputBackground`.
  - Added the method `getBackground` returning the list of backgrounds installed by the user.
  - Added the method `setBackground` for changing the background selected by the user.
  - Added the update `updateSelectedBackground`, which is sent right after a successful initialization and whenever
    the selected background changes.
  - Added the method `removeBackground` for removing a background from the list of installed backgrounds.
  - Added the method `resetBackgrounds` for restoring the default list of installed backgrounds.
  - Added the method `searchBackground` returning a background by its name.
  - Added the method `getBackgroundUrl` returning a persistent URL for a background.
  - Removed the `getWallpapers` method.
  - Removed the `wallpaper` and the `wallpapers` classes.
  - The class `fileTypeWallpaper` can be used for remote file identifiers of both old wallpapers and new backgrounds.
* Added support for descriptions in basic groups:
  - Added the field `description` to the class `basicGroupFullInfo`.
  - Replaced the method `setSupergroupDescription` with `setChatDescription` which can be used for any chat type.
* Added support for emoji suggestions:
  - Added the method `searchEmojis` for searching emojis by keywords.
  - Added the method `getEmojiSuggestionsUrl`, which can be used to automatically log in to the translation platform
    and suggest new emoji replacements.
  - Renamed the class `stickerEmojis` to `emojis`.
* Changed type of the fields `old_photo` and `new_photo` in the class `chatEventPhotoChanged` from `chatPhoto` to
  `photo`.
* Changed recommended size for `inputThumbnail` from 90x90 to 320x320.
* Combined all supported settings for phone number authentication:
  - Added the class `phoneNumberAuthenticationSettings` which contains all the settings.
  - Replaced the parameters `is_current_phone_number` and `allow_flash_call` in the methods
    `setAuthenticationPhoneNumber`, `sendPhoneNumberConfirmationCode`, `sendPhoneNumberVerificationCode` and
    `changePhoneNumber` with the parameter `settings` of the type `phoneNumberAuthenticationSettings`.
  - Added support for automatic SMS code verification for official applications via the new field `allow_app_hash` in
    the class `phoneNumberAuthenticationSettings`.
* Added support for auto-download settings presets.
  - Added the classes `autoDownloadSettings` and `autoDownloadSettingsPresets`.
  - Added the method `getAutoDownloadSettingsPresets` for getting the settings.
  - Added the method `setAutoDownloadSettings`, which needs to be called whenever the user changes the settings.
* Added support for minithumbnails - thumbnail images of a very poor quality and low resolution:
  - Added the class `minithumbnail`.
  - Added the field `minithumbnail` to `animation`, `document`, `photo`, `video` and `videoNote` classes.
  - Added the field `audio_cover_minithumbnail` to the class `audio`.
* Added support for resending messages which failed to send:
  - Added the fields `error_code`, `error_message`, `can_retry` and `retry_after` to
    the class `messageSendingStateFailed`.
  - Added the method `resendMessages`.
* Added the field `is_animated` to the `sticker`, `stickerSet` and `stickerSetInfo` classes.
  Animated stickers can be received anywhere where non-animated stickers can appear.
* Added the parameters `send_copy` and `remove_caption` to the `forwardMessages` method to allow forwarding of
  messages without links to the originals.
* Added the fields `send_copy` and `remove_caption` to `inputMessageForwarded` method to allow forwarding of
  a message without link to the original message.
* Added the method `getMessageLinkInfo` for getting information about a link to a message in a chat.
* Added the class `userPrivacySettingShowProfilePhoto` for managing visibility of the user's profile photo.
* Added the class `userPrivacySettingShowLinkInForwardedMessages` for managing whether a link to the user's account is
  included with forwarded messages.
* Added the field `thumbnail` to the classes `stickerSet` and `stickerSetInfo`, containing a thumbnail for
  the sticker set.
* Added the field `is_scam` to the classes `user` and `supergroup`.
* Added a new kind of inline keyboard button `inlineKeyboardButtonTypeLoginUrl`, which for the moment must be processed
  in the same way as an `inlineKeyboardButtonTypeUrl`.
* Added the new class `supergroupMembersFilterContacts`, allowing to only search for contacts
  in `getSupergroupMembers`.
* Added the new class `chatMembersFilterContacts`, allowing to only search for contacts in `searchChatMembers`.
* Added the class `chatEventPollStopped` representing the closing of a poll in a message in the chat event log.
* Added ability to specify the exact types of problems with a call in the method `sendCallRating` and
  the new class `CallProblem`.
* Changes in [tdweb](https://github.com/tdlib/td/blob/master/example/web/):
  - Supported non-zero `offset` and `limit` in `readFilePart`.

-----------------------------------------------------------------------------------------------------------------------

Changes in 1.4.0 (1 May 2019):

* Added a [TDLib build instructions generator](https://tdlib.github.io/td/build.html), covering in details
  TDLib building on the most popular operating systems.
* Added an example of TDLib building and usage from a browser.
  See https://github.com/tdlib/td/blob/master/example/web/ for more details.
* Allowed to pass NULL pointer to `td_json_client_execute` instead of a previously created JSON client.
  Now you can use synchronous TDLib methods through a JSON interface before creating a TDLib JSON client.
* Added support for media streaming by allowing to download any part of a file:
  - Added the `offset` parameter to `downloadFile` which specifies the starting position
    from which the file should be downloaded.
  - Added the `limit` parameter to `downloadFile` which specifies how many bytes should be downloaded starting from
    the `offset` position.
  - Added the field `download_offset` to the class `localFile` which contains the current download offset.
  - The field `downloaded_prefix_size` of the `localFile` class now contains the number of available bytes
    from the position `download_offset` instead of from the beginning of the file.
  - Added the method `getFileDownloadedPrefixSize` which can be used to get the number of locally available file bytes
    from a given offset without actually changing the download offset.
* Added the parameter `synchronous` to `downloadFile` which causes the request to return the result only after
  the download is completed.
* Added support for native polls in messages:
  - Added `messagePoll` to the types of message content; contains a poll.
  - Added the classes `poll` and `pollOption` describing a poll and a poll answer option respectively.
  - Added `inputMessagePoll` to the types of new input message content; can be used to send a poll.
  - Added the method `setPollAnswer` which can be used for voting in polls.
  - Added the method `stopPoll` which can be used to stop polls. Use the `Message.can_be_edited` field to check whether
    this method can be called on a message.
  - Added the update `updatePoll` for bots only. Ordinary users receive poll updates through `updateMessageContent`.
* Added a Notification API. See article https://core.telegram.org/tdlib/notification-api for a detailed description.
  - Added the class `pushReceiverId` which contains a globally unique identifier of the push notification subscription.
  - Changed the return type of the method `registerDevice` to `pushReceiverId` to allow matching of push notifications
    with TDLib instances.
  - Removed the fields `disable_notification` and `contains_mention` from `updateNewMessage`.
  - Renamed the class `deviceTokenGoogleCloudMessaging` to `deviceTokenFirebaseCloudMessaging`.
  - Added the field `encrypt` to classes `deviceTokenApplePushVoIP` and `deviceTokenFirebaseCloudMessaging`
    which allows to subscribe for end-to-end encrypted push notifications.
  - Added the option `notification_group_count_max` which can be used to enable the Notification API and set
    the maximum number of notification groups to be shown simultaneously.
  - Added the option `notification_group_size_max` which can be used to set the maximum number of simultaneously shown
    notifications in a group.
  - Added the synchronous method `getPushReceiverId` for matching a push notification with a TDLib instance.
  - Added the method `processPushNotification` for handling of push notifications.
  - Removed the method `processDcUpdate` in favor of the general `processPushNotification` method.
  - Added the update `updateNotificationGroup`, sent whenever a notification group changes.
  - Added the update `updateNotification`, sent whenever a notification changes.
  - Added the update `updateActiveNotifications` for syncing the list of active notifications on startup.
  - Added the update `updateHavePendingNotifications` which can be used to improve lifetime handling of
    the TDLib instance.
  - Added the possibility to disable special handling of notifications about pinned messages via the new settings
    `use_default_disable_pinned_message_notifications`, `disable_pinned_message_notifications` in
    the class `chatNotificationSettings` and the new setting `disable_pinned_message_notifications` in
    the class `scopeNotificationSettings`.
  - Added the possibility to disable special handling of notifications about mentions and replies via the new settings
    `use_default_disable_mention_notifications`, `disable_mention_notifications` in
    the class `chatNotificationSettings` and the new setting `disable_mention_notifications` in
    the class `scopeNotificationSettings`.
  - Added the class `PushMessageContent` describing the content of a notification, received through
    a push notification.
  - Added the class `NotificationType` describing a type of notification.
  - Added the class `notification` containing information about a notification.
  - Added the class `NotificationGroupType` describing a type of notification group.
  - Added the class `notificationGroup` describing a state of a notification group.
  - Added the methods `removeNotification` and `removeNotificationGroup` for handling notifications removal
    by the user.
  - Added the separate notification scope `notificationSettingsScopeChannelChats` for channel chats.
* Added support for pinned notifications in basic groups and Saved Messages:
  - Added the field `pinned_message_id` to the class `chat`.
  - Removed the field `pinned_message_id` from the class `supergroupFullInfo` in favor of `chat.pinned_message_id`.
  - Added the update `updateChatPinnedMessage`.
  - The right `can_pin_messages` is now applicable to both basic groups and supergroups.
  - Replaced the method `pinSupergroupMessage` with `pinChatMessage` which can be used for any chat type.
  - Replaced the method `unpinSupergroupMessage` with `unpinChatMessage` which can be used for any chat type.
* Added new synchronous methods for managing TDLib internal logging. The old functions are deprecated and
  will be removed in TDLib 2.0.0.
  - Added the synchronous method `setLogStream` for changing the stream to which the TDLib internal log is written.
  - Added the synchronous method `getLogStream` for getting information about the currently used log stream.
  - Added the classes `logStreamDefault`, `logStreamFile` and `logStreamEmpty` describing different supported kinds of
    log streams.
  - Added the class `logVerbosityLevel` containing the verbosity level of the TDLib internal log.
  - Added the class `logTags` containing a list of available TDLib internal log tags.
  - Added the synchronous method `setLogVerbosityLevel` for changing verbosity level of logging.
  - Added the synchronous method `getLogVerbosityLevel` for getting the current verbosity level of logging.
  - Added the synchronous method `getLogTags` returning all currently supported log tags.
  - Added the synchronous method `setLogTagVerbosityLevel` for changing the verbosity level of logging for
    some specific part of the code.
  - Added the synchronous method `getLogTagVerbosityLevel` for getting the current verbosity level for a specific part
    of the code.
  - Added the synchronous method `addLogMessage` for using the TDLib internal log by the application.
* Added support for Instant View 2.0:
  - Replaced the field `has_instant_view` in class `webPage` with the `instant_view_version` field.
  - Added the field `version` to the class `webPageInstantView`.
  - Added the class `pageBlockCaption`.
  - Changed the type of `caption` fields in `pageBlockAnimation`, `pageBlockAudio`, `pageBlockPhoto`, `pageBlockVideo`,
    `pageBlockEmbedded`, `pageBlockEmbeddedPost`, `pageBlockCollage` and `pageBlockSlideshow` from
    `RichText` to `pageBlockCaption`.
  - Added the class `pageBlockListItem` and replaced the content of the `pageBlockList` class with a list of
    `pageBlockListItem`.
  - Added 6 new kinds of `RichText`: `richTextSubscript`, `richTextSuperscript`, `richTextMarked`,
    `richTextPhoneNumber`, `richTextIcon` and `richTextAnchor`.
  - Added new classes `pageBlockRelatedArticle`, `PageBlockHorizontalAlignment`, `PageBlockVerticalAlignment` and
    `pageBlockTableCell`.
  - Added new block types `pageBlockKicker`, `pageBlockRelatedArticles`, `pageBlockTable`, `pageBlockDetails` and
    `pageBlockMap`.
  - Added the flag `is_rtl` to the class `webPageInstantView`.
  - Renamed the field `caption` in classes `pageBlockBlockQuote` and `pageBlockPullQuote` to `credit`.
  - Dimensions in `pageBlockEmbedded` can now be unknown.
  - Added the field `url` to `pageBlockPhoto` which contains a URL that needs to be opened when the photo is clicked.
  - Added the field `url` to `webPageInstantView` which must be used for the correct handling of anchors.
* Added methods for confirmation of the 2-step verification recovery email address:
  - Added the method `checkRecoveryEmailAddressCode` for checking the verification code.
  - Added the method `resendRecoveryEmailAddressCode` for resending the verification code.
  - Replaced the field `unconfirmed_recovery_email_address_pattern` in the class `passwordState` with
    the `recovery_email_address_code_info` field containing full information about the code.
  - The necessity of recovery email address confirmation in `setPassword` and `setRecoveryEmailAddress` methods
    is now returned by the corresponding `passwordState` and not by the error `EMAIL_UNCONFIRMED`.
* Improved the `MessageForwardInfo` class and added support for hidden original senders:
  - Removed the old `messageForwardedPost` and `messageForwardedFromUser` classes.
  - Added the class `messageForwardInfo` which contains information about the origin of the message, original sending
    date and identifies the place from which the message was forwarded the last time for messages forwarded to
    Saved Messages.
  - Added the classes `messageForwardOriginUser`, `messageForwardOriginHiddenUser` and `messageForwardOriginChannel`
    which describe the exact origins of a message.
* Improved getting the list of user profile photos:
  - Added the class `userProfilePhoto`, containing `id`, `added_date` and `sizes` of a profile photo.
  - Changed the type of the field `photos` in `userProfilePhotos` to a list of `userProfilePhoto` instead of
    a list of `photo`. `getUserProfilePhotos` now returns a date for each profile photo.
  - Removed the field `id` from the class `photo` (this field was only needed in the result of `getUserProfilePhotos`).
* Added the possibility to get a Telegram Passport authorization form before asking the user for a password:
  - Removed the parameter `password` from the method `getPassportAuthorizationForm`.
  - Moved the fields `elements` and `errors` from the class `passportAuthorizationForm` to
    the new class `passportElementsWithErrors`.
  - Added the method `getPassportAuthorizationFormAvailableElements` that takes the user's password and
    returns previously uploaded Telegram Passport elements and errors in them.
* Added the field `file_index` to the classes `passportElementErrorSourceFile` and
  `passportElementErrorSourceTranslationFile`.
* Added the method `getCurrentState` returning all updates describing the current `TDLib` state. It can be used to
  restore the correct state after connecting to a running TDLib instance.
* Added the class `updates` which contains a list of updates and is returned by the `getCurrentState` method.
* Added the update `updateChatOnlineMemberCount` which is automatically sent for open group chats if the number of
  online members in a group changes.
* Added support for custom language packs downloaded from the server:
  - Added the fields `base_language_pack_id`` to the class `languagePackInfo`. Strings from the base language pack
    must be used for untranslated keys from the chosen language pack.
  - Added the fields `plural_code`, `is_official`, `is_rtl`, `is_beta`, `is_installed`, `total_string_count`,
    `translated_string_count`, `translation_url` to the class `languagePackInfo`.
  - Added the method `addCustomServerLanguagePack` which adds a custom server language pack to the list of
    installed language packs.
  - Added the method `getLanguagePackInfo` which can be used for handling `https://t.me/setlanguage/...` links.
  - Added the method `synchronizeLanguagePack` which can be used to fetch the latest versions of all strings from
    a language pack.
    The method doesn't need to be called explicitly for the current used/base language packs.
  - The method `deleteLanguagePack` now also removes the language pack from the list of installed language packs.
* Added the method `getChatNotificationSettingsExceptions` which can be used to get chats with
  non-default notification settings.
* Added the parameter `hide_via_bot` to `sendInlineQueryResultMessage` which can be used for
  `getOption("animation_search_bot_username")`, `getOption("photo_search_bot_username")` and
  `getOption("venue_search_bot_username")` bots to hide that the message was sent via the bot.
* Added the class `chatReportReasonChildAbuse` which can be used to report a chat for child abuse.
* Added the method `getMessageLocally` which returns a message only if it is available locally without
  a network request.
* Added the method `writeGeneratedFilePart` which can be used to write a generated file if there is no direct access to
  TDLib's file system.
* Added the method `readFilePart` which can be used to read a file from the TDLib file cache.
* Added the class `filePart` to represent the result of the new `readFilePart` method.
* Added the field `log_size` to the `storageStatisticsFast` class which contains the size of the TDLib internal log.
  Previously the size was included into the value of the `database_size` field.
* Added the field `language_pack_database_size` to the `storageStatisticsFast` class which contains the size of the
  language pack database.
* Added the field `is_support` to the class `user` which can be used to identify Telegram Support accounts.
* Added the class `HttpUrl` encapsulating an HTTP URL.
* Added the method `getMessageLink` which can be used to create a private link (which works only for members) to
  a message in a supergroup or channel.
* Added support for channel statistics (coming soon):
  - Added the field `can_view_statistics` to the `supergroupFullInfo` class.
  - Added the method `getChatStatisticsUrl` which returns a URL with the chat statistics.
* Added support for server-side peer-to-peer calls privacy:
  - Added the class `userPrivacySettingAllowPeerToPeerCalls` for managing privacy.
  - Added the field `allow_p2p` to `callStateReady` class which must be used to determine whether
    a peer-to-peer connection can be used.
* Added the option `ignore_background_updates` which allows to skip all updates received while the TDLib instance was
  not running. The option does nothing if the database or secret chats are used.
* Added the read-only option `expect_blocking`, suggesting whether Telegram is blocked for the user.
* Added the read-only option `enabled_proxy_id`, containing the ID of the enabled proxy.
* Added the ability to identify password pending sessions (where the code was entered but not
  the two-step verification password) via the flag `is_password_pending` in the `session` class.
  TDLib guarantees that the sessions will be returned by the `getActiveSessions` method in the correct order.
* Added the classes `JsonValue` and `jsonObjectMember` which represent a JSON value and
  a member of a JSON object respectively as TDLib API objects.
* Added the synchronous methods `getJsonValue` and `getJsonString` for simple conversion between
  a JSON-encoded string and `JsonValue` TDLib API class.
* Added the methods `getApplicationConfig` and `saveApplicationLogEvent` to be used for testing purposes.
* Added the temporarily class `databaseStatistics` and the method `getDatabaseStatistics` for rough estimations of
  database tables size in a human-readable format.
* Made the method `Client.Execute` static in .NET interface.
* Removed the `on_closed` callback virtual method from low-level C++ ClientActor interface.
  Callback destructor can be used instead.
* Updated dependencies in the prebuilt TDLib for Android:
  - Updated SDK to SDK 28 in which helper classes were moved from `android.support.` to `androidx.` package.
  - Updated NDK to r19c, which dropped support for Android versions up to 4.0.4, so the minimum supported version is
    Android 4.1.
  - Updated OpenSSL to version 1.1.1.
  - Added x86_64 libraries.
* Added out of the box `FreeBSD` support.
* Significantly improved TDLib compilation time and decreased compiler RAM usage:
  - In native C++ interface `td_api::object_ptr` is now a simple homebrew const-propagating class instead of
    `std::unique_ptr`.
  - Added the script `SplitSource.php`, which can be used to split some source code files before building
    the library to reduce maximum RAM usage per file at the expense of increased build time.
* The update `updateOption` with the `version` option is now guaranteed to come before all other updates.
  It can now be used to dynamically discover available methods.
* Added the ability to delete incoming messages in private chats and revoke messages without a time limit:
  - Added the parameter `revoke` to the method `deleteChatHistory`; use it to delete chat history for all chat members.
  - Added the fields `can_be_deleted_only_for_self` and `can_be_deleted_for_all_users` to the class `chat`
    which can be used to determine for whom the chat can be deleted through the `deleteChatHistory` method.
  - The fields `Message.can_be_deleted_only_for_self` and `Message.can_be_deleted_for_all_users` can still be used
    to determine for whom the message can be deleted through the `deleteMessages` method.
* Added support for server-generated notifications about newly registered contacts:
  - Setting the option `disable_contact_registered_notifications` now affects all user sessions.
    When the option is enabled, the client will still receive `messageContactRegistered` message in the private chat,
    but there will be no notification about the message.
  - `getOption("disable_contact_registered_notifications")` can be used to fetch the actual value of the option,
    the option will not be updated automatically after a change from another device.
* Decreased the maximum allowed first name and last name length to 64, chat title length to 128,
  matching the new server-side limits.
* Decreased the maximum allowed value of the `forward_limit` parameter of the `addChatMember` method from 300 to 100,
  matching the new server-side limit.
* Added protection from opening two TDLib instances with the same database directory from one process.
* Added copying of notification settings of new secret chats from notification settings of
  the corresponding private chat.
* Excluded the sponsored chat (when using sponsored proxies) from unread counters.
* Allowed to pass decreased local_size in `setFileGenerationProgress` to restart the generation from the beginning.
* Added a check for modification time of original file in `inputFileGenerated` whenever possible.
  If the original file was changed, then TDLib will restart the generation.
* Added the destruction of MTProto keys on the server during log out.
* Added support for hexadecimal-encoded and decimal-encoded IPv4 proxy server addresses.
* Improved the behavior of `changeImportedContacts` which now also deletes contacts of users without Telegram accounts
  from the server.
* Added the ability to call `getStorageStatistics` before authorization.
* Allowed to pass `limit` = -`offset` for negative offset in the `getChatHistory` method.
* Changed the recommended `inputThumbnail` size to be at most 320x320 instead of the previous 90x90.
* Disabled building by default of the native C interface. Use `cmake --build . --target tdc` to build it.
* Numerous optimizations and bug fixes:
  - Network implementation for Windows was completely rewritten to allow a literally unlimited number of
    simultaneously used TDLib instances.
  - TDLib instances can now share working threads with each other. Only a limited number of threads will be created
    even if there are thousands of TDLib instances in a single process.
  - Removed the restriction on the size of update or response result in JSON interface.
  - Fixed pinning of the 5th chat when there is a sponsored chat.
  - Fixed IPv6 on Windows.
  - Improved network connections balancing, aliveness checks and overall stability.
  - Various autogenerated documentation fixes and improvements.

-----------------------------------------------------------------------------------------------------------------------

Changes in 1.3.0 (5 Sep 2018):

* Added a review of existing TDLib based [frameworks](https://github.com/tdlib/td/blob/master/example/README.md)
  in different programming languages.
* Added a [Getting started](https://core.telegram.org/tdlib/getting-started) guide describing the main TDLib concepts
  and basic principles required for library usage.
* When a chat is opened, only those messages that have been viewed are marked as read.
* Improved the proxy settings API:
  - A list of proxies is stored instead of just one proxy.
  - New methods `addProxy`, `editProxy`, `enableProxy`, `disableProxy`, `removeProxy` and `getProxies` were added
    instead of `setProxy` and `getProxy`.
  - Added the method `pingProxy` which can be used to compute time needed to receive a response from a Telegram server
    through a proxy or directly.
  - Added support for MTProto proxy via class `proxyTypeMtproto`.
  - Added support for HTTP proxy via class `proxyTypeHttp`.
  - For each proxy last time it was used is remembered.
  - Added the method `getProxyLink` which returns an HTTPS link that can be used to share a proxy with others.
* Improved the notification settings API. Scope notification settings are now properly synchronized between all devices
  and chat notification settings can be reset to their default values:
  - The `notificationSettings` class was split into `chatNotificationSettings` and `scopeNotificationSettings`.
  - Only two notification settings scopes are left: `notificationSettingsScopePrivateChats` which is responsible for
    default notification settings for private and secret chats and `notificationSettingsScopeGroupChats` for all other
    chats.
  - `updateNotificationSettings` was split into `updateChatNotificationSettings` and `updateScopeNotificationSettings`.
  - `setNotificationSettings` was split into `setChatNotificationSettings` and `setScopeNotificationSettings`.
  - `getNotificationSettings` was replaced with `getScopeNotificationSettings`.
* Added the field `filter` to the `searchChatMembers` method to support searching among administrators, bots,
  restricted and banned members.
* Added the ability to use synchronous requests and `setAlarm` before the library is initialized.
* Added the ability to send requests that don't need authentication before the library is initialized. These requests
  will be postponed and executed at the earliest opportunity. For example, `setNetworkType` can be used to disable the
  network for TDLib before the library tries to use it; `addProxy` can be used to add a proxy before any network
  activity; or `setOption("use_pfs")` can be used to guarantee that PFS is used for all requests.
* Added support for tg:// links in `inlineKeyboardButtonTypeUrl` and `textEntityTypeTextUrl`.
* Added the ability to call `deleteAccount` in the `authorizationStateWaitPassword` authorization state.
* Added the ability to call `checkAuthenticationCode` with an empty `first_name` for unregistered users to check the
  code validity.
* Added the methods `editMessageMedia` and `editInlineMessageMedia` for editing media messages content.
* Renamed the class `shippingAddress` to `address`.
* Changed the return value of the `requestPasswordRecovery` method from `passwordRecoveryInfo` to
  `emailAddressAuthenticationCodeInfo`.
* Added support for sponsored channels promoted by MTProto-proxies:
  - Added the field `is_sponsored` to the `chat` class.
  - Added `updateChatIsSponsored`, sent when this field changes.
* Added support for marking chats as unread:
  - Added the field `is_marked_as_unread` to `chat`.
  - Added the update `updateChatIsMarkedAsUnread`.
  - Added the method `toggleChatIsMarkedAsUnread`.
* Added support for a default value of `disable_notification`, used when a message is sent to the chat:
  - Added the field `default_disable_notification` to `chat` class.
  - Added the update `updateChatDefaultDisableNotification`.
  - Added the method `toggleChatDefaultDisableNotification`.
* Added the field `vcard` to the `contact` class.
* Added the field `type` to `venue`, which contains a provider-specific type of the venue,
* Added the update `updateUnreadChatCount`, enabled when the message database is used and sent when
  the number of unread chats has changed.
* Added the method `addLocalMessage` for adding a local message to a chat.
* Added the method `getDeepLinkInfo`, which can return information about `tg://` links that are not supported by
  the client.
* Added support for language packs:
  - Added the writable option `language_pack_database_path` which can be used to specify a path to a database
    for storing language pack strings, so that this database can be shared between different accounts.
    If not specified, language pack strings will be stored only in memory.
    Changes to the option are applied only on the next TDLib launch.
  - Added the writable option `localization_target` for setting up a name for the current localization target
    (currently supported: "android", "android_x", "ios", "macos" and "tdesktop").
  - Added the writable option `language_pack_id` for setting up an identifier of the currently used language pack from
    the current localization target (a "language pack" represents the collection of strings that can be used to display
    the interface of a particular application in a particular language).
  - Added the class `LanguagePackStringValue` describing the possible values of a string from a language pack.
  - Added the class `languagePackString` describing a string from a language pack.
  - Added the class `languagePackStrings` containing a list of language pack strings.
  - Added the class `languagePackInfo` containing information about a language pack from a localization target.
  - Added the class `localizationTargetInfo` containing information about a localization target.
  - Added the update `updateLanguagePackStrings` which is sent when some strings in a language pack have changed.
  - Added the synchronous method `getLanguagePackString` which can be used to get a language pack string from
    the local database.
  - Added the method `getLocalizationTargetInfo` which returns information about the current localization target.
  - Added the method `getLanguagePackStrings` which returns some or all strings from a language pack, possibly fetching
    them from the server.
  - Added the method `setCustomLanguagePack` for adding or editing a custom language pack.
  - Added the method `editCustomLanguagePackInfo` for editing information about a custom language pack.
  - Added the method `setCustomLanguagePackString` for adding, editing or deleting a string in a custom language pack.
  - Added the method `deleteLanguagePack` for deleting a language pack from the database.
  - Added the read-only option `suggested_language_pack_id` containing the identifier of the language pack,
    suggested for the user by the server.
* Added support for Telegram Passport:
  - Added two new message contents `messagePassportDataSent` for ordinary users and `messagePassportDataReceived`
    for bots containing information about Telegram Passport data shared with a bot.
  - Added the new file type `fileTypeSecure`.
  - Added the class `datedFile` containing information about a file along with the date it was uploaded.
  - Added the helper classes `date`, `personalDetails`, `identityDocument`, `inputIdentityDocument`,
    `personalDocument`, `inputPersonalDocument`, `passportElements`.
  - Added the class `PassportElementType` describing all supported types of Telegram Passport elements.
  - Added the class `PassportElement` containing information about a Telegram Passport element.
  - Added the class `InputPassportElement` containing information about a Telegram Passport element to save.
  - Added the classes `passportElementError` and `PassportElementErrorSource` describing an error in
    a Telegram Passport element.
  - Added the field `has_passport_data` to the `passwordState` class.
  - Added the methods `getPassportElement`, `getAllPassportElements`, `setPassportElement`, `deletePassportElement`
    for managing Telegram Passport elements.
  - Added the methods `getPassportAuthorizationForm` and `sendPassportAuthorizationForm` used for sharing
    Telegram Passport data with a service via a bot.
  - Added the methods `sendPhoneNumberVerificationCode`, `resendPhoneNumberVerificationCode` and
    `checkPhoneNumberVerificationCode` for verification of a phone number used for Telegram Passport.
  - Added the methods `sendEmailAddressVerificationCode`, `resendEmailAddressVerificationCode` and
    `checkEmailAddressVerificationCode` for verification of an email address used for Telegram Passport.
  - Added the method `getPreferredCountryLanguage` returning a most popular language in a country.
  - Added the classes `inputPassportElementError` and `InputPassportElementErrorSource` for bots describing an error in
    a Telegram Passport element.
  - Added the method `setPassportElementErrors` for bots.
  - Added the class `encryptedPassportElement` and `encryptedCredentials` for bots describing
    an encrypted Telegram Passport element.
* Improved support for Telegram terms of service:
  - Added the class `termsOfService`, containing information about the Telegram terms of service.
  - Added the field `terms_of_service` to `authorizationStateWaitCode`.
  - Added the update `updateTermsOfService` coming when new terms of service need to be accepted by the user.
  - Added the method `acceptTermsOfService` for accepting terms of service.
  - Removed the method `getTermsOfService`.
* Added the method `getMapThumbnailFile` which can be used to register and download a map thumbnail file.
* Added the methods `sendPhoneNumberConfirmationCode`, `resendPhoneNumberConfirmationCode` and
  `checkPhoneNumberConfirmationCode` which can be used to prevent an account from being deleted.
* Added the convenience methods `joinChat` and `leaveChat` which can be used instead of `setChatMemberStatus` to manage
  the current user's membership in a chat.
* Added the convenience method `getContacts` which can be used instead of `searchContacts` to get all contacts.
* Added the synchronous method `cleanFileName` which removes potentially dangerous characters from a file name.
* Added the method `getChatMessageCount` which can be used to get the number of shared media.
* Added the writable option `ignore_inline_thumbnails` which can be used to prevent file thumbnails sent
  by the server along with messages from being saved on the disk.
* Added the writable option `prefer_ipv6` which can be used to prefer IPv6 connections over IPv4.
* Added the writable option `disable_top_chats` which can be used to disable support for top chats.
* Added the class `chatReportReasonCopyright` for reporting chats containing infringing content.
* Added the method `clearAllDraftMessages` which can be used to delete all cloud drafts.
* Added the read-only options `message_text_length_max` and `message_caption_length_max`.
* Added the read-only options `animation_search_bot_username`, `photo_search_bot_username` and
  `venue_search_bot_username` containing usernames of bots which can be used in inline mode for animations, photos and
  venues search respectively.
* Numerous optimizations and bug fixes:
  - Fixed string encoding for .NET binding.
  - Fixed building TDLib SDK for Universal Windows Platform for ARM with MSVC 2017.
  - Fixed the Swift example project.
  - Fixed the syntax error in the Python example.
  - Sticker thumbnails can now have `webp` extensions if they are more likely to be in WEBP format.

-----------------------------------------------------------------------------------------------------------------------

Changes in 1.2.0 (20 Mar 2018):

* Added support for native .NET bindings through `C++/CLI` and `C++/CX`.
  See [using in .NET projects](README.md#using-dotnet) for more details.
* Added a C# example. See [README](example/csharp/README.md) for build and usage instructions.
* Added a build and usage example of TDLib SDK for Universal Windows Platform. See [README](example/uwp/README.md)
  for detailed build and usage instructions. Also, see [Unigram](https://github.com/UnigramDev/Unigram), which is
  a full-featured client rewritten from scratch using TDLib SDK for Universal Windows Platform in less than 2 months.
* Added a Swift example. See [README](example/swift/README.md) for build and usage instructions.
* Added an example of building TDLib for iOS, watchOS, tvOS, and also macOS. See [README](example/ios/README.md) for
  detailed build instructions.
* Added README to [C++](example/cpp/README.md) and [python](example/python/README.md) examples.
* Link Time Optimization is disabled by default. Use `-DTD_ENABLE_LTO=ON` CMake option and CMake >= 3.9 to enable it.
* `updateNotificationSettings` is now automatically sent when the mute time expires for a chat.
* Added automatic sending of a corresponding `chatAction` when a file is being uploaded.
* `updateUserChatAction` with `chatActionCancel` is now automatically sent when the timeout expires for an action.
* Authorization states `authorizationStateWaitCode` and `authorizationStateWaitPassword` are now saved between
  library restarts for 5 minutes.
* Added new message content type `messageWebsiteConnected`.
* Added new text entity types `textEntityTypeCashtag` and `textEntityTypePhoneNumber`.
* Added new update `updateUnreadMessageCount`, enabled when message database is used.
* Method `joinChatByInviteLink` now returns the joined `chat`.
* Method `getWebPagePreview` now accepts `formattedText` instead of plain `string`.
* Added field `phone_number` to `authenticationCodeInfo`, which contains a phone number that is being authenticated.
* Added field `is_secret` to `messageAnimation`, `messagePhoto`, `messageVideo` and `messageVideoNote` classes,
  which denotes whether the thumbnail for the content must be blurred and the content must be shown only while tapped.
* Added field `expires_in` to `messageLocation` for live locations.
* Added flag `can_be_reported` to `chat` class.
* Added flag `supports_streaming` to classes `video` and `inputMessageVideo`.
* Added parameter `message_ids` to `reportChat`, which can be used to report specific messages.
* Added method `checkChatUsername` for checking whether a username can be set for a chat.
* Added method `getRepliedMessage`, which returns a message that is replied by a given message.
* Added method `getChatPinnedMessage`, which returns the pinned message from a chat.
* Added method `searchStickers` to search by emoji for popular stickers suggested by the server.
* Added method `searchStickerSets` to search by title and name for popular sticker sets suggested by the server.
* Added method `searchInstalledStickerSets` to search by title and name for installed sticker sets.
* Added methods for handling connected websites: `getConnectedWebsites`, `disconnectWebsite` and
  `disconnectAllWebsites`.
* Added method `getCountryCode`, which uses current user IP address to identify their country.
* Added option `t_me_url`.
* Fixed `BlackBerry` spelling in `deviceTokenBlackBerryPush`.
* Fixed return type of `getChatMessageByDate` method, which is `Message` and not `Messages`.
* Ensured that updateOption("my_id") comes before `updateAuthorizationState` with `authorizationStateReady`.
* Numerous optimizations and bug fixes.

-----------------------------------------------------------------------------------------------------------------------

Changes in 1.1.1 (4 Feb 2018):
* Fixed C JSON bindings compilation error.
* Fixed locale-dependent JSON generation.

-----------------------------------------------------------------------------------------------------------------------

Changes in 1.1.0 (31 Jan 2018):

* Methods `td::Log::set_file_path` and `td_set_log_file_path` now return whether they succeeded.
* Added methods `td::Log::set_max_file_size` and `td_set_log_max_file_size` for restricting maximum TDLib log size.
* Added methods `td::Log::set_fatal_error_callback` and `td_set_log_fatal_error_callback` for providing callbacks
  on fatal errors.
* JNI-bindings are now package-agnostic. Use CMake option `TD_ENABLE_JNI` to enable JNI-bindings.
* Added a Java example. See [README](example/java/README.md) for build and usage instructions.
* Added support for text entities in media captions.
  - Added new type `formattedText` containing a text with entities.
  - Replaced all string fields `caption` with fields of type `formattedText`.
  - Replaced fields `text` and `entities` with the field `text` of type `formattedText` in class `messageText`.
  - Replaced fields `text` and `entities` with the field `text` of type `formattedText` in class `inputMessageText`.
  - Replaced fields `text` and `text_entities` with the field `text` of type `formattedText` in class `game`.
  - Removed field `parse_mode` from class `inputMessageText`.
  - Added synchronous method `parseTextEntities`.
* updateNewMessage is now sent for all sent messages.
* updateChatLastMessage is now sent when any field of the last message in a chat changes.
* Reworked the `registerDevice` method:
  - Added parameter `other_user_ids` to method `registerDevice` to support multiple accounts.
  - It is now possible to specify tokens for VoIP pushes, WNS, web Push API, Tizen Push Service as `DeviceToken`.
  - Added support for Apple Push Notification Service inside App Sandbox.
* Added method `searchChatsOnServer` analogous to `searchChats`, but using server search.
* Results from the `searchChatsOnServer` method are now excluded from `searchPublicChats` results,
  so `searchChatsOnServer` (along with `searchContacts`) should be called whenever `searchPublicChats` is called
  to ensure that no results were omitted.
* Added parameter `as_album` to method `getPublicMessageLink` to enable getting public links for media albums.
* Added field `html` to class `publicMessageLink`, containing HTML-code for message/message album embedding.
* Added parameter `only_if_pending` to method `cancelDownloadFile` to allow keeping already started downloads.
* Methods `createPrivateChat`, `createBasicGroupChat`, `createSupergroupChat` and `createSecretChat`
  can now be called without a prior call to `getUser`/`getBasicGroup`/`getSupergroup`/`getSecretChat`.
* Added parameter `force` to methods `createPrivateChat`, `createBasicGroupChat` and `createSupergroupChat` to allow
  creating a chat without network requests.
* Numerous optimizations and bug fixes.

-----------------------------------------------------------------------------------------------------------------------
