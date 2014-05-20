//
//  UIImage+YZMessage.h
//  XMPPChat
//
//  Created by 马远征 on 14-5-20.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, YZAvatarImageType)
{
    YZAvatarImageSquare,
    YZAvatarImageCircle,
};

@interface UIImage (YZMessage)
/*!
 * @method userAvatarImage:imageType:
 * @brief 获取用户的聊天小图像
 * @param  originalImage 原生图像
 * @param  type 目标图像类型：圆角图像？方角图像
 * @return
 */
+(UIImage*)userAvatarImage:(UIImage*)originalImage imageType:(YZAvatarImageType)type;
@end
