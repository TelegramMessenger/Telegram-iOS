import XCTest
import Postbox
import TelegramCore
import ChatMessageItemCommon

private func makeFile(attributes: [TelegramMediaFileAttribute]) -> TelegramMediaFile {
    return TelegramMediaFile(
        fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: 1),
        partialReference: nil,
        resource: LocalFileMediaResource(fileId: 1),
        previewRepresentations: [],
        videoThumbnails: [],
        immediateThumbnailData: nil,
        mimeType: "application/octet-stream",
        size: 1024,
        attributes: attributes,
        alternativeRepresentations: []
    )
}

final class ChatMessageMergeFingerprintTests: XCTestCase {
    /// Every pair is asserted in both orders, since the merge function is asymmetric in its
    /// arguments — the first is the *upper* message.
    private func assertMatchesReference(_ a: Message, _ b: Message, _ label: String,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let fa = ChatMessageMergeFingerprint(message: a, accountPeerId: accountPeerIdForTests)
        let fb = ChatMessageMergeFingerprint(message: b, accountPeerId: accountPeerIdForTests)
        XCTAssertEqual(chatMessageMerge(upper: fa, lower: fb),
                       referenceMessagesShouldBeMerged(accountPeerId: accountPeerIdForTests, a, b),
                       "\(label) [a upper]", file: file, line: line)
        XCTAssertEqual(chatMessageMerge(upper: fb, lower: fa),
                       referenceMessagesShouldBeMerged(accountPeerId: accountPeerIdForTests, b, a),
                       "\(label) [b upper]", file: file, line: line)
    }

    private func buildCases() -> [(String, Message)] {
        var cases: [(String, Message)] = []

        let user1 = makeUser(id: 10)
        let user2 = makeUser(id: 11)
        let accountUser = makeUser(id: 1)
        let group = makeGroupChannel(id: 100)
        let monoforum = makeGroupChannel(id: 101, isMonoforum: true)
        let plainBroadcast = makeBroadcastChannel(id: 102, messagesShouldHaveProfiles: false)
        let profileBroadcast = makeBroadcastChannel(id: 103, messagesShouldHaveProfiles: true)

        // peer and author variation
        cases.append(("group/user1", makeMessage(peer: group, author: user1)))
        cases.append(("group/user2", makeMessage(peer: group, author: user2)))
        cases.append(("group/nil-author", makeMessage(peer: group, author: nil)))
        cases.append(("otherGroup/user1", makeMessage(peer: makeGroupChannel(id: 200), author: user1)))
        cases.append(("monoforum/user1", makeMessage(peer: monoforum, author: user1)))
        cases.append(("broadcast/user1", makeMessage(peer: plainBroadcast, author: user1)))
        cases.append(("profileBroadcast/user1", makeMessage(peer: profileBroadcast, author: user1)))
        cases.append(("profileBroadcast/user2", makeMessage(peer: profileBroadcast, author: user2)))

        // incoming vs outgoing
        cases.append(("group/user1/outgoing", makeMessage(peer: group, author: user1, isOutgoing: true)))

        // author is the group channel itself, with and without an anonymous admin signature
        cases.append(("group/self-authored", makeMessage(peer: group, author: group)))
        cases.append(("group/self-authored/outgoing", makeMessage(peer: group, author: group, isOutgoing: true)))
        cases.append(("group/self-authored/signed", makeMessage(
            peer: group, author: group,
            attributes: [AuthorSignatureMessageAttribute(signature: "Admin")])))
        cases.append(("group/self-authored/signed-other", makeMessage(
            peer: group, author: group,
            attributes: [AuthorSignatureMessageAttribute(signature: "Other")])))
        cases.append(("group/self-authored/signed-empty", makeMessage(
            peer: group, author: group,
            attributes: [AuthorSignatureMessageAttribute(signature: "")])))

        // sourceAuthorInfo overrides
        cases.append(("group/sourceAuthor-user2", makeMessage(
            peer: group, author: user1,
            attributes: [SourceAuthorInfoMessageAttribute(
                originalAuthor: user2.id, originalAuthorName: nil, orignalDate: nil, originalOutgoing: false)],
            extraPeers: [user2])))
        cases.append(("group/sourceAuthor-name", makeMessage(
            peer: group, author: user1,
            attributes: [SourceAuthorInfoMessageAttribute(
                originalAuthor: nil, originalAuthorName: "Ghost", orignalDate: nil, originalOutgoing: false)])))
        cases.append(("group/sourceAuthor-name-other", makeMessage(
            peer: group, author: user1,
            attributes: [SourceAuthorInfoMessageAttribute(
                originalAuthor: nil, originalAuthorName: "Spectre", orignalDate: nil, originalOutgoing: false)])))
        // originalAuthor pointing at a peer absent from `peers` — resolves to nil
        cases.append(("group/sourceAuthor-missing-peer", makeMessage(
            peer: group, author: user1,
            attributes: [SourceAuthorInfoMessageAttribute(
                originalAuthor: makeUserPeerId(999), originalAuthorName: nil, orignalDate: nil, originalOutgoing: false)])))

        // SourceReferenceMessageAttribute override
        cases.append(("group/sourceReference-user2", makeMessage(
            peer: group, author: user1,
            attributes: [SourceReferenceMessageAttribute(
                messageId: MessageId(peerId: user2.id, namespace: Namespaces.Message.Cloud, id: 5))],
            extraPeers: [user2])))

        // timestamps straddling the 10-minute merge window
        cases.append(("group/user1/t+599", makeMessage(peer: group, author: user1, timestamp: 1599)))
        cases.append(("group/user1/t+601", makeMessage(peer: group, author: user1, timestamp: 1601)))

        // paid messages
        cases.append(("group/user1/paid", makeMessage(
            peer: group, author: user1,
            attributes: [PaidStarsMessageAttribute(stars: StarsAmount(value: 5, nanos: 0), postponeSending: false)])))
        cases.append(("monoforum/user1/paid", makeMessage(
            peer: monoforum, author: user1,
            attributes: [PaidStarsMessageAttribute(stars: StarsAmount(value: 5, nanos: 0), postponeSending: false)])))

        // inline reply markup
        cases.append(("group/user1/inlineMarkup", makeMessage(
            peer: group, author: user1,
            attributes: [ReplyMarkupMessageAttribute(
                rows: [ReplyMarkupRow(buttons: [ReplyMarkupButton(
                    title: "b", titleWhenForwarded: nil, action: .text, style: nil)])],
                flags: [.inline], placeholder: nil)])))
        cases.append(("group/user1/inlineMarkup-empty-rows", makeMessage(
            peer: group, author: user1,
            attributes: [ReplyMarkupMessageAttribute(rows: [], flags: [.inline], placeholder: nil)])))
        cases.append(("group/user1/nonInlineMarkup", makeMessage(
            peer: group, author: user1,
            attributes: [ReplyMarkupMessageAttribute(
                rows: [ReplyMarkupRow(buttons: [ReplyMarkupButton(
                    title: "b", titleWhenForwarded: nil, action: .text, style: nil)])],
                flags: [], placeholder: nil)])))

        // every mediaMergeableStyle branch
        cases.append(("group/user1/no-media", makeMessage(peer: group, author: user1)))
        cases.append(("group/user1/action", makeMessage(
            peer: group, author: user1, media: [TelegramMediaAction(action: .historyCleared)])))
        cases.append(("group/user1/expired", makeMessage(
            peer: group, author: user1, media: [TelegramMediaExpiredContent(data: .image)])))
        cases.append(("group/user1/story-mention", makeMessage(
            peer: group, author: user1,
            media: [TelegramMediaStory(storyId: StoryId(peerId: user1.id, id: 1), isMention: true)])))
        cases.append(("group/user1/story-plain", makeMessage(
            peer: group, author: user1,
            media: [TelegramMediaStory(storyId: StoryId(peerId: user1.id, id: 1), isMention: false)])))
        cases.append(("group/user1/sticker", makeMessage(
            peer: group, author: user1,
            media: [makeFile(attributes: [.Sticker(displayText: "x", packReference: nil, maskData: nil)])])))
        cases.append(("group/user1/round-video", makeMessage(
            peer: group, author: user1,
            media: [makeFile(attributes: [.Video(
                duration: 1.0, size: PixelDimensions(width: 100, height: 100),
                flags: [.instantRoundVideo], preloadSize: nil, coverTime: nil, videoCodec: nil)])])))
        cases.append(("group/user1/plain-video", makeMessage(
            peer: group, author: user1,
            media: [makeFile(attributes: [.Video(
                duration: 1.0, size: PixelDimensions(width: 100, height: 100),
                flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)])])))
        cases.append(("group/user1/plain-file", makeMessage(
            peer: group, author: user1, media: [makeFile(attributes: [])])))

        // imported forwards — one side and both sides, varying author and signature
        cases.append(("group/user1/imported-fwd-authorA", makeMessage(
            peer: group, author: user1, timestamp: 5000,
            forwardInfo: makeForwardInfo(author: user2, authorSignature: nil, date: 900, isImported: true),
            extraPeers: [user2])))
        cases.append(("group/user1/imported-fwd-authorB", makeMessage(
            peer: group, author: user1, timestamp: 5000,
            forwardInfo: makeForwardInfo(author: accountUser, authorSignature: nil, date: 900, isImported: true),
            extraPeers: [accountUser])))
        cases.append(("group/user1/imported-fwd-sigA", makeMessage(
            peer: group, author: user1, timestamp: 5000,
            forwardInfo: makeForwardInfo(author: nil, authorSignature: "Sig", date: 905, isImported: true))))
        cases.append(("group/user1/imported-fwd-sigB", makeMessage(
            peer: group, author: user1, timestamp: 5000,
            forwardInfo: makeForwardInfo(author: nil, authorSignature: "Other", date: 905, isImported: true))))
        cases.append(("group/user1/imported-fwd-far-date", makeMessage(
            peer: group, author: user1, timestamp: 1000,
            forwardInfo: makeForwardInfo(author: nil, authorSignature: "Sig", date: 90000, isImported: true))))
        cases.append(("group/user1/nonimported-fwd", makeMessage(
            peer: group, author: user1,
            forwardInfo: makeForwardInfo(author: user2, authorSignature: nil, date: 900, isImported: false),
            extraPeers: [user2])))

        // replies / saved-messages peers: the post-sameAuthor effective-author swap
        let savedMessagesPeer = accountUser
        cases.append(("saved/user1", makeMessage(peer: savedMessagesPeer, author: user1)))
        cases.append(("saved/user1/fwd-user2", makeMessage(
            peer: savedMessagesPeer, author: user1,
            forwardInfo: makeForwardInfo(author: user2, authorSignature: nil, date: 900, isImported: false),
            extraPeers: [user2])))
        cases.append(("saved/user1/fwd-nil-author", makeMessage(
            peer: savedMessagesPeer, author: user1,
            forwardInfo: makeForwardInfo(author: nil, authorSignature: "S", date: 900, isImported: false))))

        return cases
    }

    func testMatrixMatchesReference() {
        let cases = self.buildCases()
        var comparisons = 0
        for (labelA, a) in cases {
            for (labelB, b) in cases {
                self.assertMatchesReference(a, b, "\(labelA) x \(labelB)")
                comparisons += 1
            }
        }
        // Proves the loop ran and pins the matrix against silently shrinking. Raise the floor when
        // adding cases; never lower it to make a failing run pass.
        XCTAssertGreaterThanOrEqual(cases.count, 44)
        XCTAssertEqual(comparisons, cases.count * cases.count)
    }

    /// Guards against the differential test passing vacuously — e.g. a matrix where every pair
    /// returns `.none` would match any implementation that always returns `.none`.
    ///
    /// Note the expected set excludes `.semanticallyMerged`, which this function *cannot* return.
    /// The style accumulator starts at `fullyMerged` (raw 1) and only ever decreases
    /// (`if style < upperStyle`), so a sticker's `.semanticallyMerged` (raw 2) is never `< 1` and
    /// cannot survive. The sticker branch of `mediaMergeableStyle` is therefore dead in its only
    /// consumer. That is pre-existing behavior, faithfully reproduced by `chatMessageMerge`; this
    /// assertion pins it so a future change to the enum's raw values does not silently alter merge
    /// results.
    func testMatrixIsNotDegenerate() {
        let cases = self.buildCases()
        var seen = Set<Int32>()
        for (_, a) in cases {
            for (_, b) in cases {
                seen.insert(referenceMessagesShouldBeMerged(accountPeerId: accountPeerIdForTests, a, b).rawValue)
            }
        }
        XCTAssertEqual(seen, Set([ChatMessageMerge.none.rawValue,
                                  ChatMessageMerge.fullyMerged.rawValue]),
                       "the matrix must exercise both reachable merge outcomes")
    }

    /// Pins the unreachability of `.semanticallyMerged` directly, so the reasoning above is
    /// checked rather than merely asserted in a comment.
    func testSemanticallyMergedIsUnreachable() {
        XCTAssertLessThan(ChatMessageMerge.fullyMerged.rawValue,
                          ChatMessageMerge.semanticallyMerged.rawValue,
                          "if semanticallyMerged ever sorts below fullyMerged it becomes reachable "
                          + "and both chatMessageMerge and its callers need review")
    }
}
