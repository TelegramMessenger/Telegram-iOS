cmake_minimum_required(VERSION 3.10 FATAL_ERROR)

project(TDLib VERSION 1.8.46 LANGUAGES CXX C)

if (NOT DEFINED CMAKE_MODULE_PATH)
  set(CMAKE_MODULE_PATH "")
endif()
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMake" "${CMAKE_MODULE_PATH}")

if (NOT DEFINED CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR "lib")
endif()
if (NOT DEFINED CMAKE_INSTALL_BINDIR)
  set(CMAKE_INSTALL_BINDIR "bin")
endif()
if (NOT DEFINED CMAKE_INSTALL_INCLUDEDIR)
  set(CMAKE_INSTALL_INCLUDEDIR "include")
endif()

if (POLICY CMP0074)
  # use environment variables to find libraries
  cmake_policy(SET CMP0074 NEW)
endif()

include(PreventInSourceBuild)
prevent_in_source_build()

option(TD_INSTALL_STATIC_LIBRARIES "Enable installation of static libraries." ON)
option(TD_INSTALL_SHARED_LIBRARIES "Enable installation of shared libraries." ON)
option(TD_ENABLE_JNI "Use \"ON\" to enable JNI-compatible TDLib API.")
option(TD_ENABLE_DOTNET "Use \"ON\" to enable generation of C++/CLI or C++/CX TDLib API bindings.")
if (NOT CMAKE_CROSSCOMPILING)
  option(TD_GENERATE_SOURCE_FILES "Use \"ON\" to just generate TDLib source files.")
endif()

include(CTest)

option(TD_ENABLE_LTO "Use \"ON\" to enable Link Time Optimization.")

if (TD_ENABLE_LTO)
  include(CheckIPOSupported)
  check_ipo_supported(RESULT IPO_SUPPORTED)
  if (IPO_SUPPORTED)
    # set_property(DIRECTORY PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE) do not work?
    string(REPLACE ";" " " CXX_FLAGS_IPO "${CMAKE_CXX_COMPILE_OPTIONS_IPO}")
    message(STATUS "Use link time optimization CXX options: ${CXX_FLAGS_IPO}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX_FLAGS_IPO}")

    string(REPLACE ";" " " C_FLAGS_IPO "${CMAKE_C_COMPILE_OPTIONS_IPO}")
    message(STATUS "Use link time optimization C options: ${C_FLAGS_IPO}")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${C_FLAGS_IPO}")

    string(REPLACE ";" " " LINK_FLAGS_IPO "${CMAKE_CXX_LINK_OPTIONS_IPO}")
    message(STATUS "Use link time optimization linker options: ${LINK_FLAGS_IPO}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${LINK_FLAGS_IPO}")
  endif()
endif()

# Configure Ccache if available
find_program(CCACHE_FOUND ccache)
#set(CCACHE_FOUND 0)
if (CCACHE_FOUND)
  message(STATUS "Found ccache")
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
else()
  message(STATUS "Could NOT find ccache (this is NOT an error)")
endif()

set(MEMPROF "" CACHE STRING "Use one of \"ON\", \"FAST\" or \"SAFE\" to enable memory profiling. \
Works under macOS and Linux when compiled using glibc. \
In FAST mode stack is unwinded only using frame pointers, which may fail. \
In SAFE mode stack is unwinded using backtrace function from execinfo.h, which may be very slow. \
By default both methods are used to achieve the maximum speed and accuracy")

if (EMSCRIPTEN)
  # use prebuilt zlib
  set(ZLIB_FOUND 1)
  set(ZLIB_LIBRARIES)
  set(ZLIB_INCLUDE_DIR)

  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -s ALLOW_MEMORY_GROWTH=1 -s MEMFS_APPEND_TO_TYPED_ARRAYS=1 -s USE_ZLIB=1 -s MODULARIZE=1 \
    -s EXPORT_NAME=\"'createTdwebModule'\" -s WEBSOCKET_URL=\"'wss:#'\" -s EXPORTED_RUNTIME_METHODS=\"['FS','cwrap']\" -lidbfs.js -lworkerfs.js")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -s ALLOW_MEMORY_GROWTH=1 -s MEMFS_APPEND_TO_TYPED_ARRAYS=1 -s USE_ZLIB=1 -s MODULARIZE=1 \
    -s EXPORT_NAME=\"'createTdwebModule'\" -s WEBSOCKET_URL=\"'wss:#'\" -s EXPORTED_RUNTIME_METHODS=\"['FS','cwrap']\" -lidbfs.js -lworkerfs.js")
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -s DEMANGLE_SUPPORT=1 -s ASSERTIONS=1")
  set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -s DEMANGLE_SUPPORT=1 -s ASSERTIONS=1")

  set(TD_EMSCRIPTEN td_wasm)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -s WASM=1 --post-js ${CMAKE_CURRENT_SOURCE_DIR}/post.js")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -s WASM=1")
endif()

if (NOT TD_GENERATE_SOURCE_FILES)
  if (NOT OPENSSL_FOUND)
    find_package(OpenSSL)
  endif()
  if (OPENSSL_FOUND)
    message(STATUS "Found OpenSSL: ${OPENSSL_INCLUDE_DIR} ${OPENSSL_LIBRARIES}")
  endif()
endif()

set(CMAKE_THREAD_PREFER_PTHREAD ON)
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

if (THREADS_HAVE_PTHREAD_ARG)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
endif()

include(TdSetUpCompiler)
td_set_up_compiler()

if (MSVC)
  option(TD_ENABLE_MULTI_PROCESSOR_COMPILATION "Use \"ON\" to enable multi-processor compilation.")

  if (TD_ENABLE_MULTI_PROCESSOR_COMPILATION)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP")
  endif()

  if (TD_ENABLE_JNI)
    # https://github.com/tdlib/td/issues/2912
    add_definitions(-D_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)
  endif()
endif()

if (CLANG OR GCC)
  if (MEMPROF)
    include(CheckCXXCompilerFlag)
    check_cxx_compiler_flag(-no-pie CXX_NO_PIE_FLAG)
    if (CXX_NO_PIE_FLAG)
      set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -no-pie")
    elseif (APPLE)
      set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-no_pie")
    endif()
    include(AddCXXCompilerFlag)
    add_cxx_compiler_flag("-static-libstdc++")
    add_cxx_compiler_flag("-static-libgcc")
  endif()
endif()

include(GetGitRevisionDescription)
get_git_head_revision(TD_GIT_REFSPEC TD_GIT_COMMIT_HASH)
message(STATUS "Git state: ${TD_GIT_COMMIT_HASH}")

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/td/telegram/GitCommitHash.cpp.in" "${CMAKE_CURRENT_BINARY_DIR}/td/telegram/GitCommitHash.cpp" @ONLY)

add_subdirectory(tdtl)

if (TD_GENERATE_SOURCE_FILES)
  set(TDUTILS_MIME_TYPE ON CACHE BOOL "" FORCE)
  set(TDUTILS_USE_EXTERNAL_DEPENDENCIES OFF CACHE BOOL "" FORCE)
endif()
set(TDUTILS_ENABLE_INSTALL ${TD_INSTALL_STATIC_LIBRARIES} CACHE BOOL "" FORCE)
add_subdirectory(tdutils)

add_subdirectory(td/generate)

if (NOT CMAKE_CROSSCOMPILING)
  set(TD_ALWAYS_GENERATE_SOURCE "")
  if (TD_GENERATE_SOURCE_FILES)
    set(TD_ALWAYS_GENERATE_SOURCE "ALL")
  endif()
  add_custom_target(prepare_cross_compiling ${TD_ALWAYS_GENERATE_SOURCE} DEPENDS tl_generate_mtproto tl_generate_common tdmime_auto tl_generate_json)
  if (TD_ENABLE_DOTNET)
    add_custom_target(remove_cpp_documentation
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
      COMMAND remove_documentation ${TL_TD_API_AUTO_SOURCE} td/telegram/Client.h td/telegram/Log.h td/tl/TlObject.h
      COMMENT "Remove C++ documentation from sources"
      DEPENDS remove_documentation tl_generate_mtproto tl_generate_common generate_dotnet_api ${TL_TD_API_AUTO_SOURCE} td/telegram/Client.h td/telegram/Log.h td/tl/TlObject.h
    )

    add_dependencies(prepare_cross_compiling generate_dotnet_api remove_cpp_documentation)
  endif()
endif()

if (NOT OPENSSL_FOUND)
  if (NOT TD_GENERATE_SOURCE_FILES)
    message(WARNING "Can't find OpenSSL: stop TDLib building")
  endif()
  return()
endif()

if (NOT ZLIB_FOUND)
  find_package(ZLIB)
endif()
if (NOT ZLIB_FOUND)
  message(WARNING "Can't find zlib: stop TDLib building")
  return()
endif()

if (NOT TDUTILS_MIME_TYPE OR NOT TDUTILS_USE_EXTERNAL_DEPENDENCIES)
  message(WARNING "Option TDUTILS_MIME_TYPE and TDUTILS_USE_EXTERNAL_DEPENDENCIES must not be disabled: stop TDLib building")
  return()
endif()

set(TDACTOR_ENABLE_INSTALL ${TD_INSTALL_STATIC_LIBRARIES} CACHE BOOL "" FORCE)
add_subdirectory(tdactor)

set(TDNET_ENABLE_INSTALL ${TD_INSTALL_STATIC_LIBRARIES} CACHE BOOL "" FORCE)
add_subdirectory(tdnet)

set(TDSQLITE_ENABLE_INSTALL ${TD_INSTALL_STATIC_LIBRARIES} CACHE BOOL "" FORCE)
add_subdirectory(sqlite)

set(TDDB_ENABLE_INSTALL ${TD_INSTALL_STATIC_LIBRARIES} CACHE BOOL "" FORCE)
add_subdirectory(tddb)

if (BUILD_TESTING)
  add_subdirectory(test)
endif()

set(TDE2E_ENABLE_INSTALL ${TD_INSTALL_STATIC_LIBRARIES} CACHE BOOL "" FORCE)
add_subdirectory(tde2e)

if (NOT CMAKE_CROSSCOMPILING)
  add_subdirectory(benchmark)
endif()


get_directory_property(HAS_PARENT PARENT_DIRECTORY)
if (HAS_PARENT)
  set(TL_TD_JSON_AUTO ${TL_TD_JSON_AUTO_SOURCE} PARENT_SCOPE) # used in tdbot
  set(TD_TEST_SOURCE ${TD_TEST_SOURCE} PARENT_SCOPE) # used to build tests
endif()


# SOURCE SETS

set_source_files_properties(${TL_TD_API_AUTO_SOURCE} PROPERTIES GENERATED TRUE)
if (TD_ENABLE_JNI OR ANDROID)
  set(TL_JNI_OBJECT_SOURCE
    td/tl/tl_jni_object.cpp
    td/tl/tl_jni_object.h
  )
else()
  set(TL_JNI_OBJECT_SOURCE)
endif()

set(TL_TD_API_SOURCE
  ${TL_TD_API_AUTO_SOURCE}
  ${TL_JNI_OBJECT_SOURCE}
  td/tl/TlObject.h
)

set_source_files_properties(${TL_MTPROTO_AUTO_SOURCE} PROPERTIES GENERATED TRUE)

set_source_files_properties(${TL_TD_AUTO_SOURCE} PROPERTIES GENERATED TRUE)

set_source_files_properties(${TL_TD_JSON_AUTO_SOURCE} PROPERTIES GENERATED TRUE)
set(TL_TD_JSON_SOURCE
  ${TL_TD_JSON_AUTO_SOURCE}
  td/tl/tl_json.h
)

set_source_files_properties(${TL_C_AUTO_SOURCE} PROPERTIES GENERATED TRUE)
set(TL_C_SCHEME_SOURCE
  ${TL_C_AUTO_SOURCE}
)

set_source_files_properties(${TL_DOTNET_AUTO_SOURCE} PROPERTIES GENERATED TRUE)
set(TL_DOTNET_SCHEME_SOURCE
  ${TL_DOTNET_AUTO_SOURCE}
  td/tl/tl_dotnet_object.h
)

set(TD_MTPROTO_SOURCE
  td/mtproto/AuthData.cpp
  td/mtproto/ConnectionManager.cpp
  td/mtproto/DhHandshake.cpp
  td/mtproto/Handshake.cpp
  td/mtproto/HandshakeActor.cpp
  td/mtproto/HttpTransport.cpp
  td/mtproto/IStreamTransport.cpp
  td/mtproto/KDF.cpp
  td/mtproto/Ping.cpp
  td/mtproto/PingConnection.cpp
  td/mtproto/ProxySecret.cpp
  td/mtproto/RawConnection.cpp
  td/mtproto/RSA.cpp
  td/mtproto/SessionConnection.cpp
  td/mtproto/TcpTransport.cpp
  td/mtproto/TlsInit.cpp
  td/mtproto/TlsReaderByteFlow.cpp
  td/mtproto/Transport.cpp
  td/mtproto/utils.cpp

  td/mtproto/AuthData.h
  td/mtproto/AuthKey.h
  td/mtproto/ConnectionManager.h
  td/mtproto/CryptoStorer.h
  td/mtproto/DhCallback.h
  td/mtproto/DhHandshake.h
  td/mtproto/Handshake.h
  td/mtproto/HandshakeActor.h
  td/mtproto/HandshakeConnection.h
  td/mtproto/HttpTransport.h
  td/mtproto/IStreamTransport.h
  td/mtproto/KDF.h
  td/mtproto/MessageId.h
  td/mtproto/MtprotoQuery.h
  td/mtproto/NoCryptoStorer.h
  td/mtproto/PacketInfo.h
  td/mtproto/PacketStorer.h
  td/mtproto/Ping.h
  td/mtproto/PingConnection.h
  td/mtproto/ProxySecret.h
  td/mtproto/RawConnection.h
  td/mtproto/RSA.h
  td/mtproto/SessionConnection.h
  td/mtproto/TcpTransport.h
  td/mtproto/TlsInit.h
  td/mtproto/TlsReaderByteFlow.h
  td/mtproto/Transport.h
  td/mtproto/TransportType.h
  td/mtproto/utils.h

  ${TL_MTPROTO_AUTO_SOURCE}

  td/tl/TlObject.h
  td/tl/tl_object_parse.h
  td/tl/tl_object_store.h
)

set(TDLIB_SOURCE_PART1
  td/telegram/AccountManager.cpp
  td/telegram/AffiliateType.cpp
  td/telegram/AlarmManager.cpp
  td/telegram/AnimationsManager.cpp
  td/telegram/Application.cpp
  td/telegram/AttachMenuManager.cpp
  td/telegram/AudiosManager.cpp
  td/telegram/AuthManager.cpp
  td/telegram/AutoDownloadSettings.cpp
  td/telegram/AutosaveManager.cpp
  td/telegram/BackgroundInfo.cpp
  td/telegram/BackgroundManager.cpp
  td/telegram/BackgroundType.cpp
  td/telegram/BaseTheme.cpp
  td/telegram/Birthdate.cpp
  td/telegram/BoostManager.cpp
  td/telegram/BotCommand.cpp
  td/telegram/BotCommandScope.cpp
  td/telegram/BotInfoManager.cpp
  td/telegram/BotMenuButton.cpp
  td/telegram/BotQueries.cpp
  td/telegram/BotRecommendationManager.cpp
  td/telegram/BotVerification.cpp
  td/telegram/BotVerifierSettings.cpp
  td/telegram/BusinessAwayMessage.cpp
  td/telegram/BusinessAwayMessageSchedule.cpp
  td/telegram/BusinessBotManageBar.cpp
  td/telegram/BusinessChatLink.cpp
  td/telegram/BusinessConnectedBot.cpp
  td/telegram/BusinessConnectionManager.cpp
  td/telegram/BusinessGreetingMessage.cpp
  td/telegram/BusinessInfo.cpp
  td/telegram/BusinessIntro.cpp
  td/telegram/BusinessManager.cpp
  td/telegram/BusinessRecipients.cpp
  td/telegram/BusinessWorkHours.cpp
  td/telegram/CallActor.cpp
  td/telegram/CallbackQueriesManager.cpp
  td/telegram/CallDiscardReason.cpp
  td/telegram/CallManager.cpp
  td/telegram/ChannelParticipantFilter.cpp
  td/telegram/ChannelRecommendationManager.cpp
  td/telegram/ChatManager.cpp
  td/telegram/ChatReactions.cpp
  td/telegram/ClientActor.cpp
  td/telegram/CommonDialogManager.cpp
  td/telegram/ConfigManager.cpp
  td/telegram/ConnectionState.cpp
  td/telegram/ConnectionStateManager.cpp
  td/telegram/Contact.cpp
  td/telegram/CountryInfoManager.cpp
  td/telegram/DelayDispatcher.cpp
  td/telegram/Dependencies.cpp
  td/telegram/DeviceTokenManager.cpp
  td/telegram/DhCache.cpp
  td/telegram/DialogAction.cpp
  td/telegram/DialogActionBar.cpp
  td/telegram/DialogActionManager.cpp
  td/telegram/DialogAdministrator.cpp
  td/telegram/DialogDb.cpp
  td/telegram/DialogEventLog.cpp
  td/telegram/DialogFilter.cpp
  td/telegram/DialogFilterInviteLink.cpp
  td/telegram/DialogFilterManager.cpp
  td/telegram/DialogId.cpp
  td/telegram/DialogInviteLink.cpp
  td/telegram/DialogInviteLinkManager.cpp
  td/telegram/DialogLocation.cpp
  td/telegram/DialogManager.cpp
  td/telegram/DialogNotificationSettings.cpp
  td/telegram/DialogParticipant.cpp
  td/telegram/DialogParticipantFilter.cpp
  td/telegram/DialogParticipantManager.cpp
  td/telegram/DialogSource.cpp
  td/telegram/Dimensions.cpp
  td/telegram/Document.cpp
  td/telegram/DocumentsManager.cpp
  td/telegram/DownloadManager.cpp
  td/telegram/DownloadManagerCallback.cpp
  td/telegram/DraftMessage.cpp
  td/telegram/EmailVerification.cpp
  td/telegram/EmojiGroup.cpp
  td/telegram/EmojiGroupType.cpp
  td/telegram/EmojiStatus.cpp
  td/telegram/FactCheck.cpp
  td/telegram/FileReferenceManager.cpp
  td/telegram/files/FileBitmask.cpp
  td/telegram/files/FileDb.cpp
  td/telegram/files/FileDownloader.cpp
  td/telegram/files/FileDownloadManager.cpp
  td/telegram/files/FileEncryptionKey.cpp
  td/telegram/files/FileFromBytes.cpp
  td/telegram/files/FileGcParameters.cpp
  td/telegram/files/FileGcWorker.cpp
  td/telegram/files/FileGenerateManager.cpp
  td/telegram/files/FileHashUploader.cpp
  td/telegram/files/FileLoaderUtils.cpp
  td/telegram/files/FileLoadManager.cpp
  td/telegram/files/FileManager.cpp
  td/telegram/files/FileStats.cpp
  td/telegram/files/FileStatsWorker.cpp
  td/telegram/files/FileType.cpp
  td/telegram/files/FileUploader.cpp
  td/telegram/files/FileUploadManager.cpp
  td/telegram/files/PartsManager.cpp
  td/telegram/files/ResourceManager.cpp
  td/telegram/files/ResourceState.cpp
  td/telegram/ForumTopic.cpp
  td/telegram/ForumTopicEditedData.cpp
  td/telegram/ForumTopicIcon.cpp
  td/telegram/ForumTopicInfo.cpp
  td/telegram/ForumTopicManager.cpp
  td/telegram/Game.cpp
  td/telegram/GameManager.cpp
  td/telegram/GiveawayParameters.cpp
  td/telegram/Global.cpp
  td/telegram/GlobalPrivacySettings.cpp
  td/telegram/GroupCallManager.cpp
  td/telegram/GroupCallParticipant.cpp
  td/telegram/GroupCallParticipantOrder.cpp
  td/telegram/GroupCallVideoPayload.cpp
  td/telegram/HashtagHints.cpp
  td/telegram/InlineMessageManager.cpp
  td/telegram/InlineQueriesManager.cpp
  td/telegram/InputBusinessChatLink.cpp
  td/telegram/InputDialogId.cpp
  td/telegram/InputGroupCallId.cpp
  td/telegram/InputInvoice.cpp
  td/telegram/InputMessageText.cpp
  td/telegram/JsonValue.cpp
  td/telegram/LanguagePackManager.cpp
  td/telegram/LinkManager.cpp
  td/telegram/Location.cpp
  td/telegram/logevent/LogEventHelper.cpp
  td/telegram/Logging.cpp
  td/telegram/MediaArea.cpp
  td/telegram/MediaAreaCoordinates.cpp
  td/telegram/MessageContent.cpp
  td/telegram/MessageContentType.cpp
  td/telegram/MessageDb.cpp
  td/telegram/MessageEntity.cpp
  td/telegram/MessageExtendedMedia.cpp
  td/telegram/MessageForwardInfo.cpp
  td/telegram/MessageId.cpp
  td/telegram/MessageImportManager.cpp
  td/telegram/MessageInputReplyTo.cpp
  td/telegram/MessageOrigin.cpp
  td/telegram/MessageQueryManager.cpp
  td/telegram/MessageQuote.cpp
  td/telegram/MessageReaction.cpp
  td/telegram/MessageReactor.cpp
  td/telegram/MessageReplyHeader.cpp
  td/telegram/MessageReplyInfo.cpp
  td/telegram/MessageSearchFilter.cpp
  td/telegram/MessageSearchOffset.cpp
  td/telegram/MessageSelfDestructType.cpp
  td/telegram/MessageSender.cpp
  td/telegram/MessagesInfo.cpp
  td/telegram/MessagesManager.cpp
  td/telegram/MessageSource.cpp
  td/telegram/MessageThreadDb.cpp
  td/telegram/MessageTtl.cpp
  td/telegram/MessageViewer.cpp
  td/telegram/misc.cpp
  td/telegram/MissingInvitee.cpp
)
set(TDLIB_SOURCE_PART2
  td/telegram/net/AuthDataShared.cpp
  td/telegram/net/ConnectionCreator.cpp
  td/telegram/net/DcAuthManager.cpp
  td/telegram/net/DcOptionsSet.cpp
  td/telegram/net/MtprotoHeader.cpp
  td/telegram/net/NetActor.cpp
  td/telegram/net/NetQuery.cpp
  td/telegram/net/NetQueryCreator.cpp
  td/telegram/net/NetQueryDelayer.cpp
  td/telegram/net/NetQueryDispatcher.cpp
  td/telegram/net/NetQueryStats.cpp
  td/telegram/net/NetQueryVerifier.cpp
  td/telegram/net/NetStatsManager.cpp
  td/telegram/net/Proxy.cpp
  td/telegram/net/PublicRsaKeySharedCdn.cpp
  td/telegram/net/PublicRsaKeySharedMain.cpp
  td/telegram/net/PublicRsaKeyWatchdog.cpp
  td/telegram/net/Session.cpp
  td/telegram/net/SessionMultiProxy.cpp
  td/telegram/net/SessionProxy.cpp
  td/telegram/NewPasswordState.cpp
  td/telegram/NotificationGroupInfo.cpp
  td/telegram/NotificationGroupType.cpp
  td/telegram/NotificationManager.cpp
  td/telegram/NotificationSettingsManager.cpp
  td/telegram/NotificationSettingsScope.cpp
  td/telegram/NotificationSound.cpp
  td/telegram/NotificationType.cpp
  td/telegram/OnlineManager.cpp
  td/telegram/OptionManager.cpp
  td/telegram/OrderedMessage.cpp
  td/telegram/OrderInfo.cpp
  td/telegram/Outline.cpp
  td/telegram/PaidReactionType.cpp
  td/telegram/PasswordManager.cpp
  td/telegram/Payments.cpp
  td/telegram/PeerColor.cpp
  td/telegram/PeopleNearbyManager.cpp
  td/telegram/PhoneNumberManager.cpp
  td/telegram/Photo.cpp
  td/telegram/PhotoSize.cpp
  td/telegram/PhotoSizeSource.cpp
  td/telegram/PollManager.cpp
  td/telegram/Premium.cpp
  td/telegram/PremiumGiftOption.cpp
  td/telegram/PrivacyManager.cpp
  td/telegram/PromoDataManager.cpp
  td/telegram/QueryCombiner.cpp
  td/telegram/QueryMerger.cpp
  td/telegram/QuickReplyManager.cpp
  td/telegram/ReactionListType.cpp
  td/telegram/ReactionManager.cpp
  td/telegram/ReactionNotificationSettings.cpp
  td/telegram/ReactionNotificationsFrom.cpp
  td/telegram/ReactionType.cpp
  td/telegram/RecentDialogList.cpp
  td/telegram/ReferralProgramInfo.cpp
  td/telegram/ReferralProgramManager.cpp
  td/telegram/ReferralProgramParameters.cpp
  td/telegram/ReferralProgramSortOrder.cpp
  td/telegram/RepliedMessageInfo.cpp
  td/telegram/ReplyMarkup.cpp
  td/telegram/ReportReason.cpp
  td/telegram/RequestedDialogType.cpp
  td/telegram/Requests.cpp
  td/telegram/RestrictionReason.cpp
  td/telegram/SavedMessagesManager.cpp
  td/telegram/SavedMessagesTopicId.cpp
  td/telegram/ScopeNotificationSettings.cpp
  td/telegram/SecretChatActor.cpp
  td/telegram/SecretChatDb.cpp
  td/telegram/SecretChatsManager.cpp
  td/telegram/SecretInputMedia.cpp
  td/telegram/SecureManager.cpp
  td/telegram/SecureStorage.cpp
  td/telegram/SecureValue.cpp
  td/telegram/SendCodeHelper.cpp
  td/telegram/SentEmailCode.cpp
  td/telegram/SequenceDispatcher.cpp
  td/telegram/SharedDialog.cpp
  td/telegram/SpecialStickerSetType.cpp
  td/telegram/SponsoredMessageManager.cpp
  td/telegram/StarAmount.cpp
  td/telegram/StarGift.cpp
  td/telegram/StarGiftAttribute.cpp
  td/telegram/StarGiftId.cpp
  td/telegram/StarGiftManager.cpp
  td/telegram/StarManager.cpp
  td/telegram/StarSubscription.cpp
  td/telegram/StarSubscriptionPricing.cpp
  td/telegram/StateManager.cpp
  td/telegram/StatisticsManager.cpp
  td/telegram/StickerFormat.cpp
  td/telegram/StickerListType.cpp
  td/telegram/StickerMaskPosition.cpp
  td/telegram/StickerPhotoSize.cpp
  td/telegram/StickerSetId.cpp
  td/telegram/StickersManager.cpp
  td/telegram/StickerType.cpp
  td/telegram/StorageManager.cpp
  td/telegram/StoryContent.cpp
  td/telegram/StoryContentType.cpp
  td/telegram/StoryDb.cpp
  td/telegram/StoryForwardInfo.cpp
  td/telegram/StoryInteractionInfo.cpp
  td/telegram/StoryManager.cpp
  td/telegram/StoryStealthMode.cpp
  td/telegram/StoryViewer.cpp
  td/telegram/SuggestedAction.cpp
  td/telegram/SuggestedActionManager.cpp
  td/telegram/Support.cpp
  td/telegram/SynchronousRequests.cpp
  td/telegram/TargetDialogTypes.cpp
  td/telegram/Td.cpp
  td/telegram/TdDb.cpp
  td/telegram/TermsOfService.cpp
  td/telegram/TermsOfServiceManager.cpp
  td/telegram/ThemeManager.cpp
  td/telegram/ThemeSettings.cpp
  td/telegram/TimeZoneManager.cpp
  td/telegram/TopDialogCategory.cpp
  td/telegram/TopDialogManager.cpp
  td/telegram/TranscriptionInfo.cpp
  td/telegram/TranscriptionManager.cpp
  td/telegram/TranslationManager.cpp
  td/telegram/UpdatesManager.cpp
  td/telegram/UserManager.cpp
  td/telegram/Usernames.cpp
  td/telegram/UserPrivacySetting.cpp
  td/telegram/UserPrivacySettingRule.cpp
  td/telegram/UserStarGift.cpp
  td/telegram/Venue.cpp
  td/telegram/VerificationStatus.cpp
  td/telegram/VideoNotesManager.cpp
  td/telegram/VideosManager.cpp
  td/telegram/VoiceNotesManager.cpp
  td/telegram/WebApp.cpp
  td/telegram/WebAppManager.cpp
  td/telegram/WebAppOpenParameters.cpp
  td/telegram/WebPageBlock.cpp
  td/telegram/WebPagesManager.cpp

  td/telegram/AccentColorId.h
  td/telegram/AccessRights.h
  td/telegram/AccountManager.h
  td/telegram/AffectedHistory.h
  td/telegram/AffiliateType.h
  td/telegram/AlarmManager.h
  td/telegram/AnimationsManager.h
  td/telegram/Application.h
  td/telegram/AttachMenuManager.h
  td/telegram/AudiosManager.h
  td/telegram/AuthManager.h
  td/telegram/AutoDownloadSettings.h
  td/telegram/AutosaveManager.h
  td/telegram/BackgroundId.h
  td/telegram/BackgroundInfo.h
  td/telegram/BackgroundManager.h
  td/telegram/BackgroundType.h
  td/telegram/BaseTheme.h
  td/telegram/Birthdate.h
  td/telegram/BotVerification.h
  td/telegram/BotVerifierSettings.h
  td/telegram/BlockListId.h
  td/telegram/BoostManager.h
  td/telegram/BotCommand.h
  td/telegram/BotCommandScope.h
  td/telegram/BotInfoManager.h
  td/telegram/BotMenuButton.h
  td/telegram/BotQueries.h
  td/telegram/BotRecommendationManager.h
  td/telegram/BusinessAwayMessage.h
  td/telegram/BusinessAwayMessageSchedule.h
  td/telegram/BusinessBotManageBar.h
  td/telegram/BusinessChatLink.h
  td/telegram/BusinessConnectedBot.h
  td/telegram/BusinessConnectionId.h
  td/telegram/BusinessConnectionManager.h
  td/telegram/BusinessGreetingMessage.h
  td/telegram/BusinessInfo.h
  td/telegram/BusinessIntro.h
  td/telegram/BusinessManager.h
  td/telegram/BusinessRecipients.h
  td/telegram/BusinessWorkHours.h
  td/telegram/CallActor.h
  td/telegram/CallbackQueriesManager.h
  td/telegram/CallDiscardReason.h
  td/telegram/CallId.h
  td/telegram/CallManager.h
  td/telegram/ChainId.h
  td/telegram/ChannelId.h
  td/telegram/ChannelParticipantFilter.h
  td/telegram/ChannelRecommendationManager.h
  td/telegram/ChannelType.h
  td/telegram/ChatId.h
  td/telegram/ChatManager.h
  td/telegram/ChatReactions.h
  td/telegram/ClientActor.h
  td/telegram/CommonDialogManager.h
  td/telegram/ConfigManager.h
  td/telegram/ConnectionState.h
  td/telegram/ConnectionStateManager.h
  td/telegram/Contact.h
  td/telegram/CountryInfoManager.h
  td/telegram/CustomEmojiId.h
  td/telegram/DelayDispatcher.h
  td/telegram/Dependencies.h
  td/telegram/DeviceTokenManager.h
  td/telegram/DhCache.h
  td/telegram/DhConfig.h
  td/telegram/DialogAction.h
  td/telegram/DialogActionBar.h
  td/telegram/DialogActionManager.h
  td/telegram/DialogAdministrator.h
  td/telegram/DialogBoostLinkInfo.h
  td/telegram/DialogDate.h
  td/telegram/DialogDb.h
  td/telegram/DialogEventLog.h
  td/telegram/DialogFilter.h
  td/telegram/DialogFilterDialogInfo.h
  td/telegram/DialogFilterId.h
  td/telegram/DialogFilterInviteLink.h
  td/telegram/DialogFilterManager.h
  td/telegram/DialogId.h
  td/telegram/DialogInviteLink.h
  td/telegram/DialogInviteLinkManager.h
  td/telegram/DialogListId.h
  td/telegram/DialogLocation.h
  td/telegram/DialogManager.h
  td/telegram/DialogNotificationSettings.h
  td/telegram/DialogParticipant.h
  td/telegram/DialogParticipantFilter.h
  td/telegram/DialogParticipantManager.h
  td/telegram/DialogSource.h
  td/telegram/Dimensions.h
  td/telegram/Document.h
  td/telegram/DocumentsManager.h
  td/telegram/DownloadManager.h
  td/telegram/DownloadManagerCallback.h
  td/telegram/DraftMessage.h
  td/telegram/EmailVerification.h
  td/telegram/EmojiGroup.h
  td/telegram/EmojiGroupType.h
  td/telegram/EmojiStatus.h
  td/telegram/EncryptedFile.h
  td/telegram/FactCheck.h
  td/telegram/FileReferenceManager.h
  td/telegram/files/FileBitmask.h
  td/telegram/files/FileData.h
  td/telegram/files/FileDb.h
  td/telegram/files/FileDbId.h
  td/telegram/files/FileDownloader.h
  td/telegram/files/FileDownloadManager.h
  td/telegram/files/FileEncryptionKey.h
  td/telegram/files/FileFromBytes.h
  td/telegram/files/FileGcParameters.h
  td/telegram/files/FileGcWorker.h
  td/telegram/files/FileGenerateManager.h
  td/telegram/files/FileHashUploader.h
  td/telegram/files/FileId.h
  td/telegram/files/FileLoaderActor.h
  td/telegram/files/FileLoaderUtils.h
  td/telegram/files/FileLoadManager.h
  td/telegram/files/FileLocation.h
  td/telegram/files/FileManager.h
  td/telegram/files/FileSourceId.h
  td/telegram/files/FileStats.h
  td/telegram/files/FileStatsWorker.h
  td/telegram/files/FileType.h
  td/telegram/files/FileUploader.h
  td/telegram/files/FileUploadId.h
  td/telegram/files/FileUploadManager.h
  td/telegram/files/PartsManager.h
  td/telegram/files/ResourceManager.h
  td/telegram/files/ResourceState.h
  td/telegram/FolderId.h
  td/telegram/ForumTopic.h
  td/telegram/ForumTopicEditedData.h
  td/telegram/ForumTopicIcon.h
  td/telegram/ForumTopicInfo.h
  td/telegram/ForumTopicManager.h
  td/telegram/Game.h
  td/telegram/GameManager.h
  td/telegram/GitCommitHash.h
  td/telegram/GiveawayParameters.h
  td/telegram/Global.h
  td/telegram/GlobalPrivacySettings.h
  td/telegram/GroupCallId.h
  td/telegram/GroupCallManager.h
  td/telegram/GroupCallParticipant.h
  td/telegram/GroupCallParticipantOrder.h
  td/telegram/GroupCallVideoPayload.h
  td/telegram/HashtagHints.h
  td/telegram/InlineMessageManager.h
  td/telegram/InlineQueriesManager.h
  td/telegram/InputBusinessChatLink.h
  td/telegram/InputDialogId.h
  td/telegram/InputGroupCallId.h
  td/telegram/InputInvoice.h
  td/telegram/InputMessageText.h
  td/telegram/JsonValue.h
  td/telegram/LabeledPricePart.h
  td/telegram/LanguagePackManager.h
  td/telegram/LinkManager.h
  td/telegram/Location.h
  td/telegram/logevent/LogEvent.h
  td/telegram/logevent/LogEventHelper.h
  td/telegram/logevent/SecretChatEvent.h
  td/telegram/Logging.h
  td/telegram/MediaArea.h
  td/telegram/MediaAreaCoordinates.h
  td/telegram/MessageContent.h
  td/telegram/MessageContentType.h
  td/telegram/MessageCopyOptions.h
  td/telegram/MessageDb.h
  td/telegram/MessageEffectId.h
  td/telegram/MessageEntity.h
  td/telegram/MessageExtendedMedia.h
  td/telegram/MessageForwardInfo.h
  td/telegram/MessageFullId.h
  td/telegram/MessageId.h
  td/telegram/MessageImportManager.h
  td/telegram/MessageInputReplyTo.h
  td/telegram/MessageLinkInfo.h
  td/telegram/MessageOrigin.h
  td/telegram/MessageQueryManager.h
  td/telegram/MessageQuote.h
  td/telegram/MessageReaction.h
  td/telegram/MessageReactor.h
  td/telegram/MessageReplyHeader.h
  td/telegram/MessageReplyInfo.h
  td/telegram/MessageSearchFilter.h
  td/telegram/MessageSearchOffset.h
  td/telegram/MessageSelfDestructType.h
  td/telegram/MessageSender.h
  td/telegram/MessagesInfo.h
  td/telegram/MessagesManager.h
  td/telegram/MessageSource.h
  td/telegram/MessageThreadDb.h
  td/telegram/MessageThreadInfo.h
  td/telegram/MessageTtl.h
  td/telegram/MessageViewer.h
  td/telegram/MinChannel.h
  td/telegram/misc.h
  td/telegram/MissingInvitee.h
  td/telegram/net/AuthDataShared.h
  td/telegram/net/AuthKeyState.h
  td/telegram/net/ConnectionCreator.h
  td/telegram/net/DcAuthManager.h
  td/telegram/net/DcId.h
  td/telegram/net/DcOptions.h
  td/telegram/net/DcOptionsSet.h
  td/telegram/net/MtprotoHeader.h
  td/telegram/net/NetActor.h
  td/telegram/net/NetQuery.h
  td/telegram/net/NetQueryCounter.h
  td/telegram/net/NetQueryCreator.h
  td/telegram/net/NetQueryDelayer.h
  td/telegram/net/NetQueryDispatcher.h
  td/telegram/net/NetQueryStats.h
  td/telegram/net/NetQueryVerifier.h
  td/telegram/net/NetStatsManager.h
  td/telegram/net/NetType.h
  td/telegram/net/Proxy.h
  td/telegram/net/PublicRsaKeySharedCdn.h
  td/telegram/net/PublicRsaKeySharedMain.h
  td/telegram/net/PublicRsaKeyWatchdog.h
  td/telegram/net/Session.h
  td/telegram/net/SessionMultiProxy.h
  td/telegram/net/SessionProxy.h
  td/telegram/net/TempAuthKeyWatchdog.h
  td/telegram/NewPasswordState.h
  td/telegram/Notification.h
  td/telegram/NotificationGroupFromDatabase.h
  td/telegram/NotificationGroupId.h
  td/telegram/NotificationGroupInfo.h
  td/telegram/NotificationGroupKey.h
  td/telegram/NotificationGroupType.h
  td/telegram/NotificationId.h
  td/telegram/NotificationManager.h
  td/telegram/NotificationObjectFullId.h
  td/telegram/NotificationObjectId.h
  td/telegram/NotificationSettingsManager.h
  td/telegram/NotificationSettingsScope.h
  td/telegram/NotificationSound.h
  td/telegram/NotificationSoundType.h
  td/telegram/NotificationType.h
  td/telegram/OnlineManager.h
  td/telegram/OptionManager.h
  td/telegram/OrderedMessage.h
  td/telegram/OrderInfo.h
  td/telegram/Outline.h
  td/telegram/PaidReactionType.h
  td/telegram/PasswordManager.h
  td/telegram/Payments.h
  td/telegram/PeerColor.h
  td/telegram/PeopleNearbyManager.h
  td/telegram/PhoneNumberManager.h
  td/telegram/Photo.h
  td/telegram/PhotoFormat.h
  td/telegram/PhotoSize.h
  td/telegram/PhotoSizeSource.h
  td/telegram/PhotoSizeType.h
  td/telegram/PollId.h
  td/telegram/PollManager.h
  td/telegram/Premium.h
  td/telegram/PremiumGiftOption.h
  td/telegram/PrivacyManager.h
  td/telegram/PromoDataManager.h
  td/telegram/PtsManager.h
  td/telegram/PublicDialogType.h
  td/telegram/QueryCombiner.h
  td/telegram/QueryMerger.h
  td/telegram/QuickReplyManager.h
  td/telegram/QuickReplyMessageFullId.h
  td/telegram/QuickReplyShortcutId.h
  td/telegram/ReactionListType.h
  td/telegram/ReactionManager.h
  td/telegram/ReactionNotificationSettings.h
  td/telegram/ReactionNotificationsFrom.h
  td/telegram/ReactionType.h
  td/telegram/ReactionUnavailabilityReason.h
  td/telegram/RecentDialogList.h
  td/telegram/ReferralProgramInfo.h
  td/telegram/ReferralProgramManager.h
  td/telegram/ReferralProgramParameters.h
  td/telegram/ReferralProgramSortOrder.h
  td/telegram/RepliedMessageInfo.h
  td/telegram/ReplyMarkup.h
  td/telegram/ReportReason.h
  td/telegram/RequestActor.h
  td/telegram/RequestedDialogType.h
  td/telegram/Requests.h
  td/telegram/RestrictionReason.h
  td/telegram/SavedMessagesManager.h
  td/telegram/SavedMessagesTopicId.h
  td/telegram/ScheduledServerMessageId.h
  td/telegram/ScopeNotificationSettings.h
  td/telegram/SecretChatActor.h
  td/telegram/SecretChatDb.h
  td/telegram/SecretChatId.h
  td/telegram/SecretChatLayer.h
  td/telegram/SecretChatsManager.h
  td/telegram/SecretInputMedia.h
  td/telegram/SecureManager.h
  td/telegram/SecureStorage.h
  td/telegram/SecureValue.h
  td/telegram/SendCodeHelper.h
  td/telegram/SentEmailCode.h
  td/telegram/SequenceDispatcher.h
  td/telegram/ServerMessageId.h
  td/telegram/SetWithPosition.h
  td/telegram/SharedDialog.h
  td/telegram/SpecialStickerSetType.h
  td/telegram/SponsoredMessageManager.h
  td/telegram/StarAmount.h
  td/telegram/StarGift.h
  td/telegram/StarGiftAttribute.h
  td/telegram/StarGiftId.h
  td/telegram/StarGiftManager.h
  td/telegram/StarManager.h
  td/telegram/StarSubscription.h
  td/telegram/StarSubscriptionPricing.h
  td/telegram/StateManager.h
  td/telegram/StatisticsManager.h
  td/telegram/StickerFormat.h
  td/telegram/StickerListType.h
  td/telegram/StickerMaskPosition.h
  td/telegram/StickerPhotoSize.h
  td/telegram/StickerSetId.h
  td/telegram/StickersManager.h
  td/telegram/StickerType.h
  td/telegram/StorageManager.h
  td/telegram/StoryContent.h
  td/telegram/StoryContentType.h
  td/telegram/StoryDb.h
  td/telegram/StoryForwardInfo.h
  td/telegram/StoryFullId.h
  td/telegram/StoryId.h
  td/telegram/StoryInteractionInfo.h
  td/telegram/StoryListId.h
  td/telegram/StoryManager.h
  td/telegram/StoryNotificationSettings.h
  td/telegram/StoryStealthMode.h
  td/telegram/StoryViewer.h
  td/telegram/SuggestedAction.h
  td/telegram/SuggestedActionManager.h
  td/telegram/Support.h
  td/telegram/SynchronousRequests.h
  td/telegram/TargetDialogTypes.h
  td/telegram/Td.h
  td/telegram/TdCallback.h
  td/telegram/TdDb.h
  td/telegram/TermsOfService.h
  td/telegram/TermsOfServiceManager.h
  td/telegram/ThemeManager.h
  td/telegram/ThemeSettings.h
  td/telegram/TimeZoneManager.h
  td/telegram/TopDialogCategory.h
  td/telegram/TopDialogManager.h
  td/telegram/TranscriptionInfo.h
  td/telegram/TranscriptionManager.h
  td/telegram/TranslationManager.h
  td/telegram/UniqueId.h
  td/telegram/UpdatesManager.h
  td/telegram/UserId.h
  td/telegram/UserManager.h
  td/telegram/Usernames.h
  td/telegram/UserPrivacySetting.h
  td/telegram/UserPrivacySettingRule.h
  td/telegram/UserStarGift.h
  td/telegram/Venue.h
  td/telegram/VerificationStatus.h
  td/telegram/Version.h
  td/telegram/VideoNotesManager.h
  td/telegram/VideosManager.h
  td/telegram/VoiceNotesManager.h
  td/telegram/WebApp.h
  td/telegram/WebAppManager.h
  td/telegram/WebAppOpenParameters.h
  td/telegram/WebPageBlock.h
  td/telegram/WebPageId.h
  td/telegram/WebPagesManager.h

  td/telegram/AnimationsManager.hpp
  td/telegram/AudiosManager.hpp
  td/telegram/AuthManager.hpp
  td/telegram/BackgroundInfo.hpp
  td/telegram/BackgroundType.hpp
  td/telegram/Birthdate.hpp
  td/telegram/BotVerification.hpp
  td/telegram/BotVerifierSettings.hpp
  td/telegram/BusinessAwayMessage.hpp
  td/telegram/BusinessAwayMessageSchedule.hpp
  td/telegram/BusinessConnectedBot.hpp
  td/telegram/BusinessGreetingMessage.hpp
  td/telegram/BusinessInfo.hpp
  td/telegram/BusinessIntro.hpp
  td/telegram/BusinessRecipients.hpp
  td/telegram/BusinessWorkHours.hpp
  td/telegram/ChatReactions.hpp
  td/telegram/DialogFilter.hpp
  td/telegram/DialogInviteLink.hpp
  td/telegram/DialogNotificationSettings.hpp
  td/telegram/Dimensions.hpp
  td/telegram/Document.hpp
  td/telegram/DocumentsManager.hpp
  td/telegram/DraftMessage.hpp
  td/telegram/EmojiGroup.hpp
  td/telegram/FactCheck.hpp
  td/telegram/FileReferenceManager.hpp
  td/telegram/files/FileData.hpp
  td/telegram/files/FileId.hpp
  td/telegram/files/FileLocation.hpp
  td/telegram/files/FileManager.hpp
  td/telegram/files/FileSourceId.hpp
  td/telegram/ForumTopic.hpp
  td/telegram/ForumTopicEditedData.hpp
  td/telegram/ForumTopicIcon.hpp
  td/telegram/ForumTopicInfo.hpp
  td/telegram/Game.hpp
  td/telegram/GiveawayParameters.hpp
  td/telegram/InputInvoice.hpp
  td/telegram/InputMessageText.hpp
  td/telegram/MediaArea.hpp
  td/telegram/MediaAreaCoordinates.hpp
  td/telegram/MessageEntity.hpp
  td/telegram/MessageExtendedMedia.hpp
  td/telegram/MessageForwardInfo.hpp
  td/telegram/MessageInputReplyTo.hpp
  td/telegram/MessageOrigin.hpp
  td/telegram/MessageQuote.hpp
  td/telegram/MessageReaction.hpp
  td/telegram/MessageReactor.hpp
  td/telegram/MessageReplyInfo.hpp
  td/telegram/MinChannel.hpp
  td/telegram/NotificationGroupInfo.hpp
  td/telegram/OrderInfo.hpp
  td/telegram/PaidReactionType.hpp
  td/telegram/Photo.hpp
  td/telegram/PhotoSize.hpp
  td/telegram/PhotoSizeSource.hpp
  td/telegram/PhotoSizeType.hpp
  td/telegram/PollId.hpp
  td/telegram/PollManager.hpp
  td/telegram/PremiumGiftOption.hpp
  td/telegram/ReactionManager.hpp
  td/telegram/ReactionNotificationSettings.hpp
  td/telegram/ReactionNotificationsFrom.hpp
  td/telegram/ReactionType.hpp
  td/telegram/ReferralProgramInfo.hpp
  td/telegram/ReferralProgramParameters.hpp
  td/telegram/RepliedMessageInfo.hpp
  td/telegram/ReplyMarkup.hpp
  td/telegram/RequestedDialogType.hpp
  td/telegram/ScopeNotificationSettings.hpp
  td/telegram/SecureValue.hpp
  td/telegram/SendCodeHelper.hpp
  td/telegram/SharedDialog.hpp
  td/telegram/StarAmount.hpp
  td/telegram/StarGift.hpp
  td/telegram/StarGiftAttribute.hpp
  td/telegram/StarGiftId.hpp
  td/telegram/StarSubscriptionPricing.hpp
  td/telegram/StickerMaskPosition.hpp
  td/telegram/StickerPhotoSize.hpp
  td/telegram/StickersManager.hpp
  td/telegram/StoryForwardInfo.hpp
  td/telegram/StoryInteractionInfo.hpp
  td/telegram/StoryStealthMode.hpp
  td/telegram/SuggestedAction.hpp
  td/telegram/TermsOfService.hpp
  td/telegram/ThemeSettings.hpp
  td/telegram/TranscriptionInfo.hpp
  td/telegram/VideoNotesManager.hpp
  td/telegram/VideosManager.hpp
  td/telegram/VoiceNotesManager.hpp
  td/telegram/WebApp.hpp

  ${TL_TD_AUTO_SOURCE}

  td/tl/TlObject.h
  td/tl/tl_object_parse.h
  td/tl/tl_object_store.h

  ${CMAKE_CURRENT_BINARY_DIR}/td/telegram/GitCommitHash.cpp
)
set(TDLIB_SOURCE
  ${TDLIB_SOURCE_PART1}
  ${TDLIB_SOURCE_PART2}
)

set(MEMPROF_SOURCE
  memprof/memprof.cpp
  memprof/memprof.h
)

set(MEMPROF_STAT_SOURCE
  memprof/memprof_stat.cpp
  memprof/memprof_stat.h
)

# LIBRARIES

# memprof - simple library for memory usage profiling
add_library(memprof STATIC ${MEMPROF_SOURCE})
target_include_directories(memprof PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(memprof PRIVATE tdutils)
if (MEMPROF)
  target_compile_definitions(memprof PRIVATE -DUSE_MEMPROF=1)
  if (MEMPROF STREQUAL "SAFE")
    target_compile_definitions(memprof PRIVATE -DUSE_MEMPROF_SAFE=1)
  elseif (MEMPROF STREQUAL "FAST")
    target_compile_definitions(memprof PRIVATE -DUSE_MEMPROF_FAST=1)
  elseif (NOT MEMPROF)
    message(FATAL_ERROR "Unsupported MEMPROF value \"${MEMPROF}\"")
  endif()
endif()

add_library(memprof_stat EXCLUDE_FROM_ALL STATIC ${MEMPROF_STAT_SOURCE})
target_include_directories(memprof_stat PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(memprof_stat PRIVATE tdutils)


add_library(tdapi STATIC ${TL_TD_API_SOURCE})
target_include_directories(tdapi PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}> INTERFACE $<BUILD_INTERFACE:${TL_TD_AUTO_INCLUDE_DIR}>)
target_link_libraries(tdapi PRIVATE tdutils)

if (TD_ENABLE_JNI AND NOT ANDROID) # jni is available by default on Android
  if (NOT JNI_FOUND)
    find_package(JNI REQUIRED COMPONENTS JVM)
  endif()
  message(STATUS "Found JNI: ${JNI_INCLUDE_DIRS} ${JNI_LIBRARIES}")
  target_include_directories(tdapi PUBLIC ${JAVA_INCLUDE_PATH} ${JAVA_INCLUDE_PATH2})
  target_link_libraries(tdapi PUBLIC ${JAVA_JVM_LIBRARY})
endif()

if (NOT CMAKE_CROSSCOMPILING)
  add_dependencies(tdapi tl_generate_common)
endif()

add_library(tdmtproto STATIC ${TD_MTPROTO_SOURCE})
target_include_directories(tdmtproto PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}> $<BUILD_INTERFACE:${TL_TD_AUTO_INCLUDE_DIR}>)
target_include_directories(tdmtproto SYSTEM PRIVATE ${OPENSSL_INCLUDE_DIR})
target_link_libraries(tdmtproto PUBLIC tdactor tdnet tdutils PRIVATE ${OPENSSL_CRYPTO_LIBRARY} ${CMAKE_DL_LIBS} ${ZLIB_LIBRARIES})
if (WIN32)
  if (MINGW)
    target_link_libraries(tdmtproto PRIVATE ws2_32 mswsock crypt32)
  else()
    target_link_libraries(tdmtproto PRIVATE ws2_32 Mswsock Crypt32)
  endif()
endif()
if (NOT CMAKE_CROSSCOMPILING)
  add_dependencies(tdmtproto tl_generate_mtproto)
endif()

# tdcore - internal TDLib interface
if (MSVC AND TD_ENABLE_LTO)
  add_library(tdcore_part1 STATIC ${TDLIB_SOURCE_PART1})
  target_include_directories(tdcore_part1 PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}> $<BUILD_INTERFACE:${TL_TD_AUTO_INCLUDE_DIR}>)
  target_link_libraries(tdcore_part1 PUBLIC tdapi tdnet tddb tdactor tde2e tdutils PRIVATE tdmtproto)

  add_library(tdcore_part2 STATIC ${TDLIB_SOURCE_PART2})
  target_include_directories(tdcore_part2 PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}> $<BUILD_INTERFACE:${TL_TD_AUTO_INCLUDE_DIR}>)
  target_link_libraries(tdcore_part2 PUBLIC tdapi tdnet tddb tdactor tde2e tdutils PRIVATE tdmtproto)

  add_library(tdcore INTERFACE)
  target_link_libraries(tdcore INTERFACE tdcore_part1 tdcore_part2)

  set(TD_CORE_PART_TARGETS tdcore_part1 tdcore_part2)
else()
  add_library(tdcore STATIC ${TDLIB_SOURCE})
  target_include_directories(tdcore PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}> $<BUILD_INTERFACE:${TL_TD_AUTO_INCLUDE_DIR}>)
  target_link_libraries(tdcore PUBLIC tdapi tdnet tddb tdactor tde2e tdutils PRIVATE tdmtproto)

  set(TD_CORE_PART_TARGETS)
endif()

if (NOT CMAKE_CROSSCOMPILING)
  add_dependencies(tdcore tl_generate_common)
  if (TD_ENABLE_JNI)
    add_dependencies(tdcore td_generate_java_api)
  endif()
  if (TD_ENABLE_DOTNET)
    add_dependencies(tdcore remove_cpp_documentation)
  endif()
endif()

add_library(tdclient STATIC td/telegram/Client.cpp td/telegram/Client.h td/telegram/Log.cpp td/telegram/Log.h)
target_include_directories(tdclient PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
)
target_link_libraries(tdclient PUBLIC tdapi PRIVATE tdcore)

if (TD_ENABLE_DOTNET)
  add_library(tddotnet SHARED
    td/telegram/ClientDotNet.cpp
    td/telegram/LogDotNet.cpp
    ${TL_DOTNET_SCHEME_SOURCE}
  )
  set_target_properties(tddotnet PROPERTIES OUTPUT_NAME Telegram.Td)
  target_link_libraries(tddotnet PRIVATE tdclient tdutils)
  target_include_directories(tddotnet PUBLIC
    $<BUILD_INTERFACE:${TL_TD_AUTO_INCLUDE_DIR}>
  )
  if (NOT CMAKE_CROSSCOMPILING)
    add_dependencies(tddotnet generate_dotnet_api)
  endif()

  target_compile_options(tddotnet PRIVATE "/doc")
  if (CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
    set_target_properties(tddotnet PROPERTIES VS_WINRT_COMPONENT "true")
    target_compile_options(tddotnet PUBLIC "/ZW")
  else()
    set_target_properties(tddotnet PROPERTIES COMPILE_FLAGS "/GR /clr")
    target_compile_options(tddotnet PUBLIC "/EHa")
  endif()
endif()

# tdc - TDLib interface in pure C
add_library(tdc STATIC EXCLUDE_FROM_ALL ${TL_C_SCHEME_SOURCE} td/telegram/td_c_client.cpp td/telegram/td_c_client.h)
target_include_directories(tdc PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<BUILD_INTERFACE:${TL_TD_AUTO_INCLUDE_DIR}>)
target_link_libraries(tdc PRIVATE tdclient tdutils)
if (NOT CMAKE_CROSSCOMPILING)
  add_dependencies(tdc tl_generate_c)
endif()

add_library(tdjson_private STATIC ${TL_TD_JSON_SOURCE} td/telegram/ClientJson.cpp td/telegram/ClientJson.h)
target_include_directories(tdjson_private PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<BUILD_INTERFACE:${TL_TD_AUTO_INCLUDE_DIR}>)
target_link_libraries(tdjson_private PUBLIC tdclient tdutils)
if (NOT CMAKE_CROSSCOMPILING)
  add_dependencies(tdjson_private tl_generate_common tl_generate_json)
  if (TD_ENABLE_DOTNET)
    add_dependencies(tdjson_private remove_cpp_documentation)
  endif()
endif()

set(TD_JSON_HEADERS td/telegram/td_json_client.h td/telegram/td_log.h)
set(TD_JSON_SOURCE td/telegram/td_json_client.cpp td/telegram/td_log.cpp)

include(GenerateExportHeader)

add_library(tdjson SHARED ${TD_JSON_SOURCE} ${TD_JSON_HEADERS})
target_link_libraries(tdjson PRIVATE tdjson_private)
generate_export_header(tdjson EXPORT_FILE_NAME ${CMAKE_CURRENT_BINARY_DIR}/td/telegram/tdjson_export.h)
target_include_directories(tdjson PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
if (APPLE)
  set_target_properties(tdjson PROPERTIES LINK_FLAGS "-Wl,-exported_symbols_list,${CMAKE_CURRENT_SOURCE_DIR}/tdclientjson_export_list")
endif()

add_library(tdjson_static STATIC ${TD_JSON_SOURCE} ${TD_JSON_HEADERS})
target_link_libraries(tdjson_static PRIVATE tdjson_private)
target_compile_definitions(tdjson_static PUBLIC TDJSON_STATIC_DEFINE)
target_include_directories(tdjson_static PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)

# EXECUTABLES
if (EMSCRIPTEN)
  set(TD_EMSCRIPTEN_SRC td/telegram/td_emscripten.cpp)
  add_executable(${TD_EMSCRIPTEN} ${TD_EMSCRIPTEN_SRC})
  target_include_directories(${TD_EMSCRIPTEN} PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
  target_link_libraries(${TD_EMSCRIPTEN} PRIVATE tdjson_static tdactor)
endif()

if (NOT CMAKE_CROSSCOMPILING)
  add_executable(tg_cli td/telegram/cli.cpp ${TL_TD_JSON_SOURCE})

  if (NOT READLINE_FOUND)
    find_package(Readline QUIET)
  endif()
  if (READLINE_FOUND)
    message(STATUS "Found Readline: ${READLINE_INCLUDE_DIR} ${READLINE_LIBRARY}")
    if (NOT USABLE_READLINE_FOUND)
      set(CMAKE_REQUIRED_INCLUDES "${READLINE_INCLUDE_DIR}")
      set(CMAKE_REQUIRED_LIBRARIES "${READLINE_LIBRARY}")
      include(CheckCXXSourceCompiles)
      unset(USABLE_READLINE_FOUND CACHE)
      check_cxx_source_compiles("#include <stdio.h>\n#include <readline/readline.h>\nint main() { rl_free(0); }" USABLE_READLINE_FOUND)
      if (NOT USABLE_READLINE_FOUND)
        message(STATUS "Found Readline is too old, ignore it (this is NOT an error)")
        unset(READLINE_INCLUDE_DIR CACHE)
        unset(READLINE_LIBRARY CACHE)
      endif()
    endif()
    if (USABLE_READLINE_FOUND)
      target_link_libraries(tg_cli PRIVATE ${READLINE_LIBRARY})
      target_include_directories(tg_cli SYSTEM PRIVATE ${READLINE_INCLUDE_DIR})
      target_compile_definitions(tg_cli PRIVATE -DUSE_READLINE=1)
    endif()
  endif()
  target_link_libraries(tg_cli PRIVATE memprof tdclient tdcore)
  add_dependencies(tg_cli tl_generate_json)
endif()

# Exported libraries
add_library(TdStatic INTERFACE)
target_link_libraries(TdStatic INTERFACE tdclient)

add_library(TdJson INTERFACE)
target_link_libraries(TdJson INTERFACE tdjson)

add_library(TdJsonStatic INTERFACE)
target_link_libraries(TdJsonStatic INTERFACE tdjson_static)

add_library(Td::TdStatic ALIAS TdStatic)
add_library(Td::TdJson ALIAS TdJson)
add_library(Td::TdJsonStatic ALIAS TdJsonStatic)

set(INSTALL_TARGETS tdjson TdJson)
set(INSTALL_STATIC_TARGETS tdjson_static TdJsonStatic tdjson_private "${TD_CORE_PART_TARGETS}" tdcore tdmtproto tdclient TdStatic tdapi)

if (TD_INSTALL_SHARED_LIBRARIES)
  install(TARGETS ${INSTALL_TARGETS} EXPORT TdTargets
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
    INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
  )
endif()

if (TD_INSTALL_STATIC_LIBRARIES)
  install(TARGETS ${INSTALL_STATIC_TARGETS} EXPORT TdStaticTargets
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
  )
endif()

# generate pkg-config files
include(GeneratePkgConfig)

if (TD_INSTALL_STATIC_LIBRARIES)
  generate_pkgconfig(tdutils "Telegram Library - Utils")
  generate_pkgconfig(tdactor "Telegram Library - Actor")
  generate_pkgconfig(tde2e "Telegram Library - E2E")
  generate_pkgconfig(tdnet "Telegram Library - Net")
  generate_pkgconfig(tdsqlite "Telegram Library - SQLite")
  generate_pkgconfig(tddb "Telegram Library - Database")
  if (MEMPROF)
    # generate_pkgconfig(memprof "memprof - simple library for memory usage profiling")
  endif()
  generate_pkgconfig(tdmtproto "Telegram Library - MTProto implementation")
  generate_pkgconfig(tdcore "Telegram Library - Core")
  generate_pkgconfig(tdclient "Telegram Library - C++ Interface")
  if (TD_ENABLE_DOTNET)
    # generate_pkgconfig(tddotnet "Telegram Library - C# Interface")
  endif()
  # generate_pkgconfig(tdc "Telegram Library - C interface")
  generate_pkgconfig(tdapi "Telegram Library - API")
  generate_pkgconfig(tdjson_private "Telegram Library - JSON interface (private)")
  generate_pkgconfig(tdjson_static "Telegram Library - JSON interface (static)")
endif()
if (TD_INSTALL_SHARED_LIBRARIES)
  generate_pkgconfig(tdjson "Telegram Library - JSON interface (shared)")
endif()

if (TD_INSTALL_SHARED_LIBRARIES)
  install(EXPORT TdTargets
    FILE TdTargets.cmake
    NAMESPACE Td::
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/Td"
  )
endif()

if (TD_INSTALL_STATIC_LIBRARIES)
  install(EXPORT TdStaticTargets
    FILE TdStaticTargets.cmake
    NAMESPACE Td::
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/Td"
  )
endif()

if (TD_INSTALL_SHARED_LIBRARIES OR TD_INSTALL_STATIC_LIBRARIES)
  # Install tdjson/tdjson_static:
  install(FILES ${TD_JSON_HEADERS} "${CMAKE_CURRENT_BINARY_DIR}/td/telegram/tdjson_export.h" DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/td/telegram")
endif()
if (TD_INSTALL_STATIC_LIBRARIES)
  # Install tdclient:
  install(FILES td/telegram/Client.h td/telegram/Log.h DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/td/telegram")
  # Install tdapi:
  install(FILES td/tl/TlObject.h DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/td/tl")
  install(FILES "${TL_TD_AUTO_INCLUDE_DIR}/td/telegram/td_api.h" "${TL_TD_AUTO_INCLUDE_DIR}/td/telegram/td_api.hpp" DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/td/telegram")
endif()
if (TD_ENABLE_JNI)
  install(FILES td/tl/tl_jni_object.h DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/td/tl")
endif()
if (MSVC AND VCPKG_TOOLCHAIN)
  install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/" DESTINATION "${CMAKE_INSTALL_BINDIR}" FILES_MATCHING PATTERN "*.dll")
endif()

include(CMakePackageConfigHelpers)
write_basic_package_version_file("TdConfigVersion.cmake"
  VERSION "${TDLib_VERSION}"
  COMPATIBILITY ExactVersion
)
install(FILES "TdConfig.cmake" "${CMAKE_CURRENT_BINARY_DIR}/TdConfigVersion.cmake"
  DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/Td"
)

# Add SOVERSION to shared libraries
set_property(TARGET tdjson PROPERTY SOVERSION "${TDLib_VERSION}")
