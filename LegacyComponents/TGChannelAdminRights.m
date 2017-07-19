#import "TGChannelAdminRights.h"

#import "PSKeyValueCoder.h"

@implementation TGChannelAdminRights

- (instancetype)initWithCanChangeInfo:(bool)canChangeInfo canPostMessages:(bool)canPostMessages canEditMessages:(bool)canEditMessages canDeleteMessages:(bool)canDeleteMessages canBanUsers:(bool)canBanUsers canInviteUsers:(bool)canInviteUsers canChangeInviteLink:(bool)canChangeInviteLink canPinMessages:(bool)canPinMessages canAddAdmins:(bool)canAddAdmins {
    self = [super init];
    if (self != nil) {
        _canChangeInfo = canChangeInfo;
        _canPostMessages = canPostMessages;
        _canEditMessages = canEditMessages;
        _canDeleteMessages = canDeleteMessages;
        _canBanUsers = canBanUsers;
        _canInviteUsers = canInviteUsers;
        _canChangeInviteLink = canChangeInviteLink;
        _canPinMessages = canPinMessages;
        _canAddAdmins = canAddAdmins;
    }
    return self;
}

- (instancetype)initWithFlags:(int32_t)flags {
    return [self initWithCanChangeInfo:flags & (1 << 0) canPostMessages:flags & (1 << 1) canEditMessages:flags & (1 << 2) canDeleteMessages:flags & (1 << 3) canBanUsers:flags & (1 << 4) canInviteUsers:flags & (1 << 5) canChangeInviteLink:flags & (1 << 6) canPinMessages:flags & (1 << 7) canAddAdmins:flags & (1 << 9)];
}

- (int32_t)tlFlags {
    int32_t flags = 0;
    if (_canChangeInfo) {
        flags |= (1 << 0);
    }
    if (_canPostMessages) {
        flags |= (1 << 1);
    }
    if (_canEditMessages) {
        flags |= (1 << 2);
    }
    if (_canDeleteMessages) {
        flags |= (1 << 3);
    }
    if (_canBanUsers) {
        flags |= (1 << 4);
    }
    if (_canInviteUsers) {
        flags |= (1 << 5);
    }
    if (_canChangeInviteLink) {
        flags |= (1 << 6);
    }
    if (_canPinMessages) {
        flags |= (1 << 7);
    }
    if (_canAddAdmins) {
        flags |= (1 << 9);
    }
    return flags;
}

- (bool)hasAnyRights {
    return [self tlFlags] != 0;
}

- (int32_t)numberOfRights {
    int32_t flags = [self tlFlags];
    int32_t count = 0;
    for (int i = 0; i < 31; i++) {
        if (flags == 0) {
            break;
        }
        if ((flags & 1) != 0) {
            count++;
        }
        flags = flags >> 1;
    }
    return count;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    int32_t flags = [coder decodeInt32ForCKey:"f"];
    return [self initWithFlags:flags];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt32:[self tlFlags] forCKey:"f"];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TGChannelAdminRights class]]) {
        return false;
    }
    TGChannelAdminRights *other = object;
    return [self tlFlags] == [other tlFlags];
}

@end
