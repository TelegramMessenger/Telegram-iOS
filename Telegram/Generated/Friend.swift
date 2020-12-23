//
// Friend.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 10.16, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(Friend)
public class Friend: INObject {

    @available(iOS 13.0, macOS 10.16, watchOS 6.0, *)
    @NSManaged public var subtitle: String?

}

@available(iOS 13.0, macOS 10.16, watchOS 6.0, *) @available(tvOS, unavailable)
@objc(FriendResolutionResult)
public class FriendResolutionResult: INObjectResolutionResult {

    // This resolution result is for when the app extension wants to tell Siri to proceed, with a given Friend. The resolvedValue can be different than the original Friend. This allows app extensions to apply business logic constraints.
    // Use notRequired() to continue with a 'nil' value.
    @objc(successWithResolvedFriend:)
    public class func success(with resolvedObject: Friend) -> Self {
        return super.success(with: resolvedObject) as! Self
    }

    // This resolution result is to ask Siri to disambiguate between the provided Friend.
    @objc(disambiguationWithFriendsToDisambiguate:)
    public class func disambiguation(with objectsToDisambiguate: [Friend]) -> Self {
        return super.disambiguation(with: objectsToDisambiguate) as! Self
    }

    // This resolution result is to ask Siri to confirm if this is the value with which the user wants to continue.
    @objc(confirmationRequiredWithFriendToConfirm:)
    public class func confirmationRequired(with objectToConfirm: Friend?) -> Self {
        return super.confirmationRequired(with: objectToConfirm) as! Self
    }

    @available(*, unavailable)
    override public class func success(with resolvedObject: INObject) -> Self {
        fatalError()
    }

    @available(*, unavailable)
    override public class func disambiguation(with objectsToDisambiguate: [INObject]) -> Self {
        fatalError()
    }

    @available(*, unavailable)
    override public class func confirmationRequired(with objectToConfirm: INObject?) -> Self {
        fatalError()
    }

}

#endif
