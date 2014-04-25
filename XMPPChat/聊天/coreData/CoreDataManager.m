//
//  CoreDataManager.m
//  CoreDataTest
//
//  Created by 马远征 on 13-12-19.
//  Copyright (c) 2013年 马远征. All rights reserved.
//

#import "CoreDataManager.h"

@interface CoreDataManager()
{
    NSDateFormatter *_formatter;
}
@end

@implementation CoreDataManager
@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

+ (id)sharedInstance
{
    static dispatch_once_t pred;
    static CoreDataManager *manager = nil;
    dispatch_once(&pred, ^{ manager = [[self alloc] init]; });
    return manager;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        
    }
    return self;
}

- (NSDateFormatter*)dateFormatter
{
    if (_formatter == nil)
    {
        _formatter = [[NSDateFormatter alloc] init];
    }
    return _formatter;
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil)
    {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
        {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        }
    }
}
#pragma mark - Core Data stack

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil)
    {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil)
    {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"XMPPChat" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil)
    {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"XMPPChat.sqlite"];
    NSError *error = nil;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:storeURL
                                                         options:options error:&error])
    {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark -
#pragma mark - Application's Documents directory

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
}

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
                video:(NSData*)videoData
{
    return YES;
}
@end
