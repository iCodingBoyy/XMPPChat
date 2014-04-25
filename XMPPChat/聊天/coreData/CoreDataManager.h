//
//  CoreDataManager.h
//  CoreDataTest
//
//  Created by 马远征 on 13-12-19.
//  Copyright (c) 2013年 马远征. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YZChatMsgObject.h"
#import "YZChatRoomObject.h"
#import "YZChatUserObject.h"


typedef NS_ENUM(NSInteger, chatMsgType)
{
    chatMsgText = 100,
    chatMsgPicture,
    chatMsgLocaton,
    chatMsgVcard,
    chatMsgVoice,
    chatMsgVideo,
    chatMsgFile,
};

@interface CoreDataManager : NSObject
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

+ (id)sharedInstance;
- (NSDateFormatter*)dateFormatter;
- (void)saveContext;
- (NSManagedObjectContext *)managedObjectContext;
- (NSURL *)applicationDocumentsDirectory;

/**
 * @method 插入IM单聊消息
 * @brief
 * @param  msgType 消息类型
 * @param  isMgMsg 发出消息/接收消息
 * @param  timeStamp 消息类型
 * @param  message 消息内容<依消息内容不同而不同>
 * @param  userJId 用户JID
 * @param  imageData 图片文件
 * @param  voiceData 语音文件
 * @param  videoData 视频文件
 * @return
 */
- (BOOL)insertChatMsg:(chatMsgType)msgType
              isMyMsg:(BOOL)isMgMsg
            timeStamp:(NSString*)timeStamp
           msgContent:(NSString*)message
              userJID:(NSString*)userJId
              picture:(NSData*)imageData
                voice:(NSData*)voiceData
                video:(NSData*)videoData;
@end
