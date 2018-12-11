import Foundation

struct WebSearchSelectionState: Equatable {
    let selectedIds: Set<String>
    
    static func ==(lhs: WebSearchSelectionState, rhs: WebSearchSelectionState) -> Bool {
        return lhs.selectedIds == rhs.selectedIds
    }
    
    init(selectedIds: Set<String>) {
        self.selectedIds = selectedIds
    }
}

enum WebSearchMode: Int32 {
    case images
    case gifs
}

struct WebSearchInterfaceInnerState: Equatable {
    let mode: WebSearchMode
    let query: String
    let selectionState: WebSearchSelectionState
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
    
    func withUpdatedMode(_ mode: WebSearchMode) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: WebSearchInterfaceInnerState(mode: mode, query: self.state?.query ?? "", selectionState: self.state?.selectionState ?? WebSearchSelectionState(selectedIds: [])), presentationData: self.presentationData)
    }
    
    func withUpdatedQuery(_ query: String) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: WebSearchInterfaceInnerState(mode: self.state?.mode ?? .images, query: query, selectionState: self.state?.selectionState ?? WebSearchSelectionState(selectedIds: [])), presentationData: self.presentationData)
    }

    func withToggledSelectedMessages(_ ids: [String], value: Bool) -> WebSearchInterfaceState {
        var selectedIds = Set<String>()
        if let selectionState = self.state?.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        for id in ids {
            if value {
                selectedIds.insert(id)
            } else {
                selectedIds.remove(id)
            }
        }
        return WebSearchInterfaceState(state: WebSearchInterfaceInnerState(mode: self.state?.mode ?? .images, query: self.state?.query ?? "", selectionState: WebSearchSelectionState(selectedIds: selectedIds)), presentationData: self.presentationData)
    }
    
    func withUpdatedPresentationData(_ presentationData: PresentationData) -> WebSearchInterfaceState {
        return WebSearchInterfaceState(state: self.state, presentationData: presentationData)
    }
}
