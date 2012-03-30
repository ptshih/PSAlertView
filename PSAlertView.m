//
//  PSAlertView.m
//  Airwomp
//
//  Created by Peter Shih on 3/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PSAlertView.h"

#define MARGIN_X 10.0
#define MARGIN_Y 16.0

// UIWindow
@interface PSAlertViewWindow : UIWindow

@end

@implementation PSAlertViewWindow

- (void)drawRect:(CGRect)rect {
    // render the radial gradient behind the alertview
    
    CGFloat width			= self.frame.size.width;
    CGFloat height			= self.frame.size.height;
    CGFloat locations[3]	= { 0.0, 0.5, 1.0 	};
    CGFloat components[12]	= {	1, 1, 1, 0.5,
        0, 0, 0, 0.5,
        0, 0, 0, 0.7	};
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef backgroundGradient = CGGradientCreateWithColorComponents(colorspace, components, locations, 3);
    CGColorSpaceRelease(colorspace);
    
    CGContextDrawRadialGradient(UIGraphicsGetCurrentContext(), 
                                backgroundGradient, 
                                CGPointMake(width/2, height/2), 0,
                                CGPointMake(width/2, height/2), width,
                                0);
    
    CGGradientRelease(backgroundGradient);
}

- (void)dealloc {
    [super dealloc];
}

@end

// UITextField
@interface PSAlertViewTextField : UITextField

- (CGRect)rectWithInset:(CGSize)inset;

@end

@implementation PSAlertViewTextField

- (CGRect)rectWithInset:(CGSize)inset {
    CGRect clearViewRect = [self clearButtonRectForBounds:self.bounds];
    CGRect rightViewRect = [self rightViewRectForBounds:self.bounds];
    CGRect leftViewRect = [self leftViewRectForBounds:self.bounds];
    CGFloat rightMargin = MAX(clearViewRect.size.width, rightViewRect.size.width);
    CGFloat leftMargin = leftViewRect.size.width;
    
    return UIEdgeInsetsInsetRect(self.bounds, UIEdgeInsetsMake(inset.height, inset.width + leftMargin, inset.height, inset.width + rightMargin));
}

- (CGRect)textRectForBounds:(CGRect)bounds {
    return [self rectWithInset:CGSizeMake(8, 4)];
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds {
    return [self rectWithInset:CGSizeMake(8, 4)];
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
    return [self rectWithInset:CGSizeMake(8, 4)];
}

@end

// UILabel
@interface UILabel (PSAlertView)

+ (CGSize)sizeForText:(NSString*)text width:(CGFloat)width font:(UIFont*)font numberOfLines:(NSInteger)numberOfLines lineBreakMode:(UILineBreakMode)lineBreakMode;

@end

@implementation UILabel (PSAlertView)

+ (CGSize)sizeForText:(NSString*)text width:(CGFloat)width font:(UIFont*)font numberOfLines:(NSInteger)numberOfLines lineBreakMode:(UILineBreakMode)lineBreakMode {
    
    if (numberOfLines == 0) numberOfLines = INT_MAX;
    
    CGFloat lineHeight = [@"A" sizeWithFont:font].height;
    return [text sizeWithFont:font constrainedToSize:CGSizeMake(width, numberOfLines*lineHeight) lineBreakMode:lineBreakMode];
}

@end

// PSAlertView
@interface PSAlertView () <UITextFieldDelegate>

- (id)initWithTitle:(NSString *)title message:(NSString *)message buttonTitles:(NSArray *)buttonTitles textFieldPlaceholder:(NSString *)textFieldPlaceholder completionBlock:(PSAlertViewCompletionBlock)completionBlock;

- (void)show:(BOOL)animated;
- (void)dismiss:(BOOL)animated;
- (void)buttonSelected:(UIButton *)button;

- (NSInteger)addButtonWithTitle:(NSString *)title;

@property (nonatomic, copy) PSAlertViewCompletionBlock completionBlock;
@property (nonatomic, retain) UIWindow *alertWindow;
@property (nonatomic, retain) UIImageView *backgroundView;
@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *messageLabel;
@property (nonatomic, retain) PSAlertViewTextField *textField;
@property (nonatomic, retain) NSMutableArray *buttons;

@end

@implementation PSAlertView

@synthesize
completionBlock = _completionBlock,
alertWindow = _alertWindow,
backgroundView = _backgroundView,
titleLabel = _titleLabel,
messageLabel = _messageLabel,
textField = _textField,
buttons = _buttons;

#pragma mark - Show with block
+ (void)showWithTitle:(NSString *)title message:(NSString *)message buttonTitles:(NSArray *)buttonTitles textFieldPlaceholder:(NSString *)textFieldPlaceholder completionBlock:(PSAlertViewCompletionBlock)completionBlock {
    
    NSAssert([buttonTitles count] <= 4, @"PSAlertView only supports up to 4 buttons");
    
    PSAlertView *av = [[[PSAlertView alloc] initWithTitle:title message:message buttonTitles:buttonTitles textFieldPlaceholder:textFieldPlaceholder completionBlock:completionBlock] autorelease];
    [av show:YES];
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message buttonTitles:(NSArray *)buttonTitles textFieldPlaceholder:(NSString *)textFieldPlaceholder completionBlock:(PSAlertViewCompletionBlock)completionBlock {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(positionSelf:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(positionSelf:) name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(positionSelf:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
        
        // Window
        self.alertWindow = [[[PSAlertViewWindow alloc] initWithFrame:[UIScreen mainScreen].bounds] autorelease];
        self.alertWindow.windowLevel = UIWindowLevelAlert;
        self.alertWindow.backgroundColor = [UIColor clearColor];
        [self.alertWindow addSubview:self];
        
        // Completion Block
        self.completionBlock = completionBlock; // copy
        
        // Background Image
        self.backgroundView = [[[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"PSAlertView.bundle/Background.png"] stretchableImageWithLeftCapWidth:0 topCapHeight:40]] autorelease];
        [self addSubview:self.backgroundView];
        
        // Title Label
        self.titleLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.numberOfLines = 1;
        self.titleLabel.textAlignment = UITextAlignmentCenter;
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.shadowColor = [UIColor blackColor];
        self.titleLabel.shadowOffset = CGSizeMake(0.0, -0.5);
        self.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
        self.titleLabel.text = title;
        [self addSubview:self.titleLabel];
        
        // Message Label
        self.messageLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
        self.messageLabel.backgroundColor = [UIColor clearColor];
        self.messageLabel.numberOfLines = 4; // approx 140 chars
        self.messageLabel.textAlignment = UITextAlignmentCenter;
        self.messageLabel.textColor = [UIColor whiteColor];
        self.messageLabel.shadowColor = [UIColor blackColor];
        self.messageLabel.shadowOffset = CGSizeMake(0.0, -0.5);
        self.messageLabel.font = [UIFont systemFontOfSize:15.0];
        self.messageLabel.text = message;
        [self addSubview:self.messageLabel];
        
        // Buttons
        self.buttons = [NSMutableArray arrayWithCapacity:1];
        for (NSString *buttonTitle in buttonTitles) {
            [self addButtonWithTitle:buttonTitle];
        }
        
        // Optional Text Field
        if (textFieldPlaceholder) {
            self.textField = [[[PSAlertViewTextField alloc] initWithFrame:CGRectZero] autorelease];
            self.textField.background = [[UIImage imageNamed:@"PSAlertView.bundle/TextFieldBackground.png"] stretchableImageWithLeftCapWidth:1 topCapHeight:0];
            self.textField.placeholder = textFieldPlaceholder;
            self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            self.textField.font = [UIFont systemFontOfSize:16.0];
            self.textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            self.textField.keyboardAppearance = UIKeyboardAppearanceAlert;
            self.textField.delegate = self;
            [self addSubview:self.textField];
        }
    
        // Layout
        CGFloat left = MARGIN_X;
        CGFloat top = MARGIN_Y;
        CGFloat width = 284.0 - MARGIN_X * 2;
        CGSize labelSize = CGSizeZero;
        
        // Title and Message
        labelSize = [UILabel sizeForText:self.titleLabel.text width:width font:self.titleLabel.font numberOfLines:self.titleLabel.numberOfLines lineBreakMode:self.titleLabel.lineBreakMode];
        self.titleLabel.frame = CGRectMake(left, top, width, labelSize.height);
        
        top += labelSize.height;
        top += MARGIN_Y / 4.0;
        
        labelSize = [UILabel sizeForText:self.messageLabel.text width:width font:self.messageLabel.font numberOfLines:self.messageLabel.numberOfLines lineBreakMode:self.messageLabel.lineBreakMode];
        self.messageLabel.frame = CGRectMake(left, top, width, labelSize.height);
        
        top += labelSize.height;
        top += MARGIN_Y / 2.0;
        
        // Optional Text Field
        if (self.textField) {
            self.textField.frame = CGRectMake(left, top, width, 31.0);
            
            top += 31.0;
            top += MARGIN_Y / 2.0;
        }
        
        // Buttons
        NSUInteger numButtons = self.buttons.count;
        CGFloat buttonMargin = (MARGIN_X / 2.0) * (numButtons - 1);
        CGFloat buttonWidth = floorf((width - buttonMargin) / numButtons);
        [self.buttons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, BOOL *stop) {
            button.frame = CGRectMake(left + (idx * (MARGIN_X / 2.0)) + (idx * buttonWidth), top, buttonWidth, 43.0);
        }];
        
        top += 43.0;
        
        top += MARGIN_Y;
        
        CGFloat superWidth = [[UIApplication sharedApplication] keyWindow].frame.size.width;
        CGFloat superHeight = [[UIApplication sharedApplication] keyWindow].frame.size.height - [[UIApplication sharedApplication] statusBarFrame].size.height;
        CGFloat newLeft = floorf((superWidth - 284) / 2.0);
        CGFloat newTop = floorf((superHeight - top) / 2.0) + [[UIApplication sharedApplication] statusBarFrame].size.height;
        self.frame = CGRectMake(newLeft, newTop, 284, top);
        
        self.backgroundView.frame = self.bounds;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    Block_release(self.completionBlock);
    self.alertWindow = nil;
    self.textField.delegate = nil;
    self.textField = nil;
    self.titleLabel = nil;
    self.messageLabel = nil;
    self.buttons = nil;
    [super dealloc];
}

- (NSInteger)addButtonWithTitle:(NSString *)title {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:@selector(buttonSelected:) forControlEvents:UIControlEventTouchUpInside];
    [button setBackgroundImage:[[UIImage imageNamed:@"PSAlertView.bundle/Button.png"] stretchableImageWithLeftCapWidth:5 topCapHeight:0] forState:UIControlStateNormal];
    [button setBackgroundImage:[[UIImage imageNamed:@"PSAlertView.bundle/ButtonHighlighted.png"] stretchableImageWithLeftCapWidth:5 topCapHeight:0] forState:UIControlStateHighlighted];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
    button.titleLabel.shadowOffset = CGSizeMake(0.0, -0.5);
    [self addSubview:button];
    
    [self.buttons addObject:button];
    
    return (self.buttons.count - 1);
}

#pragma mark - Layout
- (void)layoutSubviews {
    [super layoutSubviews];
    
}


#pragma mark - Show
- (void)show:(BOOL)animated {
    [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate:[NSDate date]];
    
    self.alertWindow.alpha = 0.0;
    [self.alertWindow makeKeyAndVisible];
    
//    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
//    [keyWindow addSubview:self];
    
    self.transform = CGAffineTransformMakeScale(0.6, 0.6);
    [UIView animateWithDuration: 0.2 
                     animations: ^{
                         self.alertWindow.alpha = 1.0;
                         self.transform = CGAffineTransformMakeScale(1.1, 1.1);
                     }
                     completion: ^(BOOL finished){
                         [UIView animateWithDuration:1.0/15.0
                                          animations: ^{
                                              self.transform = CGAffineTransformMakeScale(0.9, 0.9);
                                          }
                                          completion: ^(BOOL finished){
                                              [UIView animateWithDuration:1.0/7.5
                                                               animations: ^{
                                                                   self.transform = CGAffineTransformIdentity;
                                                               }];
                                          }];
                     }];
}

- (void)dismiss:(BOOL)animated {
    [UIView animateWithDuration: 0.2 
                     animations: ^{
                         self.alertWindow.alpha = 0.0;
                     }
                     completion: ^(BOOL finished){
                         self.alertWindow = nil;
                     }];
}

- (void)buttonSelected:(UIButton *)button {
    NSUInteger buttonIndex = [self.buttons indexOfObjectIdenticalTo:button];
    
    self.completionBlock(buttonIndex);
    [self dismiss:YES];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Positioning (Rotation and Keyboard)
- (void)positionSelf:(NSNotification*)notification {
    
    CGFloat keyboardHeight;
    NSTimeInterval animationDuration;
    UIViewAnimationCurve animationCurve;
    
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    NSDictionary* keyboardInfo = [notification userInfo];
    CGRect keyboardFrame = [[keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    
    [[keyboardInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[keyboardInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    
    if(notification.name == UIKeyboardWillShowNotification || notification.name == UIKeyboardDidShowNotification) {
        if(UIInterfaceOrientationIsPortrait(orientation))
            keyboardHeight = keyboardFrame.size.height;
        else
            keyboardHeight = keyboardFrame.size.width;
    } else
        keyboardHeight = 0;
    
    CGRect orientationFrame = [UIScreen mainScreen].bounds;
    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    
    if(UIInterfaceOrientationIsLandscape(orientation)) {
        CGFloat temp = orientationFrame.size.width;
        orientationFrame.size.width = orientationFrame.size.height;
        orientationFrame.size.height = temp;
        
        temp = statusBarFrame.size.width;
        statusBarFrame.size.width = statusBarFrame.size.height;
        statusBarFrame.size.height = temp;
    }
    
    CGFloat activeHeight = orientationFrame.size.height;
    
    activeHeight -= keyboardHeight;
    CGFloat posY = floorf(activeHeight*0.5);
    CGFloat posX = orientationFrame.size.width/2;
    
    CGPoint newCenter;
    CGFloat rotateAngle;
    
    switch (orientation) { 
        case UIInterfaceOrientationPortraitUpsideDown:
            rotateAngle = M_PI; 
            newCenter = CGPointMake(posX, orientationFrame.size.height-posY);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            rotateAngle = -M_PI/2.0f;
            newCenter = CGPointMake(posY, posX);
            break;
        case UIInterfaceOrientationLandscapeRight:
            rotateAngle = M_PI/2.0f;
            newCenter = CGPointMake(orientationFrame.size.height-posY, posX);
            break;
        default: // as UIInterfaceOrientationPortrait
            rotateAngle = 0.0;
            newCenter = CGPointMake(posX, posY);
            break;
    } 
    
    [UIView animateWithDuration:animationDuration 
                          delay:0 
                        options:UIViewAnimationOptionAllowUserInteraction 
                     animations:^{
                         [self moveToPoint:newCenter rotateAngle:rotateAngle];
                     } completion:NULL];
    
}

- (void)moveToPoint:(CGPoint)newCenter rotateAngle:(CGFloat)angle {
    self.transform = CGAffineTransformMakeRotation(angle); 
    self.center = newCenter;
}

@end
