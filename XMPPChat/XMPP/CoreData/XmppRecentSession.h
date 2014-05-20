//
//  XmppRecentSession.h
//  XMPPChat
//
//  Created by 马远征 on 14-5-20.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface XmppRecentSession : NSManagedObject

// 消息内容
@property (nonatomic, retain) NSString * messageBody;

// 发出？接收消息，
@property (nonatomic, retain) NSNumber * outGoing;

// 接收者jid
@property (nonatomic, retain) NSString * receiverJID;

// 当前用户jid
@property (nonatomic, retain) NSString * senderJID;

// 时间戳
@property (nonatomic, retain) NSDate * timeStamp;

@end
