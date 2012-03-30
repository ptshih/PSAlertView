//
//  PSAlertView.h
//  Airwomp
//
//  Created by Peter Shih on 3/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^PSAlertViewCompletionBlock)(NSUInteger buttonIndex);

@interface PSAlertView : UIView

+ (void)showWithTitle:(NSString *)title message:(NSString *)message buttonTitles:(NSArray *)buttonTitles textFieldPlaceholder:(NSString *)textFieldPlaceholder completionBlock:(PSAlertViewCompletionBlock)completionBlock;

@end