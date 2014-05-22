//
//  YZChatMessageCell.h
//  XMPPChat
//
//  Created by 马远征 on 14-5-20.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XmppMessage.h"
#import "YZEnumDefine.h"
#import "YZMessageBubbleView.h"


@interface YZChatMessageCell : UITableViewCell
@property (nonatomic, strong, readonly) YZMessageBubbleView *messageBubbleView;
@property (nonatomic, strong, readonly) UIButton *avatorButton;
@property (nonatomic, strong) NSIndexPath *indexPath;

/**
 * @method
 * @brief 初始化UITableViewCell
 * @param  message coreData消息对象模型
 * @param  showMessageTime 是否显示时间标签
 * @param  reuseIdentifier cell复用标示符
 * @return
 */
- (instancetype)initWithXmppMessage:(XmppMessage*)message
                           showTime:(BOOL)showMessageTime
                    reuseIdentifier:(NSString *)reuseIdentifier;

/**
 * @method
 * @brief 更新cell内容
 * @param  message coreData消息对象模型
 * @param  showMessageTime 是否显示时间标签
 * @return
 */
- (void)UpdateCellWithMessage:(XmppMessage*)message
                     showTime:(BOOL)showMessageTime;

/**
 * @method
 * @brief 计算cell的高度
 * @param  message coreData消息对象模型
 * @param  showMessageTime 是否显示时间标签
 * @return
 */
+ (CGFloat)calculateCellHeightWithMessage:(XmppMessage*)message
                                 showTime:(BOOL)showMessageTime;
@end
