<?php

function disjoint_set_find(&$parents, $x) {
    if ($parents[$x] !== $x) {
        return $parents[$x] = disjoint_set_find($parents, $parents[$x]);
    }
    return $x;
}

function disjoint_set_union(&$parents, $x, $y) {
    $x = disjoint_set_find($parents, $x);
    $y = disjoint_set_find($parents, $y);

    if ($x !== $y) {
        if (rand(0, 1) == 0) {
            $parents[$x] = $y;
        } else {
            $parents[$y] = $x;
        }
    }
}

function split_file($file, $chunks, $undo) {
    $cpp_name = "$file.cpp";

    echo "Processing file $cpp_name".PHP_EOL;

    $new_files = array();
    foreach (range(0, $chunks - 1) as $n) {
        $new_files[] = "$file$n.cpp";
    }

    $is_generated = (strpos($file, 'td/generate/') === 0);

    $cmake_file = $is_generated ? 'td/generate/CMakeLists.txt' : 'CMakeLists.txt';
    $cmake = file_get_contents($cmake_file);

    $cmake_cpp_name = $cpp_name;
    $cmake_new_files = $new_files;
    if ($is_generated) {
        foreach ($cmake_new_files as &$file_ref) {
            $file_ref = str_replace('td/generate/auto/td', '${TD_AUTO_INCLUDE_DIR}', $file_ref);
        }
        $cmake_cpp_name = str_replace('td/generate/auto/td', '${TD_AUTO_INCLUDE_DIR}', $cmake_cpp_name);
    }

    if ($undo) {
        foreach ($new_files as $file) {
            if (file_exists($file)) {
                echo "Unlinking ".$file.PHP_EOL;
                unlink($file);
            }
        }

        if (strpos($cmake, $cmake_cpp_name) === false) {
            $cmake = str_replace(implode(PHP_EOL.'  ', $cmake_new_files), $cmake_cpp_name, $cmake);
            file_put_contents($cmake_file, $cmake);
        }

        return;
    }

    if (strpos($cmake, $cmake_cpp_name) !== false) {
        $cmake = str_replace($cmake_cpp_name, implode(PHP_EOL.'  ', $cmake_new_files), $cmake);
        file_put_contents($cmake_file, $cmake);
    }

    if (!file_exists($cpp_name)) {
        echo "ERROR: skip nonexistent file $cpp_name".PHP_EOL;
        return;
    }

    $lines = file($cpp_name);
    $depth = 0;
    $target_depth = 1 + $is_generated;
    $is_static = false;
    $in_define = false;
    $in_comment = false;
    $current = '';
    $common = '';
    $functions = array();
    $namespace_begin = '';
    $namespace_end = '';
    foreach ($lines as $line) {
        $add_depth = strpos($line, 'namespace ') === 0 ? 1 : (strpos($line, '}  // namespace') === 0 ? -1 : 0);
        if ($add_depth) {
            # namespace begin/end
            if ($add_depth > 0) {
              $depth += $add_depth;
            }
            if ($depth <= $target_depth) {
                if ($add_depth > 0) {
                    $namespace_begin .= $line;
                } else {
                    $namespace_end .= $line;
                }
            }
            if ($add_depth < 0) {
              $depth += $add_depth;
            }
            if ($is_static) {
                $common .= $current;
            } else {
                $functions[] = $current;
            }
            $common .= $line;
            $current = '';
            $is_static = false;
            $in_define = false;
            continue;
        }

        if (strpos($line, '#undef') === 0 && !trim($current)) {
            continue;
        }

        if ($in_comment && strpos($line, '*/') === 0) {
            $in_comment = false;
            continue;
        }
        if (strpos($line, '/*') === 0) {
            $in_comment = true;
        }
        if ($in_comment) {
            continue;
        }

        if ($depth !== $target_depth) {
            $common .= $line;
            continue;
        }

        if (strpos($line, 'static ') === 0 && $depth === $target_depth) {
            $is_static = true;
        }
        if (!trim($current) && strpos($line, '#define ') === 0) {
            $is_static = true;
            $in_define = true;
        }

        $current .= $line;
        if ((strpos($line, '}') === 0 || ($in_define && !trim($line)) || preg_match('/^[a-z].*;\s*$/i', $line)) && $depth === $target_depth) {
            # block end
            if ($is_static) {
                $common .= $current;
            } else {
                $functions[] = $current;
            }
            $current = '';
            $is_static = false;
            $in_define = false;
        }
    }
    $current = trim($current);
    if (!empty($current)) {
        fwrite(STDERR, "ERROR: $current".PHP_EOL);
        exit();
    }

    if (count($functions) < $chunks) {
        fwrite(STDERR, "ERROR: file is too small to be split more".PHP_EOL);
        return;
    }

    $deps = array();  // all functions from the same subarray must be in the same file
    $parents = array();
    foreach ($functions as $i => $f) {
        if (preg_match_all('/(?J)create_handler<(?<name>[A-Z][A-Za-z]*)>|'.
                           '(?<name>[A-Z][A-Za-z]*) (final )?: public (Td::ResultHandler|Request)|'.
                           '(CREATE_REQUEST|CREATE_NO_ARGS_REQUEST)[(](?<name>[A-Z][A-Za-z]*)|'.
                           '(?<name>complete_pending_preauthentication_requests)|'.
                           '(?<name>get_message_history_slice)|'.
                           '(Up|Down)load(?!ManagerCallback)[a-zA-Z]+C(?<name>allback)|(up|down)load_[a-z_]*_c(?<name>allback)_|'.
                           '(?<name>lazy_to_json)|'.
                           '(?<name>LogEvent)[^sA]|'.
                           '(?<name>parse)[(]|'.
                           '(?<name>store)[(]/', $f, $matches, PREG_SET_ORDER)) {
            foreach ($matches as $match) {
                $name = $match['name'];
                if ($name === 'parse' || $name === 'store') {
                    if ($is_generated) {
                        continue;
                    }
                    $name = 'LogEvent';
                }
                $deps[$name][] = $i;
            }
        }
        $parents[$i] = $i;
    }

    foreach ($deps as $func_ids) {
        foreach ($func_ids as $func_id) {
            disjoint_set_union($parents, $func_ids[0], $func_id);
        }
    }
    $sets = array();
    $set_sizes = array();
    foreach ($functions as $i => $f) {
        $parent = disjoint_set_find($parents, $i);
        if (!isset($sets[$parent])) {
            $sets[$parent] = '';
            $set_sizes[$parent] = 0;
        }
        $sets[$parent] .= $f;
        $set_sizes[$parent] += strlen($f);
    }
    arsort($set_sizes);

    $files = array_fill(0, $chunks, '');
    $file_sizes = array_fill(0, $chunks, 0);
    foreach ($set_sizes as $parent => $size) {
        $file_id = array_search(min($file_sizes), $file_sizes);
        $files[$file_id] .= $sets[$parent];
        $file_sizes[$file_id] += $size;
    }

    foreach ($files as $n => $f) {
        $new_content = $common.$namespace_begin.$f.$namespace_end;

        $std_methods = array();
        preg_match_all('/std::[a-z_0-9]*|td::unique(?!_)/', $new_content, $std_methods);
        $std_methods = array_unique($std_methods[0]);

        $needed_std_headers = array();
        $type_headers = array(
            'std::move' => '',
            'std::vector' => '',
            'std::string' => '',
            'std::uint32_t' => '',
            'std::int32_t' => '',
            'std::int64_t' => '',
            'td::unique' => 'algorithm',
            'std::count_if' => 'algorithm',
            'std::fill' => 'algorithm',
            'std::find' => 'algorithm',
            'std::is_sorted' => 'algorithm',
            'std::lower_bound' => 'algorithm',
            'std::max' => 'algorithm',
            'std::merge' => 'algorithm',
            'std::min' => 'algorithm',
            'std::partial_sort' => 'algorithm',
            'std::partition' => 'algorithm',
            'std::remove' => 'algorithm',
            'std::reverse' => 'algorithm',
            'std::rotate' => 'algorithm',
            'std::sort' => 'algorithm',
            'std::stable_sort' => 'algorithm',
            'std::upper_bound' => 'algorithm',
            'std::abs' => 'cmath',
            'std::isfinite' => 'cmath',
            'std::function' => 'functional',
            'std::greater' => 'functional',
            'std::reference_wrapper' => 'functional',
            'std::make_move_iterator' => 'iterator',
            'std::numeric_limits' => 'limits',
            'std::map' => 'map',
            'std::multimap' => 'map',
            'std::make_shared' => 'memory',
            'std::shared_ptr' => 'memory',
            'std::multiset' => 'set',
            'std::set' => 'set',
            'std::get' => 'tuple',
            'std::make_tuple' => 'tuple',
            'std::tie' => 'tuple',
            'std::tuple' => 'tuple',
            'std::decay_t' => 'type_traits',
            'std::is_same' => 'type_traits',
            'std::unordered_map' => 'unordered_map',
            'std::unordered_set' => 'unordered_set',
            'std::make_pair' => 'utility',
            'std::pair' => 'utility',
            'std::swap' => 'utility');
        foreach ($type_headers as $type => $header) {
            if (in_array($type, $std_methods)) {
                $std_methods = array_diff($std_methods, array($type));
                if ($header && !in_array($header, $needed_std_headers)) {
                    $needed_std_headers[] = $header;
                }
            }
        }

        if (!$std_methods) { // know all needed std headers
            $new_content = preg_replace_callback(
                '/#include <([a-z_]*)>/',
                function ($matches) use ($needed_std_headers) {
                    if (in_array($matches[1], $needed_std_headers)) {
                        return $matches[0];
                    }
                    return '';
                },
                $new_content
            );
        }

        $td_methods = array(
            'AccentColorId' => 'AccentColorId',
            'account_manager[_(-](?![.]get[(][)])|AccountManager[^;>]' => 'AccountManager',
            'AffiliateType' => 'AffiliateType',
            'alarm_manager[_(-](?![.]get[(][)])|AlarmManager' => 'AlarmManager',
            'animations_manager[_(-](?![.]get[(][)])|AnimationsManager[^;>]' => 'AnimationsManager',
            'attach_menu_manager[_(-](?![.]get[(][)])|AttachMenuManager[^;>]' => 'AttachMenuManager',
            'audios_manager[_(-](?![.]get[(][)])|AudiosManager' => 'AudiosManager',
            'auth_manager[_(-](?![.]get[(][)])|AuthManager' => 'AuthManager',
            'AutoDownloadSettings|[a-z_]*auto_download_settings' => 'AutoDownloadSettings',
            'autosave_manager[_(-](?![.]get[(][)])|AutosaveManager' => 'AutosaveManager',
            'BackgroundId' => 'BackgroundId',
            'background_manager[_(-](?![.]get[(][)])|BackgroundManager' => 'BackgroundManager',
            'BackgroundType' => 'BackgroundType',
            'Birthdate' => 'Birthdate',
            'boost_manager[_(-](?![.]get[(][)])|BoostManager' => 'BoostManager',
            'bot_info_manager[_(-](?![.]get[(][)])|BotInfoManager' => 'BotInfoManager',
            'BotMenuButton|[a-z_]*_menu_button' => 'BotMenuButton',
            'send_bot_custom_query|answer_bot_custom_query|set_bot_updates_status' => 'BotQueries',
            'bot_recommendation_manager[_(-](?![.]get[(][)])|BotRecommendationManager' => 'BotRecommendationManager',
            'BotVerification' => 'BotVerification',
            'BotVerifierSettings' => 'BotVerifierSettings',
            'BusinessAwayMessage' => 'BusinessAwayMessage',
            'BusinessChatLink' => 'BusinessChatLink',
            'BusinessConnectedBot' => 'BusinessConnectedBot',
            'BusinessConnectionId' => 'BusinessConnectionId',
            'business_connection_manager[_(-](?![.]get[(][)])|BusinessConnectionManager' => 'BusinessConnectionManager',
            'BusinessGreetingMessage' => 'BusinessGreetingMessage',
            'BusinessInfo|business_info' => 'BusinessInfo',
            'BusinessIntro' => 'BusinessIntro',
            'business_manager[_(-](?![.]get[(][)])|BusinessManager' => 'BusinessManager',
            'BusinessRecipients' => 'BusinessRecipients',
            'BusinessWorkHours' => 'BusinessWorkHours',
            'callback_queries_manager[_(-](?![.]get[(][)])|CallbackQueriesManager' => 'CallbackQueriesManager',
            'CallId' => 'CallId',
            'call_manager[_(-](?![.]get[(][)])|CallManager' => 'CallManager',
            'ChannelId' => 'ChannelId',
            'channel_recommendation_manager[_(-](?![.]get[(][)])|ChannelRecommendationManager' => 'ChannelRecommendationManager',
            'ChatId' => 'ChatId',
            'chat_manager[_(-](?![.]get[(][)])|ChatManager([^ ;.]| [^*])' => 'ChatManager',
            'common_dialog_manager[_(-](?![.]get[(][)])|CommonDialogManager' => 'CommonDialogManager',
            'connection_state_manager[_(-](?![.]get[(][)])|ConnectionStateManager' => 'ConnectionStateManager',
            'country_info_manager[_(-](?![.]get[(][)])|CountryInfoManager' => 'CountryInfoManager',
            'CustomEmojiId' => 'CustomEmojiId',
            'device_token_manager[_(-](?![.]get[(][)])|DeviceTokenManager' => 'DeviceTokenManager',
            'DialogAction[^M]' => 'DialogAction',
            'dialog_action_manager[_(-](?![.]get[(][)])|DialogActionManager' => 'DialogActionManager',
            'DialogFilter[^A-Z]' => 'DialogFilter',
            'DialogFilterId' => 'DialogFilterId',
            'dialog_filter_manager[_(-](?![.]get[(][)])|DialogFilterManager' => 'DialogFilterManager',
            'DialogId' => 'DialogId',
            'dialog_invite_link_manager[_(-](?![.]get[(][)])|DialogInviteLinkManager' => 'DialogInviteLinkManager',
            'DialogListId' => 'DialogListId',
            'DialogLocation' => 'DialogLocation',
            'dialog_manager[_(-](?![.]get[(][)])|DialogManager' => 'DialogManager',
            'DialogParticipantFilter' => 'DialogParticipantFilter',
            'dialog_participant_manager[_(-](?![.]get[(][)])|DialogParticipantManager' => 'DialogParticipantManager',
            'DialogSource' => 'DialogSource',
            'documents_manager[_(-](?![.]get[(][)])|DocumentsManager' => 'DocumentsManager',
            'download_manager[_(-](?![.]get[(][)])|DownloadManager[^C]' => 'DownloadManager',
            'DownloadManagerCallback' => 'DownloadManagerCallback',
            'EmailVerification' => 'EmailVerification',
            'EmojiGroup' => 'EmojiGroup',
            'FactCheck' => 'FactCheck',
            'file_reference_manager[_(-](?![.]get[(][)])|FileReferenceManager|file_references[)]' => 'FileReferenceManager',
            'file_manager[_(-](?![.]get[(][)])|FileManager([^ ;.]| [^*])|update_file[)]' => 'files/FileManager',
            'FolderId' => 'FolderId',
            'forum_topic_manager[_(-](?![.]get[(][)])|ForumTopicManager' => 'ForumTopicManager',
            'game_manager[_(-](?![.]get[(][)])|GameManager' => 'GameManager',
            'G[(][)]|Global[^A-Za-z]' => 'Global',
            'GlobalPrivacySettings' => 'GlobalPrivacySettings',
            'GroupCallId' => 'GroupCallId',
            'group_call_manager[_(-](?![.]get[(][)])|GroupCallManager' => 'GroupCallManager',
            'hashtag_hints[_(-](?![.]get[(][)])|HashtagHints' => 'HashtagHints',
            'inline_message_manager[_(-](?![.]get[(][)])|InlineMessageManager' => 'InlineMessageManager',
            'inline_queries_manager[_(-](?![.]get[(][)])|InlineQueriesManager' => 'InlineQueriesManager',
            'InputBusinessChatLink' => 'InputBusinessChatLink',
            'language_pack_manager[_(-]|LanguagePackManager' => 'LanguagePackManager',
            'link_manager[_(-](?![.]get[(][)])|LinkManager' => 'LinkManager',
            'LogeventIdWithGeneration|add_log_event|delete_log_event|get_erase_log_event_promise|parse_time|store_time' => 'logevent/LogEventHelper',
            'MessageCopyOptions' => 'MessageCopyOptions',
            'MessageEffectId' => 'MessageEffectId',
            'MessageForwardInfo|LastForwardedMessageInfo|forward_info' => 'MessageForwardInfo',
            'MessageFullId' => 'MessageFullId',
            'MessageId' => 'MessageId',
            'message_import_manager[_(-](?![.]get[(][)])|MessageImportManager' => 'MessageImportManager',
            'message_query_manager[_(-](?![.]get[(][)])|MessageQueryManager' => 'MessageQueryManager',
            'MessageLinkInfo' => 'MessageLinkInfo',
            'MessageQuote' => 'MessageQuote',
            'MessageReaction|UnreadMessageReaction|[a-z_]*message[a-z_]*reaction|reload_paid_reaction_privacy|get_chosen_tags' => 'MessageReaction',
            'MessageReactor' => 'MessageReactor',
            'MessageSearchOffset' => 'MessageSearchOffset',
            '[a-z_]*_message_sender' => 'MessageSender',
            'messages_manager[_(-](?![.]get[(][)])|MessagesManager' => 'MessagesManager',
            'MessageThreadInfo' => 'MessageThreadInfo',
            'MessageTtl' => 'MessageTtl',
            'MissingInvitee' => 'MissingInvitee',
            'notification_manager[_(-](?![.]get[(][)])|NotificationManager|notifications[)]' => 'NotificationManager',
            'notification_settings_manager[_(-](?![.]get[(][)])|NotificationSettingsManager' => 'NotificationSettingsManager',
            'online_manager[_(-](?![.]get[(][)])|OnlineManager' => 'OnlineManager',
            'option_manager[_(-](?![.]get[(][)])|OptionManager' => 'OptionManager',
            'PaidReactionType' => 'PaidReactionType',
            'password_manager[_(-](?![.]get[(][)])|PasswordManager' => 'PasswordManager',
            'people_nearby_manager[_(-](?![.]get[(][)])|PeopleNearbyManager' => 'PeopleNearbyManager',
            'phone_number_manager[_(-](?![.]get[(][)])|PhoneNumberManager' => 'PhoneNumberManager',
            'PhotoSizeSource' => 'PhotoSizeSource',
            'poll_manager[_(-](?![.]get[(][)])|PollManager' => 'PollManager',
            'privacy_manager[_(-](?![.]get[(][)])|PrivacyManager' => 'PrivacyManager',
            'promo_data_manager[_(-](?![.]get[(][)])|PromoDataManager' => 'PromoDataManager',
            'PublicDialogType|get_public_dialog_type' => 'PublicDialogType',
            'quick_reply_manager[_(-](?![.]get[(][)])|QuickReplyManager' => 'QuickReplyManager',
            'ReactionListType|[a-z_]*_reaction_list_type' => 'ReactionListType',
            'reaction_manager[_(-](?![.]get[(][)])|ReactionManager' => 'ReactionManager',
            'ReactionNotificationSettings' => 'ReactionNotificationSettings',
            'ReactionNotificationsFrom' => 'ReactionNotificationsFrom',
            'ReactionType|[a-z_]*_reaction_type' => 'ReactionType',
            'ReferralProgramInfo' => 'ReferralProgramInfo',
            'referral_program_manager[_(-](?![.]get[(][)])|ReferralProgramManager' => 'ReferralProgramManager',
            'ReferralProgramParameters' => 'ReferralProgramParameters',
            'RequestActor|RequestOnceActor' => 'RequestActor',
            'saved_messages_manager[_(-](?![.]get[(][)])|SavedMessagesManager' => 'SavedMessagesManager',
            'ScopeNotificationSettings|[a-z_]*_scope_notification_settings' => 'ScopeNotificationSettings',
            'SecretChatActor' => 'SecretChatActor',
            'secret_chats_manager[_(-]|SecretChatsManager' => 'SecretChatsManager',
            'secure_manager[_(-](?![.]get[(][)])|SecureManager' => 'SecureManager',
            'SentEmailCode' => 'SentEmailCode',
            'SharedDialog' => 'SharedDialog',
            'sponsored_message_manager[_(-](?![.]get[(][)])|SponsoredMessageManager' => 'SponsoredMessageManager',
            'StarAmount' => 'StarAmount',
            'StarGift[^A-Z]' => 'StarGift',
            'StarGiftAttribute' => 'StarGiftAttribute',
            'StarGiftId' => 'StarGiftId',
            'star_gift_manager[_(-](?![.]get[(][)])|StarGiftManager' => 'StarGiftManager',
            'star_manager[_(-](?![.]get[(][)])|StarManager' => 'StarManager',
            'StarSubscription[^P]' => 'StarSubscription',
            'StarSubscriptionPricing' => 'StarSubscriptionPricing',
            'state_manager[_(-](?![.]get[(][)])|StateManager' => 'StateManager',
            'statistics_manager[_(-](?![.]get[(][)])|StatisticsManager' => 'StatisticsManager',
            'StickerSetId' => 'StickerSetId',
            'stickers_manager[_(-](?![.]get[(][)])|StickersManager' => 'StickersManager',
            'storage_manager[_(-](?![.]get[(][)])|StorageManager' => 'StorageManager',
            'StoryId' => 'StoryId',
            'StoryListId' => 'StoryListId',
            'story_manager[_(-](?![.]get[(][)])|StoryManager' => 'StoryManager',
            'SuggestedAction|[a-z_]*_suggested_action' => 'SuggestedAction',
            'suggested_action_manager[_(-](?![.]get[(][)])|SuggestedActionManager' => 'SuggestedActionManager',
            'SynchronousRequests' => 'SynchronousRequests',
            'TargetDialogTypes' => 'TargetDialogTypes',
            'td_api' => 'td_api',
            'td_db[(][)]|TdDb[^A-Za-z]' => 'TdDb',
            'telegram_api' => 'telegram_api',
            'terms_of_service_manager[_(-](?![.]get[(][)])|TermsOfServiceManager' => 'TermsOfServiceManager',
            'theme_manager[_(-](?![.]get[(][)])|ThemeManager' => 'ThemeManager',
            'ThemeSettings' => 'ThemeSettings',
            'time_zone_manager[_(-](?![.]get[(][)])|TimeZoneManager' => 'TimeZoneManager',
            'TopDialogCategory|get_top_dialog_category' => 'TopDialogCategory',
            'top_dialog_manager[_(-](?![.]get[(][)])|TopDialogManager' => 'TopDialogManager',
            'translation_manager[_(-](?![.]get[(][)])|TranslationManager' => 'TranslationManager',
            'transcription_manager[_(-](?![.]get[(][)])|TranscriptionManager' => 'TranscriptionManager',
            'updates_manager[_(-](?![.]get[(][)])|UpdatesManager|get_difference[)]|updateSentMessage|dummyUpdate' => 'UpdatesManager',
            'UserId' => 'UserId',
            'user_manager[_(-](?![.]get[(][)])|UserManager([^ ;.]| [^*])' => 'UserManager',
            'UserStarGift' => 'UserStarGift',
            'video_notes_manager[_(-](?![.]get[(][)])|VideoNotesManager' => 'VideoNotesManager',
            'videos_manager[_(-](?![.]get[(][)])|VideosManager' => 'VideosManager',
            'voice_notes_manager[_(-](?![.]get[(][)])|VoiceNotesManager' => 'VoiceNotesManager',
            'web_app_manager[_(-](?![.]get[(][)])|WebAppManager' => 'WebAppManager',
            'WebAppOpenParameters' => 'WebAppOpenParameters',
            'WebPageId(Hash)?' => 'WebPageId',
            'web_pages_manager[_(-](?![.]get[(][)])|WebPagesManager' => 'WebPagesManager');

        foreach ($td_methods as $pattern => $header) {
            if (strpos($cpp_name, $header) !== false) {
                continue;
            }

            $include_name = '#include "td/telegram/'.$header.'.h"';
            if (strpos($new_content, $include_name) !== false && preg_match('/[^a-zA-Z0-9_]('.$pattern.')/', str_replace($include_name, '', $new_content)) === 0) {
                $new_content = str_replace($include_name, '', $new_content);
            }
        }

        if (!file_exists($new_files[$n]) || file_get_contents($new_files[$n]) !== $new_content) {
            echo "Writing file ".$new_files[$n].PHP_EOL;
            file_put_contents($new_files[$n], $new_content);
        }
    }
}

if (in_array('--help', $argv) || in_array('-h', $argv)) {
    echo "Usage: php SplitSource.php [OPTION]...\n".
         "Splits some source files to reduce a maximum amount of RAM needed for compiling a single file.\n".
         "  -u, --undo Undo all source code changes.\n".
         "  -h, --help Show this help.\n";
    exit(2);
}

$undo = in_array('--undo', $argv) || in_array('-u', $argv);
$files = array('td/telegram/ChatManager' => 10,
               'td/telegram/MessagesManager' => 50,
               'td/telegram/NotificationManager' => 10,
               'td/telegram/Requests' => 50,
               'td/telegram/StickersManager' => 10,
               'td/telegram/StoryManager' => 10,
               'td/telegram/UpdatesManager' => 10,
               'td/telegram/UserManager' => 10,
               'td/generate/auto/td/telegram/td_api' => 10,
               'td/generate/auto/td/telegram/td_api_json' => 10,
               'td/generate/auto/td/telegram/telegram_api' => 10);

foreach ($files as $file => $chunks) {
    split_file($file, $chunks, $undo);
}
