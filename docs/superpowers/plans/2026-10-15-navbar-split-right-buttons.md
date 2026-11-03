# Split Right Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The glass navigation bar groups its right buttons into pills by UIKit's rule (a text or prominent button alone,
neighbouring icon/custom buttons together), any number of pills, paired by index in push/pop, and a pill that comes or
goes in place grows out of / is sucked into its nearest neighbour as iOS 27's glass does.

**Architecture:** One pure rule (`navigationBarRightSections`) feeds `NavigationBarButtonPlacement`; the content view and
the bar view replace their fixed capsule + accent circle with an array of pills (index 0 outermost); the in-place
animator's right slot and the transition view's right roles become an index; the in-place animator learns SwiftUI's
matched removal/insertion by lending both pills' glass (items included) to one merging container at smoothness 12,
reusing the push/pop resolver functions.

**Tech Stack:** Swift, UIKit, ComponentFlow, the repo's GlassBackgroundComponent, Bazel via `Make.py`, XCTest
(`ios_unit_test`), the native reference app `Tests/NativeNavigationReference` on the K2 simulator.

**Spec:** `docs/superpowers/specs/2026-10-15-navbar-split-right-buttons-design.md` (commits 460a0ad347, 3cecedbd4b).

## Global Constraints

- Worktree `/Users/isaac/build/telegram/telegram-ios/.claude/worktrees/navbar-split`, branch `navbar/split-buttons`. All
  paths below are relative to it. **Never push.** Commit messages end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The rule: "a `.text` button or a button whose tint is not `.generic` (accent, accent-disabled: UIKit's prominent items
  and the Done checkmark) closes the current pill and gets one of its own; `.icon`, `.image`, `.node`, `.custom` and
  `.more` buttons join the current pill." Buttons and pills are outermost first (`rightButtons[0]` is the outermost).
- Pills are `navigationBarInterSectionSpacing` (12 pt) apart; a pill is at least 44 pt wide.
- "Chats keeps its look": compose (accent) and the story/proxy pair come out as the same two pills; the inline-forum slide
  pairs each content's pills **from the inner end** (its existing tests stay unchanged and pass).
- iPhone Duo's side column is untouched.
- Push/pop: right platters pair by index from the edge; the title pill takes the second slot only when its bar has at most
  one right pill; a leftover merges into the other bar's **nearest** platter.
- In place: compare old and new pills by index from the edge; a pill that goes collapses into the nearest remaining pill,
  one that comes grows out of the nearest previous pill; none left: dematerialize in place; Reduce Motion: opacity only;
  without native glass merging: fade in its own container.
- Never a still copy (snapshot, render) of bar content in an animation: lend live views (user rule 2026-10-15).
- TDD: every behaviour change has a test that fails first for the behavioural reason. Guard tests that pin existing
  behaviour say so and may pass on write.
- Tests run through Make.py from the worktree root. Shorthands used below:
  - `NBC_TEST` = `source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache test --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --target //submodules/TelegramUI/Components/NavigationBarComponent:NavigationBarComponentTests > /tmp/nbc.log 2>&1; echo exit=$?; grep -E "Executed [0-9]+ tests" bazel-testlogs/submodules/TelegramUI/Components/NavigationBarComponent/NavigationBarComponentTests/test.log | tail -1; grep -E "error:|failed \(" /tmp/nbc.log | head -20`
  - `NBN_TEST` = the same with `--target //submodules/TelegramUI/Components/NavigationBarNode:NavigationBarNodeTests`,
    log `/tmp/nbn.log`, test log `bazel-testlogs/submodules/TelegramUI/Components/NavigationBarNode/NavigationBarNodeTests/test.log`.
  - `APP_BUILD` = `source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64 > /tmp/app.log 2>&1; echo exit=$?; grep -a "Build completed\|error:" /tmp/app.log | head`
  - A test process can SIGTRAP after "0 failures" (a freed `UIWindow`): read both the exit status and the "Executed" line.
- Simulators: the logged-in app runs on "iPhone 18 Pro" `3A36B4F5-C2D0-41AA-8203-E46EA58CD43D`; the reference app on K2
  `E643A78E-DB62-4DA4-9F54-BD0836F434AF`. **Never mark messages read:** open only chats without unread messages;
  screenshot and locate a row before every tap. Drive with `axe touch -x X -y Y --down --up --delay 0.08 --udid …`
  (one invocation; two separate calls make a long press).

## Review Focus

1. **A push or pop starting mid-merge** (Edit tapped, then back tapped at once): the lent glass must be back in its
   pills and the merging container gone before the transition takes the bar's glass, or glass floats over the
   transition. Test: Task 5 `test_inPlaceMerge_platterDetachMidMerge_reclaimsTheGlass`.
2. **A long press on the partner while it merges** (context menu): the merge finishes and the glass is reclaimed before
   the menu extracts the container. Test: Task 5 `test_inPlaceMerge_contextMenuMidMerge_reclaimsTheGlass`.
3. **A relayout mid-merge** (rotation, a width change): every pill settles at its new frame and every glass is
   reclaimed. Test: Task 5 `test_inPlaceMerge_relayoutMidMerge_settlesAtTheNewFrames`.
4. **Done toggling enabled/disabled** (accent ↔ accent-disabled, Edit screens that validate input): no split, merge or
   item swap, only a retint. Test: Task 3 `test_rightPills_doneEnabledToggle_keepsThePills` (guard).
5. **A tap on the arriving pill mid-eject** (Done → Edit, then search tapped at once): the search button gets the tap
   while its glass is lent. Test: Task 5 `test_inPlaceMerge_arrivingPill_takesTapsAtOnce`.

---

### Task 0: Worktree setup (submodules)

The worktree was created without its submodules; the build needs them.

- [ ] **Step 1: Initialize submodules from the main checkout's copies (no network)**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/navbar-split
MAIN=/Users/isaac/build/telegram/telegram-ios
for p in $(git config --file .gitmodules --get-regexp '\.path$' | awk '{print $2}'); do
  git submodule update --init --reference "$MAIN/$p" -- "$p" || echo "FAILED $p"
done
git submodule update --init --recursive
git submodule status --recursive | grep -v '^ ' ; echo "(lines above: submodules not at their pins; expect none)"
```

Expected: no `FAILED` lines; the final command prints nothing above its note.

- [ ] **Step 2: Baseline suites green before any change**

Run: `NBC_TEST` and `NBN_TEST`.
Expected: `exit=0`, `Executed 139 tests, with 0 failures` and `Executed 76 tests, with 0 failures`.

---

### Task 1: Native measurement of the Administrators case

**Files:**
- Modify: `Tests/NativeNavigationReference/main.swift` (header comment; `applyRightItems(animated:)`)
- Modify: `docs/superpowers/specs/2026-10-15-navbar-split-right-buttons-design.md` ("How a pill comes and goes in place")

**Interfaces:**
- Produces: the measured order and timings that Task 5 implements (written into the spec).

- [ ] **Step 1: Add the `-adminsRight 1` flag**

In the header comment, after the `-prominentRight 1` paragraph, add:

```swift
// -adminsRight 1 (2026-10-15): the root's right items are Channel Administrators': [Edit (text), search (image)] <->
//   [the system Done item], toggled by -scenario editDone, each change with new items (as ItemListController makes).
//   For UIKit's in-place split and merge of a text pill and an image pill.
```

At the top of `applyRightItems(animated:)`, before the `prominentRight` branch:

```swift
        if UserDefaults.standard.bool(forKey: "adminsRight") && self.depth == 0 {
            if self.isEditingState {
                items.append(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.toggleEditDone)))
            } else {
                items.append(UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(self.toggleEditDone)))
                items.append(UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .plain, target: nil, action: nil))
            }
            self.navigationItem.setRightBarButtonItems(items, animated: animated)
            return
        }
```

- [ ] **Step 2: Build and install on K2**

Run: `Tests/NativeNavigationReference/build.sh E643A78E-DB62-4DA4-9F54-BD0836F434AF`
Expected: prints the `.app` path, no errors.

- [ ] **Step 3: Film both directions**

```bash
SD=/private/tmp/claude-501/-Users-isaac-build-telegram-telegram-ios/d0191f01-ab35-477d-a5a4-3f087b8c7346/scratchpad/split
K2=E643A78E-DB62-4DA4-9F54-BD0836F434AF; B=org.telegram.NativeNavigationReference
xcrun simctl terminate $K2 $B 2>/dev/null
xcrun simctl launch $K2 $B -scenario editDone -interval 2.5 -adminsRight 1 >/dev/null; sleep 0.5
xcrun simctl io $K2 recordVideo --codec h264 --force $SD/admins.mp4 >/dev/null 2>&1 & VP=$!; sleep 9; kill -INT $VP; wait
python3 $SD/../chats/sheetw.py $SD/admins.mp4 $SD/admins-coarse.png 700:150:506:180 280:60 0.0 9.0 5 12
```

Then sheet every frame of each change (find the change times on the coarse sheet; one change every 2.5 s):
`python3 $SD/../chats/sheetw.py $SD/admins.mp4 $SD/admins-merge.png 700:150:506:180 280:60 <t0> <t0+0.65> 5 1` and the
same for the next change into `admins-eject.png`.

Expected: Edit → Done: the search pill joins Done through a neck and is absorbed; Done → Edit: search grows out of
Edit. Record, with frame times relative to the change's first changed frame:
- merge: when search starts moving, when the neck appears, when it is absorbed, whether and when the partner pulses
  (before or after absorption), when the partner's item swap (Edit → checkmark) happens, when everything rests;
- eject: when the partner's swap and pulse happen, when search starts to emerge, when it separates, when it rests.

- [ ] **Step 3b: Compare with an eject whose partner does not swap**

Run `-scenario oneTwo` (`[Edit]` ↔ `[Edit, +]`, already filmed this session as `ot.mp4`) side by side: if the partner
swells before the eject only in `-adminsRight` (where its item swaps), the swell is the item swap; if in both, it
belongs to the insertion.

- [ ] **Step 4: Write the results into the spec**

Replace the paragraph starting "Whether Edit's swell before an insertion belongs to the merge…" in "How a pill comes and
goes in place" with a "Measured (Administrators case, 2026-10-15)" list of the times from Step 3 and the Step 3b
conclusion, and state in section 2 which order Task 5 implements. If the partner's pulse is tied to its item swap,
section 2 stays as written; if the insertion itself delays its emergence, add the measured delay there.

- [ ] **Step 5: Commit**

```bash
git add Tests/NativeNavigationReference/main.swift docs/superpowers/specs/2026-10-15-navbar-split-right-buttons-design.md
git commit -m "Reference app: Channel Administrators' right items; spec: the measured split and merge

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The rule

**Files:**
- Modify: `submodules/TelegramUI/Components/NavigationBarComponent/Sources/NavigationBarRowLayout.swift`
- Test: `submodules/TelegramUI/Components/NavigationBarComponent/Tests/NavigationBarRowLayoutTests.swift`

**Interfaces:**
- Produces:
  - `func navigationBarButtonRequiresOwnSection(_ button: NavigationBarComponent.Button) -> Bool`
  - `func navigationBarRightSections(_ buttons: [NavigationBarComponent.Button]) -> [[NavigationBarComponent.Button]]`
    (input and output outermost first; each pill's buttons outermost first)

- [ ] **Step 1: Write the failing tests**

Append to `NavigationBarRowLayoutTests`:

```swift
    private func sectionIds(_ sections: [[NavigationBarComponent.Button]]) -> [[AnyHashable]] {
        return sections.map { $0.map(\.id) }
    }

    // UIKit's sections (`_requiresOwnSection`, asked of UIKit on iOS 27, spec): a text button gets a pill of its own, so
    // Channel Administrators' Edit and search are two pills, Edit outermost.
    func test_rightSections_textBesideIcon_areTwoPills() {
        let sections = navigationBarRightSections([self.button("edit", .text(title: "Edit", isBold: false)), self.button("search", .icon(imageName: "S"))])
        XCTAssertEqual(self.sectionIds(sections), [["edit"], ["search"]])
    }

    // Neighbouring icon buttons share one pill.
    func test_rightSections_icons_shareOnePill() {
        let sections = navigationBarRightSections([self.button("search", .icon(imageName: "S")), self.button("add", .image(UIImage()))])
        XCTAssertEqual(self.sectionIds(sections), [["search", "add"]])
    }

    // Chats: the accent compose button alone, story and proxy together, as today.
    func test_rightSections_chats_areTheCircleAndTheCapsule() {
        let sections = navigationBarRightSections([self.accent("compose"), self.button("story", .icon(imageName: "S")), self.button("proxy", .icon(imageName: "P"))])
        XCTAssertEqual(self.sectionIds(sections), [["compose"], ["story", "proxy"]])
    }

    // Every prominent item gets a pill of its own (UIKit), a disabled Done included; a second one too.
    func test_rightSections_everyAccentButton_isAlone() {
        let sections = navigationBarRightSections([self.accent("a"), self.button("x", .icon(imageName: "X")), self.accent("b", tint: .accentDisabled)])
        XCTAssertEqual(self.sectionIds(sections), [["a"], ["x"], ["b"]])
    }

    func test_rightSections_twoTexts_areTwoPills() {
        let sections = navigationBarRightSections([self.button("select", .text(title: "Select", isBold: false)), self.button("edit", .text(title: "Edit", isBold: true))])
        XCTAssertEqual(self.sectionIds(sections), [["select"], ["edit"]])
    }

    // Node, custom and more buttons join their neighbours like icons; a text button in the middle splits them.
    func test_rightSections_nodeAndCustomJoin_textSplits() {
        let node = self.button("node", .node(ASDisplayNode()))
        let custom = NavigationBarComponent.Button(id: "custom", content: .custom(AnyComponent(TestButtonContentComponent())), action: { _ in })
        let sections = navigationBarRightSections([node, custom, self.button("t", .text(title: "T", isBold: false)), self.button("more", .more)])
        XCTAssertEqual(self.sectionIds(sections), [["node", "custom"], ["t"], ["more"]])
    }

    func test_rightSections_none() {
        XCTAssertTrue(navigationBarRightSections([]).isEmpty)
    }
```

Add `import AsyncDisplayKit` to the file's imports if it is not there.

Add a stub to `NavigationBarRowLayout.swift` so the tests compile and fail on their assertions:

```swift
func navigationBarButtonRequiresOwnSection(_ button: NavigationBarComponent.Button) -> Bool {
    return false
}

func navigationBarRightSections(_ buttons: [NavigationBarComponent.Button]) -> [[NavigationBarComponent.Button]] {
    return buttons.isEmpty ? [] : [buttons]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `NBC_TEST`
Expected: FAIL. `test_rightSections_textBesideIcon_areTwoPills`, `test_rightSections_chats_areTheCircleAndTheCapsule`,
`test_rightSections_everyAccentButton_isAlone`, `test_rightSections_twoTexts_areTwoPills`,
`test_rightSections_nodeAndCustomJoin_textSplits` fail on `XCTAssertEqual`; the icon and empty tests pass.

- [ ] **Step 3: Implement the rule**

Replace the stub with:

```swift
/// Whether UIKit gives a bar button a section (a glass pill) of its own: `-[UIBarButtonItem _requiresOwnSection]`,
/// asked of UIKit on iOS 27 (spec 2026-10-15-navbar-split-right-buttons-design.md): true for every text item and every
/// prominent one (the Done checkmark included); false for image, system-image and custom-view items.
func navigationBarButtonRequiresOwnSection(_ button: NavigationBarComponent.Button) -> Bool {
    if case .text = button.content {
        return true
    }
    return button.tint != .generic
}

/// The right side's pills, as `-[UINavigationItem _addImplicitTopBarSectionsFromItems:toSections:forPlacement:]` builds
/// sections: walking the buttons outermost first, one that requires its own section closes the current pill and takes
/// one alone; any other joins the current pill. Pills and their buttons are outermost first.
func navigationBarRightSections(_ buttons: [NavigationBarComponent.Button]) -> [[NavigationBarComponent.Button]] {
    var sections: [[NavigationBarComponent.Button]] = []
    var current: [NavigationBarComponent.Button] = []
    for button in buttons {
        if navigationBarButtonRequiresOwnSection(button) {
            if !current.isEmpty {
                sections.append(current)
                current = []
            }
            sections.append([button])
        } else {
            current.append(button)
        }
    }
    if !current.isEmpty {
        sections.append(current)
    }
    return sections
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `NBC_TEST`
Expected: `exit=0`, `Executed 146 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add submodules/TelegramUI/Components/NavigationBarComponent/Sources/NavigationBarRowLayout.swift submodules/TelegramUI/Components/NavigationBarComponent/Tests/NavigationBarRowLayoutTests.swift
git commit -m "Navigation bar: UIKit's rule for which right buttons share a glass pill

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Right pills as an array through the bar

The fixed capsule and accent circle become an array of pills in the placement, the content view and the bar view; the
in-place right slot becomes an index; the transition view maps pills 0 and 1 onto its existing two right roles (Task 4
generalizes them). Each layer compiles only together, so this task changes them all.

**Files:**
- Modify: `submodules/TelegramUI/Components/NavigationBarComponent/Sources/NavigationBarRowLayout.swift`
- Modify: `submodules/TelegramUI/Components/NavigationBarComponent/Sources/NavigationBarContentView.swift`
- Modify: `submodules/TelegramUI/Components/NavigationBarComponent/Sources/NavigationBarComponent.swift`
- Modify: `submodules/TelegramUI/Components/NavigationBarComponent/Sources/NavigationBarInPlaceAnimation.swift`
- Modify: `submodules/TelegramUI/Components/NavigationBarComponent/Sources/NavigationBarPlatterTransitionView.swift`
- Test: `…/NavigationBarComponent/Tests/NavigationBarComponentViewTests.swift`, `…/NavigationBarRowLayoutTests.swift`,
  `…/NavigationBarRegularScreenLayoutTests.swift`, `submodules/TelegramUI/Components/NavigationBarNode/Tests/NavigationBarNodeTests.swift`

**Interfaces:**
- Consumes: `navigationBarRightSections(_:)` (Task 2).
- Produces (all internal to `NavigationBarComponent` unless marked public):
  - `NavigationBarButtonPlacement.rowRightSections: [[NavigationBarComponent.Button]]` (replaces `rowRightButtons`,
    `rowCircleItem`).
  - `struct NavigationBarRightPillMetrics: Equatable { var width: CGFloat; var extent: CGFloat }`
  - `func navigationBarRightPillMetrics(widths: [CGFloat]) -> [NavigationBarRightPillMetrics]`
  - `func navigationBarRightButtonsExtent(_ pills: [NavigationBarRightPillMetrics]) -> CGFloat` (replaces the
    `capsuleWidth:circleWidth:` form; `navigationBarRightCircleExtent` is deleted)
  - `func navigationBarRightPillSlots(primaryCount: Int, secondaryCount: Int) -> [(primary: Int?, secondary: Int?)]`
  - `func navigationBarInterpolatedRightPills(primary: [NavigationBarRightPillMetrics], secondary: [NavigationBarRightPillMetrics], fraction: CGFloat) -> [NavigationBarRightPillMetrics]`
  - `NavigationBarContentView`: `rightPillContainers: [UIView]`, `func rightPillContainer(at: Int) -> UIView`,
    `rightPillWidths: [CGFloat]`, `rightPillTints: [NavigationBarComponent.Button.Tint]`, `rightPillButtonCounts: [Int]`
    (replace `rightButtonsContainer`, `rightCircleContainer`, `rightButtonsWidth`, `rightCircleWidth`,
    `rightCapsuleTint`, `rightCircleTint`, `rightButtonCount`).
  - `final class NavigationBarRightPill { let itemsContainer: UIView; var background: GlassContextExtractableContainer?; var appliedTint: NavigationBarComponent.Button.Tint }`
  - `NavigationBarComponent.View`: `rightPills: [NavigationBarRightPill]`, `func rightPillBackgroundContainer(at: Int) -> GlassContextExtractableContainer?`,
    `func appliedRightPillTint(at: Int) -> NavigationBarComponent.Button.Tint` (replace `rightButtonsContainer`,
    `rightButtonsBackgroundContainer`, `rightCircleContainer`, `rightCircleBackgroundContainer`, `appliedRightCircleTint`);
    storage `detachedRightPressScales: [CGFloat]`, `detachedRightPressGlows: [CGFloat]` behind the unchanged public
    `detachedPressScale(isLeft:)`, `detachedPressGlow(isLeft:)` (right: index 0), `detachedInnerPressScale`,
    `detachedInnerPressGlow` (index 1). `primaryRightButtonsWidth` and `primaryHasRoomForTitlePill` keep their names.
  - `enum NavigationBarCapsuleSlot: Hashable { case left; case right(Int) }`.

- [ ] **Step 1: Write the failing tests**

In `NavigationBarComponentViewTests`, add (they use the new accessors; Step 2 adds stubs so they compile):

```swift
    private func editAndSearch() -> [NavigationBarComponent.Button] {
        return [NavigationBarComponent.Button(id: "edit", content: .text(title: "Edit", isBold: false), action: { _ in }), self.fixedButton("search")]
    }

    // Channel Administrators: Edit and search are two pills, Edit outermost at the right inset and search 12 pt before it.
    func test_rightPills_editAndSearch_areTwoPillsTwelvePointsApart() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        guard let edit = view.rightPillBackgroundContainer(at: 0), let search = view.rightPillBackgroundContainer(at: 1), let editButton = view.rightButtonViews["edit"], let searchButton = view.rightButtonViews["search"] else {
            XCTFail("not two pills")
            return
        }
        XCTAssertEqual(edit.frame.maxX, 390.0 - 16.0)
        XCTAssertEqual(search.frame, CGRect(x: edit.frame.minX - 12.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertTrue(editButton.isDescendant(of: edit))
        XCTAssertTrue(searchButton.isDescendant(of: search))
        // Each pill holds one button, so each morphs into its button's context menu.
        XCTAssertTrue(edit.morphsIntoContextMenu)
        XCTAssertTrue(search.morphsIntoContextMenu)
        XCTAssertTrue(view.navigationButtonContextContainer(sourceView: searchButton) === search)
    }

    // The title clears both pills and the gap between them.
    func test_rightPills_titleBand_clearsEveryPill() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        guard let edit = view.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        XCTAssertEqual(view.primaryRightButtonsWidth, edit.frame.width + 12.0 + 44.0)
        XCTAssertFalse(view.primaryHasRoomForTitlePill)
    }

    // Review focus 4 (guard): Done toggling enabled keeps the same two pills, only retinting.
    func test_rightPills_doneEnabledToggle_keepsThePills() {
        let bar = ComponentView<Empty>()
        let enabled = self.updateBar(bar, back: .back, right: [self.fixedButton("done", tint: .accent), self.fixedButton("search")], transition: .immediate)
        guard let done = enabled.rightPillBackgroundContainer(at: 0), let search = enabled.rightPillBackgroundContainer(at: 1) else {
            XCTFail("not two pills")
            return
        }
        let view = self.updateBar(bar, back: .back, right: [self.fixedButton("done", tint: .accentDisabled), self.fixedButton("search")], transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 0) === done)
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 1) === search)
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(0)))
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(1)))
        XCTAssertEqual(view.appliedRightPillTint(at: 0), .accentDisabled)
    }

    // A transition takes every pill and gives them back.
    func test_rightPills_leaveWithThePlatters_andComeBack() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        view.plattersDetached = true
        XCTAssertNil(view.rightPillBackgroundContainer(at: 0)?.superview)
        XCTAssertNil(view.rightPillBackgroundContainer(at: 1)?.superview)
        view.plattersDetached = false
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 1)?.superview === view)
    }
```

In `NavigationBarNodeTests`, add after `test_doneBesideAnotherItem_takesTheAccentCircle`:

```swift
    // ItemListController's right items are [secondary, primary] (search, Edit): the bar draws them as two pills, Edit
    // outermost, as UIKit does.
    func test_itemListPair_searchAndEdit_areTwoPills() {
        let node = self.makeNode()
        let item = UINavigationItem(title: "Administrators")
        item.rightBarButtonItems = [UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil), UIBarButtonItem(title: "Edit", style: .plain, target: nil, action: nil)]
        node.item = item
        node.previousItem = .item(UINavigationItem())
        self.layout(node)
        guard let rowView = node.rowViewForTesting, let edit = rowView.rightPillBackgroundContainer(at: 0), let search = rowView.rightPillBackgroundContainer(at: 1) else {
            XCTFail("not two pills")
            return
        }
        XCTAssertGreaterThan(edit.frame.minX, search.frame.maxX)
        XCTAssertEqual(edit.frame.minX - search.frame.maxX, 12.0)
    }
```

Note: `UIBarButtonItem(image: UIImage())` maps to `.image` (not empty: `navigationBarItemIsEmpty` treats an item with an
image as non-empty).

- [ ] **Step 2: Stubs so the tests compile, then run them**

Add to `NavigationBarComponent.View` (temporary, replaced in Step 6):

```swift
        func rightPillBackgroundContainer(at index: Int) -> GlassContextExtractableContainer? {
            if index == 0 {
                return self.rightCircleBackgroundContainer ?? self.rightButtonsBackgroundContainer
            }
            return index == 1 && self.rightCircleBackgroundContainer != nil ? self.rightButtonsBackgroundContainer : nil
        }

        func appliedRightPillTint(at index: Int) -> NavigationBarComponent.Button.Tint {
            return index == 0 ? self.appliedRightCircleTint : .generic
        }
```

and to `NavigationBarInPlaceAnimation.swift` (temporary):

```swift
extension NavigationBarComponent.View {
    func inPlaceStateForTesting(slot: Int) -> InPlaceState? {
        return nil
    }
}
```

and write the new component tests' `inPlaceStateForTesting(slot: .right(0))` calls as `inPlaceStateForTesting(slot: 0)`
for now (Step 6 switches them to `.right(…)`).

Run: `NBC_TEST` and `NBN_TEST`.
Expected: FAIL. `test_rightPills_editAndSearch_areTwoPillsTwelvePointsApart`, `test_rightPills_titleBand_clearsEveryPill`,
`test_rightPills_leaveWithThePlatters_andComeBack` and `test_itemListPair_searchAndEdit_areTwoPills` fail ("not two pills"
or a nil superview check: today Edit and search share one capsule). `test_rightPills_doneEnabledToggle_keepsThePills`
passes on the stubs (a guard).

- [ ] **Step 3: Placement and metrics (`NavigationBarRowLayout.swift`)**

Replace `navigationBarRightCircleExtent` and `navigationBarRightButtonsExtent(capsuleWidth:circleWidth:)` with:

```swift
/// One right pill of the row as laid out: its width, and its extent, how far it takes the pills inside it in from the
/// edge (its width and UIKit's gap before the next pill; the innermost pill's extent is its width).
struct NavigationBarRightPillMetrics: Equatable {
    var width: CGFloat
    var extent: CGFloat
}

/// The metrics of pills `widths` wide, outermost first.
func navigationBarRightPillMetrics(widths: [CGFloat]) -> [NavigationBarRightPillMetrics] {
    return widths.enumerated().map { index, width in
        return NavigationBarRightPillMetrics(width: width, extent: index == widths.count - 1 ? width : width + navigationBarInterSectionSpacing)
    }
}

/// How far a content's right pills reach from its inset.
func navigationBarRightButtonsExtent(_ pills: [NavigationBarRightPillMetrics]) -> CGFloat {
    return pills.reduce(0.0, { $0 + $1.extent })
}

/// The slots two contents' pills share while one slides over the other (an inline forum over Chats), outermost first,
/// paired from the inner end: each slot's pill index in either content, nil where that content has no pill there.
func navigationBarRightPillSlots(primaryCount: Int, secondaryCount: Int) -> [(primary: Int?, secondary: Int?)] {
    let count = max(primaryCount, secondaryCount)
    return (0 ..< count).map { slot in
        let primary = slot - (count - primaryCount)
        let secondary = slot - (count - secondaryCount)
        return (primary >= 0 ? primary : nil, secondary >= 0 ? secondary : nil)
    }
}

/// The pills of a slide `fraction` of the way from `primary` to `secondary`: each slot's width and extent interpolated,
/// a pill only one content has growing from, or narrowing to, nothing at its place.
func navigationBarInterpolatedRightPills(primary: [NavigationBarRightPillMetrics], secondary: [NavigationBarRightPillMetrics], fraction: CGFloat) -> [NavigationBarRightPillMetrics] {
    return navigationBarRightPillSlots(primaryCount: primary.count, secondaryCount: secondary.count).map { slot in
        let from = slot.primary.map { primary[$0] } ?? NavigationBarRightPillMetrics(width: 0.0, extent: 0.0)
        let to = slot.secondary.map { secondary[$0] } ?? NavigationBarRightPillMetrics(width: 0.0, extent: 0.0)
        return NavigationBarRightPillMetrics(width: from.width * (1.0 - fraction) + to.width * fraction, extent: from.extent * (1.0 - fraction) + to.extent * fraction)
    }
}
```

In `NavigationBarButtonPlacement`, replace the `rowRightButtons` and `rowCircleItem` members (and their doc comments) with:

```swift
    /// The row's right pills by UIKit's rule (`navigationBarRightSections`), outermost first.
    var rowRightSections: [[NavigationBarComponent.Button]]
```

and at the end of `navigationBarButtonPlacement(…)` replace the `rowRightButtons`/`rowCircleItem` computation and the
returned members with:

```swift
    let rowRightButtons = columnLayout != nil ? rightButtons.filter { !navigationBarIsColumnItem($0) } : rightButtons
    return NavigationBarButtonPlacement(
        columnLayout: columnLayout,
        columnItems: columnItems,
        trailingCircleItem: trailingCircleItem,
        leftButtonInColumn: leftButtonInColumn,
        rowLeftButton: leftButtonInColumn ? nil : leftButton,
        rowRightSections: navigationBarRightSections(rowRightButtons)
    )
```

- [ ] **Step 4: Content view (`NavigationBarContentView.swift`)**

Replace the members `rightButtonsContainer`, `rightCircleContainer`, `rightCircleWidth`, `rightCircleTint`,
`rightCapsuleTint`, `rightButtonsWidth` and `rightButtonCount` with:

```swift
    /// The row's right pills (`NavigationBarButtonPlacement.rowRightSections`), outermost first: each one's items, in a
    /// container the bar view hosts in that pill's glass. Containers are kept (emptied) when the pills get fewer.
    private(set) var rightPillContainers: [UIView] = []
    /// Width (at least 44 pt), tint and number of buttons of each pill shown, outermost first.
    private(set) var rightPillWidths: [CGFloat] = []
    private(set) var rightPillTints: [NavigationBarComponent.Button.Tint] = []
    private(set) var rightPillButtonCounts: [Int] = []

    /// Pill `index`'s items container, made on first use.
    func rightPillContainer(at index: Int) -> UIView {
        while self.rightPillContainers.count <= index {
            self.rightPillContainers.append(UIView())
        }
        return self.rightPillContainers[index]
    }
```

In `init`, delete the two lines creating `rightButtonsContainer` and `rightCircleContainer`.

`isInRow(_:)` becomes:

```swift
    private func isInRow(_ view: UIView) -> Bool {
        if view.superview === self.leftButtonsContainer {
            return true
        }
        return self.rightPillContainers.contains(where: { $0 === view.superview })
    }
```

In `updateTransitionAsPrevious`, replace the four lines on `rightButtonsContainer`/`rightCircleContainer` with:

```swift
        for container in self.rightPillContainers {
            alphaTransition.setAlpha(view: container, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setBlur(layer: container.layer, radius: fraction * 10.0)
        }
```

In `updateTransitionAsNext`, replace the lines on `rightButtonsContainer`/`rightCircleContainer` with:

```swift
        for container in self.rightPillContainers {
            alphaTransition.setAlpha(view: container, alpha: pow(fraction, 2.0))
            alphaTransition.setBlur(layer: container.layer, radius: (1.0 - fraction) * 10.0)
        }
```

In `update(…)`, replace the block from `var nextRightButtonX: CGFloat = 0.0` through
`self.rightCircleTint = placement.rowCircleItem?.tint ?? .generic` with:

```swift
        var validRightButtons = Set<AnyHashable>()
        var rightPillWidths: [CGFloat] = []
        for (index, section) in placement.rowRightSections.enumerated() {
            let container = self.rightPillContainer(at: index)
            var nextX: CGFloat = 0.0
            // Laid out left to right: the pill's innermost button first.
            for button in section.reversed() {
                validRightButtons.insert(button.id)
                let originX = nextX
                let buttonSize = self.updateButtonView(button, isLeft: false, container: container, theme: theme, rowWidth: size.width, availableHeight: size.height, transition: itemsTransition, alphaTransition: alphaTransition, frame: { buttonSize in
                    return CGRect(origin: CGPoint(x: originX, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
                })
                nextX += buttonSize.width
            }
            rightPillWidths.append(max(44.0, nextX))
        }
        self.rightPillWidths = rightPillWidths
        self.rightPillTints = placement.rowRightSections.map(navigationBarCapsuleTint)
        self.rightPillButtonCounts = placement.rowRightSections.map(\.count)
```

Further down, delete `self.rightButtonsWidth = nextRightButtonX` and `self.rightCapsuleTint = …`, and replace the right
extent line with:

```swift
        let rightExtent = rightInset + navigationBarRightButtonsExtent(navigationBarRightPillMetrics(widths: rightPillWidths))
```

- [ ] **Step 5: Bar view (`NavigationBarComponent.swift`)**

5a. Add above `extension NavigationBarComponent` (file scope):

```swift
/// One right pill of the row, index 0 outermost: the bar-level items container (it holds each content's items for this
/// pill) and its glass. Pills are kept (without glass) when the row has fewer, so a content's items keep their host.
final class NavigationBarRightPill {
    let itemsContainer: UIView
    var background: GlassContextExtractableContainer?
    /// The tint the last layout gave the glass.
    var appliedTint: NavigationBarComponent.Button.Tint = .generic

    init() {
        self.itemsContainer = UIView()
    }
}
```

5b. In `View`, replace `rightButtonsContainer`, `rightButtonsBackgroundContainer`, `rightCircleContainer`,
`rightCircleBackgroundContainer` and `appliedRightCircleTint` (and their doc comments) with:

```swift
        /// The row's right pills, outermost first (see `NavigationBarRightPill`).
        private(set) var rightPills: [NavigationBarRightPill] = []

        /// Pill `index`, made on first use.
        func rightPill(at index: Int) -> NavigationBarRightPill {
            while self.rightPills.count <= index {
                self.rightPills.append(NavigationBarRightPill())
            }
            return self.rightPills[index]
        }

        func rightPillBackgroundContainer(at index: Int) -> GlassContextExtractableContainer? {
            return index < self.rightPills.count ? self.rightPills[index].background : nil
        }

        func appliedRightPillTint(at index: Int) -> NavigationBarComponent.Button.Tint {
            return index < self.rightPills.count ? self.rightPills[index].appliedTint : .generic
        }

        private var rightBackgroundContainers: [GlassContextExtractableContainer] {
            return self.rightPills.compactMap(\.background)
        }
```

Delete the Step 2 stubs, `rightOuterBackgroundContainer` and `rightInnerBackgroundContainer`; in `init` delete the three
lines creating `rightButtonsContainer` (and its anchor point) and `rightCircleContainer`.

5c. Press storage: replace `detachedPressScales`, `detachedPressGlows` and `lastPressSample` tuples with:

```swift
        private var detachedLeftPressScale: CGFloat = 1.0
        private var detachedLeftPressGlow: CGFloat = 0.0
        /// The press UIKit was drawing on each right pill (index from the edge) when the platters were detached.
        private(set) var detachedRightPressScales: [CGFloat] = []
        private(set) var detachedRightPressGlows: [CGFloat] = []
        private var lastPressSample: (left: CGFloat, right: [CGFloat], time: Double)?
```

`samplePress()` becomes:

```swift
        private func samplePress() {
            let now = self.pressSamplerClock()
            let left = self.leftButtonsBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
            let right = self.rightPills.map { $0.background.flatMap(navigationBarCapsulePressScale) ?? 1.0 }
            if abs(left - 1.0) < 0.0005 && right.allSatisfy({ abs($0 - 1.0) < 0.0005 }) {
                if let sample = self.lastPressSample, now - sample.time < 0.1 {
                    // The press was just taken off: keep the last pressed sample for the hand-over.
                    return
                }
            } else {
                // A press held past the first window: its end is what the hand-over needs.
                self.pressSamplerDeadline = max(self.pressSamplerDeadline, now + 0.5)
            }
            self.lastPressSample = (left, right, now)
        }
```

In `plattersDetached`'s `didSet`, replace the detaching branch's press block (from `var pressScales = (` through the
`self.detachedPressGlows = (…)` assignment) with:

```swift
                        var leftScale = self.leftButtonsBackgroundContainer.flatMap(navigationBarCapsulePressScale) ?? 1.0
                        var rightScales = self.rightPills.map { $0.background.flatMap(navigationBarCapsulePressScale) ?? 1.0 }
                        // A press UIKit has already taken off (the touch just ended) is in the last sample.
                        if let sample = self.lastPressSample, now - sample.time < 0.1 {
                            if abs(leftScale - 1.0) < 0.0005 {
                                leftScale = sample.left
                            }
                            for index in rightScales.indices where abs(rightScales[index] - 1.0) < 0.0005 && index < sample.right.count {
                                rightScales[index] = sample.right[index]
                            }
                        }
                        self.lastPressSample = nil
                        self.detachedLeftPressScale = leftScale
                        self.detachedRightPressScales = rightScales
                        // A glow is always there with a press: when the glow layer cannot be found (a UIKit change), a
                        // press alone stands for a full one. A press passes 1.03 within ~20 ms, so 1.01 tells it from a
                        // reading that is merely not exactly 1.
                        func glow(_ container: GlassContextExtractableContainer?, press: CGFloat) -> CGFloat {
                            if let container, let glow = navigationBarCapsulePressGlow(container) {
                                return glow
                            }
                            return press > 1.01 ? 1.0 : 0.0
                        }
                        self.detachedLeftPressGlow = glow(self.leftButtonsBackgroundContainer, press: leftScale)
                        self.detachedRightPressGlows = zip(self.rightPills, rightScales).map { glow($0.background, press: $1) }
```

and the reset branch with:

```swift
                        self.detachedLeftPressScale = 1.0
                        self.detachedLeftPressGlow = 0.0
                        self.detachedRightPressScales = []
                        self.detachedRightPressGlows = []
```

The four public accessors become:

```swift
        public func detachedPressScale(isLeft: Bool) -> CGFloat {
            return isLeft ? self.detachedLeftPressScale : (self.detachedRightPressScales.first ?? 1.0)
        }

        public var detachedInnerPressScale: CGFloat {
            return self.detachedRightPressScales.count > 1 ? self.detachedRightPressScales[1] : 1.0
        }

        public var detachedInnerPressGlow: CGFloat {
            return self.detachedRightPressGlows.count > 1 ? self.detachedRightPressGlows[1] : 0.0
        }

        public func detachedPressGlow(isLeft: Bool) -> CGFloat {
            return isLeft ? self.detachedLeftPressGlow : (self.detachedRightPressGlows.first ?? 0.0)
        }
```

5d. `applyPlattersDetached()`: `let containers: [UIView] = ([self.leftButtonsBackgroundContainer].compactMap { $0 } as [UIView]) + self.rightBackgroundContainers`.
`navigationButtonContextContainer(sourceView:)`: replace the right capsule and circle checks with
`for container in self.rightBackgroundContainers where sourceView.isDescendant(of: container) { return container }`.
`hitTest`: replace the right capsule and circle checks with
`} else if self.rightBackgroundContainers.contains(where: { result.isDescendant(of: $0) }) { self.beginPressSampling() }`.
`animateButtonsIn(duration:)`: replace its two right-container lines with
`for container in contentView.rightPillContainers { container.layer.animateAlpha(from: 0.0, to: container.alpha, duration: duration) }`.
`primaryRightButtonsWidth`:
`return navigationBarRightButtonsExtent(navigationBarRightPillMetrics(widths: contentView.rightPillWidths))`.
`primaryHasRoomForTitlePill`: `return contentView.rightPillWidths.count < 2`.

5e. Content hosting: wherever a content view's `rightButtonsContainer`/`rightCircleContainer` was added to or removed
from the bar's containers (primary and secondary creation, primary removal, secondary removal in both branches), delete
those lines; the layout in 5f hosts each content's pill containers. For a removed content, add:
`for container in contentView.rightPillContainers { container.removeFromSuperview() }` beside its other removals.

5f. The in-place trigger, before the content update: replace `var inPlaceRight = false` / `var inPlaceCircle = false`
and their computation with:

```swift
            var inPlaceRight = Set<Int>()
            var previousRightPillCount = 0
            if let previousPrimary = previousComponent?.primaryContent {
                previousRightPillCount = navigationBarButtonPlacement(leftButton: previousPrimary.leftButton, rightButtons: previousPrimary.rightButtons, hasBack: previousPrimary.back != nil, columnLength: previousComponent?.sideColumnLength).rowRightSections.count
            }
```

and inside the existing `if !transition.animation.isImmediate {` block, after `inPlaceLeft = …`:

```swift
                    // UIKit's sections change apart, compared by index from the edge.
                    let previousSections = navigationBarButtonPlacement(leftButton: previousPrimary.leftButton, rightButtons: previousPrimary.rightButtons, hasBack: previousPrimary.back != nil, columnLength: nil).rowRightSections
                    let sections = navigationBarButtonPlacement(leftButton: primary.leftButton, rightButtons: primary.rightButtons, hasBack: primary.back != nil, columnLength: nil).rowRightSections
                    for index in 0 ..< max(previousSections.count, sections.count) {
                        let previous = index < previousSections.count ? previousSections[index] : []
                        let current = index < sections.count ? sections[index] : []
                        if navigationBarCapsuleItemsDiffer(previous, current) {
                            inPlaceRight.insert(index)
                        }
                    }
```

Replace `leavingRight`/`leavingCircle` with:

```swift
            var leavingRight: [Int: NavigationBarInPlaceCapsule.Items] = [:]
            for index in inPlaceRight {
                leavingRight[index] = self.inPlaceLeavingItems(slot: .right(index))
            }
            let itemsTransition: ComponentTransition = (inPlaceLeft || !inPlaceRight.isEmpty) ? .immediate : transition
```

5g. The right layout. In the block after the contents are updated, delete every line that reads or sets
`rightButtonsEffectiveWidth`, `rightCircleEffectiveWidth`, `rightCircleEffectiveExtent` and the content views'
`rightButtonsContainer`/`rightCircleContainer` frames (in both the two-content and the one-content branches; keep the
left-side lines), delete `rightButtonCount` and `rightCapsuleTintColor`, and replace the whole `if rightButtonsEffectiveWidth != 0.0 { … } else { … }`
block and the circle block after it (through the end of `if rightCircleEffectiveWidth != 0.0 { … } else if … { … }`) with:

```swift
            // The right pills. While two contents slide (an inline forum over Chats) their pills are paired from the
            // inner end, so today's slide is kept (spec, structure).
            let primaryPills = self.primaryContentView.map { navigationBarRightPillMetrics(widths: $0.rightPillWidths) } ?? []
            let secondaryPills = self.secondaryContentView.map { navigationBarRightPillMetrics(widths: $0.rightPillWidths) }
            let rightPillMetrics: [NavigationBarRightPillMetrics]
            let rightPillSlots: [(primary: Int?, secondary: Int?)]
            if let secondaryPills {
                rightPillMetrics = navigationBarInterpolatedRightPills(primary: primaryPills, secondary: secondaryPills, fraction: component.secondaryTransition)
                rightPillSlots = navigationBarRightPillSlots(primaryCount: primaryPills.count, secondaryCount: secondaryPills.count)
            } else {
                rightPillMetrics = primaryPills
                rightPillSlots = primaryPills.indices.map { ($0, nil) }
            }
            let rightEdge = availableSize.width - component.rightInset - component.trailingButtonsInset
            let isDark = component.theme.overallDarkAppearance
            var outerExtent: CGFloat = 0.0
            for (slot, metrics) in rightPillMetrics.enumerated() {
                let pill = self.rightPill(at: slot)
                let frame = CGRect(x: rightEdge - outerExtent - metrics.width, y: 0.0, width: metrics.width, height: 44.0)
                outerExtent += metrics.extent
                let owners = rightPillSlots[slot]

                // Each content's items for this pill, right-aligned in it.
                var buttonCount = 0
                var primaryWeight: CGFloat = 0.0
                var secondaryWeight: CGFloat = 0.0
                var primaryTint: NavigationBarComponent.Button.Tint = .generic
                var secondaryTint: NavigationBarComponent.Button.Tint = .generic
                if let index = owners.primary, let contentView = self.primaryContentView {
                    let container = contentView.rightPillContainer(at: index)
                    if container.superview !== pill.itemsContainer {
                        pill.itemsContainer.addSubview(container)
                    }
                    let width = contentView.rightPillWidths[index]
                    let itemsFrame = CGRect(x: metrics.width - width, y: 0.0, width: width, height: 44.0)
                    if secondaryPills == nil {
                        (primaryContentTransition.animation.isImmediate ? primaryContentTransition : itemsTransition).setFrame(view: container, frame: itemsFrame)
                    } else {
                        primaryContentTransition.setFrame(view: container, frame: itemsFrame)
                    }
                    if self.secondaryContentView == nil || component.secondaryTransition < 1.0 {
                        buttonCount += contentView.rightPillButtonCounts[index]
                    }
                    primaryWeight = width * (secondaryPills == nil ? 1.0 : 1.0 - component.secondaryTransition)
                    primaryTint = contentView.rightPillTints[index]
                }
                if let index = owners.secondary, let contentView = self.secondaryContentView {
                    let container = contentView.rightPillContainer(at: index)
                    let width = contentView.rightPillWidths[index]
                    let itemsFrame = CGRect(x: metrics.width - width, y: 0.0, width: width, height: 44.0)
                    if container.superview !== pill.itemsContainer {
                        pill.itemsContainer.addSubview(container)
                        container.frame = itemsFrame
                    }
                    if secondaryContentIsAnimatingIn {
                        container.frame = CGRect(x: pill.itemsContainer.bounds.width - width, y: 0.0, width: width, height: 44.0)
                    }
                    transition.setFrame(view: container, frame: itemsFrame)
                    if component.secondaryTransition > 0.0 {
                        buttonCount += contentView.rightPillButtonCounts[index]
                    }
                    secondaryWeight = width * component.secondaryTransition
                    secondaryTint = contentView.rightPillTints[index]
                }
                // The tint of the content the pill mostly belongs to (a forum sliding over Chats has no compose circle,
                // so Chats' keeps its accent glass while it narrows).
                let tint = secondaryWeight > primaryWeight ? secondaryTint : primaryTint
                pill.appliedTint = tint
                let tintColor = navigationBarGlassTintColor(tint, theme: component.theme)

                guard metrics.width != 0.0 else {
                    self.removeRightPillGlass(pill, slot: slot, inPlace: inPlaceRight.contains(slot), leaving: leavingRight[slot], tintColor: tintColor, isDark: isDark, transition: transition)
                    continue
                }
                let background: GlassContextExtractableContainer
                var backgroundTransition = transition
                var isNew = false
                if let current = pill.background {
                    background = current
                } else {
                    isNew = true
                    backgroundTransition = backgroundTransition.withAnimation(.none)
                    background = GlassContextExtractableContainer()
                    pill.background = background
                    self.addSubview(background)
                    background.contentView.addSubview(pill.itemsContainer)
                    background.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, isVisible: false, transition: .immediate)
                }
                if inPlaceRight.contains(slot) {
                    self.startInPlaceChange(container: background, slot: .right(slot), isNew: isNew, frame: frame, tintColor: tintColor, isDark: isDark, leaving: leavingRight[slot])
                } else if let inPlace = self.inPlaceCapsule(for: background) {
                    self.retargetInPlace(inPlace, frame: frame, tintColor: tintColor, isDark: isDark, transition: transition)
                } else {
                    backgroundTransition.setFrame(view: background, frame: frame)
                    background.update(size: frame.size, cornerRadius: frame.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, transition: transition)
                    backgroundTransition.setFrame(view: pill.itemsContainer, frame: CGRect(origin: CGPoint(), size: frame.size))
                }
                background.morphsIntoContextMenu = buttonCount == 1
            }
            // Pills the row no longer has.
            for slot in rightPillMetrics.count ..< self.rightPills.count {
                let pill = self.rightPills[slot]
                self.removeRightPillGlass(pill, slot: slot, inPlace: inPlaceRight.contains(slot), leaving: leavingRight[slot], tintColor: navigationBarGlassTintColor(pill.appliedTint, theme: component.theme), isDark: isDark, transition: transition)
            }
```

and add the helper to `View`:

```swift
        /// A right pill's glass goes: dematerializing in place for an in-place change, else fading out with the layout.
        private func removeRightPillGlass(_ pill: NavigationBarRightPill, slot: Int, inPlace: Bool, leaving: NavigationBarInPlaceCapsule.Items?, tintColor: GlassBackgroundView.TintColor, isDark: Bool, transition: ComponentTransition) {
            guard let background = pill.background else {
                return
            }
            pill.background = nil
            if inPlace {
                self.startInPlaceRemoval(container: background, slot: .right(slot), tintColor: tintColor, isDark: isDark, leaving: leaving)
            } else {
                background.update(size: background.bounds.size, cornerRadius: background.bounds.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, isVisible: false, transition: transition)
                transition.attachAnimation(view: background, id: "remove", completion: { [weak background] _ in
                    background?.removeFromSuperview()
                })
            }
        }
```

Note on `startInPlaceRemoval`: it resets the removed capsule's live items view (`capsule.items`), which for a right pill
is `pill.itemsContainer`; the pill object is kept, so the next glass for that slot takes the same items container.

- [ ] **Step 6: In-place slots (`NavigationBarInPlaceAnimation.swift`)**

Replace the slot enum with:

```swift
/// A glass container of the bar's row: the left capsule, or a right pill by index from the edge (0: the outermost).
enum NavigationBarCapsuleSlot: Hashable {
    case left
    case right(Int)
}
```

`inPlaceContainer(_:)`: `case .left: return self.leftButtonsBackgroundContainer` / `case let .right(index): return self.rightPillBackgroundContainer(at: index)`.
`inPlaceItemsView(_:)`: `case .left: return self.leftButtonsContainer` / `case let .right(index): return self.rightPill(at: index).itemsContainer`.
`inPlaceLeavingItems(slot:)`: `case .left: source = contentView.leftButtonsContainer` / `case let .right(index): source = contentView.rightPillContainer(at: index)`.
`inPlaceStateForTesting(isLeft:)`: `slot: isLeft ? .left : .right(0)`. Delete the temporary `inPlaceStateForTesting(slot: Int)`
and switch Step 1's calls to `.right(0)` / `.right(1)`.

- [ ] **Step 7: Transition view, minimal (`NavigationBarPlatterTransitionView.swift`)**

In `layout(side:contentView:kind:)`, replace the `circleWidth` block and the `rightButtonsWidth` block with:

```swift
        // UIKit's sections 0 and 1 (Task 4 gives every pill a role).
        let rightPills = navigationBarRightPillMetrics(widths: contentView.rightPillWidths)
        var outerExtent: CGFloat = 0.0
        for (index, pill) in rightPills.enumerated() {
            let maxX = rowMaxX - outerExtent
            outerExtent += pill.extent
            guard index < 2 else {
                continue
            }
            let role: Role = index == 0 ? .trailing : .trailingInner
            layout.frames[role] = CGRect(x: maxX - pill.width, y: side.rowFrame.minY, width: pill.width, height: 44.0)
            let container = contentView.rightPillContainer(at: index)
            container.frame = CGRect(origin: CGPoint(), size: CGSize(width: pill.width, height: 44.0))
            layout.itemViews[role] = container
            layout.tints[role] = navigationBarGlassTintColor(contentView.rightPillTints[index], theme: side.theme)
            layout.signatures[role] = navigationBarCapsuleSignature(side.content, role: role, columnLength: side.columnFrame?.height, hidesColumnButtons: side.hidesColumnButtons)
        }
```

`itemsContainer(of:kind:contentView:)`: replace the array literal with
`[contentView.leftButtonsContainer, contentView.columnButtonsContainer, contentView.columnTrailingContainer] + contentView.rightPillContainers`.
`navigationBarCapsuleSignature`: `.trailing` → `return placement.rowRightSections.first.map { $0.map { $0.id } }`;
`.trailingInner` → `return placement.rowRightSections.count > 1 ? placement.rowRightSections[1].map { $0.id } : nil`.

- [ ] **Step 8: Update the existing tests to the new names and rule**

- `NavigationBarRowLayoutTests`: `test_accentButtonWithOthers_takesTheRowCircle` and
  `test_disabledAccentButtonWithOthers_takesTheRowCircle` assert `self.sectionIds(placement.rowRightSections)` equals
  `[["compose"], ["story", "proxy"]]` and `[["done"], ["a"]]`; `test_loneAccentButton_staysTheCapsule` →
  `[["done"]]`; `test_secondAccentButton_staysInTheCapsule` becomes `test_secondAccentButton_getsItsOwnPill` asserting
  `[["a"], ["x"], ["b"]]` (UIKit gives every prominent item a section: this supersedes the accent-circle spec's ruling
  1, by the user's choice of UIKit's rule); `test_column_keepsTheAccentButtonInItsTrailingCircle` asserts
  `placement.rowRightSections.isEmpty`; `test_noColumn_everyButtonStaysInTheRow` asserts `[["a"], ["b"]]` (the text
  button splits); `test_column_iconButtonsMove_textStaysInTheRow` and any other `rowRightButtons` read →
  `placement.rowRightSections.flatMap { $0 }.map(\.id)`.
- `NavigationBarRegularScreenLayoutTests`: `rowRightButtons.isEmpty` → `rowRightSections.isEmpty`;
  `rowRightButtons.map(\.id)` → `rowRightSections.flatMap { $0 }.map(\.id)`; `test_noColumn_accentButtonStaysInTheRow`
  (its `rightButtons` are `[a, done]`, `a` outermost) asserts
  `placement.rowRightSections.map { $0.map(\.id) } == [[AnyHashable("a")], [AnyHashable("done")]]`.
- `NavigationBarComponentViewTests`: `rightCircleBackgroundContainer` → `rightPillBackgroundContainer(at: 0)`;
  `rightButtonsBackgroundContainer` beside a circle (Chats' buttons) → `rightPillBackgroundContainer(at: 1)`, else
  `(at: 0)`; `primaryContentView!.rightCircleContainer` → `primaryContentView!.rightPillContainer(at: 0)`;
  `primaryContentView?.rightCircleWidth` → `primaryContentView?.rightPillWidths.first`; `view.rightButtonsContainer.alpha`
  → `view.rightPill(at: 0).itemsContainer.alpha`; `appliedRightCircleTint` → `appliedRightPillTint(at: 0)`; slots
  `.rightCircle` → `.right(0)`, `.right` beside it → `.right(1)`, a lone `.right` → `.right(0)`.
- `NavigationBarNodeTests`: `rightCircleBackgroundContainer` → `rightPillBackgroundContainer(at: 0)` (the test with
  `[___done, Edit]`: items `[done, Edit]` reversed gives `rightButtons` `[Edit, done]`, so Edit is pill 0 and Done pill
  1; change the assertions to `rightPillBackgroundContainer(at: 1)?.frame.width == 44.0` and rename the test
  `test_doneBesideAnotherItem_isAPillOfItsOwn`); `rightButtonsBackgroundContainer` → `rightPillBackgroundContainer(at: 0)`.

- [ ] **Step 9: Run both suites**

Run: `NBC_TEST` and `NBN_TEST`.
Expected: `exit=0` for both; `Executed 150 tests, with 0 failures` (146 + 4) and `Executed 77 tests, with 0 failures`.
The two inline-forum slide tests pass unchanged in substance (only their accessors were renamed).

- [ ] **Step 10: Build the app**

Run: `APP_BUILD`.
Expected: `exit=0`, `Build completed successfully` (ChatListNavigationBar and NewsHeaderView compile against the kept
`detachedPressScale(isLeft:)`/`detachedInnerPressScale` accessors).

- [ ] **Step 11: Commit**

```bash
git add -A submodules/TelegramUI/Components/NavigationBarComponent submodules/TelegramUI/Components/NavigationBarNode/Tests
git commit -m "Navigation bar: right buttons in any number of glass pills, by UIKit's rule

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Push and pop pair any number of right pills

**Files:**
- Modify: `…/NavigationBarComponent/Sources/NavigationBarPlatterTransitionView.swift`
- Modify: `…/NavigationBarComponent/Sources/NavigationBarGlassAnimation.swift`
- Modify: `…/NavigationBarComponent/Sources/NavigationBarComponentTransitionState.swift`
- Modify: `…/NavigationBarComponent/Sources/NavigationBarComponent.swift` (press accessors)
- Modify: `submodules/TelegramUI/Components/NavigationBarNode/Sources/NavigationBarNode.swift`,
  `…/NavigationBarNode/Sources/NavigationBarTransitionRenderer.swift`,
  `submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListNavigationBar.swift`,
  `submodules/TelegramUI/Components/News/NewsScreen/Sources/NewsHeaderView.swift`
- Test: `…/NavigationBarComponent/Tests/NavigationBarPlatterTransitionViewTests.swift`, `…/NavigationBarComponentViewTests.swift`,
  `…/NavigationBarNode/Tests/NavigationBarNodeTests.swift`

**Interfaces:**
- Consumes: `NavigationBarContentView.rightPillWidths/rightPillTints/rightPillContainer(at:)`, `rowRightSections`,
  `detachedRightPressScales/Glows` (Task 3).
- Produces:
  - `NavigationBarPlatterTransitionView.Role`: `case leading, trailing(Int), columnBack, columnButtons, columnTrailing`;
    `static func all(rightCount: Int) -> [Role]`.
  - `func navigationBarNearestPartner(of frame: CGRect, among candidates: [CGRect]) -> Int?` (NavigationBarGlassAnimation.swift)
  - `NavigationBarComponentTransitionState` and `NavigationBarPlatterTransitionView.Side`: `trailingPressScales: [CGFloat]`,
    `trailingPressGlows: [CGFloat]` (replace `trailingPressScale`, `trailingPressGlow`, `trailingInnerPressScale`,
    `trailingInnerPressGlow`).
  - `NavigationBarComponent.View` public: `detachedRightPressScales`, `detachedRightPressGlows` (public getters),
    `detachedPressScale(isLeft:)`/`detachedPressGlow(isLeft:)` kept for the left only (rename to
    `detachedLeftPressScale`, `detachedLeftPressGlow`, public); `detachedInner…` deleted.

- [ ] **Step 1: Write the failing tests**

In `NavigationBarPlatterTransitionViewTests` add:

```swift
    private func text(_ id: String) -> NavigationBarComponent.Button {
        return NavigationBarComponent.Button(id: id, content: .text(title: id, isBold: false), action: { _ in })
    }

    // UIKit pairs every section by index from the edge: a bar with three right pills morphs each into the other bar's
    // pill at the same index, the innermost one included.
    func test_threeRightPills_pairByIndex() {
        let view = self.makeView(bottom: self.side(right: [self.text("a"), self.text("b"), self.button("c")]), top: self.side(right: [self.text("x"), self.text("y"), self.button("z")]))
        view.beginTransition(isInteractive: false, toTop: true)
        let identity = view.platterIdentityForTesting(.trailing(2))
        XCTAssertNotNil(identity)
        self.time.advance(by: 1.5)
        XCTAssertEqual(view.platterIdentityForTesting(.trailing(2)), identity)
        XCTAssertEqual(view.platterStateForTesting(.trailing(2))?.opacity ?? 0.0, 1.0, accuracy: 0.001)
    }

    // A leftover pill merges into the other bar's nearest platter (SwiftUI's resolver), not always the outermost: the
    // third pill of three collapses into the second of two.
    func test_leftoverPill_collapsesIntoTheNearestPlatter() {
        let top = self.side(right: [self.text("x"), self.text("y")])
        let view = self.makeView(bottom: self.side(right: [self.text("a"), self.text("b"), self.button("c")]), top: top)
        view.beginTransition(isInteractive: false, toTop: true)
        self.time.advance(by: 0.6)
        guard let leftover = view.platterStateForTesting(.trailing(2)), let inner = view.platterStateForTesting(.trailing(1)), let outer = view.platterStateForTesting(.trailing(0)) else {
            XCTFail("missing platters")
            return
        }
        XCTAssertLessThan(abs(leftover.frame.midX - inner.frame.midX), abs(leftover.frame.midX - outer.frame.midX))
    }
```

In `NavigationBarComponentViewTests` add:

```swift
    // A transition carries on the press UIKit draws on every right pill, by index from the edge.
    func test_detachingPlatters_measuresEveryRightPill() {
        let bar = ComponentView<Empty>()
        let view = self.updateBar(bar, back: nil, right: [self.fixedButton("a", tint: .accent), self.fixedButton("b", tint: .accent), self.fixedButton("c")], transition: .immediate)
        guard let third = view.rightPillBackgroundContainer(at: 2), let glass = navigationBarTestGlassEffectView(content: third.contentView, container: third) else {
            XCTFail("no third pill")
            return
        }
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: 55.0, height: 55.0)
        glass.center = center
        view.plattersDetached = true
        XCTAssertEqual(view.detachedRightPressScales.count, 3)
        XCTAssertEqual(view.detachedRightPressScales[2], 55.0 / 44.0, accuracy: 0.001)
    }
```

Change every `.trailingInner` in the existing transition tests to `.trailing(1)` and every bare `.trailing` to
`.trailing(0)`; in `NavigationBarNodeTests` likewise (`platterStateForTesting(.trailing)` → `(.trailing(0))`). In the
component tests replace `detachedPressScale(isLeft: true)` / `detachedPressGlow(isLeft: true)` with
`detachedLeftPressScale` / `detachedLeftPressGlow`, `detachedPressScale(isLeft: false)` / `detachedInnerPressScale`
with `detachedRightPressScales[0]` / `[1]`, and the glow reads likewise with `detachedRightPressGlows`.

- [ ] **Step 2: Run to verify the new tests fail**

To make the tests compile, apply only Step 3's `Role` enum and its `Role.all(rightCount:)` uses now, keeping today's
behaviour (pills 0 and 1 → `.trailing(0)`, `.trailing(1)`; pills ≥ 2 still skipped in `layout`; the matched morph still
only index 1 into index 0), and make `detachedRightPressScales` `public private(set)`.

Run: `NBC_TEST`.
Expected: FAIL: `test_threeRightPills_pairByIndex` (no `.trailing(2)` platter: identity nil) and
`test_leftoverPill_collapsesIntoTheNearestPlatter` ("missing platters"). `test_detachingPlatters_measuresEveryRightPill`
passes (Task 3 already samples every pill; kept as a guard of the public array).

- [ ] **Step 3: Roles by index**

Replace the `Role` enum with:

```swift
    /// A capsule's place: the row's leading capsule, a right platter by index from the edge (UIKit's
    /// `SectionID(index, owner)`: 0 the outermost), and iPhone Duo's column back circle, buttons capsule and trailing
    /// circle.
    enum Role: Hashable {
        case leading
        case trailing(Int)
        case columnBack
        case columnButtons
        case columnTrailing

        /// Every role, with right platters up to `rightCount`.
        static func all(rightCount: Int) -> [Role] {
            return [.leading] + (0 ..< rightCount).map { .trailing($0) } + [.columnBack, .columnButtons, .columnTrailing]
        }

        var rightIndex: Int? {
            if case let .trailing(index) = self {
                return index
            }
            return nil
        }
    }
```

Add to the view:

```swift
    /// The right platters the two layouts and the current platters hold.
    private var rightRoleCount: Int {
        let indices = [self.bottomLayout, self.topLayout].flatMap { $0.frames.keys.compactMap(\.rightIndex) } + self.platters.keys.compactMap(\.rightIndex)
        return (indices.max() ?? -1) + 1
    }
```

and replace each `Role.allCases` with `Role.all(rightCount: self.rightRoleCount)`.

In `layout(side:contentView:kind:)`, drop the `guard index < 2` and set `let role: Role = .trailing(index)`. The title
pill block becomes `if let pill = side.titlePill, layout.frames[.trailing(1)] == nil, layout.frames.keys.filter({ $0.rightIndex != nil }).count <= 1 {`
with `.trailing(1)` for its role.

In `beginTransition`'s press switch: `case let .trailing(index): pressScale = index < (fromSide?.trailingPressScales.count ?? 0) ? fromSide!.trailingPressScales[index] : 1.0` and
the same for `pressGlow` with `trailingPressGlows`.

`navigationBarCapsuleSignature`: one case `case let .trailing(index): return index < placement.rowRightSections.count ? placement.rowRightSections[index].map { $0.id } : nil`.

- [ ] **Step 4: The nearest partner, shared**

Add to `NavigationBarGlassAnimation.swift`:

```swift
/// The partner SwiftUI's resolver gives a matched insertion or removal (`sourceElement(target:otherElements:config:context:)`,
/// SwiftUICore 27 0x1c6ea55d8, the best `Entry.geometryResult(to:context:)`: the distance between the glass shapes): the
/// candidate nearest `frame`, by the gap between the two shapes, then by their centres. Nil without candidates.
func navigationBarNearestPartner(of frame: CGRect, among candidates: [CGRect]) -> Int? {
    func gap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = max(0.0, max(a.minX - b.maxX, b.minX - a.maxX))
        let dy = max(0.0, max(a.minY - b.maxY, b.minY - a.maxY))
        return (dx * dx + dy * dy).squareRoot()
    }
    func centres(_ a: CGRect, _ b: CGRect) -> CGFloat {
        return hypot(a.midX - b.midX, a.midY - b.midY)
    }
    return candidates.indices.min(by: { lhs, rhs in
        return (gap(frame, candidates[lhs]), centres(frame, candidates[lhs])) < (gap(frame, candidates[rhs]), centres(frame, candidates[rhs]))
    })
}
```

- [ ] **Step 5: Matched morph with the nearest partner**

In `Platter`, add `var partner: Role?` beside `isMatched`.

In `switchTo(_:)`, replace `let oldOutermost = …` with:

```swift
        // What an inserted right platter can grow out of: the other bar's right platters, not ones this switch creates
        // (UIKit matches an inserted entry to an old one only).
        let oldRight: [(role: Role, platter: Platter)] = self.platters.compactMap { role, platter in
            return role.rightIndex != nil && !platter.isLeaving ? (role, platter) : nil
        }
        let targetRight: [(role: Role, frame: CGRect)] = target.frames.compactMap { role, frame in
            return role.rightIndex != nil ? (role, frame) : nil
        }
```

Replace the insertion's `if role == .trailingInner, !motion.reduce, let outermost = oldOutermost {` branch with:

```swift
                    if role.rightIndex != nil, !motion.reduce, let partnerIndex = navigationBarNearestPartner(of: frame, among: oldRight.map { $0.platter.frame(at: self.time) }) {
                        // Grows out of the other bar's nearest platter, as UIKit's inserted section matched to an old one.
                        let partner = oldRight[partnerIndex]
                        let partnerTarget = target.frames[partner.role] ?? partner.platter.frame(at: self.time)
                        let start = self.startMatchedMorph(platter, source: partner.platter.frame(at: self.time), target: frame, appearing: true, containerWidth: containerWidth)
                        platter.partner = partner.role
                        self.pulseMatchedPair(platter, ownSize: frame.size, start: start, partner: partner.platter, partnerFrame: partnerTarget, rowFrame: rowFrame)
                    } else {
```

and the removal's `if role == .trailingInner, !motion.reduce, let outermostFrame = target.frames[.trailing] {` branch with:

```swift
                if role.rightIndex != nil, !motion.reduce, let partnerIndex = navigationBarNearestPartner(of: platter.frame(at: self.time), among: targetRight.map(\.frame)) {
                    // Collapses into this bar's nearest platter, as UIKit's removed section matched to a new one.
                    let partner = targetRight[partnerIndex]
                    let own = platter.frame(at: self.time)
                    let start = self.startMatchedMorph(platter, source: own, target: partner.frame, appearing: false, containerWidth: containerWidth)
                    platter.partner = partner.role
                    if let partnerPlatter = self.platters[partner.role] {
                        self.pulseMatchedPair(platter, ownSize: own.size, start: start, partner: partnerPlatter, partnerFrame: partner.frame, rowFrame: rowFrame)
                    }
                } else {
```

Rename `pulseMatchedPair`'s `outermost:`/`outermostFrame:` parameters to `partner:`/`partnerFrame:` (body unchanged
otherwise). Where a platter is materialized or dematerialized in place, also set `platter.partner = nil`.

`mergesGlass(_:)` becomes:

```swift
    private func mergesGlass(_ platter: Platter) -> Bool {
        guard self.glassMergesShapes(), platter.role.rightIndex != nil else {
            return false
        }
        func materialized(_ partner: Platter) -> Bool {
            return !partner.isLeaving && partner.dematerialization.target == 0.0 && partner.dematerialization.value(at: self.time) < 0.001
        }
        if platter.isMatched, let role = platter.partner, let partner = self.platters[role] {
            return materialized(partner)
        }
        // The partner of a matched platter, while that one merges with it.
        return materialized(platter) && self.platters.values.contains(where: { $0.isMatched && $0.partner == platter.role })
    }
```

- [ ] **Step 6: Press arrays in the state, the side and the fillers**

`NavigationBarComponentTransitionState`: replace the four trailing press properties (and their init parameters and
assignments) with:

```swift
    /// The press UIKit was drawing on each right platter (index from the edge) when the bar gave them to the
    /// transition (missing: none); its glow likewise (missing: 0).
    public var trailingPressScales: [CGFloat]
    public var trailingPressGlows: [CGFloat]
```

with init parameters `trailingPressScales: [CGFloat] = [], trailingPressGlows: [CGFloat] = []`. Do the same in
`NavigationBarPlatterTransitionView.Side`.

`NavigationBarComponent.View`: make `detachedRightPressScales`/`detachedRightPressGlows` `public private(set)`; replace
`detachedPressScale(isLeft:)` and `detachedPressGlow(isLeft:)` with `public var detachedLeftPressScale: CGFloat` /
`public var detachedLeftPressGlow: CGFloat` getters over the private storage (rename the storage `_detachedLeft…`);
delete `detachedInnerPressScale` and `detachedInnerPressGlow`.

Fillers — `NavigationBarNode.swift` (line ~842), `ChatListNavigationBar.swift` (~1160) and `NewsHeaderView.swift`
(~424): pass

```swift
            leadingPressScale: barView.detachedLeftPressScale,
            leadingPressGlow: barView.detachedLeftPressGlow,
            trailingPressScales: barView.detachedRightPressScales,
            trailingPressGlows: barView.detachedRightPressGlows,
```

(in `NavigationBarNode`, `self.rowView?.detachedLeftPressScale ?? 1.0`, `?? 0.0`, `?? []`). `NavigationBarTransitionRenderer.swift`:
build both `Side`s with `trailingPressScales: state.trailingPressScales, trailingPressGlows: state.trailingPressGlows`
and compare those two arrays in the `Side` equality at line ~283 instead of the four removed fields.

- [ ] **Step 7: Run both suites**

Run: `NBC_TEST` and `NBN_TEST`.
Expected: `exit=0`; `Executed 153 tests, with 0 failures` and `Executed 77 tests, with 0 failures`.

- [ ] **Step 8: Build the app**

Run: `APP_BUILD`. Expected: `exit=0`.

- [ ] **Step 9: Commit**

```bash
git add -A submodules/TelegramUI/Components/NavigationBarComponent submodules/TelegramUI/Components/NavigationBarNode submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListNavigationBar.swift submodules/TelegramUI/Components/News/NewsScreen/Sources/NewsHeaderView.swift
git commit -m "Navigation transitions: any number of right platters, paired by index; leftovers merge into the nearest

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: In-place merge: sucked in, ejected out

**Files:**
- Modify: `submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/GlassBackgroundComponent.swift`
  (`GlassContextExtractableContainer`)
- Modify: `…/NavigationBarComponent/Sources/NavigationBarInPlaceAnimation.swift`
- Modify: `…/NavigationBarComponent/Sources/NavigationBarComponent.swift` (removal/insertion dispatch; detaching and
  context-menu hooks)
- Test: `…/NavigationBarComponent/Tests/NavigationBarComponentViewTests.swift`

**Interfaces:**
- Consumes: `navigationBarNearestPartner(of:among:)` (Task 4); `NavigationBarGlassSettings.resolvedMatchedOffset`,
  `.matchedDelay`, `.transitionAnchor`, `.kickFactor`, `.pressRelease`, `.platterSmoothness`, `NavigationBarKickCurve`,
  `NavigationBarGlassPulseCurve`, `NavigationSpringCurve` (existing).
- Produces:
  - `GlassContextExtractableContainer`: `public func lendGlass() -> UIView`, `public func reclaimGlass()`,
    `public private(set) var isGlassLent: Bool`.
  - `NavigationBarComponent.View`: `var glassMergesShapes: () -> Bool`, `func startInPlaceMatched(container:slot:isRemoval:frame:partnerSlot:partnerFrame:tintColor:isDark:leaving:)`.
  - `InPlaceState`: adds `isMatched: Bool`, `isGlassLent: Bool`, `pulseAnchor: CGPoint`, `press: CGFloat`.

- [ ] **Step 1: Write the failing tests**

Add to `NavigationBarComponentViewTests` (`editAndSearch()` is from Task 3):

```swift
    private func doneOnly() -> [NavigationBarComponent.Button] {
        return [self.fixedButton("done", tint: .accent)]
    }

    private func settle(_ view: NavigationBarComponent.View) {
        for _ in 0 ..< 360 {
            view.inPlaceTickForTesting(dt: 1.0 / 120.0)
        }
    }

    // Edit -> Done: the search pill is sucked into Done (its nearest remaining pill), its glass merged with Done's in one
    // container while it collapses, then gone; Done's glass is its own again.
    func test_inPlaceMerge_leavingPill_collapsesIntoTheNearestPill() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let search = before.rightPillBackgroundContainer(at: 1), let edit = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("not two pills")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        guard let start = view.inPlaceStateForTesting(slot: .right(1)) else {
            XCTFail("no merge")
            return
        }
        XCTAssertTrue(start.isMatched)
        XCTAssertTrue(search.isGlassLent)
        XCTAssertTrue(edit.isGlassLent)
        view.inPlaceTickForTesting(dt: 0.3)
        guard let mid = view.inPlaceStateForTesting(slot: .right(1)) else {
            XCTFail("merge ended early")
            return
        }
        XCTAssertGreaterThan(mid.frame.midX, start.frame.midX)
        self.settle(view)
        XCTAssertNil(search.superview)
        XCTAssertFalse(edit.isGlassLent)
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 0) === edit)
    }

    // The partner pulses anchored on the side facing the leaving pill (its left).
    func test_inPlaceMerge_partnerPulse_isAnchoredTowardTheLeavingPill() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertLessThan(view.inPlaceStateForTesting(slot: .right(0))?.pulseAnchor.x ?? 1.0, 0.5)
    }

    // Done -> Edit: search grows out of the Edit pill (its nearest previous pill) and separates to its own frame.
    func test_inPlaceMerge_arrivingPill_growsOutOfItsPartner() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let done = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        let doneFrame = done.frame
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        guard let start = view.inPlaceStateForTesting(slot: .right(1)), let search = view.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no eject")
            return
        }
        XCTAssertTrue(start.isMatched)
        XCTAssertEqual(start.frame.midX, doneFrame.midX, accuracy: 0.5)
        self.settle(view)
        XCTAssertFalse(search.isGlassLent)
        XCTAssertEqual(search.frame.maxX, (view.rightPillBackgroundContainer(at: 0)?.frame.minX ?? 0.0) - 12.0)
    }

    // Edit -> Done -> Edit before the merge ends: the search pill that was leaving is the one that comes back.
    func test_inPlaceMerge_pillComingBack_isReused() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let search = before.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no pill")
            return
        }
        let _ = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        before.inPlaceTickForTesting(dt: 0.1)
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        XCTAssertTrue(view.rightPillBackgroundContainer(at: 1) === search)
        self.settle(view)
        XCTAssertTrue(search.superview === view)
        XCTAssertFalse(search.isGlassLent)
    }

    // Without native glass merging the leaving pill keeps its own container and fades with it.
    func test_inPlaceMerge_withoutNativeMerging_fadesInItsOwnContainer() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { false }
        guard let search = before.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertFalse(search.isGlassLent)
        self.settle(view)
        XCTAssertNil(search.superview)
    }

    // Reduce Motion: the leaving pill dematerializes where it is, no merge.
    func test_inPlaceMerge_underReduceMotion_dematerializesInPlace() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        before.inPlaceReduceMotion = { true }
        guard let search = before.rightPillBackgroundContainer(at: 1) else {
            XCTFail("no pill")
            return
        }
        let frame = search.frame
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(1))?.isMatched, false)
        view.inPlaceTickForTesting(dt: 0.2)
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(1))?.frame ?? .zero, frame)
        XCTAssertFalse(search.isGlassLent)
    }

    // Review focus 5: the arriving search pill takes a tap at once, while its glass is lent.
    func test_inPlaceMerge_arrivingPill_takesTapsAtOnce() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .immediate)
        before.glassMergesShapes = { true }
        testWindow.addSubview(before)
        defer {
            before.removeFromSuperview()
        }
        let view = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        guard let search = view.rightPillBackgroundContainer(at: 1), let searchButton = view.rightButtonViews["search"] else {
            XCTFail("no pill")
            return
        }
        XCTAssertTrue(search.isGlassLent)
        let point = searchButton.convert(CGPoint(x: searchButton.bounds.midX, y: searchButton.bounds.midY), to: view)
        XCTAssertTrue(view.hitTest(point, with: nil)?.isDescendant(of: searchButton) ?? false)
    }

    // Review focus 1: a transition taking the platters mid-merge gets every glass back in its pill and no merging
    // container left in the bar.
    func test_inPlaceMerge_platterDetachMidMerge_reclaimsTheGlass() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        view.plattersDetached = true
        XCTAssertFalse(edit.isGlassLent)
        XCTAssertFalse(view.subviews.contains(where: { $0 is GlassBackgroundContainerView }))
    }

    // Review focus 2: a long press on the partner mid-merge finishes the merge before the menu extracts its container.
    func test_inPlaceMerge_contextMenuMidMerge_reclaimsTheGlass() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        view.inPlaceTickForTesting(dt: 0.05)
        guard let doneButton = view.rightButtonViews["done"], let container = view.navigationButtonContextContainer(sourceView: doneButton) as? GlassContextExtractableContainer else {
            XCTFail("no context container")
            return
        }
        XCTAssertFalse(container.isGlassLent)
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(1)))
    }

    // Review focus 3: a relayout mid-merge (a wider bar) settles every pill at its new frame with its glass reclaimed.
    func test_inPlaceMerge_relayoutMidMerge_settlesAtTheNewFrames() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        let _ = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        before.inPlaceTickForTesting(dt: 0.05)
        let content = NavigationBarComponent.Content(title: .text("Private Chats"), back: .back, leftButton: nil, rightButtons: self.doneOnly(), backPressed: {})
        let _ = bar.update(transition: .easeInOut(duration: 0.3), component: AnyComponent(NavigationBarComponent(theme: self.makeTheme(), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More"), leftInset: 16.0, rightInset: 16.0, primaryContent: content, secondaryContent: nil, secondaryTransition: 0.0)), environment: {}, containerSize: CGSize(width: 430.0, height: 44.0))
        let view = bar.view as! NavigationBarComponent.View
        self.settle(view)
        guard let done = view.rightPillBackgroundContainer(at: 0) else {
            XCTFail("no pill")
            return
        }
        XCTAssertEqual(done.frame, CGRect(x: 430.0 - 16.0 - 44.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertFalse(done.isGlassLent)
    }

    // A press UIKit was drawing on the partner when its glass was lent goes on as the animator's own release.
    func test_inPlaceMerge_partnerPress_continuesAsASpring() {
        let bar = ComponentView<Empty>()
        let before = self.updateBar(bar, back: .back, right: self.editAndSearch(), transition: .immediate)
        before.glassMergesShapes = { true }
        guard let edit = before.rightPillBackgroundContainer(at: 0), let glass = navigationBarTestGlassEffectView(content: edit.contentView, container: edit) else {
            XCTFail("no pill")
            return
        }
        let center = glass.center
        glass.bounds = CGRect(x: 0.0, y: 0.0, width: edit.bounds.width * 1.1, height: 44.0 * 1.1)
        glass.center = center
        let view = self.updateBar(bar, back: .back, right: self.doneOnly(), transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(view.inPlaceStateForTesting(slot: .right(0))?.press ?? 1.0, 1.1, accuracy: 0.01)
        self.settle(view)
        XCTAssertNil(view.inPlaceStateForTesting(slot: .right(0)))
    }
```

`testWindow` is the file's existing process-wide window.

Stubs so the file compiles: in `GlassContextExtractableContainer` add `public private(set) var isGlassLent = false`; in
`NavigationBarComponent.View` add `var glassMergesShapes: () -> Bool = { GlassBackgroundContainerView.mergesShapes }`;
in `InPlaceState` add `var isMatched = false`, `var isGlassLent = false`, `var pulseAnchor = CGPoint(x: 0.5, y: 0.5)`,
`var press: CGFloat = 1.0` (defaulted, so `inPlaceStateForTesting` still builds it).

- [ ] **Step 2: Run to verify they fail**

Run: `NBC_TEST`.
Expected: FAIL. `…collapsesIntoTheNearestPill` (`isMatched` false), `…isAnchoredTowardTheLeavingPill` (anchor 0.5),
`…growsOutOfItsPartner` (`isMatched` false), `…takesTapsAtOnce` (`isGlassLent` false),
`…partnerPress_continuesAsASpring` (press 1.0). The reuse, fade, reduce-motion, detach, context-menu and relayout tests
may pass on the stubs: they are guards of behaviour Task 3 already has, kept so the merge cannot break it.

- [ ] **Step 3: Lend and reclaim the glass (`GlassContextExtractableContainer`)**

Replace the stub with:

```swift
    /// Whether the glass view is lent out (`lendGlass`).
    public private(set) var isGlassLent = false
    private var glassFrameBeforeLending = CGRect()

    /// The glass view, its content (the items) included, lent to another container while it merges with a neighbour's
    /// (the navigation bar's in-place merge): it leaves this view's hierarchy until `reclaimGlass()`. Updates still
    /// reach it; the borrower places it. Hit testing still finds the content (`normalContentView`).
    public func lendGlass() -> UIView {
        if !self.isGlassLent {
            self.isGlassLent = true
            self.glassFrameBeforeLending = self.glassView.frame
        }
        return self.glassView
    }

    /// Takes the lent glass view back, where it was.
    public func reclaimGlass() {
        guard self.isGlassLent else {
            return
        }
        self.isGlassLent = false
        self.glassView.transform = .identity
        self.extractableContentView.addSubview(self.glassView)
        self.glassView.frame = self.glassFrameBeforeLending
    }
```

In `updateState(state:transition:completion:)` (the context-menu extraction), call `self.reclaimGlass()` first.

- [ ] **Step 4: The in-place matched morph (`NavigationBarInPlaceAnimation.swift`)**

4a. In `NavigationBarInPlaceCapsule`, add:

```swift
    /// A matched removal or insertion (spec, animation): the shape follows curves on the in-place clock, collapsing
    /// into, or growing out of, its partner.
    final class Matched {
        var x: NavigationSpringCurve
        var y: NavigationSpringCurve
        var width: NavigationSpringCurve
        var height: NavigationSpringCurve
        var dematerialization: NavigationSpringCurve
        var kick: NavigationBarKickCurve?
        let isRemoval: Bool
        /// The partner's glass container.
        weak var partner: GlassContextExtractableContainer?

        init(source: CGRect, target: CGRect, start: Double, spring: NavigationTransitionSpring, dematerializationFrom: CGFloat, isRemoval: Bool, kick: NavigationBarKickCurve?, partner: GlassContextExtractableContainer) {
            func curve(_ from: CGFloat, _ to: CGFloat, _ rest: NavigationSpringRest) -> NavigationSpringCurve {
                return NavigationSpringCurve(startTime: start, from: from, target: to, spring: spring, rest: rest)
            }
            self.x = curve(source.minX, target.minX, .glass(0.01))
            self.y = curve(source.minY, target.minY, .glass(0.01))
            self.width = curve(source.width, target.width, .glass(0.01))
            self.height = curve(source.height, target.height, .glass(0.01))
            self.dematerialization = curve(dematerializationFrom, isRemoval ? 1.0 : 0.0, .glass(0.001))
            self.kick = kick
            self.isRemoval = isRemoval
            self.partner = partner
        }

        func frame(at time: Double) -> CGRect {
            let kick = self.kick?.translation(at: time) ?? CGSize()
            return CGRect(x: self.x.value(at: time) + kick.width, y: self.y.value(at: time) + kick.height, width: max(0.0, self.width.value(at: time)), height: max(0.0, self.height.value(at: time)))
        }

        func isAtRest(at time: Double) -> Bool {
            let rest = max(self.x.restTime, self.y.restTime, self.width.restTime, self.height.restTime, self.dematerialization.restTime, self.kick?.restTime ?? 0.0)
            return time >= rest
        }
    }

    var matched: Matched?
    /// SwiftUI's pulse of a matched pair, about the pair's anchor (on the in-place clock); while it runs it replaces
    /// `pulse`.
    var anchoredPulse: NavigationBarGlassPulseCurve?
    /// A press UIKit was drawing when this capsule's glass was lent, continued (nil: none).
    var press: NavigationSpringCurve?
    /// The glass view lent to the bar's merging container, while this capsule merges.
    var lentGlass: UIView?
```

`frame` gets a time parameter: rename the existing `var frame: CGRect` to `var springFrame: CGRect` and add

```swift
    func frame(at time: Double) -> CGRect {
        return self.matched?.frame(at: time) ?? self.springFrame
    }
```

and `isAtRest` becomes `func isAtRest(at time: Double) -> Bool` adding
`&& (self.matched?.isAtRest(at: time) ?? true) && (self.anchoredPulse.map { time >= $0.restTime } ?? true) && (self.press.map { time >= $0.restTime } ?? true)`.
Update every caller (`currentFrame(of:)`, `inPlaceStateForTesting`, `startInPlaceChange`, `startInPlaceRemoval`,
`applyInPlace`, `tickInPlace`) to pass `self.inPlaceTime`.

4b. In `NavigationBarComponent.View` (the `View` class body, `NavigationBarComponent.swift`), add stored properties:

```swift
        /// The in-place animator's clock (animation seconds since the bar was made), for its matched morphs' curves.
        var inPlaceTime: Double = 0.0
        /// Where two pills' glass merges during an in-place matched morph, at the bar's platter smoothness; made on first
        /// use, below the pills, spanning the bar.
        var inPlaceMergeContainer: GlassBackgroundContainerView?
```

and replace the `glassMergesShapes` stub's doc with "Whether a glass container merges the shapes in it (native glass),
read as each in-place merge starts."

In `tickInPlace(dt:)`, first line: `self.inPlaceTime += Double(dt)`.

4c. Add to the in-place extension:

```swift
    /// A pill that goes collapses into `partner`'s pill, or one that comes grows out of it (SwiftUI's matched removal and
    /// insertion, `Resolver.adjustMatchedEntry`, spec): after the resolved delay (`minDelay` for a removal, none for an
    /// insertion) the shape springs between its frame and the partner's on the transition spring with the kick, its
    /// items leaving into, or appearing from, the `.match` appearance; both pills pulse about the pair's anchor; with
    /// native glass both glass views are lent to one container at smoothness 12 so the shapes merge.
    func startInPlaceMatched(container: GlassContextExtractableContainer, slot: NavigationBarCapsuleSlot, isRemoval: Bool, frame: CGRect, partner: GlassContextExtractableContainer, partnerFrame: CGRect, tintColor: GlassBackgroundView.TintColor, isDark: Bool, leaving: NavigationBarInPlaceCapsule.Items?) {
        let motion = self.inPlaceMotion
        let time = self.inPlaceTime
        let capsule: NavigationBarInPlaceCapsule
        if let current = self.inPlaceCapsule(for: container) {
            capsule = current
        } else {
            capsule = NavigationBarInPlaceCapsule(slot: slot, container: container, frame: isRemoval ? self.currentFrame(of: container) : partnerFrame, tintColor: tintColor, isDark: isDark)
            self.inPlaceCapsules.append(capsule)
            container.layer.removeAllAnimations()
        }
        let source = isRemoval ? capsule.frame(at: time) : partnerFrame
        let target = isRemoval ? partnerFrame : frame
        let own = isRemoval ? source : target
        let delta = CGSize(width: own.midX - partnerFrame.midX, height: own.midY - partnerFrame.midY)
        let disjoint = !source.intersects(target)
        let resolved = NavigationBarGlassSettings.resolvedMatchedOffset(disjoint ? delta : nil, isRemoval: isRemoval)
        let start = time + (resolved.map { NavigationBarGlassSettings.matchedDelay(offset: $0, containerWidth: self.bounds.width) } ?? 0.0)
        let kick = disjoint ? NavigationBarKickCurve(offset: CGSize(width: delta.width / NavigationBarGlassSettings.kickFactor, height: delta.height / NavigationBarGlassSettings.kickFactor), startTime: start) : nil
        let fromDematerialization: CGFloat = isRemoval ? capsule.dematerialization.value : 1.0
        capsule.matched = NavigationBarInPlaceCapsule.Matched(source: source, target: target, start: start, spring: motion.transition, dematerializationFrom: fromDematerialization, isRemoval: isRemoval, kick: kick, partner: partner)
        capsule.setFrame(target)
        capsule.maxScale = motion.matchScale
        capsule.isRemoved = isRemoval
        container.isUserInteractionEnabled = !isRemoval

        // Items: the leaving ones go into the partner (`.match`), the new ones appear from it.
        if isRemoval {
            if let items = capsule.items {
                capsule.items = nil
                Self.resetInPlaceItems(items.view, size: items.frame.size)
            }
            if let leaving {
                container.contentView.addSubview(leaving.view)
                leaving.maxScale = motion.matchScale
                leaving.appearance.animate(to: 1.0, spring: motion.transition)
                capsule.leaving.append(leaving)
            }
        } else {
            let itemsView = self.inPlaceItemsView(slot)
            itemsView.layer.removeAllAnimations()
            let items = NavigationBarInPlaceCapsule.Items(view: itemsView, frame: frame, appearance: 1.0, motion: motion)
            items.maxScale = motion.matchScale
            items.appearance.animate(to: 0.0, spring: motion.transition)
            capsule.items = items
        }

        // Both pulse about the pair's anchor: the partner now, the entry when it starts moving.
        let anchor = NavigationBarGlassSettings.transitionAnchor(partner: partnerFrame, container: self.bounds)
        let partnerCapsule = self.inPlaceCapsuleCreatingIfNeeded(for: partner, frame: partnerFrame, tintColor: tintColor, isDark: isDark)
        partnerCapsule.pulse = nil
        partnerCapsule.anchoredPulse = motion.pulseCurve(size: partnerFrame.size, startTime: time, anchor: anchor)
        capsule.anchoredPulse = motion.pulseCurve(size: own.size, startTime: start, anchor: anchor)

        container.update(size: target.size, cornerRadius: target.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, isVisible: true, transition: .immediate)
        if self.glassMergesShapes() {
            self.lendInPlaceGlass(partnerCapsule)
            self.lendInPlaceGlass(capsule)
        } else {
            // Without merging the pill's own glass appears or disappears (UIKit's materialization), as push/pop does.
            container.update(size: target.size, cornerRadius: target.height * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, isVisible: !isRemoval, transition: NavigationBarGlassSettings.uikitTransition(for: NavigationBarGlassSettings.materialize))
        }
        self.applyInPlace(capsule)
        self.applyInPlace(partnerCapsule)
        self.startInPlaceLinkIfNeeded()
    }

    /// `container`'s in-place capsule, made at `frame` (resting there) when it has none.
    func inPlaceCapsuleCreatingIfNeeded(for container: GlassContextExtractableContainer, frame: CGRect, tintColor: GlassBackgroundView.TintColor, isDark: Bool) -> NavigationBarInPlaceCapsule {
        if let current = self.inPlaceCapsule(for: container) {
            return current
        }
        let slot: NavigationBarCapsuleSlot = self.rightPills.firstIndex(where: { $0.background === container }).map { .right($0) } ?? .left
        let capsule = NavigationBarInPlaceCapsule(slot: slot, container: container, frame: frame, tintColor: tintColor, isDark: isDark)
        capsule.items = NavigationBarInPlaceCapsule.Items(view: self.inPlaceItemsView(slot), frame: frame, appearance: 0.0, motion: self.inPlaceMotion)
        self.inPlaceCapsules.append(capsule)
        container.layer.removeAllAnimations()
        return capsule
    }

    /// Lends `capsule`'s glass to the merging container, carrying on a press UIKit is drawing on it as a spring.
    private func lendInPlaceGlass(_ capsule: NavigationBarInPlaceCapsule) {
        guard capsule.lentGlass == nil else {
            return
        }
        let press = navigationBarCapsulePressScale(capsule.container)
        if abs(press - 1.0) > 0.0005 {
            capsule.press = NavigationSpringCurve(startTime: self.inPlaceTime, from: press, target: 1.0, spring: NavigationBarGlassSettings.pressRelease, rest: .glass(0.0005))
        }
        let mergeContainer: GlassBackgroundContainerView
        if let current = self.inPlaceMergeContainer {
            mergeContainer = current
        } else {
            mergeContainer = GlassBackgroundContainerView(spacing: NavigationBarGlassSettings.platterSmoothness)
            mergeContainer.isUserInteractionEnabled = false
            self.inPlaceMergeContainer = mergeContainer
            self.insertSubview(mergeContainer, aboveSubview: self.underButtonsView)
        }
        mergeContainer.frame = self.bounds
        mergeContainer.update(size: self.bounds.size, isDark: capsule.isDark, transition: .immediate)
        let glass = capsule.container.lendGlass()
        mergeContainer.contentView.addSubview(glass)
        capsule.lentGlass = glass
    }

    /// Gives `capsule`'s glass back; the merging container goes when nothing is lent to it.
    private func reclaimInPlaceGlass(_ capsule: NavigationBarInPlaceCapsule) {
        guard capsule.lentGlass != nil else {
            return
        }
        capsule.lentGlass = nil
        capsule.container.reclaimGlass()
        if !self.inPlaceCapsules.contains(where: { $0.lentGlass != nil }) {
            self.inPlaceMergeContainer?.removeFromSuperview()
            self.inPlaceMergeContainer = nil
        }
    }
```

Note: the merging container must not be a `GlassContextExtractableContainer`, so the press sampler and
`navigationButtonContextContainer` never see it.

4d. `applyInPlace(_:)`: compute `frame = capsule.frame(at: self.inPlaceTime)`, the dematerialization from
`capsule.matched?.dematerialization.value(at: time) ?? capsule.dematerialization.value`, the pulse from
`capsule.anchoredPulse?.scale(at: time) ?? capsule.pulse?.scale ?? (1, 1)` about `capsule.anchoredPulse?.anchor ?? (0.5, 0.5)`,
and multiply by `capsule.press?.value(at: time) ?? 1.0`. Then:

```swift
        let container = capsule.container
        container.bounds = CGRect(origin: CGPoint(), size: frame.size)
        container.center = CGPoint(x: frame.midX, y: frame.midY)
        if let glass = capsule.lentGlass {
            // The glass is drawn by the merging container: the pill's own view stays untransformed, so its items take taps.
            container.transform = .identity
            glass.bounds = CGRect(origin: CGPoint(), size: frame.size)
            let fixed = CGPoint(x: frame.midX + (anchor.x - 0.5) * frame.width * (1.0 - pulse.width), y: frame.midY + (anchor.y - 0.5) * frame.height * (1.0 - pulse.height))
            glass.center = fixed
            glass.transform = CGAffineTransform(scaleX: scale.width, y: scale.height)
        } else {
            container.transform = CGAffineTransform(scaleX: scale.width, y: scale.height)
        }
```

where `scale` is `(1 + d·(maxScale − 1))·pulse·press` per axis as before. Keep the existing `container.update(…)` and
items placement after it, using `frame` from above.

4e. `finishInPlace(_:)` and every place a capsule settles or is removed: call `self.reclaimInPlaceGlass(capsule)`
first. In `tickInPlace(dt:)`, a settled matched capsule whose partner capsule is still merging leaves that partner's
glass lent until the partner settles (the partner reclaims in its own `finishInPlace`).

4f. `finishInPlaceAnimations()` reclaims every lent glass (it already runs `finishInPlace` per capsule) and removes
`inPlaceMergeContainer`. `navigationButtonContextContainer(sourceView:)` calls `self.finishInPlaceAnimations()` first
when any capsule has lent glass.

4g. `inPlaceStateForTesting(slot:)` fills the new fields: `isMatched: capsule.matched != nil`,
`isGlassLent: capsule.lentGlass != nil`, `pulseAnchor: capsule.anchoredPulse?.anchor ?? CGPoint(x: 0.5, y: 0.5)`,
`press: capsule.press?.value(at: self.inPlaceTime) ?? 1.0`, `frame: capsule.frame(at: self.inPlaceTime)`.

- [ ] **Step 5: Dispatch removals and insertions to the matched morph (`NavigationBarComponent.swift`)**

5a. Before the contents are updated (beside the in-place trigger of Task 3 Step 5f), record the pills' frames now:

```swift
            let previousRightPillFrames: [CGRect] = self.rightPills.map { pill in
                guard let background = pill.background else {
                    return .null
                }
                return self.inPlaceCapsule(for: background)?.frame(at: self.inPlaceTime) ?? background.frame
            }
```

5b. In the right-pill loop of Task 3 Step 5g, for a slot that is new in place (`isNew && inPlaceRight.contains(slot) && slot >= previousRightPillCount`)
with a previous pill to grow out of and no Reduce Motion, call the matched insertion instead of `startInPlaceChange`:

```swift
                let previousFrames = previousRightPillFrames.enumerated().filter { !$0.element.isNull }
                if isNew, inPlaceRight.contains(slot), slot >= previousRightPillCount, !self.inPlaceReduceMotion(), let nearest = navigationBarNearestPartner(of: frame, among: previousFrames.map(\.element)), let partner = self.rightPillBackgroundContainer(at: previousFrames[nearest].offset) {
                    self.startInPlaceMatched(container: background, slot: .right(slot), isRemoval: false, frame: frame, partner: partner, partnerFrame: previousFrames[nearest].element, tintColor: tintColor, isDark: isDark, leaving: nil)
                } else if inPlaceRight.contains(slot) {
```

(the existing `startInPlaceChange` call becomes this `else if`'s body).

5c. Collect the new pills' frames in the loop (`var rightPillFrames: [Int: CGRect] = [:]`, set
`rightPillFrames[slot] = frame` for each slot with a width). In `removeRightPillGlass`, add a
`partner: (container: GlassContextExtractableContainer, frame: CGRect)?` parameter; when `inPlace` and a partner is given
and Reduce Motion is off, call
`self.startInPlaceMatched(container: background, slot: .right(slot), isRemoval: true, frame: background.frame, partner: partner.container, partnerFrame: partner.frame, tintColor: tintColor, isDark: isDark, leaving: leaving)`
instead of `startInPlaceRemoval`. The removal loop passes the nearest new pill:

```swift
            let newFrames = rightPillFrames.sorted(by: { $0.key < $1.key })
            for slot in rightPillMetrics.count ..< self.rightPills.count {
                let pill = self.rightPills[slot]
                let ownFrame = previousRightPillFrames.count > slot ? previousRightPillFrames[slot] : .null
                var partner: (container: GlassContextExtractableContainer, frame: CGRect)?
                if !ownFrame.isNull, let nearest = navigationBarNearestPartner(of: ownFrame, among: newFrames.map(\.value)), let container = self.rightPillBackgroundContainer(at: newFrames[nearest].key) {
                    partner = (container, newFrames[nearest].value)
                }
                self.removeRightPillGlass(pill, slot: slot, inPlace: inPlaceRight.contains(slot), leaving: leavingRight[slot], partner: partner, tintColor: navigationBarGlassTintColor(pill.appliedTint, theme: component.theme), isDark: isDark, transition: transition)
            }
```

(the in-loop call for a zero-width slot passes `partner: nil`).

5d. A pill that was leaving and comes back (`test_inPlaceMerge_pillComingBack_isReused`): when a slot gets a pill while
an in-place capsule of the same `rightPills[slot]` is still collapsing (`isRemoved`), take that container back as
`pill.background` instead of making a new one: before `GlassContextExtractableContainer()` in the loop, look for
`self.inPlaceCapsules.first(where: { $0.slot == .right(slot) && $0.isRemoved })`, set `isRemoved = false`,
`container.isUserInteractionEnabled = true`, and run `startInPlaceMatched(…, isRemoval: false, …)` from its current frame
with the partner it was collapsing into (`capsule.matched?.partner`), as SwiftUI's resolver reuses a removed entry.

- [ ] **Step 6: Run the suites**

Run: `NBC_TEST` and `NBN_TEST`.
Expected: `exit=0`; `Executed 164 tests, with 0 failures` (153 + 11) and `Executed 77 tests, with 0 failures`.

- [ ] **Step 7: Build, install and film the Administrators case**

Run: `APP_BUILD`, then install the fresh build on the logged-in simulator (the whole-`.app` copy from the root
`CLAUDE.md`, sourcing `bazel-out/ios_sim_arm64*/bin/Telegram/Telegram.ipa`).

Reach Channel Administrators of `https://t.me/qwefqwfeqwfqwe` without opening any chat with unread messages (search for
the channel, open its profile from the search result's avatar, not the chat). Film Edit → Done → Edit with
`xcrun simctl io 3A36B4F5-C2D0-41AA-8203-E46EA58CD43D recordVideo` and sheet each change frame by frame. Expected: the
order and timings recorded in the spec by Task 1 (search sucked into Done, ejected from Edit). Check the press: tap
Edit and look at the Edit/Done pill in the first 0.3 s for a doubled squeeze; if UIKit's own press also carries on
(the pill shrinks twice), drop the press continuation (`lendInPlaceGlass`'s `capsule.press`) and the
`test_inPlaceMerge_partnerPress_continuesAsASpring` test, and record it as a ruling.

- [ ] **Step 8: Commit**

```bash
git add -A submodules/TelegramUI/Components/NavigationBarComponent submodules/TelegramUI/Components/GlassBackgroundComponent/Sources/GlassBackgroundComponent.swift
git commit -m "Navigation bar: a pill that comes or goes in place grows out of, or is sucked into, its neighbour

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: In-app verification, survey, release build

**Files:**
- Modify: `docs/superpowers/specs/2026-10-15-navbar-split-right-buttons-design.md` (a "Results" section)
- Modify: `docs/superpowers/2026-10-14-navbar-transitions-handoff.md` (item 8 done; any new open items)

- [ ] **Step 1: Films on the iPhone 18 Pro simulator** (screenshot before every tap; no chat with unread messages)

  - Channel Administrators: Edit → Done → Edit; a fast double tap on Edit; a push to an admin and back by tap and by
    swipe back.
  - Channel Members and Removed Users of the same channel (their search + Edit/Done pairs).
  - Chats: its look unchanged (compose circle beside story/proxy), Edit mode in and out.
  - A chat (Peter Isaac, no unread) push and pop; News: a "For you" post push and pop.

  Expected: every right pair splits as the rule says; merges and ejects match Task 1's film; push/pop morph with nothing
  sliding or popping.

- [ ] **Step 2: iPhone Duo pass**

  On the Duo simulator, Channel Administrators folded and unfolded. Expected: the side column unchanged; text buttons in
  the row as split pills.

- [ ] **Step 3: Look-change survey**

  List the screens whose look changes under the rule (a text button beside another right button):
  `grep -rn "rightBarButtonItems = \[\|setRightBarButtonItems(\[\|secondaryRightNavigationButton:" submodules --include=*.swift`
  and screenshot each reachable one. Record the list with screenshots in the spec's Results.

- [ ] **Step 4: Release build**

Run: `APP_BUILD` with `--configuration=release_arm64` in place of `debug_sim_arm64`.
Expected: `exit=0` (the framework export lists are computed only in release).

- [ ] **Step 5: Results and handoff, commit**

Write the films' findings, the survey, the builds and suites into a "Results (2026-10-…)" section of the spec; mark item
8 done in the handoff with a pointer to the spec; list anything left open.

```bash
git add docs/superpowers/specs/2026-10-15-navbar-split-right-buttons-design.md docs/superpowers/2026-10-14-navbar-transitions-handoff.md
git commit -m "Split right buttons: in-app results, look-change survey, handoff

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
