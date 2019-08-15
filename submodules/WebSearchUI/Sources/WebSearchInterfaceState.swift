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
    
    init (presentationData: PresentationData) {
        self.state = nil
        self.presentationData = presentationData
    }
    
    init(state: WebSearchInterfaceInnerState?, presentationData: PresentationData) {
        self.state = state
        self.presentationData = presentationData
    }
    
    func withUpdatedScope(_ scope: WebSearchScope) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: WebSearchInterfaceInnerState(scope: scope, query: self.state?.query ?? ""), presentationData: self.presentationData)
    }
    
    func withUpdatedQuery(_ query: String) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: WebSearchInterfaceInnerState(scope: self.state?.scope ?? .images, query: query), presentationData: self.presentationData)
    }
    
    func withUpdatedPresentationData(_ presentationData: PresentationData) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: self.state, presentationData: presentationData)
    }
}
