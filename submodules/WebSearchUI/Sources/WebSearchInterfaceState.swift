import Foundation
import UIKit
import TelegramPresentationData
import TelegramUIPreferences

struct WebSearchInterfaceInnerState: Equatable {
    let scope: WebSearchScope
    let query: String
}

struct WebSearchInterfaceState: Equatable {
    let state: WebSearchInterfaceInnerState?
    let presentationData: PresentationData
    let gifProvider: String?
    
    init (presentationData: PresentationData) {
        self.state = nil
        self.presentationData = presentationData
        self.gifProvider = nil
    }
    
    init(state: WebSearchInterfaceInnerState?, presentationData: PresentationData, gifProvider: String? = nil) {
        self.state = state
        self.presentationData = presentationData
        self.gifProvider = gifProvider
    }
    
    func withUpdatedScope(_ scope: WebSearchScope) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: WebSearchInterfaceInnerState(scope: scope, query: self.state?.query ?? ""), presentationData: self.presentationData, gifProvider: self.gifProvider)
    }
    
    func withUpdatedQuery(_ query: String) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: WebSearchInterfaceInnerState(scope: self.state?.scope ?? .images, query: query), presentationData: self.presentationData, gifProvider: self.gifProvider)
    }
    
    func withUpdatedPresentationData(_ presentationData: PresentationData) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: self.state, presentationData: presentationData, gifProvider: self.gifProvider)
    }
    
    func withUpdatedGifProvider(_ gifProvider: String?) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: self.state, presentationData: self.presentationData, gifProvider: gifProvider)
    }
}
