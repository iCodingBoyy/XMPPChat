//
//  YZChatRoomObject.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-3.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class YZChatUserObject;

@interface YZChatRoomObject : NSManagedObject

@property (nonatomic, retain) NSString * lastMsgContent;
@property (nonatomic, retain) NSString * lastMsgTimeStamp;
@property (nonatomic, retain) YZChatUserObject *chatObject;

@end
