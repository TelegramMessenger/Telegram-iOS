//
//  FillNode.swift
//  lottie-swift
//
//  Created by Brandon Withrow on 1/17/19.
//

import Foundation
import CoreGraphics

final class FillNodeProperties: NodePropertyMap {
  
  init(fill: Fill) {
    self.color = NodeProperty(provider: KeyframeInterpolator(keyframes: fill.color.keyframes))
    self.opacity = NodeProperty(provider: KeyframeInterpolator(keyframes: fill.opacity.keyframes))
    self.type = fill.fillRule
    let keypathProperties: [String : AnyNodeProperty] = [
      "Opacity" : opacity,
      "Color" : color
    ]
    self.properties = Array(keypathProperties.values)
  }
  
  let opacity: NodeProperty<Vector1D>
  let color: NodeProperty<Color>
  let type: FillRule
  
  let properties: [AnyNodeProperty]
  
}

final class FillNode: AnimatorNode, RenderNode {
  
  let fillRender: FillRenderer
  var renderer: NodeOutput & Renderable {
    return fillRender
  }
  
  let fillProperties: FillNodeProperties

  init(parentNode: AnimatorNode?, fill: Fill) {
    self.fillRender = FillRenderer(parent: parentNode?.outputNode)
    self.fillProperties = FillNodeProperties(fill: fill)
    self.parentNode = parentNode
  }
  
  // MARK: Animator Node Protocol
  
  var propertyMap: NodePropertyMap {
    return fillProperties
  }
  
  let parentNode: AnimatorNode?
  var hasLocalUpdates: Bool = false
  var hasUpstreamUpdates: Bool = false
  var lastUpdateFrame: CGFloat? = nil
  var isEnabled: Bool = true {
    didSet {
      fillRender.isEnabled = isEnabled
    }
  }
  
  func localUpdatesPermeateDownstream() -> Bool {
    return false
  }
  
  func rebuildOutputs(frame: CGFloat) {
    fillRender.color = fillProperties.color.value.cgColorValue
    fillRender.opacity = fillProperties.opacity.value.cgFloatValue * 0.01
    fillRender.fillRule = fillProperties.type
  }
}
