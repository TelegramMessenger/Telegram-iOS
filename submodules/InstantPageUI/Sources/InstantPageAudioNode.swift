import Foundation
import UIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import UniversalMediaPlayer
import AccountContext
import RadialStatusNode

private func generatePlayButton(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 48.0, height: 48.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.65)
        let _ = try? drawSvgPath(context, path: "M24,0.825 C11.2008009,0.825 0.825,11.2008009 0.825,24 C0.825,36.7991991 11.2008009,47.175 24,47.175 C36.7991991,47.175 47.175,36.7991991 47.175,24 C47.175,11.2008009 36.7991991,0.825 24,0.825 S ")
        let _ = try? drawSvgPath(context, path: "M19,16.8681954 L19,32.1318046 L19,32.1318046 C19,32.6785665 19.4432381,33.1218046 19.99,33.1218046 C20.1882157,33.1218046 20.3818677,33.0623041 20.5458864,32.9510057 L31.7927564,25.319201 L31.7927564,25.319201 C32.2451886,25.0121934 32.3630786,24.3965458 32.056071,23.9441136 C31.9857457,23.8404762 31.8963938,23.7511243 31.7927564,23.680799 L20.5458864,16.0489943 L20.5458864,16.0489943 C20.0934542,15.7419868 19.4778066,15.8598767 19.170799,16.312309 C19.0595006,16.4763277 19,16.6699796 19,16.8681954 Z ")
    })
}

private func generatePauseButton(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 48.0, height: 48.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.65)
        
        let _ = try? drawSvgPath(context, path: "M24,0.825 C11.2008009,0.825 0.825,11.2008009 0.825,24 C0.825,36.7991991 11.2008009,47.175 24,47.175 C36.7991991,47.175 47.175,36.7991991 47.175,24 C47.175,11.2008009 36.7991991,0.825 24,0.825 S ")
        let _ = try? drawSvgPath(context, path: "M17,16 L21,16 C21.5567619,16 22,16.4521029 22,17 L22,32 C22,32.5478971 21.5567619,33 21,33 L17,33 C16.4432381,33 16,32.5478971 16,32 L16,17 C16,16.4521029 16.4432381,16 17,16 Z ")
        let _ = try? drawSvgPath(context, path: "M26.99,16 L31.01,16 C31.5567619,16 32,16.4432381 32,16.99 L32,32.01 C32,32.5567619 31.5567619,33 31.01,33 L26.99,33 C26.4432381,33 26,32.5567619 26,32.01 L26,16.99 C26,16.4432381 26.4432381,16 26.99,16 Z ")
    })
}

private func titleString(media: InstantPageMedia, theme: InstantPageTheme, strings: PresentationStrings) -> NSAttributedString {
    let string = NSMutableAttributedString()
    if let file = media.media as? TelegramMediaFile {
        loop: for attribute in file.attributes {
            if case let .Audio(isVoice, _, title, performer, _) = attribute, !isVoice {
                let titleText: String = title ?? strings.MediaPlayer_UnknownTrack
                let subtitleText: String = performer ?? strings.MediaPlayer_UnknownArtist
                
                let titleString = NSAttributedString(string: titleText, font: Font.semibold(17.0), textColor: theme.textCategories.paragraph.color)
                let subtitleString = NSAttributedString(string: " — \(subtitleText)", font: Font.regular(17.0), textColor: theme.textCategories.paragraph.color)
                
                string.append(titleString)
                string.append(subtitleString)
                
                break loop
            }
        }
    }
    return string
}

final class InstantPageAudioNode: ASDisplayNode, InstantPageNode {
    private let context: AccountContext
    let media: InstantPageMedia
    private let openMedia: (InstantPageMedia) -> Void
    private var strings: PresentationStrings
    private var theme: InstantPageTheme
    
    private let playlistType: MediaManagerPlayerType
    
    private var playImage: UIImage
    private var pauseImage: UIImage
    
    private let buttonNode: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    private let titleNode: ASTextNode
    private let scrubbingNode: MediaPlayerScrubbingNode
    private var playbackStatusDisposable: Disposable?
    private var playerStatusDisposable: Disposable?
    
    private var isPlaying: Bool = false
    private var playbackState: SharedMediaPlayerItemPlaybackState?
    
    init(context: AccountContext, strings: PresentationStrings, theme: InstantPageTheme, webPage: TelegramMediaWebpage, media: InstantPageMedia, openMedia: @escaping (InstantPageMedia) -> Void) {
        self.context = context
        self.strings = strings
        self.theme = theme
        self.media = media
        self.openMedia = openMedia
        
        self.playImage = generatePlayButton(color: theme.textCategories.paragraph.color)!
        self.pauseImage = generatePauseButton(color: theme.textCategories.paragraph.color)!
        
        self.buttonNode = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        
        var backgroundAlpha: CGFloat = 0.1
        var brightness: CGFloat = 0.0
        theme.textCategories.paragraph.color.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        if brightness > 0.5 {
            backgroundAlpha = 0.4
        }
        self.scrubbingNode = MediaPlayerScrubbingNode(content: .standard(lineHeight: 3.0, lineCap: .round, scrubberHandle: .line, backgroundColor: theme.textCategories.paragraph.color.withAlphaComponent(backgroundAlpha), foregroundColor: theme.textCategories.paragraph.color, bufferingColor: theme.textCategories.paragraph.color.withAlphaComponent(0.5), chapters: []))
        
        let playlistType: MediaManagerPlayerType
        if let file = self.media.media as? TelegramMediaFile {
            playlistType = file.isVoice ? .voice : .music
        } else {
            playlistType = .music
        }
        self.playlistType = playlistType
        
        super.init()
        
        self.titleNode.attributedText = titleString(media: media, theme: theme, strings: strings)
        
        self.addSubnode(self.statusNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.scrubbingNode)
        
        self.statusNode.transitionToState(RadialStatusNodeState.customIcon(self.playImage), animated: false, completion: {})
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.statusNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.statusNode.alpha = 0.4
                } else {
                    strongSelf.statusNode.alpha = 1.0
                    strongSelf.statusNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.scrubbingNode.seek = { [weak self] timestamp in
            if let strongSelf = self {
                if let _ = strongSelf.playbackState {
                    strongSelf.context.sharedContext.mediaManager.playlistControl(.seek(timestamp), type: strongSelf.playlistType)
                }
            }
        }
        
        /*if let applicationContext = account.applicationContext as? TelegramApplicationContext, let (playlistId, itemId) = instantPageAudioPlaylistAndItemIds(webpage: webpage, media: self.media) {
            let playbackStatus: Signal<MediaPlayerPlaybackStatus?, NoError> = applicationContext.mediaManager.filteredPlaylistPlayerStateAndStatus(playlistId: playlistId, itemId: itemId)
                |> mapToSignal { status -> Signal<MediaPlayerPlaybackStatus?, NoError> in
                    if let status = status, let playbackStatus = status.status {
                        return playbackStatus
                            |> map { playbackStatus -> MediaPlayerPlaybackStatus? in
                                return playbackStatus.status
                            }
                            |> distinctUntilChanged(isEqual: { lhs, rhs in
                                return lhs == rhs
                            })
                    } else {
                        return .single(nil)
                    }
                }*/
            /*self.playbackStatusDisposable = (playbackStatus |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    var isPlaying = false
                    if let status = status {
                        switch status {
                            case .paused:
                                break
                            case let .buffering(_, whilePlaying):
                                isPlaying = whilePlaying
                            case .playing:
                                isPlaying = true
                        }
                    }
                    if strongSelf.isPlaying != isPlaying {
                        strongSelf.isPlaying = isPlaying
                        if isPlaying {
                            strongSelf.statusNode.transitionToState(RadialStatusNodeState.customIcon(strongSelf.pauseImage), animated: false, completion: {})
                        } else {
                            strongSelf.statusNode.transitionToState(RadialStatusNodeState.customIcon(strongSelf.playImage), animated: false, completion: {})
                        }
                    }
                }
            })*/
        
        self.scrubbingNode.status = context.sharedContext.mediaManager.filteredPlaylistState(accountId: context.account.id, playlistId: InstantPageMediaPlaylistId(webpageId: webPage.webpageId), itemId: InstantPageMediaPlaylistItemId(index: self.media.index), type: self.playlistType)
        |> map { playbackState -> MediaPlayerStatus in
            return playbackState?.status ?? MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
        }
            
        self.playerStatusDisposable = (context.sharedContext.mediaManager.filteredPlaylistState(accountId: context.account.id, playlistId: InstantPageMediaPlaylistId(webpageId: webPage.webpageId), itemId: InstantPageMediaPlaylistItemId(index: self.media.index), type: playlistType)
        |> deliverOnMainQueue).start(next: { [weak self] playbackState in
            guard let strongSelf = self else {
                return
            }
            strongSelf.playbackState = playbackState
            let isPlaying: Bool
            if let status = playbackState?.status {
                if case .playing = status.status {
                    isPlaying = true
                } else {
                    isPlaying = false
                }
            } else {
                isPlaying = false
            }
            if strongSelf.isPlaying != isPlaying {
                strongSelf.isPlaying = isPlaying
                if isPlaying {
                    strongSelf.statusNode.transitionToState(RadialStatusNodeState.customIcon(strongSelf.pauseImage), animated: false, completion: {})
                } else {
                    strongSelf.statusNode.transitionToState(RadialStatusNodeState.customIcon(strongSelf.playImage), animated: false, completion: {})
                }
            }
        })
    }
    
    deinit {
        self.playerStatusDisposable?.dispose()
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        if self.strings !== strings || self.theme !== theme {
            let themeUpdated = self.theme !== theme
            self.strings = strings
            self.theme = theme
            
            if themeUpdated {
                self.playImage = generatePlayButton(color: theme.textCategories.paragraph.color)!
                self.pauseImage = generatePauseButton(color: theme.textCategories.paragraph.color)!
                
                self.titleNode.attributedText = titleString(media: self.media, theme: theme, strings: strings)
                
                var brightness: CGFloat = 0.0
                theme.textCategories.paragraph.color.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
                
                self.setNeedsLayout()
            }
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    @objc func buttonPressed() {
        if let _ = self.playbackState {
            self.context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: self.playlistType)
        } else {
            self.openMedia(self.media)
        }
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let insets = UIEdgeInsets(top: 18.0, left: 17.0, bottom: 18.0, right: 17.0)
        let leftInset: CGFloat = 46.0 + 10.0
        let rightInset: CGFloat = 0.0
        
        let maxTitleWidth = max(1.0, size.width - insets.left - leftInset - rightInset - insets.right)
        let titleSize = self.titleNode.measure(CGSize(width: maxTitleWidth, height: size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: insets.left + leftInset, y: 2.0), size: titleSize)
        
        self.buttonNode.frame = CGRect(origin: CGPoint(x: insets.left, y: 0.0), size: CGSize(width: 48.0, height: 48.0))
        self.statusNode.frame = CGRect(origin: CGPoint(x: insets.left, y: 0.0), size: CGSize(width: 48.0, height: 48.0))
        
        var topOffset: CGFloat = 0.0
        if self.titleNode.attributedText == nil || self.titleNode.attributedText!.length == 0 {
            topOffset = -10.0
        }
        
        let leftScrubberInset: CGFloat = insets.left + 46.0 + 10.0
        let rightScrubberInset: CGFloat = insets.right
        self.scrubbingNode.frame = CGRect(origin: CGPoint(x: leftScrubberInset, y: 26.0 + topOffset), size: CGSize(width: size.width - leftScrubberInset - rightScrubberInset, height: 15.0))
    }
}

