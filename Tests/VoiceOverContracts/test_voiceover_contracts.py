import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class MessageRendererContractTests(unittest.TestCase):
    def test_all_top_level_renderers_use_shared_accessibility_data(self) -> None:
        renderers = (
            "submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift",
            "submodules/TelegramUI/Components/Chat/ChatMessageStickerItemNode/Sources/ChatMessageStickerItemNode.swift",
            "submodules/TelegramUI/Components/Chat/ChatMessageAnimatedStickerItemNode/Sources/ChatMessageAnimatedStickerItemNode.swift",
            "submodules/TelegramUI/Components/Chat/ChatMessageInstantVideoItemNode/Sources/ChatMessageInstantVideoItemNode.swift",
        )
        for renderer in renderers:
            with self.subTest(renderer=renderer):
                contents = source(renderer)
                self.assertIn("ChatMessageAccessibilityData(item:", contents)
                self.assertIn("updateAccessibilityData", contents)

    def test_shared_contract_assigns_required_properties(self) -> None:
        contents = source(
            "submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift"
        )
        for assignment in (
            "accessibilityNode.accessibilityLabel = accessibilityData.label",
            "accessibilityNode.accessibilityValue = accessibilityData.value",
            "accessibilityNode.accessibilityHint = accessibilityData.hint",
            "accessibilityNode.accessibilityTraits = accessibilityData.traits",
            "accessibilityNode.accessibilityIdentifier = \"message.",
            "accessibilityNode.accessibilityCustomActions",
        ):
            with self.subTest(assignment=assignment):
                self.assertIn(assignment, contents)

    def test_shared_contract_exposes_message_actions(self) -> None:
        contents = source(
            "submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift"
        )
        for action in (".reply", ".react", ".options", ".copy", ".forward", ".delete"):
            with self.subTest(action=action):
                self.assertIn(f"case {action}:", contents)

    def test_shared_contract_covers_media_reply_and_message_states(self) -> None:
        contents = source(
            "submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift"
        )
        media_contracts = (
            "TelegramMediaImage",
            "file.isInstantVideo",
            ".Sticker(",
            ".Audio(",
            ".Video(",
            "TelegramMediaWebpage",
            "TelegramMediaContact",
            "TelegramMediaPoll",
        )
        state_contracts = (
            "VoiceOver_Chat_Selected",
            "traits.insert(.selected)",
            "VoiceOver_Chat_Sending",
            "VoiceOver_Chat_Failed",
            "Conversation_ChecksTooltip_Read",
            "Conversation_ChecksTooltip_Delivered",
            "VoiceOver_Chat_NotPlayedByRecipient",
            "VoiceOver_Chat_PlayedByRecipient",
            "ReplyMessageAttribute",
            "VoiceOver_Chat_ReplyingToMessage",
            ".navigateToReply(replyMessageId)",
        )
        for contract in media_contracts + state_contracts:
            with self.subTest(contract=contract):
                self.assertIn(contract, contents)

        fallback_contents = source(
            "submodules/ChatListUI/Sources/Node/ChatListItemStrings.swift"
        )
        for media_type in (
            "TelegramMediaPaidContent",
            "TelegramMediaMap",
            "TelegramMediaGame",
            "TelegramMediaInvoice",
            "TelegramMediaAction",
            "TelegramMediaStory",
            "TelegramMediaGiveaway",
            "TelegramMediaGiveawayResults",
        ):
            with self.subTest(media_type=media_type):
                self.assertIn(media_type, fallback_contents)


class ChatNavigationContractTests(unittest.TestCase):
    def test_history_supports_voiceover_scroll_and_stable_message_focus(self) -> None:
        list_view = source("submodules/Display/Source/ListView.swift")
        self.assertIn(
            "override open func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool",
            list_view,
        )
        self.assertIn("self.rotated ? .up : .down", list_view)
        self.assertIn("UIAccessibility.Notification.pageScrolled", list_view)

        history = source("submodules/TelegramUI/Sources/ChatHistoryListNode.swift")
        for contract in (
            "accessibilityFocusedMessageId",
            "accessibilityContainsFocus()",
            "restoreAccessibilityFocus()",
        ):
            self.assertIn(contract, history)

    def test_input_exposes_stable_hit_target_and_screen_frame(self) -> None:
        contents = source(
            "submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift"
        )
        for contract in (
            'accessibilityIdentifier = "chat.input"',
            "inputHitTestSlop",
            "UIAccessibility.convertToScreenCoordinates",
            "accessibilityRespondsToUserInteraction = true",
            "UIAccessibility.post(notification: .layoutChanged, argument: new.inputView)",
        ):
            self.assertIn(contract, contents)


class FocusPersistenceContractTests(unittest.TestCase):
    def test_transaction_lists_restore_only_existing_stable_ids(self) -> None:
        owners = (
            "submodules/TelegramUI/Components/Chat/ChatHistorySearchContainerNode/Sources/ChatHistorySearchContainerNode.swift",
            "submodules/ChatListUI/Sources/ChatListSearchListPaneNode.swift",
            "submodules/ContactListUI/Sources/ContactListNode.swift",
            "submodules/ContactListUI/Sources/ContactsSearchContainerNode.swift",
            "submodules/ContactListUI/Sources/InviteContactsControllerNode.swift",
            "submodules/TelegramUI/Components/AttachmentFileController/Sources/AttachmentFileSearchItem.swift",
            "submodules/TelegramUI/Components/ChatEntityKeyboardInputNode/Sources/StickerPaneSearchContentNode.swift",
            "submodules/TelegramUI/Components/GroupStickerPackSetupController/Sources/GroupStickerSearchContainerNode.swift",
            "submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode/Sources/GiftsListView.swift",
            "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/Panes/PeerInfoMembersPane.swift",
            "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/Panes/PeerInfoGroupsInCommonPaneNode.swift",
            "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/Panes/PeerInfoRecommendedPeersPane.swift",
            "submodules/ShareController/Sources/SharePeersContainerNode.swift",
            "submodules/ShareController/Sources/ShareSearchContainerNode.swift",
            "submodules/ShareController/Sources/ShareTopicsContainerNode.swift",
        )
        for owner in owners:
            with self.subTest(owner=owner):
                contents = source(owner)
                self.assertIn("accessibilityElementIsFocused", contents)
                self.assertIn("UIAccessibility.post(notification: .layoutChanged", contents)

        history = source("submodules/TelegramUI/Sources/ChatHistoryListNode.swift")
        self.assertIn("accessibilityContainsFocus()", history)
        self.assertIn("restoreAccessibilityFocus()", history)
        self.assertIn("accessibilityFocusedMessageId", history)

        sticker_item = source(
            "submodules/FeaturedStickersScreen/Sources/StickerPaneSearchStickerItem.swift"
        )
        self.assertIn('accessibilityIdentifier = "sticker.', sticker_item)
        self.assertIn("override func accessibilityActivate() -> Bool", sticker_item)


class ModalContractTests(unittest.TestCase):
    def test_shared_modal_controllers_enforce_complete_contract(self) -> None:
        controllers = (
            "submodules/Display/Source/AlertController.swift",
            "submodules/Display/Source/ActionSheetController.swift",
            "submodules/TelegramUI/Components/ContextControllerImpl/Sources/ContextControllerImpl.swift",
            "submodules/TelegramUI/Components/ContextControllerImpl/Sources/PeekController.swift",
            "submodules/TelegramUI/Components/ContextControllerImpl/Sources/PinchController.swift",
        )
        for controller in controllers:
            with self.subTest(controller=controller):
                contents = source(controller)
                self.assertIn("accessibilityPerformEscape", contents)
                self.assertIn("restoreAccessibilityFocus", contents)

        share_controller = source("submodules/ShareController/Sources/ShareController.swift")
        self.assertIn("accessibilityPerformEscape", share_controller)
        share_node = source("submodules/ShareController/Sources/ShareControllerNode.swift")
        self.assertIn("activateInitialAccessibilityFocus", share_node)
        self.assertIn("performAccessibilityEscape", share_node)

    def test_modal_nodes_contain_voiceover_traversal(self) -> None:
        node_sources = (
            "submodules/Display/Source/AlertControllerNode.swift",
            "submodules/Display/Source/ActionSheetControllerNode.swift",
            "submodules/ShareController/Sources/ShareControllerNode.swift",
            "submodules/TelegramUI/Components/ContextControllerImpl/Sources/ContextControllerImpl.swift",
            "submodules/TelegramUI/Components/ContextControllerImpl/Sources/PeekController.swift",
            "submodules/TelegramUI/Components/ContextControllerImpl/Sources/PinchController.swift",
        )
        for node_source in node_sources:
            with self.subTest(node_source=node_source):
                self.assertIn("accessibilityViewIsModal = true", source(node_source))

    def test_modal_backgrounds_are_hidden_and_reduce_motion_is_respected(self) -> None:
        alert = source("submodules/Display/Source/AlertControllerNode.swift")
        action_sheet = source("submodules/Display/Source/ActionSheetControllerNode.swift")
        self.assertIn("dimContainerView.accessibilityElementsHidden = true", alert)
        for background in (
            "dismissTapView",
            "leftDimView",
            "rightDimView",
            "topDimView",
            "bottomDimView",
        ):
            self.assertIn(f"{background}.accessibilityElementsHidden = true", action_sheet)
        self.assertIn("UIAccessibility.isReduceMotionEnabled", alert)
        self.assertIn("UIAccessibility.isReduceMotionEnabled", action_sheet)

        archive = source(
            "submodules/TelegramUI/Components/Settings/ArchiveInfoScreen/Sources/ArchiveInfoScreen.swift"
        )
        self.assertIn("self.accessibilityViewIsModal = true", archive)
        self.assertIn("UIAccessibility.post(notification: .screenChanged", archive)
        self.assertIn("override public func accessibilityPerformEscape() -> Bool", archive)


class SelectionAndShareContractTests(unittest.TestCase):
    def test_share_peer_and_topic_selection_expose_full_state(self) -> None:
        peer = source("submodules/ShareController/Sources/ShareControllerPeerGridItem.swift")
        topic = source("submodules/ShareController/Sources/ShareTopicGridItem.swift")
        for contract in (
            "accessibilityLabel",
            "accessibilityValue",
            "accessibilityHint",
            "accessibilityTraits.insert(.selected)",
            "accessibilityTraits.insert(.notEnabled)",
            "override func accessibilityActivate() -> Bool",
        ):
            self.assertIn(contract, peer)
        for contract in (
            "accessibilityLabel",
            "accessibilityValue",
            "accessibilityTraits.insert(.selected)",
            "override func accessibilityActivate() -> Bool",
        ):
            self.assertIn(contract, topic)

    def test_share_modes_focus_error_and_escape_contracts_are_retained(self) -> None:
        segmented = source("submodules/SegmentedControlNode/Sources/SegmentedControlNode.swift")
        self.assertIn("itemNode.accessibilityLabel = item.title", segmented)
        self.assertIn("itemNode.accessibilityTraits.insert(.selected)", segmented)

        node = source("submodules/ShareController/Sources/ShareControllerNode.swift")
        for contract in (
            "activateInitialAccessibilityFocus",
            "accessibilityFocusTarget(peerId:",
            "accessibilityInitialFocusTarget",
            "UIAccessibility.post(notification: .screenChanged",
            "UIAccessibility.post(notification: .layoutChanged, argument: self.actionButtonNode.view)",
        ):
            self.assertIn(contract, node)
        controller = source("submodules/ShareController/Sources/ShareController.swift")
        self.assertIn("override public func accessibilityPerformEscape() -> Bool", controller)


class GiftsContractTests(unittest.TestCase):
    def test_gift_card_exposes_semantics_activation_and_context_menu(self) -> None:
        contents = source(
            "submodules/TelegramUI/Components/Gifts/GiftItemComponent/Sources/GiftItemComponent.swift"
        )
        for contract in (
            "override public func accessibilityActivate() -> Bool",
            "self.isAccessibilityElement = exposesCard && !component.isPlaceholder",
            "self.containerButton.isAccessibilityElement = false",
            "self.accessibilityLabel = label",
            "self.accessibilityValue = values.isEmpty ? nil",
            "self.accessibilityTraits = [.image]",
            "self.accessibilityTraits.insert(.button)",
            "self.accessibilityTraits.insert(.selected)",
            "accessibilityOpenContextMenu",
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, contents)

    def test_gifts_keep_selection_limit_actions_and_stable_focus(self) -> None:
        contents = source(
            "submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode/Sources/GiftsListView.swift"
        )
        for contract in (
            "accessibilityTraits.insert(.selected)",
            "accessibilityTraits.insert(.notEnabled)",
            "RequestPeer_ReachedMaximum",
            "kind: .movePrevious",
            "kind: .moveNext",
            "kind: .togglePinned",
            "accessibilityCustomActions",
            "focusedItemId",
            "UIAccessibility.post(notification: .layoutChanged, argument: accessibilityView)",
            "itemView.accessibilityElementsHidden = true",
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, contents)

    def test_collection_tabs_expose_selection_and_reorder_actions_without_duplicates(self) -> None:
        selector = source(
            "submodules/TelegramUI/Components/TabSelectorComponent/Sources/TabSelectorComponent.swift"
        )
        for contract in (
            "self.isAccessibilityElement = true",
            "self.containerNode.accessibilityElementsHidden = true",
            "self.accessibilityLabel = title",
            "self.accessibilityTraits.insert(.selected)",
            "self.accessibilityTraits.insert(.notEnabled)",
            "override func accessibilityActivate() -> Bool",
            "accessibilityReorderPreviousTitle",
            "accessibilityReorderNextTitle",
            "itemView.accessibilityCustomActions",
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, selector)

        collection_tab = source(
            "submodules/TelegramUI/Components/PeerInfo/CollectionTabItemComponent/Sources/CollectionTabItemComponent.swift"
        )
        self.assertIn("self.accessibilityLabel = component.title", collection_tab)


class AccessibilityPreferencesContractTests(unittest.TestCase):
    def test_rich_messages_scale_with_chat_text_size_and_invalidate_layout_cache(self) -> None:
        contents = source(
            "submodules/TelegramUI/Components/Chat/ChatMessageRichDataBubbleContentNode/Sources/ChatMessageRichDataBubbleContentNode.swift"
        )
        for contract in (
            "baseFontSize: CGFloat",
            "item.presentationData.fontSize.baseDisplaySize",
            "let fontScale = baseFontSize / 17.0",
            "scaledFontSize(17.0)",
            "current.baseFontSize == baseFontSize",
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, contents)
        for fixed_size in (
            "size: 19.0",
            "size: 18.0",
            "size: 17.0",
            "size: 15.0",
            "size: 14.0",
            "size: 13.0",
        ):
            with self.subTest(fixed_size=fixed_size):
                self.assertNotIn(fixed_size, contents)

    def test_settings_rows_have_voice_control_names_and_stable_targets(self) -> None:
        owners = (
            (
                "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/ListItems/PeerInfoScreenDisclosureItem.swift",
                '"peerInfo.disclosure.',
            ),
            (
                "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/ListItems/PeerInfoScreenActionItem.swift",
                '"peerInfo.action.',
            ),
        )
        for owner, identifier in owners:
            with self.subTest(owner=owner):
                contents = source(owner)
                self.assertIn("activateArea.accessibilityLabel = item.text", contents)
                self.assertIn("activateArea.accessibilityRespondsToUserInteraction = item.action != nil", contents)
                self.assertIn(identifier, contents)

    def test_common_modals_support_dynamic_type_and_reduce_transparency(self) -> None:
        archive = source(
            "submodules/TelegramUI/Components/Settings/ArchiveInfoScreen/Sources/ArchiveInfoScreen.swift"
        )
        archive_content = source(
            "submodules/TelegramUI/Components/Settings/ArchiveInfoScreen/Sources/ArchiveInfoContentComponent.swift"
        )
        alert_controller = source("submodules/Display/Source/AlertController.swift")
        action_sheet_controller = source("submodules/Display/Source/ActionSheetController.swift")
        alert_node = source("submodules/Display/Source/AlertControllerNode.swift")
        action_sheet_group = source("submodules/Display/Source/ActionSheetItemGroupNode.swift")

        self.assertIn("UIFontMetrics(forTextStyle: .headline)", archive)
        self.assertIn("UIFontMetrics(forTextStyle: .headline)", archive_content)
        self.assertIn("UIFontMetrics(forTextStyle: .body)", archive_content)
        self.assertIn("UIContentSizeCategory.didChangeNotification", alert_controller)
        self.assertIn("UIContentSizeCategory.didChangeNotification", action_sheet_controller)
        self.assertIn("UIAccessibility.isReduceTransparencyEnabled", alert_node)
        self.assertIn("UIAccessibility.isReduceTransparencyEnabled", action_sheet_group)

    def test_url_auth_alert_reflows_at_accessibility_sizes(self) -> None:
        contents = source("submodules/TelegramUI/Sources/ChatMessageActionUrlAuthController.swift")
        for contract in (
            "UIFontMetrics(forTextStyle: .footnote)",
            "UIFontMetrics(forTextStyle: .headline)",
            "override func contentSizeCategoryUpdated()",
            "preferredContentSizeCategory.isAccessibilityCategory",
        ):
            self.assertIn(contract, contents)


class ReleaseGateContractTests(unittest.TestCase):
    def test_ui_suite_keeps_tree_audit_and_performance_budget(self) -> None:
        contents = source("Telegram/Tests/Sources/AccessibilityUITests.swift")
        for contract in (
            "performAccessibilityAudit()",
            "initialTreeElementBudget",
            "averageTraversalBudget",
            "maximumTraversalBudget",
            "XCTClockMetric()",
            "XCTMemoryMetric()",
            "XCTAttachment",
            "testPopulatedChatMessageContractWhenFixtureIsAvailable",
            "testChatInputHitTargetWhenFixtureIsAvailable",
            "VOICEOVER_USE_EXISTING_DATA",
            "testSettingsVoiceControlContractAndPerformanceWhenFixtureIsAvailable",
            "testChatTypingAccessibilityPerformanceWhenFixtureIsAvailable",
            "settingsTreeElementBudget",
            "typingUpdateAverageBudget",
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, contents)

    def test_workflow_runs_both_automated_gate_layers(self) -> None:
        contents = source(".github/workflows/voiceover-gate.yml")
        self.assertIn('branches:\n      - "VoiceOver-fixes"', contents)
        self.assertIn("python3 -m unittest discover", contents)
        self.assertIn("--target=Telegram:iOSAppUITestSuite", contents)
        self.assertIn("actions/upload-artifact@v4", contents)

    def test_release_process_artifacts_are_present(self) -> None:
        for artifact in (
            ".github/PULL_REQUEST_TEMPLATE.md",
            ".github/ISSUE_TEMPLATE/voiceover_tracking.md",
            "ACCESSIBILITY_CHANGELOG.md",
            "docs/VOICEOVER_RELEASE_GATE.md",
        ):
            with self.subTest(artifact=artifact):
                self.assertTrue((ROOT / artifact).is_file())


if __name__ == "__main__":
    unittest.main()
