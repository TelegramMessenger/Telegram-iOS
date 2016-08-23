import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

private let titleFont = Font.regular(16.0)
private let descriptionFont = Font.regular(13.0)

private let incomingTitleColor = UIColor(0x0b8bed)
private let outgoingTitleColor = UIColor(0x3faa3c)
private let incomingDescriptionColor = UIColor(0x999999)
private let outgoingDescriptionColor = UIColor(0x6fb26a)

private let fileIconIncomingImage = UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocumentIncoming")?.precomposed()
private let fileIconOutgoingImage = UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocumentOutgoing")?.precomposed()

final class ChatMessageInteractiveFileNode: ASTransformNode {
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    
    private var iconNode: TransformImageNode?
    private var progressNode: RadialProgressNode?
    private var tapRecognizer: UITapGestureRecognizer?
    
    private let statusDisposable = MetaDisposable()
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var fetchStatus: MediaResourceStatus?
    private let fetchDisposable = MetaDisposable()
    
    var activateLocalContent: () -> Void = { }
    private var file: TelegramMediaFile?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = true
        self.titleNode.isLayerBacked = true
        
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = true
        self.descriptionNode.isLayerBacked = true
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.fileTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
        self.tapRecognizer = tapRecognizer
    }
    
    @objc func progressPressed() {
        if let fetchStatus = self.fetchStatus {
            switch fetchStatus {
                case .Fetching:
                    if let cancel = self.fetchControls.with({ return $0?.cancel }) {
                        cancel()
                    }
                case .Remote:
                    if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                        fetch()
                    }
                case .Local:
                    break
            }
        }
    }
    
    @objc func fileTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let fetchStatus = self.fetchStatus, case .Local = fetchStatus {
                self.activateLocalContent()
            } else {
                self.activateLocalContent()
                //self.progressPressed()
            }
        }
    }
    
    func asyncLayout() -> (_ account: Account, _ file: TelegramMediaFile, _ incoming: Bool, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void))) {
        let currentFile = self.file
        
        let titleAsyncLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionAsyncLayout = TextNode.asyncLayout(self.descriptionNode)
        
        return { account, file, incoming, constrainedSize in
            return (CGFloat.greatestFiniteMagnitude, { constrainedSize in
                //var updateImageSignal: Signal<TransformImageArguments -> DrawingContext, NoError>?
                var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
                var updatedFetchControls: FetchControls?
                
                var mediaUpdated = false
                if let currentFile = currentFile {
                    mediaUpdated = file != currentFile
                } else {
                    mediaUpdated = true
                }
                
                if mediaUpdated {
                    //updateImageSignal = chatMessagePhoto(account, photo: image)
                    updatedStatusSignal = chatMessageFileStatus(account: account, file: file)
                    updatedFetchControls = FetchControls(fetch: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.fetchDisposable.set(chatMessageFileInteractiveFetched(account: account, file: file).start())
                        }
                    }, cancel: {
                        chatMessageFileCancelInteractiveFetch(account: account, file: file)
                    })
                }
                
                var candidateTitleString: NSAttributedString?
                var candidateDescriptionString: NSAttributedString?
                
                for attribute in file.attributes {
                    if case let .Audio(_, _, title, performer, _) = attribute {
                        candidateTitleString = NSAttributedString(string: title ?? "Unknown Track", font: titleFont, textColor: incoming ? incomingTitleColor : outgoingTitleColor)
                        candidateDescriptionString = NSAttributedString(string: performer ?? dataSizeString(file.size), font: descriptionFont, textColor:incoming ? incomingDescriptionColor : outgoingDescriptionColor)
                        break
                    }
                }
                
                var titleString: NSAttributedString
                let descriptionString: NSAttributedString
                
                if let candidateTitleString = candidateTitleString {
                    titleString = candidateTitleString
                } else {
                    titleString = NSAttributedString(string: file.fileName ?? "File", font: titleFont, textColor: incoming ? incomingTitleColor : outgoingTitleColor)
                }
                
                if let candidateDescriptionString = candidateDescriptionString {
                    descriptionString = candidateDescriptionString
                } else {
                    descriptionString = NSAttributedString(string: dataSizeString(file.size), font: descriptionFont, textColor:incoming ? incomingDescriptionColor : outgoingDescriptionColor)
                }
                
                let textConstrainedSize = CGSize(width: constrainedSize.width - 44.0 - 8.0, height: constrainedSize.height)
                
                let (titleLayout, titleApply) = titleAsyncLayout(titleString, nil, 1, .middle, textConstrainedSize, nil)
                let (descriptionLayout, descriptionApply) = descriptionAsyncLayout(descriptionString, nil, 1, .middle, textConstrainedSize, nil)
                
                return (max(titleLayout.size.width, descriptionLayout.size.width) + 44.0 + 8.0, { boundingWidth in
                    let progressFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 44.0, height: 44.0))
                    
                    let titleAndDescriptionHeight = titleLayout.size.height - 1.0 + descriptionLayout.size.height
                    
                    let titleFrame = CGRect(origin: CGPoint(x: progressFrame.maxX + 8.0, y: floor((44.0 - titleAndDescriptionHeight) / 2.0)), size: titleLayout.size)
                    let descriptionFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY - 1.0), size: descriptionLayout.size)
                    
                    return (titleFrame.union(descriptionFrame).union(progressFrame).size, { [weak self] in
                        if let strongSelf = self {
                            strongSelf.file = file
                            
                            let _ = titleApply()
                            let _ = descriptionApply()
                            
                            strongSelf.titleNode.frame = titleFrame
                            strongSelf.descriptionNode.frame = descriptionFrame
                            
                            /*if let updateImageSignal = updateImageSignal {
                                strongSelf.imageNode.setSignal(account, signal: updateImageSignal)
                            }*/
                            
                            if let updatedStatusSignal = updatedStatusSignal {
                                strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                                    displayLinkDispatcher.dispatch {
                                        if let strongSelf = strongSelf {
                                            strongSelf.fetchStatus = status
                                            
                                            if strongSelf.progressNode == nil {
                                                let progressNode = RadialProgressNode(theme: RadialProgressTheme(backgroundColor: UIColor(incoming ? 0x1195f2 : 0x3fc33b), foregroundColor: incoming ? UIColor.white : UIColor(0xe1ffc7), icon: incoming ? fileIconIncomingImage : fileIconOutgoingImage))
                                                strongSelf.progressNode = progressNode
                                                progressNode.frame = progressFrame
                                                strongSelf.addSubnode(progressNode)
                                            }
                                            
                                            switch status {
                                                case let .Fetching(progress):
                                                    strongSelf.progressNode?.state = .Fetching(progress: progress)
                                                case .Local:
                                                    strongSelf.progressNode?.state = .Play
                                                case .Remote:
                                                    strongSelf.progressNode?.state = .Remote
                                            }
                                        }
                                    }
                                }))
                            }
                            
                            strongSelf.progressNode?.frame = progressFrame
                            
                            if let updatedFetchControls = updatedFetchControls {
                                let _ = strongSelf.fetchControls.swap(updatedFetchControls)
                            }
                        }
                    })
                })
            })
        }
    }
    
    static func asyncLayout(_ node: ChatMessageInteractiveFileNode?) -> (_ account: Account, _ file: TelegramMediaFile, _ incoming: Bool, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageInteractiveFileNode))) {
        let currentAsyncLayout = node?.asyncLayout()
        
        return { account, file, incoming, constrainedSize in
            var fileNode: ChatMessageInteractiveFileNode
            var fileLayout: (_ account: Account, _ file: TelegramMediaFile, _ incoming: Bool, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void)))
            
            if let node = node, let currentAsyncLayout = currentAsyncLayout {
                fileNode = node
                fileLayout = currentAsyncLayout
            } else {
                fileNode = ChatMessageInteractiveFileNode()
                fileLayout = fileNode.asyncLayout()
            }
            
            let (initialWidth, continueLayout) = fileLayout(account, file, incoming, constrainedSize)
            
            return (initialWidth, { constrainedSize in
                let (finalWidth, finalLayout) = continueLayout(constrainedSize)
                
                return (finalWidth, { boundingWidth in
                    let (finalSize, apply) = finalLayout(boundingWidth)
                    
                    return (finalSize, {
                        apply()
                        return fileNode
                    })
                })
            })
        }
    }
}
