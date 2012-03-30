//
//  PSAlertView.h
//  Airwomp
//
//  Created by Peter Shih on 3/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^PSAlertViewCompletionBlock)(NSUInteger buttonIndex, NSString *textFieldValue);

@interface PSAlertView : UIView

+ (void)showWithTitle:(NSString *)title message:(NSString *)message buttonTitles:(NSArray *)buttonTitles textFieldPlaceholder:(NSString *)textFieldPlaceholder completionBlock:(PSAlertViewCompletionBlock)completionBlock;

+ (void)showWithTitle:(NSString *)title message:(NSString *)message buttonTitles:(NSArray *)buttonTitles emailText:(NSString *)emailText completionBlock:(PSAlertViewCompletionBlock)completionBlock;

@end