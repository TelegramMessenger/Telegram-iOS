//
//  ASLog.m
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASLog.h>

os_log_t ASNodeLog() {
  return ASCreateOnce((ASEnableLogs && ASNodeLogEnabled) ? as_log_create("org.TextureGroup.Texture", "Node") : OS_LOG_DISABLED);
}

os_log_t ASLayoutLog() {
  return ASCreateOnce((ASEnableLogs && ASLayoutLogEnabled) ? as_log_create("org.TextureGroup.Texture", "Layout") : OS_LOG_DISABLED);
}

os_log_t ASCollectionLog() {
  return ASCreateOnce((ASEnableLogs && ASCollectionLogEnabled) ? as_log_create("org.TextureGroup.Texture", "Collection") : OS_LOG_DISABLED);
}

os_log_t ASDisplayLog() {
  return ASCreateOnce((ASEnableLogs && ASDisplayLogEnabled) ? as_log_create("org.TextureGroup.Texture", "Display") : OS_LOG_DISABLED);
}

os_log_t ASImageLoadingLog() {
  return ASCreateOnce((ASEnableLogs && ASImageLoadingLogEnabled) ? as_log_create("org.TextureGroup.Texture", "ImageLoading") : OS_LOG_DISABLED);
}

os_log_t ASMainThreadDeallocationLog() {
  return ASCreateOnce((ASEnableLogs && ASMainThreadDeallocationLogEnabled) ? as_log_create("org.TextureGroup.Texture", "MainDealloc") : OS_LOG_DISABLED);
}
