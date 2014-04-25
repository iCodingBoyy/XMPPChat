//
//  YZChatMsgObject.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-3.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class YZChatUserObject;

@interface YZChatMsgObject : NSManagedObject

@property (nonatomic, retain) NSString * timeStamp;
@property (nonatomic, retain) NSString * msgContent;
@property (nonatomic, retain) NSNumber * msgType;
@property (nonatomic, retain) NSString * voicePath;
@property (nonatomic, retain) NSString * videoPath;
@property (nonatomic, retain) NSString * picturePath;
@property (nonatomic, retain) NSNumber * isMyMsg;
@property (nonatomic, retain) YZChatUserObject *chatObject;

@end
