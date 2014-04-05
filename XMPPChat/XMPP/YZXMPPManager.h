//
//  YZXMPPManager.h
//  XMPPChat
//
//  Created by 马远征 on 14-3-28.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XMPPReconnect.h>
#import <XMPPRoster.h>
#import <XMPPRosterCoreDataStorage.h>
#import <XMPPCapabilitiesCoreDataStorage.h>
#import <XMPPFramework.h>
#import <XMPPvCardTempModule.h>
#import <XMPPvCardAvatarModule.h>
#import <XMPPvCardCoreDataStorage.h>
#import <XMPPUserCoreDataStorageObject.h>
#import <TURNSocket.h>


#define KXMPPHostName @"www.savvy-tech.net"
#define KXMPPHostPort 5222
#define KXMPPResource @"XMPPFrameWork"
#define KXMPPConnectTimeOut 30


typedef NS_ENUM(NSInteger, XMPPOperation)
{
    XMPPLoginServerOp = 10,
    XMPPRegisterServerOp,
};

typedef NS_ENUM(NSInteger, XMPPErrorCode)
{
    XMPPNULLStreamError = -10001,
    XMPPNULLParamsError,
    XMPPConnectServerError,
    XMPPDisConnectServerError,
    XMPPConnectTimeOutError,
    XMPPAuthenticateServerError,
    XMPPRegisterServerError,
};


typedef void (^resultBlock)(BOOL finished, NSError *error);
typedef void (^AuthComplete)();
typedef void (^AuthError)(XMPPErrorCode errorCode);



@interface YZXMPPManager : NSObject  <TURNSocketDelegate,GCDAsyncSocketDelegate>

@property (nonatomic, strong, readonly) XMPPStream *xmppStream;
@property (nonatomic, strong, readonly) XMPPReconnect *xmppReconnect;
@property (nonatomic, strong, readonly) XMPPRoster *xmppRoster;
@property (nonatomic, strong, readonly) XMPPRosterCoreDataStorage *xmppRosterStorage;
@property (nonatomic, strong, readonly) XMPPvCardTempModule *xmppvCardTempModule;
@property (nonatomic, strong, readonly) XMPPvCardAvatarModule *xmppvCardAvatarModule;
@property (nonatomic, strong, readonly) XMPPCapabilities *xmppCapabilities;
@property (nonatomic, strong, readonly) XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;
@property (nonatomic, strong, readonly) XMPPvCardCoreDataStorage *xmppvCardStorage;

@property (nonatomic, assign) XMPPOperation xmppOperation;
@property (nonatomic, strong) NSData *sendData;
+ (id)sharedYZXMPP;

- (NSManagedObjectContext *)mgdObjContext_roster;
- (NSManagedObjectContext *)mgdObjContext_capabilities;

// auth
- (void)LoginWithName:(NSString *)userName
             passWord:(NSString *)passWord
             complete:(AuthComplete)completeBlock
              failure:(AuthError)errorBlock;

- (void)registerWithName:(NSString*)userName
                passWord:(NSString*)passWord
                complete:(AuthComplete)completeBlock
                 failure:(AuthError)errorBlock;
- (BOOL)connect;
- (void)disconnect;

// 花名册查询
- (void)fethcRosterOnServer;
- (void)fetchRoster;
- (void)fetchUserWithXMPPJID:(NSString*)searchField;

- (void)xmppAddFriendsSubscribe:(NSString*)name;
- (void)setNickname:(NSString *)nickname forUser:(NSString*)jidUser;

- (void)sendMessage:(NSString*)message toUser:(NSString*)user;
- (void)sendFile:(NSData*)data toUser:(NSString*)xmppUser;
@end
