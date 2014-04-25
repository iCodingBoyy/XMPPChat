//
//  YZChatUserObject.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-3.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface YZChatUserObject : NSManagedObject

@property (nonatomic, retain) NSString * userJID;
@property (nonatomic, retain) NSString * nickName;
@property (nonatomic, retain) NSString * birthday;
@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSString * icon;
@property (nonatomic, retain) NSString * phone;
@property (nonatomic, retain) NSSet *chatMsg;
@property (nonatomic, retain) NSManagedObject *chatRoom;
@end

@interface YZChatUserObject (CoreDataGeneratedAccessors)

- (void)addChatMsgObject:(NSManagedObject *)value;
- (void)removeChatMsgObject:(NSManagedObject *)value;
- (void)addChatMsg:(NSSet *)values;
- (void)removeChatMsg:(NSSet *)values;

@end
