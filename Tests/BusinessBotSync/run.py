from pathlib import Path
import subprocess
import tempfile


submodule = Path(__file__).resolve().parents[2]
source = (submodule / 'submodules/TelegramCore/Sources/TelegramEngine/Messages/QuickReplyMessages.swift').read_text()
implementation = source[source.index('public enum AccountConnectedBotError'):source.index('func _internal_updatePersonalChannel')]
rights = source[source.index('public struct TelegramBusinessBotRights:'):source.index('    public init(from decoder:', source.index('public struct TelegramBusinessBotRights:'))]
rights = rights.replace('OptionSet, Codable', 'OptionSet') + '}\n'
decoder = source[source.index('extension TelegramBusinessBotRights {'):source.index('extension TelegramBusinessRecipients {')]
fixture = Path(__file__).with_name('BusinessBotSyncTests.swift').read_text()
dependency = submodule / 'submodules/SSignalKit'
with tempfile.TemporaryDirectory(prefix='business-bot-sync-') as directory:
    directory = Path(directory)
    (directory / 'Tests').mkdir()
    (directory / 'Package.swift').write_text(f'''// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "BusinessBotSync",
    platforms: [.macOS(.v10_13)],
    dependencies: [.package(name: "SSignalKit", path: "{dependency}")],
    targets: [.testTarget(name: "BusinessBotSyncTests", dependencies: [.product(name: "SwiftSignalKit", package: "SSignalKit")], path: "Tests")]
)
''')
    (directory / 'Tests/BusinessBotSyncTests.swift').write_text('import XCTest\nimport SwiftSignalKit\n' + (rights + decoder + implementation).replace('public ', '') + fixture)
    raise SystemExit(subprocess.run(['swift', 'test', '--package-path', str(directory), '--jobs', '4']).returncode)
