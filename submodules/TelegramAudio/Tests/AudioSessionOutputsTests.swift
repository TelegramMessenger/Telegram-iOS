import XCTest
import AVFoundation
import TelegramAudio

/// How a call classifies `AVAudioSession`'s route into the outputs of its audio menu (bug #118: on an
/// iPad with wired EarPods the headset's microphone was offered as a separate output, checked, and
/// drawn as a Bluetooth device, and choosing "Headphones" reverted to it).
final class AudioSessionOutputsTests: XCTestCase {
    private let iPhoneMic = AudioSessionRoutePort(portType: .builtInMic, uid: "Built-In Microphone", name: "iPhone Microphone")
    private let iPadMic = AudioSessionRoutePort(portType: .builtInMic, uid: "Built-In Microphone", name: "iPad Microphone")
    private let receiver = AudioSessionRoutePort(portType: .builtInReceiver, uid: "Built-In Receiver", name: "Receiver")
    private let speaker = AudioSessionRoutePort(portType: .builtInSpeaker, uid: "Speaker", name: "Speaker")
    private let wiredHeadphones = AudioSessionRoutePort(portType: .headphones, uid: "Wired Headphones", name: "Headphones")
    /// A Lightning or 3.5 mm EarPods microphone, as the iPad in the report named it.
    private let earPodsMic = AudioSessionRoutePort(portType: .headsetMic, uid: "AppleUSBAudioEngine:Apple Inc.:EarPods:1", name: "EarPods Microphone")
    /// USB-C EarPods can report their microphone as a USB audio input.
    private let earPodsUSBMic = AudioSessionRoutePort(portType: .usbAudio, uid: "AppleUSBAudioEngine:Apple Inc.:EarPods:2", name: "EarPods Microphone")
    private let iPhoneHeadsetMic = AudioSessionRoutePort(portType: .headsetMic, uid: "Wired Microphone", name: "Headset Microphone")
    private let airPodsHFP = AudioSessionRoutePort(portType: .bluetoothHFP, uid: "AA:BB:CC:DD:EE:FF-tsco", name: "AirPods Pro")
    private let bluetoothSpeakerA2DP = AudioSessionRoutePort(portType: .bluetoothA2DP, uid: "11:22:33:44:55:66-tacl", name: "JBL Flip")
    private let carHFP = AudioSessionRoutePort(portType: .bluetoothHFP, uid: "66:55:44:33:22:11-tsco", name: "My Car")
    private let carPlay = AudioSessionRoutePort(portType: .carAudio, uid: "CarPlay", name: "CarPlay")
    private let usbMic = AudioSessionRoutePort(portType: .usbAudio, uid: "AppleUSBAudioEngine:Blue:Yeti:1", name: "Yeti Stereo Microphone")

    private func label(_ output: AudioSessionOutput) -> String {
        switch output {
        case .builtin:
            return "builtin"
        case .speaker:
            return "speaker"
        case .headphones:
            return "headphones"
        case let .port(port):
            return "port:\(port.name):\(port.type)"
        }
    }

    private func classify(outputs: [AudioSessionRoutePort], inputs: [AudioSessionRoutePort], available: [AudioSessionRoutePort], hasLoudspeaker: Bool) -> (available: [String], current: String) {
        let result = audioSessionOutputs(route: AudioSessionRoute(outputs: outputs, inputs: inputs, availableInputs: available), hasLoudspeaker: hasLoudspeaker)
        return (result.available.map(self.label), self.label(result.current))
    }

    // MARK: - Wired headsets

    func testIPadWithEarPodsIsOneHeadphonesRoute() {
        let result = self.classify(outputs: [self.wiredHeadphones], inputs: [self.earPodsMic], available: [self.iPadMic, self.earPodsMic], hasLoudspeaker: false)
        XCTAssertEqual(result.available, ["speaker", "headphones"])
        XCTAssertEqual(result.current, "headphones")
    }

    func testIPadWithUSBCEarPodsIsOneHeadphonesRoute() {
        let result = self.classify(outputs: [self.wiredHeadphones], inputs: [self.earPodsUSBMic], available: [self.iPadMic, self.earPodsUSBMic], hasLoudspeaker: false)
        XCTAssertEqual(result.available, ["speaker", "headphones"])
        XCTAssertEqual(result.current, "headphones")
    }

    /// `.builtin` applied with the headset plugged in (as at a call's start) pins the built-in microphone while the
    /// sound stays in the headset (an iPad has no receiver). The route is then classified as before the fix: the
    /// headset's microphone is its own item, so the audio button keeps a menu with a way back to it, and "Headphones"
    /// stays current.
    /// An iPad offers its speaker, not a "builtin" route that would leave the sound in the headset: choosing it moves
    /// the sound to the speaker, which is then current, so the two-item toggle goes back to "Headphones".
    func testIPadWithEarPodsOnItsSpeakerTogglesBackToHeadphones() {
        let result = self.classify(outputs: [self.speaker], inputs: [self.iPadMic], available: [self.iPadMic, self.earPodsMic], hasLoudspeaker: false)
        XCTAssertEqual(result.available, ["speaker", "headphones"])
        XCTAssertEqual(result.current, "speaker")
    }

    func testIPadWithEarPodsAndBuiltInMicPinnedOffersTheHeadsetMicrophone() {
        let result = self.classify(outputs: [self.wiredHeadphones], inputs: [self.iPadMic], available: [self.iPadMic, self.earPodsMic], hasLoudspeaker: false)
        XCTAssertEqual(result.available, ["speaker", "headphones", "port:EarPods Microphone:generic"])
        XCTAssertEqual(result.current, "headphones")
        XCTAssertEqual(self.headsetInput(outputs: [self.wiredHeadphones], available: [self.iPadMic, self.earPodsMic]), self.earPodsMic)
    }

    /// Headphones without a microphone leave nothing to choose between: they stay the current output.
    func testWiredHeadphonesWithoutMicrophoneAreCurrent() {
        let result = self.classify(outputs: [self.wiredHeadphones], inputs: [self.iPhoneMic], available: [self.iPhoneMic], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "headphones", "speaker"])
        XCTAssertEqual(result.current, "headphones")
    }

    /// A USB microphone next to wired headphones is taken for the headset's microphone.
    func testUSBMicrophoneNextToWiredHeadphonesIsPartOfHeadphones() {
        let result = self.classify(outputs: [self.wiredHeadphones], inputs: [self.usbMic], available: [self.iPadMic, self.usbMic], hasLoudspeaker: false)
        XCTAssertEqual(result.available, ["speaker", "headphones"])
        XCTAssertEqual(result.current, "headphones")
        XCTAssertEqual(self.headsetInput(outputs: [self.wiredHeadphones], available: [self.iPadMic, self.usbMic]), self.usbMic)
    }

    func testIPhoneWithEarPodsIsOneHeadphonesRoute() {
        let result = self.classify(outputs: [self.wiredHeadphones], inputs: [self.iPhoneHeadsetMic], available: [self.iPhoneMic, self.iPhoneHeadsetMic], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "headphones", "speaker"])
        XCTAssertEqual(result.current, "headphones")
    }

    func testIPhoneWithEarPodsOnSpeakerOffersHeadphones() {
        let result = self.classify(outputs: [self.speaker], inputs: [self.iPhoneMic], available: [self.iPhoneMic, self.iPhoneHeadsetMic], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "headphones", "speaker"])
        XCTAssertEqual(result.current, "speaker")
    }

    /// While a Bluetooth device is the output, "Headphones" can mean that device (an A2DP-only one reads as
    /// headphones), so the wired headset keeps being offered by its microphone, as before.
    func testWiredHeadsetIsOfferedByItsMicrophoneWhileAirPodsAreCurrent() {
        let result = self.classify(outputs: [self.airPodsHFP], inputs: [self.airPodsHFP], available: [self.iPhoneMic, self.iPhoneHeadsetMic, self.airPodsHFP], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "speaker", "port:Headset Microphone:wired", "port:AirPods Pro:bluetooth"])
        XCTAssertEqual(result.current, "port:AirPods Pro:bluetooth")
    }

    func testWiredHeadsetIsOfferedByItsMicrophoneWhileABluetoothSpeakerIsCurrent() {
        let result = self.classify(outputs: [self.bluetoothSpeakerA2DP], inputs: [self.iPhoneMic], available: [self.iPhoneMic, self.iPhoneHeadsetMic], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "speaker", "port:Headset Microphone:wired"])
        XCTAssertEqual(result.current, "headphones")
    }

    /// The fold of a USB microphone needs wired headphones as the output; elsewhere it stays a port that
    /// still selects the headset.
    func testUSBCEarPodsMicrophoneIsAPortWhileTheSpeakerIsCurrent() {
        let result = self.classify(outputs: [self.speaker], inputs: [self.iPhoneMic], available: [self.iPhoneMic, self.earPodsUSBMic], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "speaker", "port:EarPods Microphone:generic"])
        XCTAssertEqual(result.current, "speaker")
    }

    func testIPhoneWithEarPodsAndBuiltInMicPinnedOffersTheHeadsetMicrophone() {
        let result = self.classify(outputs: [self.wiredHeadphones], inputs: [self.iPhoneMic], available: [self.iPhoneMic, self.iPhoneHeadsetMic], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "headphones", "speaker", "port:Headset Microphone:wired"])
        XCTAssertEqual(result.current, "headphones")
    }

    func testEarPodsCurrentWithAirPodsAvailable() {
        let result = self.classify(outputs: [self.wiredHeadphones], inputs: [self.iPhoneHeadsetMic], available: [self.iPhoneMic, self.iPhoneHeadsetMic, self.airPodsHFP], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "headphones", "speaker", "port:AirPods Pro:bluetooth"])
        XCTAssertEqual(result.current, "headphones")
    }

    // MARK: - Bluetooth, car, built-in (unchanged)

    func testAirPodsAreABluetoothPort() {
        let result = self.classify(outputs: [self.airPodsHFP], inputs: [self.airPodsHFP], available: [self.iPhoneMic, self.airPodsHFP], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "speaker", "port:AirPods Pro:bluetooth"])
        XCTAssertEqual(result.current, "port:AirPods Pro:bluetooth")
    }

    func testAirPodsOnIPadAreABluetoothPort() {
        let result = self.classify(outputs: [self.airPodsHFP], inputs: [self.airPodsHFP], available: [self.iPadMic, self.airPodsHFP], hasLoudspeaker: false)
        XCTAssertEqual(result.available, ["speaker", "port:AirPods Pro:bluetooth"])
        XCTAssertEqual(result.current, "port:AirPods Pro:bluetooth")
    }

    /// A speaker without a microphone has no input to list; the route reads as headphones, as before.
    func testBluetoothSpeakerWithoutMicrophone() {
        let result = self.classify(outputs: [self.bluetoothSpeakerA2DP], inputs: [self.iPhoneMic], available: [self.iPhoneMic], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "speaker"])
        XCTAssertEqual(result.current, "headphones")
    }

    func testBluetoothHandsFreeCarKitIsABluetoothPort() {
        let result = self.classify(outputs: [self.carHFP], inputs: [self.carHFP], available: [self.iPhoneMic, self.carHFP], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "speaker", "port:My Car:bluetooth"])
        XCTAssertEqual(result.current, "port:My Car:bluetooth")
    }

    func testCarPlayIsAGenericPort() {
        let result = self.classify(outputs: [self.carPlay], inputs: [self.carPlay], available: [self.iPhoneMic, self.carPlay], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "speaker", "port:CarPlay:generic"])
        XCTAssertEqual(result.current, "port:CarPlay:generic")
    }

    func testIPhoneReceiver() {
        let result = self.classify(outputs: [self.receiver], inputs: [self.iPhoneMic], available: [self.iPhoneMic], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "speaker"])
        XCTAssertEqual(result.current, "builtin")
    }

    func testIPhoneSpeaker() {
        let result = self.classify(outputs: [self.speaker], inputs: [self.iPhoneMic], available: [self.iPhoneMic], hasLoudspeaker: true)
        XCTAssertEqual(result.available, ["builtin", "speaker"])
        XCTAssertEqual(result.current, "speaker")
    }

    func testIPadBuiltInOnly() {
        let result = self.classify(outputs: [self.speaker], inputs: [self.iPadMic], available: [self.iPadMic], hasLoudspeaker: false)
        XCTAssertEqual(result.available, ["speaker"])
        XCTAssertEqual(result.current, "speaker")
    }

    /// A USB microphone without wired headphones is its own input, not a headset.
    func testUSBMicrophoneWithoutHeadphonesStaysAPort() {
        let result = self.classify(outputs: [self.speaker], inputs: [self.usbMic], available: [self.iPadMic, self.usbMic], hasLoudspeaker: false)
        XCTAssertEqual(result.available, ["speaker", "port:Yeti Stereo Microphone:generic"])
        XCTAssertEqual(result.current, "port:Yeti Stereo Microphone:generic")
    }

    func testNoAvailableInputsOffersNothing() {
        let result = self.classify(outputs: [self.speaker], inputs: [], available: [], hasLoudspeaker: false)
        XCTAssertEqual(result.available, ["speaker"])
        let missing = audioSessionOutputs(route: AudioSessionRoute(outputs: [self.speaker], inputs: [], availableInputs: nil), hasLoudspeaker: true)
        XCTAssertEqual(missing.available, [])
        XCTAssertEqual(missing.current, .builtin)
    }

    // MARK: - Selecting "Headphones"

    private func headsetInput(outputs: [AudioSessionRoutePort], available: [AudioSessionRoutePort]) -> AudioSessionRoutePort? {
        return audioSessionWiredHeadsetInput(route: AudioSessionRoute(outputs: outputs, inputs: [], availableInputs: available))
    }

    func testSelectingHeadphonesPinsTheEarPodsMicrophone() {
        XCTAssertEqual(self.headsetInput(outputs: [self.wiredHeadphones], available: [self.iPadMic, self.earPodsMic]), self.earPodsMic)
        XCTAssertEqual(self.headsetInput(outputs: [self.wiredHeadphones], available: [self.iPadMic, self.earPodsUSBMic]), self.earPodsUSBMic)
    }

    func testSelectingHeadphonesFromTheSpeakerPinsTheWiredHeadset() {
        XCTAssertEqual(self.headsetInput(outputs: [self.speaker], available: [self.iPhoneMic, self.iPhoneHeadsetMic]), self.iPhoneHeadsetMic)
    }

    /// An A2DP-only device is reported as "Headphones"; re-applying that must not move the call to the wired headset.
    func testHeadphonesWhileABluetoothDeviceIsCurrentPinsNothing() {
        XCTAssertNil(self.headsetInput(outputs: [self.bluetoothSpeakerA2DP], available: [self.iPhoneMic, self.iPhoneHeadsetMic]))
        XCTAssertNil(self.headsetInput(outputs: [self.airPodsHFP], available: [self.iPhoneMic, self.iPhoneHeadsetMic, self.airPodsHFP]))
    }

    func testSelectingHeadphonesWithoutAHeadsetMicrophonePinsNothing() {
        XCTAssertNil(self.headsetInput(outputs: [self.wiredHeadphones], available: [self.iPhoneMic]))
        XCTAssertNil(self.headsetInput(outputs: [self.speaker], available: [self.iPadMic, self.usbMic]))
        XCTAssertNil(self.headsetInput(outputs: [self.airPodsHFP], available: [self.iPhoneMic, self.airPodsHFP]))
    }
}
