import Foundation
import UIKit
import Display

public struct MosaicItemPosition: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let top = MosaicItemPosition(rawValue: 1)
    public static let bottom = MosaicItemPosition(rawValue: 2)
    public static let left = MosaicItemPosition(rawValue: 4)
    public static let right = MosaicItemPosition(rawValue: 8)
    public static let inside = MosaicItemPosition(rawValue: 16)
    public static let unknown = MosaicItemPosition(rawValue: 65536)
    
    public var isWide: Bool {
        return self.contains(.left) && self.contains(.right) && (self.contains(.top) || self.contains(.bottom))
    }
}

private struct MosaicItemInfo {
    let index: Int
    let imageSize: CGSize
    let aspectRatio: CGFloat

    var layoutFrame: CGRect = CGRect()
    var position: MosaicItemPosition = []
}

private struct MosaicLayoutAttempt {
    let lineCounts: [Int]
    let heights: [CGFloat]
}

public func chatMessageBubbleMosaicLayout(maxSize: CGSize, itemSizes: [CGSize], spacing: CGFloat = 1.0, fillWidth: Bool = false) -> ([(CGRect, MosaicItemPosition)], CGSize) {
    var proportions = ""
    var averageAspectRatio: CGFloat = 1.0
    var forceCalc = false
    
    var itemInfos = itemSizes.enumerated().map { index, itemSize -> MosaicItemInfo in
        let aspectRatio = itemSize.height.isZero ? 1.0 : itemSize.width / itemSize.height
        if aspectRatio > 1.2 {
            proportions += "w"
        } else if aspectRatio < 0.8 {
            proportions += "n"
        } else {
            proportions += "q"
        }
        
        if aspectRatio > 2.0 {
            forceCalc = true
        }
        averageAspectRatio += aspectRatio
        
        return MosaicItemInfo(index: index, imageSize: itemSize, aspectRatio: aspectRatio, layoutFrame: CGRect(), position: [])
    }
    
    let minWidth: CGFloat = 68.0
    let minHeight: CGFloat = 81.0
    let maxAspectRatio = maxSize.width / maxSize.height
    if !itemInfos.isEmpty {
        averageAspectRatio = averageAspectRatio / CGFloat(itemInfos.count)
    }
    
    if !forceCalc {
        if itemInfos.count == 2 {
            if proportions == "ww" && averageAspectRatio > 1.4 * maxAspectRatio && itemInfos[1].aspectRatio - itemInfos[0].aspectRatio < 0.2 {
                let width = maxSize.width
                let height = floor(min(width / itemInfos[0].aspectRatio, min(width / itemInfos[1].aspectRatio, (maxSize.height - spacing) / 2.0)))
                
                itemInfos[0].layoutFrame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
                itemInfos[0].position = [.top, .left, .right]
                
                itemInfos[1].layoutFrame = CGRect(x: 0.0, y: height + spacing, width: width, height: height)
                itemInfos[1].position = [.bottom, .left, .right]
            } else if proportions == "ww" || proportions == "qq" {
                let width = (maxSize.width - spacing) / 2.0
                let height = floor(min(width / itemInfos[0].aspectRatio, min(width / itemInfos[1].aspectRatio, maxSize.height)))
                
                itemInfos[0].layoutFrame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
                itemInfos[0].position = [.top, .left, .bottom]
                
                itemInfos[1].layoutFrame = CGRect(x: width + spacing, y: 0.0, width: width, height: height)
                itemInfos[1].position = [.top, .right, .bottom]
            } else {
                let secondWidth = floor(min(0.5 * (maxSize.width - spacing), round((maxSize.width - spacing) / itemInfos[0].aspectRatio / (1.0 / itemInfos[0].aspectRatio + 1.0 / itemInfos[1].aspectRatio))))
                let firstWidth = maxSize.width - secondWidth - spacing
                let height = floor(min(maxSize.height, round(min(firstWidth / itemInfos[0].aspectRatio, secondWidth / itemInfos[1].aspectRatio))))
                
                itemInfos[0].layoutFrame = CGRect(x: 0.0, y: 0.0, width: firstWidth, height: height)
                itemInfos[0].position = [.top, .left, .bottom]
                
                itemInfos[1].layoutFrame = CGRect(x: firstWidth + spacing, y: 0.0, width: secondWidth, height: height)
                itemInfos[1].position = [.top, .right, .bottom]
            }
        } else if (itemInfos.count == 3) {
            if proportions.hasPrefix("n") {
                let firstHeight = maxSize.height
                
                let thirdHeight = min((maxSize.height - spacing) * 0.5, round(itemInfos[1].aspectRatio * (maxSize.width - spacing) / (itemInfos[2].aspectRatio + itemInfos[1].aspectRatio)))
                let secondHeight = maxSize.height - thirdHeight - spacing
                var rightWidth = max(minWidth, min((maxSize.width - spacing) * 0.5, round(min(thirdHeight * itemInfos[2].aspectRatio, secondHeight * itemInfos[1].aspectRatio))))
                if fillWidth {
                    rightWidth = floorToScreenPixels(maxSize.width / 2.0)
                }
                var leftWidth = round(min(firstHeight * itemInfos[0].aspectRatio, (maxSize.width - spacing - rightWidth)))
                if fillWidth {
                    leftWidth = maxSize.width - spacing - rightWidth
                }
                itemInfos[0].layoutFrame = CGRect(x: 0.0, y: 0.0, width: leftWidth, height: firstHeight)
                itemInfos[0].position = [.top, .left, .bottom]
                
                itemInfos[1].layoutFrame = CGRect(x: leftWidth + spacing, y: 0.0, width: rightWidth, height: secondHeight)
                itemInfos[1].position = [.right, .top]
                
                itemInfos[2].layoutFrame = CGRect(x: leftWidth + spacing, y: secondHeight + spacing, width: rightWidth, height: thirdHeight)
                itemInfos[2].position = [.right, .bottom]
            } else {
                var width = maxSize.width
                let firstHeight = floor(min(width / itemInfos[0].aspectRatio, (maxSize.height - spacing) * 0.66))
                itemInfos[0].layoutFrame = CGRect(x: 0.0, y: 0.0, width: width, height: firstHeight)
                itemInfos[0].position = [.top, .left, .right]
                
                width = (maxSize.width - spacing) / 2.0
                let secondHeight = min(maxSize.height - firstHeight - spacing, round(min(width / itemInfos[1].aspectRatio, width / itemInfos[2].aspectRatio)))
                itemInfos[1].layoutFrame = CGRect(x: 0.0, y: firstHeight + spacing, width: width, height: secondHeight)
                itemInfos[1].position = [.left, .bottom]
                
                itemInfos[2].layoutFrame = CGRect(x: width + spacing, y: firstHeight + spacing, width: width, height: secondHeight)
                itemInfos[2].position = [.right, .bottom]
            }
        } else if itemInfos.count == 4 {
            if proportions == "wwww" || proportions.hasPrefix("w") {
                let w = maxSize.width
                let h0 = round(min(w / itemInfos[0].aspectRatio, (maxSize.height - spacing) * 0.66))
                itemInfos[0].layoutFrame = CGRect(x: 0.0, y: 0.0, width: w, height: h0)
                itemInfos[0].position = [.top, .left, .right]
                
                var h = round((maxSize.width - 2 * spacing) / (itemInfos[1].aspectRatio + itemInfos[2].aspectRatio + itemInfos[3].aspectRatio))
                let w0 = max(minWidth, min((maxSize.width - 2 * spacing) * 0.4, h * itemInfos[1].aspectRatio))
                let w2 = max(max(minWidth, (maxSize.width - 2 * spacing) * 0.33), h * itemInfos[3].aspectRatio)
                let w1 = w - w0 - w2 - 2 * spacing
                h = max(minHeight, min(maxSize.height - h0 - spacing, h))
                itemInfos[1].layoutFrame = CGRect(x: 0.0, y: h0 + spacing, width: w0, height: h)
                itemInfos[1].position = [.left, .bottom]
                
                itemInfos[2].layoutFrame = CGRect(x: w0 + spacing, y: h0 + spacing, width: w1, height: h)
                itemInfos[2].position = [.bottom]
                
                itemInfos[3].layoutFrame = CGRect(x: w0 + w1 + 2 * spacing, y: h0 + spacing, width: w2, height: h)
                itemInfos[3].position = [.right, .bottom]
            } else {
                let h = maxSize.height
                let w0 = round(min(h * itemInfos[0].aspectRatio, (maxSize.width - spacing) * 0.6))
                itemInfos[0].layoutFrame = CGRect(x: 0.0, y: 0.0, width: w0, height: h)
                itemInfos[0].position = [.top, .left, .bottom]
                
                var w = round((maxSize.height - 2 * spacing) / (1.0 / itemInfos[1].aspectRatio + 1.0 /  itemInfos[2].aspectRatio + 1.0 / itemInfos[3].aspectRatio))
                let h0 = floor(w / itemInfos[1].aspectRatio)
                let h1 = floor(w / itemInfos[2].aspectRatio)
                let h2 = h - h0 - h1 - 2.0 * spacing
                w = max(minWidth, min(maxSize.width - w0 - spacing, w))
                itemInfos[1].layoutFrame = CGRect(x: w0 + spacing, y: 0.0, width: w, height: h0)
                itemInfos[1].position = [.right, .top]
                
                itemInfos[2].layoutFrame = CGRect(x: w0 + spacing, y: h0 + spacing, width: w, height: h1)
                itemInfos[2].position = [.right]
                
                itemInfos[3].layoutFrame = CGRect(x: w0 + spacing, y: h0 + h1 + 2 * spacing, width: w, height: h2)
                itemInfos[3].position = [.right, .bottom]
            }
        }
    }
    
    if forceCalc || itemInfos.count >= 5 {
        var croppedRatios: [CGFloat] = []
        for itemInfo in itemInfos {
            let aspectRatio = itemInfo.aspectRatio
            var croppedRatio = aspectRatio
            if averageAspectRatio > 1.1 {
                croppedRatio = max(1.0, aspectRatio)
            } else {
                croppedRatio = min(1.0, aspectRatio)
            }
            
            croppedRatio = max(0.66667, min(1.7, croppedRatio))
            croppedRatios.append(croppedRatio)
        }
        
        func multiHeight(_ ratios: [CGFloat]) -> CGFloat {
            var ratioSum: CGFloat = 0.0
            for ratio in ratios {
                ratioSum += ratio
            }
            return (maxSize.width - CGFloat(ratios.count - 1) * spacing) / ratioSum
        }
        
        var attempts: [MosaicLayoutAttempt] = []
        func addAttempt(_ lineCounts: [Int], _ heights: [CGFloat], _ attempts: inout [MosaicLayoutAttempt]) {
            attempts.append(MosaicLayoutAttempt(lineCounts: lineCounts, heights: heights))
        }
        
        for firstLine in 1 ..< croppedRatios.count {
            let secondLine = croppedRatios.count - firstLine
            if firstLine > 3 || secondLine > 3 {
                continue
            }
            
            addAttempt([firstLine, croppedRatios.count - firstLine], [multiHeight(Array(croppedRatios[0..<firstLine])), multiHeight(Array(croppedRatios[firstLine..<croppedRatios.count]))], &attempts)
        }
        
        for firstLine in 1 ..< croppedRatios.count - 1 {
            for secondLine in 1 ..< croppedRatios.count - firstLine {
                let thirdLine = croppedRatios.count - firstLine - secondLine
                if firstLine > 3 || secondLine > (averageAspectRatio < 0.85 ? 4 : 3) || thirdLine > 3 {
                    continue
                }
                
                addAttempt([firstLine, secondLine, thirdLine], [multiHeight(Array(croppedRatios[0 ..< firstLine])), multiHeight(Array(croppedRatios[firstLine ..< croppedRatios.count - thirdLine])), multiHeight(Array(croppedRatios[firstLine + secondLine ..< croppedRatios.count]))], &attempts)
            }
        }
        
        if croppedRatios.count - 2 >= 1 {
            outer: for firstLine in 1 ..< croppedRatios.count - 2 {
                if croppedRatios.count - firstLine < 1 {
                    continue outer
                }
                for secondLine in 1 ..< croppedRatios.count - firstLine {
                    for thirdLine in 1 ..< croppedRatios.count - firstLine - secondLine {
                        let fourthLine = croppedRatios.count - firstLine - secondLine - thirdLine
                        if firstLine > 3 || secondLine > 3 || thirdLine > 3 || fourthLine > 3 {
                            continue
                        }
                        
                        addAttempt([firstLine, secondLine, thirdLine, fourthLine], [multiHeight(Array(croppedRatios[0 ..< firstLine])), multiHeight(Array(croppedRatios[firstLine ..< croppedRatios.count - thirdLine - fourthLine])), multiHeight(Array(croppedRatios[firstLine + secondLine ..< croppedRatios.count - fourthLine])), multiHeight(Array(croppedRatios[firstLine + secondLine + thirdLine ..< croppedRatios.count]))], &attempts)
                    }
                }
            }
        }
        
        let maxHeight = floor(maxSize.width / 3.0 * 4.0)
        var optimal: MosaicLayoutAttempt? = nil
        var optimalDiff: CGFloat = 0.0
        for attempt in attempts {
            var totalHeight = spacing * CGFloat(attempt.heights.count - 1)
            var minLineHeight: CGFloat = .greatestFiniteMagnitude
            var maxLineHeight: CGFloat = 0.0
            for h in attempt.heights {
                totalHeight += floor(h)
                if totalHeight < minLineHeight {
                    minLineHeight = totalHeight
                }
                if totalHeight > maxLineHeight {
                    maxLineHeight = totalHeight
                }
            }
            
            var diff = abs(totalHeight - maxHeight)
            
            if attempt.lineCounts.count > 1 {
                if (attempt.lineCounts[0] > attempt.lineCounts[1]) || (attempt.lineCounts.count > 2 && attempt.lineCounts[1] > attempt.lineCounts[2]) || (attempt.lineCounts.count > 3 && attempt.lineCounts[2] > attempt.lineCounts[3]) {
                    diff *= 1.5
                }
            }
            
            if minLineHeight < minWidth {
                diff *= 1.5
            }
            
            if optimal == nil || diff < optimalDiff {
                optimal = attempt
                optimalDiff = diff
            }
        }
        
        var index = 0
        var y: CGFloat = 0.0
        if let optimal = optimal {
            for i in 0 ..< optimal.lineCounts.count {
                let count = optimal.lineCounts[i]
                let lineHeight = ceil(optimal.heights[i])
                var x: CGFloat = 0.0
                
                var positionFlags: MosaicItemPosition = []
                if i == 0 {
                    positionFlags.insert(.top)
                }
                if i == optimal.lineCounts.count - 1 {
                    positionFlags.insert(.bottom)
                }
                
                for k in 0 ..< count {
                    var innerPositionFlags = positionFlags
                    
                    if k == 0 {
                        innerPositionFlags.insert(.left)
                    }
                    if k == count - 1 {
                        innerPositionFlags.insert(.right)
                    }
                    
                    if positionFlags == .none {
                        innerPositionFlags = .inside
                    }
                    
                    let ratio = croppedRatios[index]
                    let width = ceil(ratio * lineHeight)
                    itemInfos[index].layoutFrame = CGRect(x: x, y: y, width: width, height: lineHeight)
                    itemInfos[index].position = innerPositionFlags
                    
                    x += width + spacing
                    index += 1
                }
                
                y += lineHeight + spacing
            }
            
            index = 0
            var maxWidth: CGFloat = 0.0
            for i in 0 ..< optimal.lineCounts.count {
                let count = optimal.lineCounts[i]
                for k in 0 ..< count {
                    if k == count - 1 {
                        maxWidth = max(maxWidth, itemInfos[index].layoutFrame.maxX)
                    }
                    index += 1
                }
            }
            
            index = 0
            for i in 0 ..< optimal.lineCounts.count {
                let count = optimal.lineCounts[i]
                for k in 0 ..< count {
                    if k == count - 1 {
                        var frame = itemInfos[index].layoutFrame
                        frame.size.width = max(frame.width, maxWidth - frame.minX)
                        itemInfos[index].layoutFrame = frame
                    }
                    index += 1
                }
            }
        }
    }
    
    var dimensions = CGSize()
    for itemInfo in itemInfos {
        dimensions.width = max(dimensions.width, round(itemInfo.layoutFrame.maxX))
        dimensions.height = max(dimensions.height, round(itemInfo.layoutFrame.maxY))
    }
    
    return (itemInfos.map { ($0.layoutFrame, $0.position) }, dimensions)
}
