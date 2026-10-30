import XCTest
import UIKit
import Display
@testable import PasswordSetupUI

final class TwoFactorDataInputHorizontalLayoutTests: XCTestCase {
    private let rowSideInset: CGFloat = 48.0

    private func layout(size: CGSize, safeInsets: UIEdgeInsets, deviceMetrics: DeviceMetrics = .iPhoneDuo, reservedCorners: ContainerViewLayoutCorners = .none) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: reservedCorners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    // The iPhone Duo postures (docs/iphone-duo-layout.md).
    private var foldedPortrait: ContainerViewLayout {
        return self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil))
    }
    private var foldedLandscapeLeft: ContainerViewLayout {
        return self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)))
    }
    private var foldedLandscapeRight: ContainerViewLayout {
        return self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0), reservedCorners: ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 82.0), topRight: nil, bottomLeft: nil, bottomRight: nil))
    }
    private var unfoldedLandscape: ContainerViewLayout {
        return self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil))
    }

    private func horizontalLayout(_ layout: ContainerViewLayout, isAuthorizationFlow: Bool) -> TwoFactorDataInputHorizontalLayout {
        return twoFactorDataInputHorizontalLayout(layout: layout, isAuthorizationFlow: isAuthorizationFlow, rowSideInset: self.rowSideInset)
    }

    private func assertActionsAlignWithFields(_ result: TwoFactorDataInputHorizontalLayout, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.actionsMinX, result.contentMinX + self.rowSideInset, "leading edge", file: file, line: line)
        XCTAssertEqual(result.actionsMinX + result.actionsWidth, result.contentMinX + result.contentWidth - self.rowSideInset, "trailing edge", file: file, line: line)
    }

    // Equal side insets (every other device): content, button and actions across the screen, as before.

    func test_regularPhone_unchanged() {
        let layout = self.layout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), deviceMetrics: .iPhone16Pro)
        let expected = TwoFactorDataInputHorizontalLayout(contentMinX: 0.0, contentWidth: 402.0, bottomMinX: 0.0, bottomWidth: 402.0, actionsMinX: 48.0, actionsWidth: 306.0)
        XCTAssertEqual(self.horizontalLayout(layout, isAuthorizationFlow: false), expected)
        XCTAssertEqual(self.horizontalLayout(layout, isAuthorizationFlow: true), expected)
    }

    func test_regularPhoneLandscape_unchanged() {
        let layout = self.layout(size: CGSize(width: 874.0, height: 402.0), safeInsets: UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0), deviceMetrics: .iPhone16Pro)
        let expected = TwoFactorDataInputHorizontalLayout(contentMinX: 0.0, contentWidth: 874.0, bottomMinX: 0.0, bottomWidth: 874.0, actionsMinX: 48.0, actionsWidth: 778.0)
        XCTAssertEqual(self.horizontalLayout(layout, isAuthorizationFlow: false), expected)
        XCTAssertEqual(self.horizontalLayout(layout, isAuthorizationFlow: true), expected)
    }

    // Settings (authorized): the content keeps to the band, the button spans the strip, and the text actions in the
    // button's row line up with the fields ("Re-send Code" ended 84pt past the Code field's right edge).

    func test_authorized_foldedPortrait_actionsLineUpWithTheFields() {
        let result = self.horizontalLayout(self.foldedPortrait, isAuthorizationFlow: false)
        XCTAssertEqual(result, TwoFactorDataInputHorizontalLayout(contentMinX: 0.0, contentWidth: 382.0, bottomMinX: 0.0, bottomWidth: 466.0, actionsMinX: 48.0, actionsWidth: 286.0))
        self.assertActionsAlignWithFields(result)
    }

    func test_authorized_foldedLandscapeLeft_actionsLineUpWithTheFields() {
        let result = self.horizontalLayout(self.foldedLandscapeLeft, isAuthorizationFlow: false)
        XCTAssertEqual(result, TwoFactorDataInputHorizontalLayout(contentMinX: 0.0, contentWidth: 594.0, bottomMinX: 0.0, bottomWidth: 594.0, actionsMinX: 48.0, actionsWidth: 498.0))
        self.assertActionsAlignWithFields(result)
    }

    func test_authorized_foldedLandscapeRight_actionsLineUpWithTheFields() {
        let result = self.horizontalLayout(self.foldedLandscapeRight, isAuthorizationFlow: false)
        XCTAssertEqual(result, TwoFactorDataInputHorizontalLayout(contentMinX: 84.0, contentWidth: 594.0, bottomMinX: 0.0, bottomWidth: 678.0, actionsMinX: 132.0, actionsWidth: 498.0))
        self.assertActionsAlignWithFields(result)
    }

    func test_authorized_unfoldedLandscape_actionsLineUpWithTheFields() {
        let result = self.horizontalLayout(self.unfoldedLandscape, isAuthorizationFlow: false)
        XCTAssertEqual(result, TwoFactorDataInputHorizontalLayout(contentMinX: 0.0, contentWidth: 867.0, bottomMinX: 0.0, bottomWidth: 951.0, actionsMinX: 48.0, actionsWidth: 771.0))
        self.assertActionsAlignWithFields(result)
    }

    // Login (password recovery): unchanged, the actions keep to the button's frame (authorizationBottomBand).

    func test_login_foldedPortrait_actionsInTheButtonsFrame() {
        XCTAssertEqual(self.horizontalLayout(self.foldedPortrait, isAuthorizationFlow: true), TwoFactorDataInputHorizontalLayout(contentMinX: 0.0, contentWidth: 382.0, bottomMinX: 0.0, bottomWidth: 382.0, actionsMinX: 48.0, actionsWidth: 286.0))
    }

    func test_login_unfoldedLandscape_actionsInTheButtonsFrame() {
        XCTAssertEqual(self.horizontalLayout(self.unfoldedLandscape, isAuthorizationFlow: true), TwoFactorDataInputHorizontalLayout(contentMinX: 84.0, contentWidth: 783.0, bottomMinX: 0.0, bottomWidth: 951.0, actionsMinX: 48.0, actionsWidth: 855.0))
    }
}
