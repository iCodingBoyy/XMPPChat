//
//  UIImage+YZMessage.m
//  XMPPChat
//
//  Created by 马远征 on 14-5-20.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "UIImage+YZMessage.h"


@implementation UIImage (YZMessage)

static void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth,
                                 float ovalHeight)
{
    float fw, fh;
    if (ovalWidth == 0 || ovalHeight == 0)
    {
        CGContextAddRect(context, rect);
        return;
    }
    
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM(context, ovalWidth, ovalHeight);
    fw = CGRectGetWidth(rect) / ovalWidth;
    fh = CGRectGetHeight(rect) / ovalHeight;
    
    CGContextMoveToPoint(context, fw, fh/2);  // Start at lower right corner
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);  // Top right corner
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1); // Top left corner
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1); // Lower left corner
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1); // Back to lower right
    
    CGContextClosePath(context);
    CGContextRestoreGState(context);
}


- (UIImage *)createRoundedWithRadius:(CGFloat)radius
{
    if (!radius)
        radius = 8;
    
    int w = self.size.width;
    int h = self.size.height;
    
    UIImage *img = self;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
    CGRect rect = CGRectMake(0, 0, w, h);
    
    CGContextBeginPath(context);
    addRoundedRectToPath(context, rect, radius, radius);
    CGContextClosePath(context);
    CGContextClip(context);
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), img.CGImage);
    CGImageRef imageMasked = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:imageMasked];
    CGImageRelease(imageMasked);
    return image;
}


+(UIImage*)userAvatarImage:(UIImage*)originalImage imageType:(YZAvatarImageType)type
{
    CGFloat radius = 0.0;
    if (type == YZAvatarImageCircle)
    {
        radius = originalImage.size.width / 2.0;
    }
    else
    {
        radius = 8;
    }
    UIImage *avator = [originalImage createRoundedWithRadius:radius];
    return avator;
}

@end
