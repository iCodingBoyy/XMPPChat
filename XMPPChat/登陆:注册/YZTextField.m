//
//  YZTextField.m
//  CustomUIControl
//
//  Created by 马远征 on 14-3-24.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "YZTextField.h"
#import <QuartzCore/QuartzCore.h>

@implementation YZTextField

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        
    }
    return self;
}


- (void)drawRect:(CGRect)rect
{
    [self.layer setBackgroundColor:[UIColor whiteColor].CGColor];
    [self.layer setBorderColor:[UIColor grayColor].CGColor];
    [self.layer setBorderWidth:1.0];
    [self.layer setCornerRadius:8.0f];
    [self.layer setMasksToBounds:YES];
    
    UIGraphicsBeginImageContext(rect.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 2.0);
    CGContextSetRGBStrokeColor(context, 0.6, 0.6, 0.6, 1.0);
    
    const CGFloat myShadowColorValues[] = {0,0,0,1};
    
    CGRect myRect = CGContextGetClipBoundingBox(context);
    CGColorSpaceRef myColorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorRef colorRef = CGColorCreate(myColorSpace, myShadowColorValues);
    CGContextSetShadowWithColor(context, CGSizeMake(-1, 1), 2, colorRef);
    
    CGContextStrokeRect(context, myRect);
    
    UIImage *backgroundImage = (UIImage *)UIGraphicsGetImageFromCurrentImageContext();
    UIImageView *myImageView =[[UIImageView alloc]initWithFrame:CGRectMake(0,0,self.frame.size.width,self.frame.size.height)];
    [myImageView setImage:backgroundImage];
    [self addSubview:myImageView];
    myImageView = nil;
    UIGraphicsEndImageContext();
    
}

@end
