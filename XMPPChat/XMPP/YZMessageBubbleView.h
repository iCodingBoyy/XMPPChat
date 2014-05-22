//
//  YZMessageBubbleView.h
//  XMPPChat
//
//  Created by 马远征 on 14-5-21.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XmppMessage.h"
#import "YZEnumDefine.h"

@interface YZMessageBubbleView : UIView

@property (nonatomic, strong, readonly) XmppMessage *message;
@property (nonatomic, strong, readonly) UIImageView *buddleImageView;
@property (nonatomic, strong, readonly) UIImageView *animationVoiceImageView;
@property (nonatomic, strong, readonly) UIImageView *videoPlayImageView;
@property (nonatomic, strong, readonly) UILabel *geoLocationlabel;
@property (nonatomic, strong, readonly) UITextView *displayTextView;
/**
 * @method 初始化气泡视图
 * @param  frame 气泡视图的frame
 * @param  message coreData消息对象模型
 * @return
 */
- (instancetype)initWithFrame:(CGRect)frame message:(XmppMessage*)message;


/**
 * @method 更新气泡视图的内容
 * @param  message coreData消息对象模型
 * @return
 */
- (void)UpdateCellWithMessage:(XmppMessage*)message;

/**
 * @method 计算气泡视图的高度
 * @param  message coreData消息对象模型
 * @return
 */
+ (CGFloat)calculateCellHeightWithMessage:(XmppMessage*)message;
@end
