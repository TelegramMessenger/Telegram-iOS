//
//  ASLog.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLog.h>
#import <stdatomic.h>

static atomic_bool __ASLogEnabled = ATOMIC_VAR_INIT(YES);

void ASDisableLogging() {
  atomic_store(&__ASLogEnabled, NO);
}

void ASEnableLogging() {
  atomic_store(&__ASLogEnabled, YES);
}

ASDISPLAYNODE_INLINE BOOL ASLoggingIsEnabled() {
  return atomic_load(&__ASLogEnabled);
}

os_log_t ASNodeLog() {
  return (ASNodeLogEnabled && ASLoggingIsEnabled()) ? ASCreateOnce(as_log_create("org.TextureGroup.Texture", "Node")) : OS_LOG_DISABLED;
}

os_log_t ASLayoutLog() {
  return (ASLayoutLogEnabled && ASLoggingIsEnabled()) ? ASCreateOnce(as_log_create("org.TextureGroup.Texture", "Layout")) : OS_LOG_DISABLED;
}

os_log_t ASCollectionLog() {
  return (ASCollectionLogEnabled && ASLoggingIsEnabled()) ?ASCreateOnce(as_log_create("org.TextureGroup.Texture", "Collection")) : OS_LOG_DISABLED;
}

os_log_t ASDisplayLog() {
  return (ASDisplayLogEnabled && ASLoggingIsEnabled()) ?ASCreateOnce(as_log_create("org.TextureGroup.Texture", "Display")) : OS_LOG_DISABLED;
}

os_log_t ASImageLoadingLog() {
  return (ASImageLoadingLogEnabled && ASLoggingIsEnabled()) ? ASCreateOnce(as_log_create("org.TextureGroup.Texture", "ImageLoading")) : OS_LOG_DISABLED;
}

os_log_t ASMainThreadDeallocationLog() {
  return (ASMainThreadDeallocationLogEnabled && ASLoggingIsEnabled()) ? ASCreateOnce(as_log_create("org.TextureGroup.Texture", "MainDealloc")) : OS_LOG_DISABLED;
}
