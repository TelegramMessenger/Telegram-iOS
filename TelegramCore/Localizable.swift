// Generated using SwiftGen, by O.Halligon — https://github.com/AliSoftware/SwiftGen

import Foundation

enum L10n {
  /// Group Created
  case ChatServiceGroupCreated
  /// %@ invited %@
  case ChatServiceGroupAddedMembers(String, String)
  /// %@ joined group
  case ChatServiceGroupAddedSelf(String)
  /// %@ kicked %@
  case ChatServiceGroupRemovedMembers(String, String)
  /// %@ left group
  case ChatServiceGroupRemovedSelf(String)
  /// %@ updated group photo
  case ChatServiceGroupUpdatedPhoto(String)
  /// %@ removed group photo
  case ChatServiceGroupRemovedPhoto(String)
  /// %@ renamed group to \"%@\"
  case ChatServiceGroupUpdatedTitle(String, String)
  /// %@ pinned %@
  case ChatServiceGroupUpdatedPinnedMessage(String, String)
  /// %@ removed pinned message
  case ChatServiceGroupRemovedPinnedMessage(String)
  /// %@ joined group via invite link
  case ChatServiceGroupJoinedByLink(String)
  /// The group was upgraded to a supergroup
  case ChatServiceGroupMigratedToSupergroup
}

extension L10n: CustomStringConvertible {
  var description: String { return self.string }

  var string: String {
    switch self {
      case .ChatServiceGroupCreated:
        return L10n.tr("Chat.Service.Group.Created")
      case .ChatServiceGroupAddedMembers(let p0, let p1):
        return L10n.tr("Chat.Service.Group.AddedMembers", p0, p1)
      case .ChatServiceGroupAddedSelf(let p0):
        return L10n.tr("Chat.Service.Group.AddedSelf", p0)
      case .ChatServiceGroupRemovedMembers(let p0, let p1):
        return L10n.tr("Chat.Service.Group.RemovedMembers", p0, p1)
      case .ChatServiceGroupRemovedSelf(let p0):
        return L10n.tr("Chat.Service.Group.RemovedSelf", p0)
      case .ChatServiceGroupUpdatedPhoto(let p0):
        return L10n.tr("Chat.Service.Group.UpdatedPhoto", p0)
      case .ChatServiceGroupRemovedPhoto(let p0):
        return L10n.tr("Chat.Service.Group.RemovedPhoto", p0)
      case .ChatServiceGroupUpdatedTitle(let p0, let p1):
        return L10n.tr("Chat.Service.Group.UpdatedTitle", p0, p1)
      case .ChatServiceGroupUpdatedPinnedMessage(let p0, let p1):
        return L10n.tr("Chat.Service.Group.UpdatedPinnedMessage", p0, p1)
      case .ChatServiceGroupRemovedPinnedMessage(let p0):
        return L10n.tr("Chat.Service.Group.RemovedPinnedMessage", p0)
      case .ChatServiceGroupJoinedByLink(let p0):
        return L10n.tr("Chat.Service.Group.JoinedByLink", p0)
      case .ChatServiceGroupMigratedToSupergroup:
        return L10n.tr("Chat.Service.Group.MigratedToSupergroup")
    }
  }

  private static func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

func tr(_ key: L10n) -> String {
  return key.string
}

