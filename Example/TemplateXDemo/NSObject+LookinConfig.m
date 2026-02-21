//
//  NSObject+LookinConfig.m
//  TemplateXDemo
//
//  Created by 吕良(吕游) on 2026/2/21.
//

#import "NSObject+LookinConfig.h"
#import <UIKit/UIKit.h>

@implementation NSObject (LookinConfig)

+ (BOOL)lookin_shouldCaptureImageOfView:(UIView *)view {
    if ([NSStringFromClass([view class]) isEqualToString: @"_UIFloatingBarContainerView"]) {
        // Lookin will not show image of the view
        return NO;
    } else {
        return YES;
    }
}

@end
