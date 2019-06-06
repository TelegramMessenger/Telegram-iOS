import Foundation
#if BUCK
import MtProtoKit
#else
import MtProtoKitDynamic
#endif

import LegacyComponents

@objc class LegacyHTTPOperationImpl: AFHTTPRequestOperation, LegacyHTTPRequestOperation {
}
