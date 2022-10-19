//
//  RealtimeUpdateFeature.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 3/5/19.
//

import UIKit

protocol RealtimeUpdateFeatureProtocol {
    static var shared: RealtimeUpdateFeatureProtocol? { get set }
    
    var success: (() -> Void)? { get set }
    var error: ((Error) -> Void)? { set get }
    var disconnect: (() -> Void)? { get set }
    var enabled: Bool { get set }
    
	init(hash: String, sourceLanguage: String, organizationName: String?)
    
    func start()
    func stop()
    func subscribe(control: Refreshable)
    func unsubscribe(control: Refreshable)
    func refreshAllControls()
}

class RealtimeUpdateFeature: RealtimeUpdateFeatureProtocol {
    static var shared: RealtimeUpdateFeatureProtocol?
    
    var success: (() -> Void)?
    var error: ((Error) -> Void)?
    var disconnect: (() -> Void)?
    var localization: String {
        let localizations = Localization.current.provider.remoteStorage.localizations
        return CrowdinSDK.currentLocalization ?? Bundle.main.preferredLanguage(with: localizations)
    }
    var hashString: String
    let organizationName: String?
	
	var distributionResponse: DistributionsResponse? = nil
    
    var active: Bool { return socketManger?.active ?? false }
    var enabled: Bool {
        set {
            newValue ? start() : stop()
        }
        get {
            return active
        }
    }
    
    private var controls = NSHashTable<AnyObject>.weakObjects()
    private var socketManger: CrowdinSocketManagerProtocol?
    private var mappingManager: CrowdinMappingManagerProtocol
    
    required init(hash: String, sourceLanguage: String, organizationName: String? = nil) {
        self.hashString = hash
		self.organizationName = organizationName
        self.mappingManager = CrowdinMappingManager(hash: hash, sourceLanguage: sourceLanguage)
    }
	
    func downloadDistribution(with successHandler: (() -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        let distributionsAPI = DistributionsAPI(hashString: self.hashString, organizationName: organizationName, auth: LoginFeature.shared)
		distributionsAPI.getDistribution { (response, error) in
            if let response = response {
                self.distributionResponse = response
                successHandler?()
            } else if let error = error {
                errorHandler?(error)
            } else {
                errorHandler?(NSError(domain: "Unable to download project distribution", code: defaultCrowdinErrorCode, userInfo: nil))
            }
		}
	}
    
    func subscribe(control: Refreshable) {
        guard let localizationKey = control.key else { return }
        guard let id = self.mappingManager.id(for: localizationKey) else { return }
        socketManger?.subscribeOnUpdateDraft(localization: localization, stringId: id)
        socketManger?.subscribeOnUpdateTopSuggestion(localization: localization, stringId: id)
        controls.add(control)
    }
    
    func unsubscribe(control: Refreshable) {
        controls.remove(control)
    }
    
    func start() {
        guard CrowdinSDK.inSDKLocalizations.contains(localization) else {
            let message = "Unable to start real-time preview as there is no '\(localization)' language in Crowdin project target languages."
            print(message)
            self.error?(NSError(domain: message, code: defaultCrowdinErrorCode, userInfo: nil))
            return
        }
        if LoginFeature.isLogined {
            _start()
        } else if let loginFeature = LoginFeature.shared {
            loginFeature.login(completion: {
                self.start()
            }) { err in
                self.error?(err)
            }
        } else {
            error?(NSError(domain: "Login feature is not configured properly", code: defaultCrowdinErrorCode, userInfo: nil))
        }
    }
    
    func _start() {
		guard let projectId = distributionResponse?.data.project.id, let projectWsHash = distributionResponse?.data.project.wsHash, let userId = distributionResponse?.data.user.id, let wsUrl = distributionResponse?.data.wsUrl else {
            self.downloadDistribution(with: {
                self._start()
            }, errorHandler: error)
			return
		}
        setupRealtimeUpdatesLocalizationProvider(with: projectId) { [weak self] in
            guard let self = self else { return }
            self.setupSocketManager(with: projectId, projectWsHash: projectWsHash, userId: userId, wsUrl: wsUrl)
        }
    }
    
    func stop() {
        self.socketManger?.stop()
        self.socketManger?.didChangeString = nil
        self.socketManger?.didChangePlural = nil
        self.socketManger = nil
        self.removeRealtimeUpdatesLocalizationProvider()
    }
    
    var oldProvider: LocalizationProviderProtocol? = nil
    
    func setupRealtimeUpdatesLocalizationProvider(with projectId: String, completion: @escaping () -> Void) {
        oldProvider = Localization.current.provider
        Localization.current.provider = LocalizationProvider(localization: self.localization, localStorage: RULocalLocalizationStorage(localization: self.localization), remoteStorage: RURemoteLocalizationStorage(localization: self.localization, hash: self.hashString, projectId: projectId, organizationName: self.organizationName))
        
        Localization.current.provider.completion = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.subscribeAllVisibleConrols()
                self.refreshAllControls()
                completion()
            }
        }
        Localization.current.provider.errorHandler = error
        Localization.current.provider.refreshLocalization()
    }
    
    func removeRealtimeUpdatesLocalizationProvider() {
        if let ruLocalLocalizationStorage = Localization.current.provider.localStorage as? RULocalLocalizationStorage {
            ruLocalLocalizationStorage.deintegrate()
        }
        if let provider = oldProvider {
            Localization.current.provider = provider
            Localization.current.provider.refreshLocalization()
            self.refreshAllControls()
        }
    }
    
    func setupSocketManager(with projectId: String, projectWsHash: String, userId: String, wsUrl: String) {
        self.socketManger = CrowdinSocketManager(hashString: hashString, projectId: projectId, projectWsHash: projectWsHash, userId: userId, wsUrl: wsUrl, languageResolver: ManifestManager.shared(for: hashString))
        self.socketManger?.didChangeString = { id, newValue in
            self.didChangeString(with: id, to: newValue)
        }
        
        self.socketManger?.didChangePlural = { id, newValue in
            self.didChangePlural(with: id, to: newValue)
        }
        
        self.socketManger?.error = error
        self.socketManger?.connect = {
            self.success?()
            self.subscribeAllVisibleConrols()
        }
        self.socketManger?.disconnect = disconnect
        self.socketManger?.start()
    }
    
    func refreshAllControls() {
        self.controls.allObjects.forEach { (control) in
            if let refreshable = control as? Refreshable {
                refreshable.refresh()
            }
        }
    }
}

extension RealtimeUpdateFeature {
    func refreshControl(with localizationKey: String, newText: String) {
        self.controls.allObjects.forEach { (control) in
            if let refreshable = control as? Refreshable {
                if let key = refreshable.key, key == localizationKey {
                    refreshable.refresh(text: newText)
                }
            }
        }
    }
    
    func subscribeAllVisibleConrols() {
        UIApplication.shared.windows.forEach({
            subscribeAllControls(from: $0)
        })
    }
    
    func subscribeAllControls(from view: UIView) {
        view.subviews.forEach { (subview) in
            if let refreshable = subview as? Refreshable {
                self.subscribe(control: refreshable)
            }
            subscribeAllControls(from: subview)
        }
    }
    
    func didChangeString(with id: Int, to newValue: String) {
        guard let key = mappingManager.stringLocalizationKey(for: id) else { return }
        self.refreshControl(with: key, newText: newValue)
        Localization.current.provider.set(string: newValue, for: key)
    }
    
    func didChangePlural(with id: Int, to newValue: String) {
        guard let key = mappingManager.pluralLocalizationKey(for: id) else { return }
        self.refreshControl(with: key, newText: newValue)
    }
}
