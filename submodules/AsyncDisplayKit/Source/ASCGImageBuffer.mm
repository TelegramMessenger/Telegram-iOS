//
//  ASCGImageBuffer.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASCGImageBuffer.h>

#import <sys/mman.h>
#import <mach/mach_init.h>
#import <mach/vm_map.h>
#import <mach/vm_statistics.h>

/**
 * The behavior of this class is modeled on the private function
 * _CGDataProviderCreateWithCopyOfData, which is the function used
 * by CGBitmapContextCreateImage.
 *
 * If the buffer is larger than a page, we use mmap and mark it as
 * read-only when they are finished drawing. Then we wrap the VM
 * in an NSData
 */
@implementation ASCGImageBuffer {
  BOOL _createdData;
  BOOL _isVM;
  NSUInteger _length;
}

- (instancetype)initWithLength:(NSUInteger)length
{
  if (self = [super init]) {
    _length = length;
    _isVM = false;//(length >= vm_page_size);
    if (_isVM) {
      _mutableBytes = mmap(NULL, length, PROT_WRITE | PROT_READ, MAP_ANONYMOUS | MAP_PRIVATE, VM_MAKE_TAG(VM_MEMORY_COREGRAPHICS_DATA), 0);
      if (_mutableBytes == MAP_FAILED) {
        NSAssert(NO, @"Failed to map for CG image data.");
        _isVM = NO;
      }
    }
    
    // Check the VM flag again because we may have failed above.
    if (!_isVM) {
      _mutableBytes = malloc(length);
    }
  }
  return self;
}

- (void)dealloc
{
  if (!_createdData) {
    [ASCGImageBuffer deallocateBuffer:_mutableBytes length:_length isVM:_isVM];
  }
}

- (CGDataProviderRef)createDataProviderAndInvalidate
{
  NSAssert(!_createdData, @"Should not create data provider from buffer multiple times.");
  _createdData = YES;
  
  // Mark the pages as read-only.
  if (_isVM) {
    __unused kern_return_t result = vm_protect(mach_task_self(), (vm_address_t)_mutableBytes, _length, true, VM_PROT_READ);
    NSAssert(result == noErr, @"Error marking buffer as read-only: %@", [NSError errorWithDomain:NSMachErrorDomain code:result userInfo:nil]);
  }
  
  // Wrap in an NSData
  BOOL isVM = _isVM;
  NSData *d = [[NSData alloc] initWithBytesNoCopy:_mutableBytes length:_length deallocator:^(void * _Nonnull bytes, NSUInteger length) {
    [ASCGImageBuffer deallocateBuffer:bytes length:length isVM:isVM];
  }];
  return CGDataProviderCreateWithCFData((__bridge CFDataRef)d);
}

+ (void)deallocateBuffer:(void *)buf length:(NSUInteger)length isVM:(BOOL)isVM
{
  if (isVM) {
    __unused kern_return_t result = vm_deallocate(mach_task_self(), (vm_address_t)buf, length);
    NSAssert(result == noErr, @"Failed to unmap cg image buffer: %@", [NSError errorWithDomain:NSMachErrorDomain code:result userInfo:nil]);
  } else {
    free(buf);
  }
}

@end
