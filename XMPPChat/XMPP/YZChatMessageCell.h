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



@interface YZChatMessageCell : UITableViewCell
- (instancetype)initWithXmppMessage:(XmppMessage*)message
                    reuseIdentifier:(NSString *)reuseIdentifier;
@end
