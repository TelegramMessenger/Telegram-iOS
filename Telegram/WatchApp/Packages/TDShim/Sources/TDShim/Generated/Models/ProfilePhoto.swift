//
//  ProfilePhoto.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a user profile photo
public struct ProfilePhoto: Codable, Equatable, Hashable, Identifiable {

    /// A big (640x640) user profile photo. The file can be downloaded only before the photo is changed
    public let big: File

    /// True, if the photo has animated variant
    public let hasAnimation: Bool

    /// Photo identifier; 0 for an empty photo. Can be used to find a photo in a list of user profile photos
    public let id: TdInt64

    /// True, if the photo is visible only for the current user
    public let isPersonal: Bool

    /// User profile photo minithumbnail; may be null
    public let minithumbnail: Minithumbnail?

    /// A small (160x160) user profile photo. The file can be downloaded only before the photo is changed
    public let small: File


    public init(
        big: File,
        hasAnimation: Bool,
        id: TdInt64,
        isPersonal: Bool,
        minithumbnail: Minithumbnail?,
        small: File
    ) {
        self.big = big
        self.hasAnimation = hasAnimation
        self.id = id
        self.isPersonal = isPersonal
        self.minithumbnail = minithumbnail
        self.small = small
    }
}

