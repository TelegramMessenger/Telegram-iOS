import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext
import CompanionRenderer

struct CompanionOption {
    let name: String
    let file: TelegramMediaFile
    let message: Message

    var title: String {
        return self.name.replacingOccurrences(of: "catalog_", with: "")
            .components(separatedBy: ".").first!.replacingOccurrences(of: "_", with: " ").capitalized
    }

    func matches(_ kind: CompanionComponentKind) -> Bool {
        switch kind {
        case .model: return self.name.hasSuffix(".model.glb")
        case .animation, .itemAnimation: return self.name.hasSuffix(".animation.glb")
        case .materials: return self.name.hasSuffix(".materials.glb") && !self.name.contains("_item.")
        case .itemMaterials: return self.name.hasSuffix("_item.materials.glb") || self.name.hasSuffix("_any.materials.glb")
        case .item: return self.name.hasSuffix(".item.glb")
        case .scene: return self.name.hasSuffix(".scene.glb")
        @unknown default: return false
        }
    }

    var socket: String? {
        switch self.name {
        case "catalog_cat_ears.item.glb": return "ears"
        case "catalog_eyebrows.item.glb": return "brows"
        case "catalog_curl.item.glb", "catalog_spikes.item.glb": return "hair"
        case "catalog_nose.item.glb", "catalog_xx_eyes.item.glb": return "face"
        case "catalog_top_hat.item.glb", "catalog_cherry_stem.item.glb", "catalog_blue_hat_2d.item.glb", "catalog_blue_hat_3d.item.glb", "catalog_orange_hat.item.glb", "catalog_pink_hat.item.glb", "catalog_cap.item.glb", "catalog_cap_badge.item.glb": return "headwear"
        default: return nil
        }
    }
}

/// Fetches metadata only. Opening the catalog never starts a GLB download.
final class CompanionCatalog {
    private let context: AccountContext
    private let resolution = MetaDisposable()
    private let search = MetaDisposable()
    private var generation = 0
    private var messages: [MessageId: Message] = [:]
    var updated: (([CompanionOption], String?) -> Void)?

    init(context: AccountContext) { self.context = context }
    deinit { self.resolution.dispose(); self.search.dispose() }

    func load() {
        self.generation += 1
        let generation = self.generation
        self.messages.removeAll()
        self.search.set(nil)
        self.resolution.set((self.context.engine.peers.resolvePeerByName(name: "tttt3dexample", referrer: nil)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self, self.generation == generation else { return }
            if case let .result(peer) = result {
                guard let peer else {
                    self.updated?([], "Could not open @tttt3dexample. Please try again.")
                    return
                }
                self.loadPage(peerId: peer.id, state: nil, generation: generation)
            }
        }))
    }

    private func loadPage(peerId: PeerId, state: SearchMessagesState?, generation: Int) {
        self.search.set((self.context.engine.messages.searchMessages(location: .peer(peerId: peerId, fromId: nil, tags: .file, reactions: nil, threadId: nil, minDate: nil, maxDate: nil), query: "", state: state, limit: 100)
        |> deliverOnMainQueue).start(next: { [weak self] result, nextState in
            guard let self, self.generation == generation else { return }
            let previousCount = self.messages.count
            for message in result.messages { self.messages[message.id] = message }
            if !result.completed && self.messages.count > previousCount {
                Queue.mainQueue().async { [weak self] in
                    guard let self, self.generation == generation else { return }
                    self.loadPage(peerId: peerId, state: nextState, generation: generation)
                }
                return
            }
            // The most recent message wins when a component is uploaded again with the same name.
            var files: [String: CompanionOption] = [:]
            for message in self.messages.values.sorted(by: { $0.id.id > $1.id.id }) {
                for media in message.media {
                    guard let file = media as? TelegramMediaFile, let name = file.fileName,
                        name.lowercased().hasSuffix(".glb"), files[name] == nil else { continue }
                    files[name] = CompanionOption(name: name, file: file, message: message)
                }
            }
            let options = files.values.sorted(by: { $0.name < $1.name })
            let error: String? = !result.completed ? "Catalog loading stopped before the last page. Please try again." : options.isEmpty ? "No GLB files found. Please try again." : nil
            self.updated?(options, error)
        }))
    }
}
