//
//  ViewController.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>


@interface ViewController () <ASEditableTextNodeDelegate>
{
  ASEditableTextNode *_textNode;
  
  // These elements are a test case for ASTextNode truncation.
  UILabel *_label;
  ASTextNode *_node;
}

@end


@implementation ViewController

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  // simple editable text node.  here we use it synchronously, but it fully supports async layout & display
  _textNode = [[ASEditableTextNode alloc] init];
  _textNode.returnKeyType = UIReturnKeyDone;
  _textNode.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.1f];

  // with placeholder text (displayed if the user hasn't entered text)
  NSDictionary *placeholderAttrs = @{ NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-LightItalic" size:18.0f] };
  _textNode.attributedPlaceholderText = [[NSAttributedString alloc] initWithString:@"Tap to type!"
                                                                        attributes:placeholderAttrs];

  // and typing attributes (style for any text the user enters)
  _textNode.typingAttributes = @{ NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:18.0f] };

  // the usual delegate methods are available; see ASEditableTextNodeDelegate
  _textNode.delegate = self;
  
  
  // Do any additional setup after loading the view, typically from a nib.
  NSDictionary *attrs = @{ NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:12.0f] };
  NSAttributedString *string = [[NSAttributedString alloc] initWithString:@"1\n2\n3\n4\n5" attributes:attrs];
  
  _label = [[UILabel alloc] init];
  _label.attributedText = string;
  _label.backgroundColor = [UIColor lightGrayColor];
  _label.numberOfLines = 3;
  _label.frame = CGRectMake(20, 400, 40, 100);
  
  _node = [[ASTextNode alloc] init];
  _node.maximumNumberOfLines = 3;
  _node.backgroundColor = [UIColor lightGrayColor];
  _node.attributedText = string;
  _node.frame = CGRectMake(70, 400, 40, 100);
//  [_node measure:CGSizeMake(40, 50)];  No longer needed now that https://github.com/facebook/AsyncDisplayKit/issues/1295 is fixed.

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubnode:_textNode];
  [self.view addSubnode:_node];
  [self.view addSubview:_label];

  [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)]];
}

- (void)viewWillLayoutSubviews
{
  // place the text node in the top half of the screen, with a bit of padding
  _textNode.frame = CGRectMake(0, 20, self.view.bounds.size.width, (self.view.bounds.size.height / 2) - 40);
}

- (void)tap:(UITapGestureRecognizer *)sender
{
  // dismiss the keyboard when we tap outside the text field
  [_textNode resignFirstResponder];
}

@end
