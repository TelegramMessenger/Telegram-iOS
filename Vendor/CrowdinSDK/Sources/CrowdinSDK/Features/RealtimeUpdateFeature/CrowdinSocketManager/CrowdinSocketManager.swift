//
//  SocketConnectionManager.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 5/6/19.
//

import Foundation
import Starscream

protocol CrowdinSocketManagerProtocol {
    init(hashString: String, projectId: String, projectWsHash: String, userId: String, wsUrl: String, languageResolver: LanguageResolver)

    var active: Bool { get }
    var connect: (() -> Void)? { set get }
    var error: ((Error) -> Void)? { set get }
    var disconnect: (() -> Void)? { set get }
    var didChangeString: ((Int, String) -> Void)? { set get }
    var didChangePlural: ((Int, String) -> Void)? { set get }
    
    func start()
    func stop()
    
    func subscribeOnUpdateDraft(localization: String, stringId: Int)
    func subscribeOnUpdateTopSuggestion(localization: String, stringId: Int)
}

class CrowdinSocketManager: NSObject, CrowdinSocketManagerProtocol {
    var socketAPI: SocketAPI
    var languageResolver: LanguageResolver
    
    var active: Bool {
        return socketAPI.isConnected
    }
    
    var connect: (() -> Void)? = nil {
        didSet {
            self.socketAPI.onConnect = connect
        }
    }
    var error: ((Error) -> Void)? = nil {
        didSet {
            self.socketAPI.onError = error
        }
    }
    var disconnect: (() -> Void)? = nil {
        didSet {
            self.socketAPI.onDisconnect = disconnect
        }
    }
    var didChangeString: ((Int, String) -> Void)? = nil
    var didChangePlural: ((Int, String) -> Void)? = nil
    
	required init(hashString: String, projectId: String, projectWsHash: String, userId: String, wsUrl: String, languageResolver: LanguageResolver) {
		self.socketAPI = SocketAPI(hashString: hashString, projectId: projectId, projectWsHash: projectWsHash, userId: userId, wsUrl: wsUrl)
        self.languageResolver = languageResolver
        super.init()
        self.socketAPI.didReceiveUpdateTopSuggestion = updateTopSuggestion(_:)
        self.socketAPI.didReceiveUpdateDraft = updateDraft(_:)
    }
    
    func start() {
        self.socketAPI.connect()
    }
    
    func stop() {
        self.socketAPI.disconect()
    }
    
    func subscribeOnUpdateDraft(localization: String, stringId: Int) {
        guard let crowdinLocalization = languageResolver.crowdinLanguageCode(for: localization) else { return }
        self.socketAPI.subscribeOnUpdateDraft(localization: crowdinLocalization, stringId: stringId)
    }
    
    func subscribeOnUpdateTopSuggestion(localization: String, stringId: Int) {
        guard let crowdinLocalization = languageResolver.crowdinLanguageCode(for: localization) else { return }
        self.socketAPI.subscribeOnUpdateTopSuggestion(localization: crowdinLocalization, stringId: stringId)
    }
    
    func updateDraft(_ draft: UpdateDraftResponse) {
        guard let event = draft.event else { return }
        let data = event.split(separator: ":").map({ String($0) })
        guard data.count == 6 else { return }
        guard let id = Int(data[5]) else { return }
        guard let newText = draft.data?.text else { return }
        guard let pluralForm = draft.data?.pluralForm else { return }
        if pluralForm == "none" {
            self.didChangeString?(id, newText)
        } else {
            self.didChangePlural?(id, newText)
        }
    }
    
    func updateTopSuggestion(_ topSuggestion: TopSuggestionResponse) {
        guard let event = topSuggestion.event else { return }
        let data = event.split(separator: ":").map({ String($0) })
        guard data.count == 5 else { return }
        guard let id = Int(data[4]) else { return }
        guard let newText = topSuggestion.data?.text else { return }
        
        // TODO: Fix in future:
        // We're unable to detect what exact was changed string or plural. Send two callbacks.
        self.didChangeString?(id, newText)
        self.didChangePlural?(id, newText)
    }
}
