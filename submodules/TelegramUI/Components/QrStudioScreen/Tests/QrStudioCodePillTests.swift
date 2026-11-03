import XCTest
@testable import QrStudioScreen

final class QrStudioCodePillTests: XCTestCase {
    private func freeExpiring(at time: Double) -> QrStudioCodeState {
        var state = QrStudioCodeState()
        state.perform(.expire, at: time)
        return state
    }

    func testPaidStateHasNoWhiteGlass() {
        let state = QrStudioCodeState()
        XCTAssertFalse(state.removeFee)
        XCTAssertEqual(QrStudioBurn.front(state, width: 200, at: 10), 0)
        XCTAssertEqual(QrStudioBurn.menu(for: state), [])
    }

    func testPourFillsThenBurnsDown() {
        let state = self.freeExpiring(at: 100)
        XCTAssertTrue(state.removeFee)
        XCTAssertTrue(state.expires)
        XCTAssertEqual(QrStudioBurn.front(state, width: 200, at: 100), 0, accuracy: 0.001)
        XCTAssertEqual(QrStudioBurn.front(state, width: 200, at: 100 + QrStudioBurn.refill), 210 * (1 - QrStudioBurn.refill / 60), accuracy: 0.1)
        XCTAssertEqual(QrStudioBurn.front(state, width: 200, at: 130), 105, accuracy: 0.5)
        XCTAssertEqual(QrStudioBurn.front(state, width: 200, at: 160), 0, accuracy: 0.001)
        var previous = CGFloat.greatestFiniteMagnitude
        for i in 1 ... 59 {
            let front = QrStudioBurn.front(state, width: 200, at: 100 + Double(i))
            XCTAssertLessThanOrEqual(front, previous)
            previous = front
        }
    }

    func testPermanentHasNoWhiteGlass() {
        var state = self.freeExpiring(at: 0)
        state.perform(.permanent, at: 20)
        XCTAssertTrue(state.removeFee)
        XCTAssertFalse(state.expires)
        XCTAssertEqual(QrStudioBurn.front(state, width: 200, at: 25), 0, accuracy: 0.001)
        XCTAssertNil(QrStudioBurn.cutPath(front: QrStudioBurn.front(state, width: 200, at: 25), rect: CGRect(x: 0, y: 0, width: 200, height: 24), time: 25, liquid: 0))
    }

    func testRenewWhileExpiringPoursFromCurrentLevel() {
        var state = self.freeExpiring(at: 0)
        state.perform(.renew, at: 30)
        XCTAssertEqual(state.pourFrom, 0.5, accuracy: 0.001)
        XCTAssertEqual(QrStudioBurn.front(state, width: 200, at: 30), 105, accuracy: 0.5)
    }

    func testRestoreReturnsToPaid() {
        var state = self.freeExpiring(at: 0)
        state.perform(.restore, at: 10)
        XCTAssertFalse(state.removeFee)
        XCTAssertFalse(state.expires)
    }

    func testNextCodeIsDueShortlyBeforeTheCurrentOneExpires() {
        let state = self.freeExpiring(at: 0)
        XCTAssertFalse(state.needsNextCode(at: 39.5))
        XCTAssertTrue(state.needsNextCode(at: 40.5))
        var permanent = state
        permanent.perform(.permanent, at: 1)
        XCTAssertFalse(permanent.needsNextCode(at: 100))
    }

    func testANewCodeRefillsWithItsOwnLifetime() {
        var state = self.freeExpiring(at: 0)
        state.adopt(deadline: 61.0 + 35.0, at: 61.0)
        XCTAssertEqual(state.issuedAt, 61.0)
        XCTAssertEqual(state.lifetime, 35.0, accuracy: 0.001)
        XCTAssertEqual(state.pourFrom, 0.0)
        XCTAssertEqual(state.remaining(at: 61.0), 35.0, accuracy: 0.001)
        XCTAssertEqual(QrStudioBurn.level(state, at: 61.0 + QrStudioBurn.refill), 1.0, accuracy: 0.02)
    }

    func testACodeArrivingWhileThePourRunsKeepsIt() {
        var state = QrStudioCodeState()
        state.perform(.expire, at: 10.0)
        state.adopt(deadline: 10.1 + 45.0, at: 10.1)
        XCTAssertEqual(state.issuedAt, 10.0)
        XCTAssertEqual(state.remaining(at: 10.1), 45.0, accuracy: 0.001)
    }

    func testMenuPerState() {
        let expiring = self.freeExpiring(at: 0)
        XCTAssertEqual(QrStudioBurn.menu(for: expiring), [[.renew, .permanent], [.restore]])
        var permanent = expiring
        permanent.perform(.permanent, at: 1)
        XCTAssertEqual(QrStudioBurn.menu(for: permanent), [[.renew, .expire], [.restore]])
    }

    func testShatterOnlyWhenWhiteIsLeft() {
        let expiring = self.freeExpiring(at: 0)
        XCTAssertTrue(QrStudioBurn.shatters(expiring, action: .permanent))
        XCTAssertTrue(QrStudioBurn.shatters(expiring, action: .restore))
        XCTAssertFalse(QrStudioBurn.shatters(expiring, action: .renew))
        var permanent = expiring
        permanent.perform(.permanent, at: 1)
        XCTAssertFalse(QrStudioBurn.shatters(permanent, action: .restore))
        XCTAssertFalse(QrStudioBurn.shatters(permanent, action: .expire))
        XCTAssertFalse(QrStudioBurn.shatters(QrStudioCodeState(), action: .restore))
    }

    func testClock() {
        XCTAssertEqual(QrStudioBurn.clock(59.2), "1:00")
        XCTAssertEqual(QrStudioBurn.clock(42.0), "0:42")
        XCTAssertEqual(QrStudioBurn.clock(0.0), "0:00")
    }

    func testFlashPeaksAtTheEndOfThePour() {
        let state = self.freeExpiring(at: 0)
        XCTAssertEqual(QrStudioBurn.flash(state, at: 0.0), 0)
        XCTAssertEqual(QrStudioBurn.flash(state, at: QrStudioBurn.refill), 1, accuracy: 0.001)
        XCTAssertEqual(QrStudioBurn.flash(state, at: 2.0), 0)
    }

    func testParticlesAreFiniteAndBounded() {
        let state = self.freeExpiring(at: 0)
        let pill = CGSize(width: 180, height: 24)
        var maxCount = 0
        for i in 0 ..< 200 {
            let time = Double(i) * 0.05
            let particles = QrStudioBurn.timerParticles(state, pill: pill, at: time)
            maxCount = max(maxCount, particles.count)
            for particle in particles {
                XCTAssertTrue(particle.x.isFinite && particle.y.isFinite && particle.radius.isFinite)
                XCTAssertGreaterThan(particle.radius, 0)
                XCTAssertTrue((0.0 ... 1.0).contains(particle.alpha))
                XCTAssertTrue((0.0 ... 1.0).contains(particle.heat))
            }
        }
        XCTAssertGreaterThan(maxCount, 20)
        XCTAssertLessThan(maxCount, 400)
    }

    func testShatterParticles() {
        let shatter = QrStudioShatter(at: 10, width: 180, level: 0.5)
        XCTAssertEqual(shatter.front, 95, accuracy: 0.001)
        let early = QrStudioBurn.shatterParticles(shatter, at: 10.05)
        XCTAssertGreaterThan(early.count, 100)
        XCTAssertTrue(QrStudioBurn.shatterParticles(shatter, at: 9.0).isEmpty)
        XCTAssertTrue(QrStudioBurn.shatterParticles(shatter, at: 11.0).isEmpty)
    }
}
