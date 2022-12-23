public var hideUnblock: Bool {
    let remoteValue = RemoteConfigServiceImpl.shared.get(Bool.self, byKey: "hideUnblock")
    let defaultValue = false
    return remoteValue ?? defaultValue
}

public var hideLottery: Bool {
    let remoteValue = RemoteConfigServiceImpl.shared.get(Bool.self, byKey: "hideLottery")
    let defaultValue = false
    return remoteValue ?? defaultValue
}
