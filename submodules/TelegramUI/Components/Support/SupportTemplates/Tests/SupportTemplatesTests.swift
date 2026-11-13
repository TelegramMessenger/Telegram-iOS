import XCTest
@testable import SupportTemplates

private func parse(_ text: String) -> SupportTemplatesFile {
    return parseSupportTemplatesFile(text.data(using: .utf8)!)
}

final class SupportTemplatesParserTests: XCTestCase {
    func testParsesBlocksWithUrlKeysAndMultilineValue() {
        let file = parse("""
        {URL}
        https://example.com/tl_main.txt

        {QUESTION}
        How do I reset my password?
        {KEYS}
        reset
          Pass Word
        {VALUE}

        Open Settings.

        Tap Reset.\r

        {QUESTION}
        Second one
        {VALUE}
        Answer
        """)
        XCTAssertEqual(file.url, "https://example.com/tl_main.txt")
        XCTAssertEqual(file.questions.count, 2)
        let first = file.questions["howdoiresetmypassword"]
        XCTAssertEqual(first?.question, "How do I reset my password?")
        XCTAssertEqual(first?.originalKeys, ["reset", "Pass Word"])
        XCTAssertEqual(first?.normalizedKeys, ["reset", "pass word"])
        XCTAssertEqual(first?.value, "Open Settings.\n\nTap Reset.")
        XCTAssertEqual(file.questions["secondone"]?.value, "Answer")
    }

    func testIgnoresLowercaseAndInlineTokensAndTextBeforeFirstToken() {
        let file = parse("""
        preamble line
        {QUESTION}
        Q
        {VALUE}
        {value}
        text {VALUE}
        """)
        XCTAssertEqual(file.questions["q"]?.value, "{value}\ntext {VALUE}")
    }

    func testValueLinesKeepTrailingSpacesOnly() {
        let file = parse("{QUESTION}\nQ\n{KEYS}\n h \n{VALUE}\n  Hola. \r\n\tsecond line  \n   \nthird \r\n{QUESTION}\nR\n{VALUE}\nend \n")
        XCTAssertEqual(file.questions["q"]?.value, "Hola. \nsecond line  \n\nthird ")
        XCTAssertEqual(file.questions["q"]?.originalKeys, ["h"])
        XCTAssertEqual(file.questions["r"]?.value, "end ")
    }

    func testSecondValueIsLost() {
        let file = parse("{QUESTION}\nQ\n{VALUE}\nfirst\n{VALUE}\nsecond\n")
        XCTAssertEqual(file.questions.count, 1)
        XCTAssertEqual(file.questions["q"]?.value, "first")
    }

    func testSecondKeysSectionIsIgnored() {
        let file = parse("{QUESTION}\nQ\n{KEYS}\na\n{KEYS}\nb\n{VALUE}\nv")
        XCTAssertEqual(file.questions["q"]?.originalKeys, ["a"])
    }

    func testSecondKeysSectionIsAcceptedAfterAnEmptyFirst() {
        let file = parse("{QUESTION}\nQ\n{KEYS}\n\n{KEYS}\nb\n{VALUE}\nv")
        XCTAssertEqual(file.questions["q"]?.originalKeys, ["b"])
    }

    func testBlockWithoutValueMergesIntoTheNext() {
        let file = parse("{QUESTION}\nq1\n{KEYS}\nk\n{QUESTION}\nq2\n{VALUE}\nv")
        XCTAssertEqual(file.questions.count, 1)
        XCTAssertEqual(file.questions["q1"]?.originalKeys, ["k"])
        XCTAssertEqual(file.questions["q1"]?.value, "v")
    }

    func testQuestionWithoutValueAtTheEndIsKept() {
        let file = parse("{QUESTION}\nOnly a question")
        XCTAssertEqual(file.questions["onlyaquestion"]?.value, "")
    }

    func testQuestionWithoutLettersOrDigitsIsDropped() {
        let file = parse("{QUESTION}\n?!\n{VALUE}\nv")
        XCTAssertTrue(file.questions.isEmpty)
        XCTAssertTrue(file.isEmpty)
    }

    func testFirstDuplicateQuestionWins() {
        let file = parse("{QUESTION}\nSame?\n{VALUE}\none\n{QUESTION}\nsame\n{VALUE}\ntwo")
        XCTAssertEqual(file.questions["same"]?.value, "one")
    }

    func testUnknownTokenEndsTheValueAndIgnoresWhatFollows() {
        let file = parse("{QUESTION}\nQ\n{VALUE}\nv\n{OTHER}\nignored\n{QUESTION}\nR\n{VALUE}\nw")
        XCTAssertEqual(file.questions["q"]?.value, "v")
        XCTAssertEqual(file.questions["r"]?.value, "w")
    }

    func testFirstUrlWinsForTheWholeFile() {
        let file = parse("{URL}\n\nfirst\nsecond\n{URL}\nthird")
        XCTAssertEqual(file.url, "first")
    }

    func testFileNames() {
        XCTAssertTrue(isSupportTemplatesFileName("tl_main.txt"))
        XCTAssertTrue(isSupportTemplatesFileName("TL_Main.TXT"))
        XCTAssertFalse(isSupportTemplatesFileName("main.txt"))
        XCTAssertFalse(isSupportTemplatesFileName("tl_main.txt.old"))
    }
}

final class SupportTemplatesNormalizationTests: XCTestCase {
    func testQuestionKeepsLowercaseLettersAndDigitsWithAccents() {
        XCTAssertEqual(supportTemplatesNormalizedQuestion("Café: Ёлка 42?"), "caféёлка42")
    }

    func testKeyIsTrimmedLoweredAndLosesAccents() {
        XCTAssertEqual(supportTemplatesNormalizedKey("  Café Crème "), "cafe creme")
        XCTAssertEqual(supportTemplatesNormalizedKey("Ёлка"), "елка")
        XCTAssertEqual(supportTemplatesNormalizedKey("Йод"), "йод")
        XCTAssertEqual(supportTemplatesNormalizedKey("ＡＢＣ１"), "abc1")
        XCTAssertEqual(supportTemplatesNormalizedKey("e\u{301}"), "e")
    }

    func testSearchWordsSplitOnTDesktopSeparators() {
        XCTAssertEqual(supportTemplatesSearchWords("  Hello, world! a_b-c @x what? #tag "), ["hello", "world", "a", "b", "c", "x", "what?", "#tag"])
    }
}

final class SupportTemplatesSearchTests: XCTestCase {
    private func makeTemplates() -> SupportTemplates {
        let main = parse("""
        {QUESTION}
        Payment failed
        {KEYS}
        payment
        {VALUE}
        Please try another card.

        {QUESTION}
        How to pay
        {VALUE}
        Use a payment card.

        {QUESTION}
        Delete account
        {KEYS}
        del
        {VALUE}
        Go to the deletion page.
        """)
        let extra = parse("""
        {QUESTION}
        How to pay
        {VALUE}
        Use a card.
        """)
        return SupportTemplates(files: ["tl_a.txt": main, "tl_b.txt": extra])
    }

    func testKeyOutranksQuestionAndPrefixMatchIsNotDoubled() {
        let results = makeTemplates().query("pay")
        XCTAssertEqual(results.map(\.question), ["Payment failed", "How to pay", "How to pay"])
    }

    func testExactKeyWordScoresDouble() {
        let templates = makeTemplates()
        XCTAssertEqual(templates.query("payment").first?.question, "Payment failed")
    }

    func testTiesSortByFileNameDescending() {
        let results = makeTemplates().query("how")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].value, "Use a card.")
        XCTAssertEqual(results[1].value, "Use a payment card.")
    }

    func testEveryWordMustMatch() {
        let templates = makeTemplates()
        XCTAssertEqual(templates.query("pay card").map(\.question), ["Payment failed", "How to pay", "How to pay"])
        XCTAssertTrue(templates.query("pay zebra").isEmpty)
        XCTAssertTrue(templates.query("").isEmpty)
        XCTAssertTrue(templates.query("!!!").isEmpty)
    }

    func testResultsAreLimitedToTen() {
        var text = ""
        for i in 0 ..< 15 {
            text += "{QUESTION}\nTopic \(i)\n{VALUE}\nanswer\n"
        }
        let templates = SupportTemplates(files: ["tl_many.txt": parse(text)])
        XCTAssertEqual(templates.query("topic").count, SupportTemplates.queryLimit)
    }

    func testMatchExact() {
        let templates = makeTemplates()
        XCTAssertEqual(templates.maxKeyLength, 7)
        XCTAssertEqual(templates.matchExact(" DEL ")?.question.question, "Delete account")
        XCTAssertNil(templates.matchExact("de"))
        XCTAssertNil(templates.matchExact(""))
        XCTAssertNil(templates.matchExact("payment!"))
    }

    func testMatchFromEndTakesTheLongestKey() {
        let templates = SupportTemplates(files: ["tl_k.txt": parse("""
        {QUESTION}
        Short
        {KEYS}
        ay
        {VALUE}
        s
        {QUESTION}
        Long
        {KEYS}
        pay
        {VALUE}
        l
        """)])
        XCTAssertEqual(templates.matchFromEnd("please PAY")?.key, "pay")
        XCTAssertEqual(templates.matchFromEnd("okay")?.key, "ay")
        XCTAssertNil(templates.matchFromEnd("pay "))
        XCTAssertNil(templates.matchFromEnd(""))
    }
}

final class SupportHashtagStripTests: XCTestCase {
    private struct Entity: Equatable {
        var range: Range<Int>
    }

    private func strip(_ text: String, _ ranges: [Range<Int>] = []) -> (String, [Range<Int>]) {
        let result = supportStrippingHashtag(text: text, entities: ranges.map(Entity.init), range: { $0.range }, updatedRange: { entity, range in
            var entity = entity
            entity.range = range
            return entity
        })
        return (result.text, result.entities.map(\.range))
    }

    func testStripsTrailingTagGroup() {
        XCTAssertEqual(strip("Hello\n#tsf_a #TSFb more_words").0, "Hello")
        XCTAssertEqual(strip("Hello #tsf").0, "Hello ")
        XCTAssertEqual(strip("Hello\n\n#tsf").0, "Hello\n")
        XCTAssertEqual(strip("Hello\r\n#tsf").0, "Hello\r")
        XCTAssertEqual(strip("abc#tsf").0, "abc")
        XCTAssertEqual(strip("#tsf_x").0, "")
    }

    func testLeavesTextWithoutAStrippableTag() {
        XCTAssertEqual(strip("Hello #tsf.").0, "Hello #tsf.")
        XCTAssertEqual(strip("Hello #tsf привет").0, "Hello #tsf привет")
        XCTAssertEqual(strip("Hello #ts").0, "Hello #ts")
        XCTAssertEqual(strip("Hello #tsf\u{A0}x").0, "Hello #tsf\u{A0}x")
    }

    func testLaterTagStripsWhenAnEarlierOneIsBlocked() {
        XCTAssertEqual(strip("a #tsf. b #tsf_c").0, "a #tsf. b ")
    }

    func testEntitiesShrinkToTheCut() {
        let (text, ranges) = strip("hello wo\n#tsf", [0 ..< 13, 3 ..< 10, 6 ..< 8, 8 ..< 9, 10 ..< 13])
        XCTAssertEqual(text, "hello wo")
        XCTAssertEqual(ranges, [0 ..< 8, 3 ..< 8, 6 ..< 8])
    }

    func testWholeTextRemovedDropsEntities() {
        let (text, ranges) = strip("#tsf", [0 ..< 4])
        XCTAssertEqual(text, "")
        XCTAssertEqual(ranges, [])
    }

    func testCountsUtf16Units() {
        let (text, ranges) = strip("😀 hi\n#tsf", [0 ..< 8])
        XCTAssertEqual(text, "😀 hi")
        XCTAssertEqual(ranges, [0 ..< 5])
    }
}
