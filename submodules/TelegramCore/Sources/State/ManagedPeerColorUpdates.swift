import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public final class EngineAvailableColorOptions: Codable, Equatable {
    public final class MultiColorPack: Codable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case colors = "c"
        }
        
        public let colors: [UInt32]
        
        public init(colors: [UInt32]) {
            self.colors = colors
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.colors = try container.decode([Int32].self, forKey: .colors).map(UInt32.init(bitPattern:))
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.colors.map(Int32.init(bitPattern:)), forKey: .colors)
        }
        
        public static func ==(lhs: MultiColorPack, rhs: MultiColorPack) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.colors != rhs.colors {
                return false
            }
            return true
        }
    }
    
    public final class ColorOption: Codable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case palette = "p"
            case background = "b"
            case stories = "s"
        }
        
        public let palette: MultiColorPack
        public let background: MultiColorPack
        public let stories: MultiColorPack?
        
        public init(palette: MultiColorPack, background: MultiColorPack, stories: MultiColorPack?) {
            self.palette = palette
            self.background = background
            self.stories = stories
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.palette = try container.decode(MultiColorPack.self, forKey: .palette)
            self.background = try container.decode(MultiColorPack.self, forKey: .background)
            self.stories = try container.decodeIfPresent(MultiColorPack.self, forKey: .stories)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.palette, forKey: .palette)
            try container.encode(self.background, forKey: .background)
            try container.encodeIfPresent(self.stories, forKey: .stories)
        }
        
        public static func ==(lhs: ColorOption, rhs: ColorOption) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.palette != rhs.palette {
                return false
            }
            if lhs.background != rhs.background {
                return false
            }
            if lhs.stories != rhs.stories {
                return false
            }
            return true
        }
    }
    
    public final class ColorOptionPack: Codable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case light = "l"
            case dark = "d"
            case isHidden = "h"
            case requiredChannelMinBoostLevel = "rcmb"
            case requiredGroupMinBoostLevel = "rgmb"
        }
        
        public let light: ColorOption
        public let dark: ColorOption?
        public let isHidden: Bool
        public let requiredChannelMinBoostLevel: Int32?
        public let requiredGroupMinBoostLevel: Int32?
        
        public init(light: ColorOption, dark: ColorOption?, isHidden: Bool, requiredChannelMinBoostLevel: Int32?, requiredGroupMinBoostLevel: Int32?) {
            self.light = light
            self.dark = dark
            self.isHidden = isHidden
            self.requiredChannelMinBoostLevel = requiredChannelMinBoostLevel
            self.requiredGroupMinBoostLevel = requiredGroupMinBoostLevel
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.light = try container.decode(ColorOption.self, forKey: .light)
            self.dark = try container.decodeIfPresent(ColorOption.self, forKey: .dark)
            self.isHidden = try container.decode(Bool.self, forKey: .isHidden)
            self.requiredChannelMinBoostLevel = try container.decodeIfPresent(Int32.self, forKey: .requiredChannelMinBoostLevel)
            self.requiredGroupMinBoostLevel = try container.decodeIfPresent(Int32.self, forKey: .requiredGroupMinBoostLevel)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.light, forKey: .light)
            try container.encodeIfPresent(self.dark, forKey: .dark)
            try container.encodeIfPresent(self.isHidden, forKey: .isHidden)
            try container.encodeIfPresent(self.requiredChannelMinBoostLevel, forKey: .requiredChannelMinBoostLevel)
            try container.encodeIfPresent(self.requiredGroupMinBoostLevel, forKey: .requiredGroupMinBoostLevel)
        }
        
        public static func ==(lhs: ColorOptionPack, rhs: ColorOptionPack) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.light != rhs.light {
                return false
            }
            if lhs.dark != rhs.dark {
                return false
            }
            if lhs.isHidden != rhs.isHidden {
                return false
            }
            if lhs.requiredChannelMinBoostLevel != rhs.requiredChannelMinBoostLevel {
                return false
            }
            if lhs.requiredGroupMinBoostLevel != rhs.requiredGroupMinBoostLevel {
                return false
            }
            return true
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case hash = "h"
        case options = "o"
    }
    
    public final class Option: Codable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case key = "k"
            case value = "v"
        }
        
        public let key: Int32
        public let value: ColorOptionPack
        
        public init(key: Int32, value: ColorOptionPack) {
            self.key = key
            self.value = value
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.key = try container.decode(Int32.self, forKey: .key)
            self.value = try container.decode(ColorOptionPack.self, forKey: .value)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.key, forKey: .key)
            try container.encode(self.value, forKey: .value)
        }
        
        public static func ==(lhs: Option, rhs: Option) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.key != rhs.key {
                return false
            }
            if lhs.value != rhs.value {
                return false
            }
            return true
        }
    }
    
    public let hash: Int32
    public let options: [Option]
    
    public init(hash: Int32, options: [Option]) {
        self.hash = hash
        self.options = options
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hash = try container.decode(Int32.self, forKey: .hash)
        self.options = try container.decode([Option].self, forKey: .options)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.hash, forKey: .hash)
        try container.encode(self.options, forKey: .options)
    }
    
    public static func ==(lhs: EngineAvailableColorOptions, rhs: EngineAvailableColorOptions) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.options != rhs.options {
            return false
        }
        return true
    }
}

private extension EngineAvailableColorOptions.ColorOption {
    convenience init?(apiColors: Api.help.PeerColorSet) {
        let palette: EngineAvailableColorOptions.MultiColorPack
        let background: EngineAvailableColorOptions.MultiColorPack
        let stories: EngineAvailableColorOptions.MultiColorPack?
        
        switch apiColors {
        case let .peerColorSet(colors):
            if colors.isEmpty {
                return nil
            }
            palette = EngineAvailableColorOptions.MultiColorPack(colors: colors.map(UInt32.init(bitPattern:)))
            background = palette
            stories = nil
        case let .peerColorProfileSet(palleteColors, bgColors, storyColors):
            if palleteColors.isEmpty {
                return nil
            }
            palette = EngineAvailableColorOptions.MultiColorPack(colors: palleteColors.map(UInt32.init(bitPattern:)))
            
            if bgColors.isEmpty {
                return nil
            }
            background = EngineAvailableColorOptions.MultiColorPack(colors: bgColors.map(UInt32.init(bitPattern:)))
            
            if !storyColors.isEmpty {
                stories = EngineAvailableColorOptions.MultiColorPack(colors: storyColors.map(UInt32.init(bitPattern:)))
            } else {
                stories = nil
            }
        }
        
        self.init(palette: palette, background: background, stories: stories)
    }
}

private extension EngineAvailableColorOptions {
    convenience init(hash: Int32, apiColors: [Api.help.PeerColorOption]) {
        var mappedOptions: [Option] = []
        for apiColor in apiColors {
            switch apiColor {
            case let .peerColorOption(flags, colorId, colors, darkColors, requiredChannelMinBoostLevel, requiredGroupMinBoostLevel):
                let isHidden = (flags & (1 << 0)) != 0
                
                let mappedColors = colors.flatMap(EngineAvailableColorOptions.ColorOption.init(apiColors:))
                let mappedDarkColors = darkColors.flatMap(EngineAvailableColorOptions.ColorOption.init(apiColors:))
                
                if let mappedColors = mappedColors {
                    mappedOptions.append(Option(key: colorId, value: ColorOptionPack(light: mappedColors, dark: mappedDarkColors, isHidden: isHidden, requiredChannelMinBoostLevel: requiredChannelMinBoostLevel, requiredGroupMinBoostLevel: requiredGroupMinBoostLevel)))
                } else if colorId >= 0 && colorId <= 6 {
                    let staticMap: [UInt32] = [
                        0xcc5049,
                        0xd67722,
                        0x955cdb,
                        0x40a920,
                        0x309eba,
                        0x368ad1,
                        0xc7508b
                    ]
                    let colorPack = MultiColorPack(colors: [staticMap[Int(colorId)]])
                    let defaultColors = EngineAvailableColorOptions.ColorOption(palette: colorPack, background: colorPack, stories: nil)
                    mappedOptions.append(Option(key: colorId, value: ColorOptionPack(light: defaultColors, dark: nil, isHidden: isHidden, requiredChannelMinBoostLevel: requiredChannelMinBoostLevel, requiredGroupMinBoostLevel: requiredGroupMinBoostLevel)))
                }
            }
        }
        
        self.init(hash: hash, options: mappedOptions)
    }
}

func managedPeerColorUpdates(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let poll = combineLatest(
        _internal_fetchPeerColors(postbox: postbox, network: network, scope: .replies),
        _internal_fetchPeerColors(postbox: postbox, network: network, scope: .profile)
    )
    |> mapToSignal { _ -> Signal<Never, NoError> in
    }
    return (poll |> then(.complete() |> suspendAwareDelay(2.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

public enum PeerColorsScope {
    case replies
    case profile
}

private func _internal_fetchPeerColors(postbox: Postbox, network: Network, scope: PeerColorsScope) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Int32 in
        #if DEBUG
        if "".isEmpty {
            return 0
        }
        #endif
        return _internal_cachedAvailableColorOptions(transaction: transaction, scope: scope).hash
    }
    |> mapToSignal { hash -> Signal<Never, NoError> in
        let signal: Signal<Api.help.PeerColors, MTRpcError>
        switch scope {
        case .replies:
            signal = network.request(Api.functions.help.getPeerColors(hash: hash))
        case .profile:
            signal = network.request(Api.functions.help.getPeerProfileColors(hash: hash))
        }
        
        return signal
        |> `catch` { _ -> Signal<Api.help.PeerColors, NoError> in
            return .single(.peerColorsNotModified)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            switch result {
            case .peerColorsNotModified:
                return .complete()
            case let .peerColors(hash, colors):
                return postbox.transaction { transaction -> Void in
                    let value = EngineAvailableColorOptions(hash: hash, apiColors: colors)
                    _internal_setCachedAvailableColorOptions(transaction: transaction, scope: scope, value: value)
                }
                |> ignoreValues
            }
        }
    }
}

func _internal_cachedAvailableColorOptions(postbox: Postbox, scope: PeerColorsScope) -> Signal<EngineAvailableColorOptions, NoError> {
    return postbox.transaction { transaction -> EngineAvailableColorOptions in
        return _internal_cachedAvailableColorOptions(transaction: transaction, scope: scope)
    }
}

func _internal_observeAvailableColorOptions(postbox: Postbox, scope: PeerColorsScope) -> Signal<EngineAvailableColorOptions, NoError> {
    let key = ValueBoxKey(length: 8)
    switch scope {
    case .replies:
        key.setInt64(0, value: 0)
    case .profile:
        key.setInt64(0, value: 1)
    }
    let viewKey: PostboxViewKey = .cachedItem(ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.peerColorOptions, key: key))
    return postbox.combinedView(keys: [viewKey])
    |> map { views -> EngineAvailableColorOptions in
        guard let view = views.views[viewKey] as? CachedItemView, let value = view.value?.get(EngineAvailableColorOptions.self) else {
            return EngineAvailableColorOptions(hash: 0, options: [])
        }
        return value
    }
}

func _internal_cachedAvailableColorOptions(transaction: Transaction, scope: PeerColorsScope) -> EngineAvailableColorOptions {
    let key = ValueBoxKey(length: 8)
    switch scope {
    case .replies:
        key.setInt64(0, value: 0)
    case .profile:
        key.setInt64(0, value: 1)
    }
    
    let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.peerColorOptions, key: key))?.get(EngineAvailableColorOptions.self)
    if let cached = cached {
        return cached
    } else {
        return EngineAvailableColorOptions(hash: 0, options: [])
    }
}

func _internal_setCachedAvailableColorOptions(transaction: Transaction, scope: PeerColorsScope, value: EngineAvailableColorOptions) {
    let key = ValueBoxKey(length: 8)
    switch scope {
    case .replies:
        key.setInt64(0, value: 0)
    case .profile:
        key.setInt64(0, value: 1)
    }
    
    if let entry = CodableEntry(value) {
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.peerColorOptions, key: key), entry: entry)
    }
}
