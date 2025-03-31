//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/DarwinHttp.h"

#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"

#import <Foundation/Foundation.h>

namespace td {

namespace {

NSURLSession *getSession() {
  static NSURLSession *urlSession = [] {
    auto configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.networkServiceType = NSURLNetworkServiceTypeResponsiveData;
    configuration.timeoutIntervalForResource = 90;
    configuration.waitsForConnectivity = true;
    return [NSURLSession sessionWithConfiguration:configuration];
  }();
  return urlSession;
}

NSString *to_ns_string(CSlice slice) {
  return [NSString stringWithUTF8String:slice.c_str()];
}

NSData *to_ns_data(Slice data) {
  return [NSData dataWithBytes:static_cast<const void *>(data.data()) length:data.size()];
}

auto http_get(CSlice url) {
  auto nsurl = [NSURL URLWithString:to_ns_string(url)];
  auto request = [NSURLRequest requestWithURL:nsurl];
  return request;
}

auto http_post(CSlice url, Slice data) {
  auto nsurl = [NSURL URLWithString:to_ns_string(url)];
  auto request = [NSMutableURLRequest requestWithURL:nsurl];
  [request setHTTPMethod:@"POST"];
  [request setHTTPBody:to_ns_data(data)];
  [request setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
  [request setValue:@"" forHTTPHeaderField:@"Host"];
  [request setValue:to_ns_string(PSLICE() << data.size()) forHTTPHeaderField:@"Content-Length"];
  [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
  return request;
}

void http_send(NSURLRequest *request, Promise<BufferSlice> promise) {
  __block auto callback = std::move(promise);
  NSURLSessionDataTask *dataTask =
    [getSession()
      dataTaskWithRequest:request
      completionHandler:
        ^(NSData *data, NSURLResponse *response, NSError *error) {
          if (error == nil) {
            callback.set_value(BufferSlice(Slice((const char *)([data bytes]), [data length])));
          } else {
            callback.set_error(Status::Error(static_cast<int32>([error code]), "HTTP request failed"));
          }
        }];
  [dataTask resume];
}
}  // namespace

void DarwinHttp::get(CSlice url, Promise<BufferSlice> promise) {
  return http_send(http_get(url), std::move(promise));
}

void DarwinHttp::post(CSlice url, Slice data, Promise<BufferSlice> promise) {
  return http_send(http_post(url, data), std::move(promise));
}

}  // namespace td
