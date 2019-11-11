
public_header_names = [
  "ASAvailability.h",
  "ASBaseDefines.h",
  "ASDisplayNode.h",
  "ASDisplayNode+Ancestry.h",
  "ASDisplayNode+Convenience.h",
  "ASDisplayNodeExtras.h",
  "ASConfiguration.h",
  "ASConfigurationDelegate.h",
  "ASConfigurationInternal.h",

  "ASControlNode.h",
  "ASImageNode.h",
  "ASTextNode.h",
  "ASTextNode2.h",
  "ASEditableTextNode.h",
  "ASButtonNode.h",

  "ASImageProtocols.h",

  "ASRangeManagingNode.h",
  "ASSectionContext.h",

  "ASElementMap.h",

  "ASSupplementaryNodeSource.h",

  "ASScrollNode.h",

  "ASNodeController+Beta.h",
  "ASViewController.h",
  "ASNavigationController.h",
  "ASTabBarController.h",
  "ASRangeControllerUpdateRangeProtocol+Beta.h",

  "ASLayout.h",
  "ASDimension.h",
  "ASDimensionInternal.h",
  "ASLayoutElement.h",
  "ASLayoutSpec.h",
  "ASBackgroundLayoutSpec.h",
  "ASCenterLayoutSpec.h",
  "ASCornerLayoutSpec.h",
  "ASRelativeLayoutSpec.h",
  "ASInsetLayoutSpec.h",
  "ASOverlayLayoutSpec.h",
  "ASRatioLayoutSpec.h",
  "ASAbsoluteLayoutSpec.h",
  "ASStackLayoutDefines.h",
  "ASStackLayoutSpec.h",

  "_ASAsyncTransaction.h",
  "_ASAsyncTransactionGroup.h",
  "_ASAsyncTransactionContainer.h",
  "ASCollections.h",
  "_ASDisplayLayer.h",
  "_ASDisplayView.h",
  "ASDisplayNode+Beta.h",
  "ASTextNode+Beta.h",
  "ASTextNodeTypes.h",
  "ASBlockTypes.h",
  "ASContextTransitioning.h",
  "ASControlNode+Subclasses.h",
  "ASDisplayNode+Subclasses.h",
  "ASEqualityHelpers.h",
  "ASEventLog.h",
  "ASHashing.h",
  "ASHighlightOverlayLayer.h",
  "ASImageContainerProtocolCategories.h",
  "ASLocking.h",
  "ASLog.h",
  "ASMainThreadDeallocation.h",
  "ASMutableAttributedStringBuilder.h",
  "ASRunLoopQueue.h",
  "ASTextKitComponents.h",
  "ASThread.h",
  "ASTraitCollection.h",
  "ASVisibilityProtocols.h",
  "ASWeakSet.h",

  "CoreGraphics+ASConvenience.h",
  "NSMutableAttributedString+TextKitAdditions.h",
  "UICollectionViewLayout+ASConvenience.h",
  "UIView+ASConvenience.h",
  "UIImage+ASConvenience.h",
  "ASGraphicsContext.h",
  "NSArray+Diffing.h",
  "ASObjectDescriptionHelpers.h",
  "UIResponder+AsyncDisplayKit.h",

  "AsyncDisplayKit+Debug.h",

  "ASExperimentalFeatures.h",
  "ASAssert.h",
]

public_headers = ["Source/" + name for name in public_header_names]
private_headers = glob([
  "Source/*.h",
], exclude = public_headers)

exported_headers_rule_name = "AsyncDisplayKit_ExportedHeaders"
exported_headers_path = "includedir"
name = "AsyncDisplayKit"

genrule(
  name = exported_headers_rule_name,
  srcs = public_headers,
  outs = [exported_headers_path + "/" + name + "/" + x.split('/')[::-1][0] for x in public_headers],
  cmd  = "cp $(SRCS) $(RULEDIR)" + "/" + exported_headers_path + "/" + name,
)
exported_headers = [":" + exported_headers_rule_name]

objc_library(
    name = "AsyncDisplayKit",
    enable_modules = True,
    module_name = "AsyncDisplayKit",
    srcs = glob([
        "Source/**/*.m",
        "Source/**/*.mm",
    ]) + private_headers,
    hdrs = exported_headers,
    defines = [
        "MINIMAL_ASDK",
    ],
    includes = [
      exported_headers_path,
    ],
    sdk_frameworks = [
      "Foundation",
      "UIKit",
      "QuartzCore",
      "CoreMedia",
      "CoreText",
      "CoreGraphics",
    ],
    visibility = [
        "//visibility:public",
    ],
)
