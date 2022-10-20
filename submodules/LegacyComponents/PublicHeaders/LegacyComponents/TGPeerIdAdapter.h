#ifndef Telegraph_TGPeerIdAdapter_h
#define Telegraph_TGPeerIdAdapter_h

static inline bool TGPeerIdIsGroup(int64_t peerId) {
    return peerId < 0 && peerId > INT32_MIN;
}

static inline bool TGPeerIdIsUser(int64_t peerId) {
    return peerId > 0 && peerId < INT32_MAX;
}

static inline bool TGPeerIdIsChannel(int64_t peerId) {
    return peerId <= ((int64_t)INT32_MIN) * 2 && peerId > ((int64_t)INT32_MIN) * 3;
}

static inline bool TGPeerIdIsAdminLog(int64_t peerId) {
    return peerId <= ((int64_t)INT32_MIN) * 3 && peerId > ((int64_t)INT32_MIN) * 4;
}

static inline bool TGPeerIdIsAd(int64_t peerId) {
    return peerId <= ((int64_t)INT32_MIN) * 4 && peerId > ((int64_t)INT32_MIN) * 5;
}

static inline int32_t TGChannelIdFromPeerId(int64_t peerId) {
    if (TGPeerIdIsChannel(peerId)) {
        return (int32_t)(((int64_t)INT32_MIN) * 2 - peerId);
    } else {
        return 0;
    }
}

static inline int64_t TGPeerIdFromChannelId(int32_t channelId) {
    return ((int64_t)INT32_MIN) * 2 - ((int64_t)channelId);
}

static inline int64_t TGPeerIdFromAdminLogId(int32_t channelId) {
    return ((int64_t)INT32_MIN) * 3 - ((int64_t)channelId);
}

static inline int64_t TGPeerIdFromAdId(int32_t channelId) {
    return ((int64_t)INT32_MIN) * 4 - ((int64_t)channelId);
}

static inline int64_t TGPeerIdFromGroupId(int32_t groupId) {
    return -groupId;
}

static inline int32_t TGGroupIdFromPeerId(int64_t peerId) {
    if (TGPeerIdIsGroup(peerId)) {
        return (int32_t)-peerId;
    } else {
        return 0;
    }
}

static inline int32_t TGAdminLogIdFromPeerId(int64_t peerId) {
    if (TGPeerIdIsAdminLog(peerId)) {
        return (int32_t)(((int64_t)INT32_MIN) * 3 - peerId);
    } else {
        return 0;
    }
}

static inline int32_t TGAdIdFromPeerId(int64_t peerId) {
    if (TGPeerIdIsAd(peerId)) {
        return (int32_t)(((int64_t)INT32_MIN) * 4 - peerId);
    } else {
        return 0;
    }
}

static inline bool TGPeerIdIsSecretChat(int64_t peerId) {
    return peerId <= ((int64_t)INT32_MIN) && peerId > ((int64_t)INT32_MIN) * 2;
}

#endif
