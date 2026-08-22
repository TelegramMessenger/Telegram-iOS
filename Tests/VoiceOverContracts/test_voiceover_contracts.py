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
        ):
            with self.subTest(contract=contract):
                self.assertIn(contract, contents)

    def test_workflow_runs_both_automated_gate_layers(self) -> None:
        contents = source(".github/workflows/voiceover-gate.yml")
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
