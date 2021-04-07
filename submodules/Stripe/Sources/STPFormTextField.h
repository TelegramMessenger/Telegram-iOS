//
//  STPFormTextField.h
//  Stripe
//
//  Created by Jack Flintermann on 7/16/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class STPFormTextField;

typedef NS_ENUM(NSInteger, STPFormTextFieldAutoFormattingBehavior) {
    STPFormTextFieldAutoFormattingBehaviorNone,
    STPFormTextFieldAutoFormattingBehaviorPhoneNumbers,
    STPFormTextFieldAutoFormattingBehaviorCardNumbers,
    STPFormTextFieldAutoFormattingBehaviorExpiration,
};

@protocol STPFormTextFieldDelegate <UITextFieldDelegate>
@optional
- (void)formTextFieldDidBackspaceOnEmpty:(nonnull STPFormTextField *)formTextField;
- (nonnull NSAttributedString *)formTextField:(nonnull STPFormTextField *)formTextField
           modifyIncomingTextChange:(nonnull NSAttributedString *)input;
- (void)formTextFieldTextDidChange:(nonnull STPFormTextField *)textField;
@end

@interface STPFormTextField : UITextField

@property(nonatomic, readwrite, nullable) UIColor *defaultColor;
@property(nonatomic, readwrite, nullable) UIColor *errorColor;
@property(nonatomic, readwrite, nullable) UIColor *placeholderColor;

@property(nonatomic, readwrite, assign)BOOL selectionEnabled; // defaults to NO
@property(nonatomic, readwrite, assign)BOOL preservesContentsOnPaste; // defaults to NO
@property(nonatomic, readwrite, assign)STPFormTextFieldAutoFormattingBehavior autoFormattingBehavior;
@property(nonatomic, readwrite, assign)BOOL validText;
@property(nonatomic, readwrite, weak, nullable)id<STPFormTextFieldDelegate>formDelegate;

- (CGSize)measureTextSize;

@end
