

//
// RMPhoneFormat.h v1.0

// Copyright (c) 2012, Rick Maddy
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <Foundation/Foundation.h>

@interface RMPhoneFormat : NSObject

+ (RMPhoneFormat *)instance;

- (id)init;
- (id)initWithDefaultCountry:(NSString *)countryCode;

- (NSString *)format:(NSString *)str implicitPlus:(bool)implicitPlus;

// Calling code for the user's default country based on their Region Format setting
- (NSString *)defaultCallingCode;
// countryCode must be 2-letter ISO 3166-1 code. Result does not include a leading +
- (NSString *)callingCodeForCountryCode:(NSString *)countryCode;
// callingCode should be 1 to 3 digit calling code. Result is a set of matching, lowercase, 2-letter ISO 3166-1 country codes
- (NSSet *)countriesForCallingCode:(NSString *)callingCode;

#ifdef DEBUG
- (void)dump;
#endif

@end
