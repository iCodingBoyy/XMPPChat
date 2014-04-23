//
//  YZXMPPManager.m
//  XMPPChat
//
//  Created by 马远征 on 14-3-28.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "YZXMPPManager.h"
#import <objc/runtime.h>


#define KXMPPLoginNAME @"KXMPPLoginNAME"
#define KXMPPLOGINPWD @"KXMPPLOGINPWD"


@interface YZXMPPManager() <XMPPRosterDelegate,XMPPMessageArchivingStorage>
{
    BOOL allowSelfSignedCertificates;
	BOOL allowSSLHostNameMismatch;
}
@property (nonatomic, strong) NSString *passWord;
@property (nonatomic, assign) BOOL isXmppConnected;
@property (nonatomic,   copy) AuthComplete authCompleteBlock;
@property (nonatomic,   copy) AuthError authErrorBlock;
@end

@implementation YZXMPPManager

+ (YZXMPPManager*)sharedYZXMPP
{
    static dispatch_once_t pred;
    static YZXMPPManager *xmppManager = nil;
    dispatch_once(&pred, ^{ xmppManager = [[self alloc] init]; });
    return xmppManager;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        [self initXMPPStream];
    }
    return self;
}


#pragma mark -
#pragma mark init/release xmpp

- (void)initXMPPStream
{
    _xmppStream = [[XMPPStream alloc]init];
    
#if !TARGET_IPHONE_SIMULATOR
	{
        _xmppStream.enableBackgroundingOnSocket = YES;
	}
#endif
    _xmppStream.hostName = KXMPPHostName;
    _xmppStream.hostPort = KXMPPHostPort;
    
    // 自动重连
    _xmppReconnect = [[XMPPReconnect alloc]init];
    _xmppReconnect.autoReconnect = YES;
    
    // 花名册
    _xmppRosterStorage = [XMPPRosterCoreDataStorage sharedInstance];
    _xmppRoster = [[XMPPRoster alloc]initWithRosterStorage:_xmppRosterStorage];
    _xmppRoster.autoFetchRoster = YES;
    _xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    
    
    // vCard
    _xmppvCardStorage = [XMPPvCardCoreDataStorage sharedInstance];
	_xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:_xmppvCardStorage];
	_xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:_xmppvCardTempModule];
    
    // cap
//    _xmppCapabilitiesStorage = [XMPPCapabilitiesCoreDataStorage sharedInstance];
//    _xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:_xmppCapabilitiesStorage];
//    _xmppCapabilities.autoFetchHashedCapabilities = YES;
//    _xmppCapabilities.autoFetchNonHashedCapabilities = NO;
//
//    // message
    _xmppMessageArchivingCoreDataStorage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
    _xmppMessageArchiving = [[XMPPMessageArchiving alloc]initWithMessageArchivingStorage:_xmppMessageArchivingCoreDataStorage];
    [_xmppMessageArchiving setClientSideMessageArchivingOnly:YES];
    
    
    [_xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [_xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
//    [_xmppCapabilities addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [_xmppMessageArchiving addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    _xmppFileTransfer = [[XMPPFileTransfer alloc]init];
    [_xmppFileTransfer addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [_xmppFileTransfer activate:_xmppStream];
    
//    XMPPMessageDeliveryReceipts * deliveryReceiptsModule = [[XMPPMessageDeliveryReceipts alloc] init];
//    deliveryReceiptsModule.autoSendMessageDeliveryRequests = YES;
//    [deliveryReceiptsModule activate:_xmppStream];

    
    // activate
    [_xmppReconnect         activate:_xmppStream];
    [_xmppRoster            activate:_xmppStream];
    [_xmppvCardTempModule   activate:_xmppStream];
	[_xmppvCardAvatarModule activate:_xmppStream];
//	[_xmppCapabilities      activate:_xmppStream];
    [_xmppMessageArchiving  activate:_xmppStream];
    
    allowSelfSignedCertificates = YES;
	allowSSLHostNameMismatch = YES;
}


- (void)releaseXMPPStream
{
    [_xmppStream removeDelegate:self];
    [_xmppRoster removeDelegate:self];
    [_xmppMessageArchiving removeDelegate:self];
    
    [_xmppReconnect deactivate];
    [_xmppRoster deactivate];
    [_xmppvCardTempModule deactivate];
    [_xmppvCardAvatarModule deactivate];
    [_xmppCapabilities deactivate];
    [_xmppMessageArchiving deactivate];
    [_xmppFileTransfer deactivate];
    
    [_xmppStream disconnect];
    
    _xmppStream = nil;
    _xmppReconnect = nil;
    _xmppRoster = nil;
    _xmppRosterStorage = nil;
    _xmppvCardStorage = nil;
    _xmppvCardTempModule = nil;
    _xmppvCardAvatarModule = nil;
    _xmppCapabilities = nil;
    _xmppCapabilitiesStorage = nil;
    _xmppMessageArchiving = nil;
    _xmppFileTransfer = nil;
}


#pragma mark -
#pragma mark NSManagedObjectContext

- (NSManagedObjectContext *)mgdObjContext_roster
{
	return [_xmppRosterStorage mainThreadManagedObjectContext];
}

- (NSManagedObjectContext *)mgdObjContext_capabilities
{
	return [_xmppCapabilitiesStorage mainThreadManagedObjectContext];
}



#pragma mark -
#pragma mark 登录

- (void)LoginWithName:(NSString *)userName
             passWord:(NSString *)passWord
             complete:(AuthComplete)completeBlock
              failure:(AuthError)errorBlock
{
    _authCompleteBlock = completeBlock;
    _authErrorBlock = errorBlock;
    _xmppOperation = XMPPLoginServerOp;
    
    if (userName == nil || passWord == nil)
    {
        _authErrorBlock(XMPPNULLParamsError);
        return;
    }
    
    if ([_xmppStream isConnecting])
    {
        return;
    }
    
    if ( [_xmppStream isConnected] && [_xmppStream isAuthenticated] )
    {
        _authCompleteBlock();
        return;
    }
    
    [[NSUserDefaults standardUserDefaults]setObject:userName forKey:KXMPPLoginNAME];
    [[NSUserDefaults standardUserDefaults]setObject:passWord forKey:KXMPPLOGINPWD];
    
    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@/%@",userName,KXMPPHostName,KXMPPResource];
    XMPPJID *xmppJID = [XMPPJID jidWithString:xmppJIDString];
    [_xmppStream setMyJID:xmppJID];
    _passWord = passWord;
    
    NSError *error = nil;
    if ([_xmppStream isConnected])
    {
        [_xmppStream authenticateWithPassword:passWord error:&error];
        if (error)
        {
            _authErrorBlock(XMPPAuthenticateServerError);
        }
        return;
    }
    
    if (![_xmppStream connectWithTimeout:KXMPPConnectTimeOut error:&error])
    {
        _authErrorBlock(XMPPConnectServerError);
        return;
    }
}


- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    [self goOnline];
    if (_authCompleteBlock)
    {
        _authCompleteBlock();
    }
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(DDXMLElement *)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    [self disconnect];
    if (_authErrorBlock)
    {
        _authErrorBlock(XMPPAuthenticateServerError);
    }
}

#pragma mark -
#pragma mark 注册

- (void)registerWithName:(NSString*)userName
                passWord:(NSString*)passWord
                complete:(AuthComplete)completeBlock
                 failure:(AuthError)errorBlock
{
    _authCompleteBlock = completeBlock;
    _authErrorBlock = errorBlock;
    _xmppOperation = XMPPRegisterServerOp;
    
    if (userName == nil || passWord == nil)
    {
        _authErrorBlock(XMPPNULLParamsError);
        return;
    }
    
    if ([_xmppStream isConnecting])
    {
        return;
    }
    
    [[NSUserDefaults standardUserDefaults]setObject:userName forKey:KXMPPLoginNAME];
    [[NSUserDefaults standardUserDefaults]setObject:passWord forKey:KXMPPLOGINPWD];
    
    XMPPJID *xmppJID = [XMPPJID jidWithUser:userName domain:KXMPPHostName resource:KXMPPResource];
    [_xmppStream setMyJID:xmppJID];
    _passWord = passWord;
    
    NSError *error = nil;
    if ([_xmppStream isConnected])
    {
        
        [_xmppStream registerWithPassword:passWord error:&error];
        if (error)
        {
            _authErrorBlock(XMPPRegisterServerError);
        }
        return;
    }
    
    if (![_xmppStream connectWithTimeout:KXMPPConnectTimeOut error:&error])
    {
        _authErrorBlock(XMPPConnectServerError);
        return;
    }
}

- (void)xmppStreamDidRegister:(XMPPStream *)sender
{
    NSLog(@"---Register---%@",sender.myJID.user);
    [_xmppRoster setNickname:sender.myJID.user forUser:sender.myJID];
    
    if (_authCompleteBlock)
    {
        _authCompleteBlock();
    }
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(DDXMLElement *)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    if (_authErrorBlock)
    {
        _authErrorBlock(XMPPRegisterServerError);
    }
}


#pragma mark -
#pragma mark connect/disconnet

- (BOOL)connect
{
    if (_xmppStream == nil)
    {
        return NO;
    }
    
    if (![_xmppStream isDisconnected])
    {
        return YES;
    }
    
    NSString *loginName = [[NSUserDefaults standardUserDefaults]stringForKey:KXMPPLoginNAME];
    NSString *loginPwd = [[NSUserDefaults standardUserDefaults]stringForKey:KXMPPLOGINPWD];
    
    if (loginName == nil || loginPwd == nil)
    {
        return NO;
    }
    
//    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@/%@",loginName,KXMPPHostName,KXMPPResource];
//    XMPPJID *xmppJID = [XMPPJID jidWithString:xmppJIDString];
    XMPPJID *xmppJID = [XMPPJID jidWithUser:loginName domain:KXMPPHostName resource:KXMPPResource];
    [_xmppStream setMyJID:xmppJID];
    
    NSError *error = nil;
    if (![_xmppStream connectWithTimeout:KXMPPConnectTimeOut error:&error])
    {
        return NO;
    }
    
    return YES;
}

- (void)disconnect
{
    [self gooffline];
    [_xmppStream disconnect];
    [_xmppvCardTempModule removeDelegate:self];
}

- (NSString *)xmppStream:(XMPPStream *)sender alternativeResourceForConflictingResource:(NSString *)conflictingResource
{
    return KXMPPResource;
}


- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	if (allowSelfSignedCertificates)
	{
		[settings setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
	}
	
	if (allowSSLHostNameMismatch)
	{
		[settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
	}
	else
	{
		NSString *expectedCertName = nil;
		NSString *serverDomain = _xmppStream.hostName;
		NSString *virtualDomain = [_xmppStream.myJID domain];
		
		if ([serverDomain isEqualToString:@"talk.google.com"])
		{
			if ([virtualDomain isEqualToString:@"gmail.com"])
			{
				expectedCertName = virtualDomain;
			}
			else
			{
				expectedCertName = serverDomain;
			}
		}
		else if (serverDomain == nil)
		{
			expectedCertName = virtualDomain;
		}
		else
		{
			expectedCertName = serverDomain;
		}
		
		if (expectedCertName)
		{
			[settings setObject:expectedCertName forKey:(NSString *)kCFStreamSSLPeerName];
		}
	}
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamWillConnect:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    _isXmppConnected = YES;
    
    // 认证服务器
    if (_xmppOperation == XMPPLoginServerOp)
    {
        NSError *error = nil;
        [_xmppStream authenticateWithPassword:_passWord error:&error];
        if ( error )
        {
            if (_authErrorBlock)
            {
                _authErrorBlock(XMPPAuthenticateServerError);
            }
        }
    }
    
    // 注册服务器
    if (_xmppOperation == XMPPRegisterServerOp)
    {
        NSError *error = nil;
        [_xmppStream registerWithPassword:_passWord error:&error];
        if ( error )
        {
            if (_authErrorBlock)
            {
                _authErrorBlock(XMPPRegisterServerError);
            }
        }
    }
}

- (void)xmppStreamConnectDidTimeout:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    if (_authErrorBlock)
    {
        _authErrorBlock(XMPPConnectTimeOutError);
    }
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);

    if (error)
    {
        DDLogError(@"Unable to connect to server. Check xmppStream.hostName");
        if (_authErrorBlock)
        {
            _authErrorBlock(XMPPDisConnectServerError);
        }
    }
}


#pragma mark -
#pragma mark online/offline

- (void)goOnline
{
    XMPPPresence *presence = [XMPPPresence presence];
    [_xmppStream sendElement:presence];
}

- (void)gooffline
{
    XMPPPresence *xmppPresence = [XMPPPresence presenceWithType:@"unavailable"];
    [_xmppStream sendElement:xmppPresence];
}

#pragma mark -
#pragma mark queryRoster

- (void)fethcRosterOnServer
{
    if (_xmppStream == nil)
    {
        NSLog(@"----为实例化的XMPPStream------");
        return;
    }
    NSXMLElement *queryEle = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
    NSXMLElement *iqEle = [NSXMLElement elementWithName:@"iq"];
    XMPPJID *myJID = _xmppStream.myJID;
    [iqEle addAttributeWithName:@"from" stringValue:myJID.description];
    [iqEle addAttributeWithName:@"to" stringValue:myJID.domain];
    [iqEle addAttributeWithName:@"id" stringValue:[_xmppStream generateUUID]];
    [iqEle addAttributeWithName:@"type" stringValue:@"get"];
    [iqEle addChild:queryEle];
    [_xmppStream sendElement:iqEle];
}


- (void)fetchRoster
{
    if (_xmppRoster)
    {
        [_xmppRoster fetchRoster];
    }
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    if ( [@"result" isEqualToString:iq.type] )
    {
        NSXMLElement *query = iq.childElement;
        if ( [@"query" isEqualToString:query.name] )
        {
            NSArray *items = [query children];
            for (NSXMLElement *item in items)
            {
                NSString *jid = [item attributeStringValueForName:@"jid"];
                if (jid)
                {
                    XMPPJID *xmppJID = [XMPPJID jidWithString:jid];
                    if (_delegate && [_delegate respondsToSelector:@selector(YZXmppMgr:didReceiveJID:)])
                    {
                        [_delegate YZXmppMgr:self didReceiveJID:xmppJID];
                    }
                }
            }
        }
    }
    return YES;
}
#define PresenceServerURL @"http://www.savvy-tech.net:9090/plugins/presence/status"

- (BOOL)sendFile:(NSData *)data toUser:(NSString *)xmppUser
{
    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@/Server",xmppUser,KXMPPHostName];
    NSString *fileName = [NSString stringWithFormat:@"photo%@.png",[_xmppStream generateUUID]];
    XMPPJID *senderJID = [XMPPJID jidWithString:xmppJIDString];
    [_xmppFileTransfer initiateFileTransferTo:senderJID fileName:fileName fileData:data];
    return YES;
}

#pragma mark -
#pragma mark 好友管理

- (void)setNickname:(NSString *)nickname forUser:(NSString*)xmppUser
{
    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@",xmppUser,KXMPPHostName];
    XMPPJID *jid = [XMPPJID jidWithString:xmppJIDString];
    [_xmppRoster setNickname:nickname forUser:jid];
}

- (void)xmppAddFriendsSubscribe:(NSString*)name
{
    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@/%@",name,KXMPPHostName,KXMPPResource];
    XMPPJID *jid = [XMPPJID jidWithString:xmppJIDString];
    [_xmppRoster addUser:jid withNickname:name];
}

- (void)removeBuddy:(NSString*)name
{
    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@",name,KXMPPHostName];
    XMPPJID *jid = [XMPPJID jidWithString:xmppJIDString];
    [_xmppRoster removeUser:jid];
}


- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
//
    if (presence.from)
    {
        [_xmppRoster acceptPresenceSubscriptionRequestFrom:presence.from andAddToRoster:YES];
    }
//
//    XMPPUserCoreDataStorageObject *user = [_xmppRosterStorage userForJID:[presence from]
//	                                                         xmppStream:_xmppStream
//	                                               managedObjectContext:[self mgdObjContext_roster]];
//	
//	NSString *body = nil;
//	
//	if (![user.displayName isEqualToString:presence.fromStr])
//	{
//		body = [NSString stringWithFormat:@"Buddy request from %@ <%@>", user.displayName, presence.fromStr];
//	}
//	else
//	{
//		body = [NSString stringWithFormat:@"Buddy request from %@", user.displayName];
//	}
//	
//	
//	if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
//	{
//		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:user.displayName
//		                                                    message:body
//		                                                   delegate:nil
//		                                          cancelButtonTitle:@"Not implemented"
//		                                          otherButtonTitles:nil];
//		[alertView show];
//	}
//	else
//	{
//		UILocalNotification *localNotification = [[UILocalNotification alloc] init];
//		localNotification.alertAction = @"Not implemented";
//		localNotification.alertBody = body;
//		
//		[[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
//	}
//
}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(DDXMLElement *)item
{
//    NSLog(@"---%s-----%@",__FUNCTION__,item.description);
}



- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
//    NSLog(@"----presence---%@",presence.type);
    
    if ( ![presence.from.user isEqualToString:sender.myJID.user])
    {
        if ([presence.type isEqualToString:@"available"])
        {
            if (_delegate && [_delegate respondsToSelector:@selector(YZXmppMgr:newBuddyOnline:)])
            {
                [_delegate YZXmppMgr:self newBuddyOnline:presence.from.user];
            }
        }
        else if ([presence.type isEqualToString:@"unavailable"])
        {
            if (_delegate && [_delegate respondsToSelector:@selector(YZXmppMgr:buddyWentOffline:)])
            {
                [_delegate YZXmppMgr:self buddyWentOffline:presence.from.user];
            }
        }
    }
    
    if ([presence.type isEqualToString:@"subscribed"])
    {
        [_xmppRoster acceptPresenceSubscriptionRequestFrom:presence.from andAddToRoster:YES];
    }
}


#pragma mark -xmpp通信

- (void)sendMessage:(NSString*)message toUser:(NSString*)user
{
    NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:message];
    NSXMLElement *chatMessage = [NSXMLElement elementWithName:@"message"];
    [chatMessage addAttributeWithName:@"type" stringValue:@"chat"];
    
    NSString *to = [NSString stringWithFormat:@"%@@%@", user,KXMPPHostName];
    [chatMessage addAttributeWithName:@"to" stringValue:to];

    [chatMessage addChild:body];
    [self.xmppStream sendElement:chatMessage];
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
    DEBUG_METHOD(@"---%s---%@",__FUNCTION__,message.description);
}

- (void)xmppStream:(XMPPStream *)sender didFailToSendMessage:(XMPPMessage *)message error:(NSError *)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    DEBUG_METHOD(@"---%s---%@",__FUNCTION__,message.description);
    if ([message isChatMessageWithBody])
	{
		XMPPUserCoreDataStorageObject *user = [_xmppRosterStorage userForJID:[message from]
		                                                         xmppStream:_xmppStream
		                                               managedObjectContext:[self mgdObjContext_roster]];
		
		NSString *body = [[message elementForName:@"body"] stringValue];
		NSString *displayName = user.displayName;
        
		if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
		{
			
		}
		else
		{
			UILocalNotification *localNotification = [[UILocalNotification alloc] init];
			localNotification.alertAction = @"Ok";
			localNotification.alertBody = [NSString stringWithFormat:@"From: %@\n\n%@",displayName,body];
			[[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
		}
	}
}

@end
