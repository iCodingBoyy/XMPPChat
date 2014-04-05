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


@interface YZXMPPManager() <XMPPRosterDelegate,XMPPStreamDelegate,XMPPReconnectDelegate>

@property (nonatomic, strong) NSString *passWord;
@property (nonatomic, assign) BOOL isXmppConnected;
@property (nonatomic,   copy) AuthComplete authCompleteBlock;
@property (nonatomic,   copy) AuthError authErrorBlock;
@end

@implementation YZXMPPManager

+ (id)sharedYZXMPP
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
    [_xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    // 自动重连
    _xmppReconnect = [[XMPPReconnect alloc]init];
    [_xmppReconnect activate:_xmppStream];
    [_xmppReconnect addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    // 花名册
    _xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc]init];
    _xmppRoster = [[XMPPRoster alloc]initWithRosterStorage:_xmppRosterStorage];
    _xmppRoster.autoFetchRoster = YES;
    _xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    _xmppRoster.autoClearAllUsersAndResources = NO;
    [_xmppRoster activate:_xmppStream];
    [_xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    // vCard
    _xmppvCardStorage = [XMPPvCardCoreDataStorage sharedInstance];
	_xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:_xmppvCardStorage];
	_xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:_xmppvCardTempModule];
    
    // cap
    _xmppCapabilitiesStorage = [XMPPCapabilitiesCoreDataStorage sharedInstance];
    _xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:_xmppCapabilitiesStorage];
    
    _xmppCapabilities.autoFetchHashedCapabilities = YES;
    _xmppCapabilities.autoFetchNonHashedCapabilities = NO;
    [_xmppvCardTempModule   activate:_xmppStream];
	[_xmppvCardAvatarModule activate:_xmppStream];
	[_xmppCapabilities      activate:_xmppStream];
}

- (void)releaseXMPPStream
{
    [_xmppStream removeDelegate:self];
    [_xmppRoster removeDelegate:self];
    
    [_xmppReconnect deactivate];
    [_xmppRoster deactivate];
    [_xmppvCardTempModule deactivate];
    [_xmppvCardAvatarModule deactivate];
    [_xmppCapabilities deactivate];
    
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
    
    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@/%@",userName,KXMPPHostName,KXMPPResource];
    XMPPJID *xmppJID = [XMPPJID jidWithString:xmppJIDString];
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
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
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

//NSString *errorString = @"参数输入不完整.";
//NSDictionary *userInfoDic = [NSDictionary dictionaryWithObject:errorString forKey: NSLocalizedDescriptionKey];
//NSError *error = [NSError errorWithDomain:KFFHttpRequestErrorDomain code:FFHttpRequestParamsError userInfo:userInfoDic] ;

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
    
    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@/%@",loginName,KXMPPHostName,KXMPPResource];
    XMPPJID *xmppJID = [XMPPJID jidWithString:xmppJIDString];
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
}

- (void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkConnectionFlags)connectionFlags
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkConnectionFlags)connectionFlags
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    return YES;
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
            NSLog(@"--%s---not-auth-----%@",__FUNCTION__,error);
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
            NSLog(@"--%s----register-----%@",__FUNCTION__,error);
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
    [iqEle addAttributeWithName:@"id" stringValue:@"123456789"];
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

- (void)fetchUserWithXMPPJID:(NSString*)searchField
{
    NSString *userBare1  = [[_xmppStream myJID] bare];
    
    NSXMLElement *query = [NSXMLElement elementWithName:@"query"];
    [query addAttributeWithName:@"xmlns" stringValue:@"jabber:iq:search"];
    
    
    NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
    [x addAttributeWithName:@"type" stringValue:@"submit"];
    
    NSXMLElement *formType = [NSXMLElement elementWithName:@"field"];
    [formType addAttributeWithName:@"type" stringValue:@"hidden"];
    [formType addAttributeWithName:@"var" stringValue:@"FORM_TYPE"];
    [formType addChild:[NSXMLElement elementWithName:@"value" stringValue:@"jabber:iq:search" ]];
    
    NSXMLElement *userName = [NSXMLElement elementWithName:@"field"];
    [userName addAttributeWithName:@"var" stringValue:@"Username"];
    [userName addChild:[NSXMLElement elementWithName:@"value" stringValue:@"1" ]];
    
    NSXMLElement *name = [NSXMLElement elementWithName:@"field"];
    [name addAttributeWithName:@"var" stringValue:@"Name"];
    [name addChild:[NSXMLElement elementWithName:@"value" stringValue:@"1"]];
    
    NSXMLElement *email = [NSXMLElement elementWithName:@"field"];
    [email addAttributeWithName:@"var" stringValue:@"Email"];
    [email addChild:[NSXMLElement elementWithName:@"value" stringValue:@"1"]];
    
    NSXMLElement *search = [NSXMLElement elementWithName:@"field"];
    [search addAttributeWithName:@"var" stringValue:@"search"];
    [search addChild:[NSXMLElement elementWithName:@"value" stringValue:searchField]];
    
    [x addChild:formType];
    [x addChild:userName];
    //[x addChild:name];
    //[x addChild:email];
    [x addChild:search];
    [query addChild:x];
    
    
    NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
    [iq addAttributeWithName:@"type" stringValue:@"set"];
    [iq addAttributeWithName:@"id" stringValue:@"searchByUserName"];
    [iq addAttributeWithName:@"to" stringValue:[NSString stringWithFormat:@"search.%@",_xmppStream.hostName ]];
    [iq addAttributeWithName:@"from" stringValue:userBare1];
    [iq addChild:query];
    [_xmppStream sendElement:iq];
}


//- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
//{
//    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
//    
//    if ([@"result" isEqualToString:iq.type])
//    {
//        NSXMLElement *query = iq.childElement;
//        if ([@"query" isEqualToString:query.name])
//        {
//            NSArray *items = [query children];
//            for (NSXMLElement *item in items)
//            {
//                NSString *jid = [item attributeStringValueForName:@"jid"];
//                XMPPJID *xmppJID = [XMPPJID jidWithString:jid];
//                NSLog(@"-%s--%@",__FUNCTION__,xmppJID);
//            }
//        }
//    }
//    
//    if ([TURNSocket isNewStartTURNRequest:iq])
//    {
//        [TURNSocket initialize];
//        TURNSocket *turnSocket = [[TURNSocket alloc]initWithStream:_xmppStream incomingTURNRequest:iq];
//        [turnSocket startWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
//        NSLog(@"---xmppFile-----");
//    }
//    return YES;
//}

- (void)sendFile:(NSData*)data toUser:(NSString*)xmppUser
{
    _sendData = data;
    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@/%@",xmppUser,KXMPPHostName,KXMPPResource];
    XMPPJID *jid = [XMPPJID jidWithString:xmppJIDString];
    NSLog(@"------domian---%@",_xmppStream.myJID.domain);
    [TURNSocket setProxyCandidates:[NSArray arrayWithObjects:KXMPPHostName, nil]];
    
    TURNSocket *turnSocket = [[TURNSocket alloc]initWithStream:_xmppStream toJID:jid];
    [turnSocket startWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
}

- (void)turnSocket:(TURNSocket *)sender didSucceed:(GCDAsyncSocket *)socket
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
//    socket.delegate = self;
//    [socket readDataWithTimeout:30 tag:1005];
    socket.delegate = self;
    [socket writeData:_sendData withTimeout:30 tag:1003];
    [socket disconnectAfterWriting];
    
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
}

- (void)turnSocketDidFail:(TURNSocket *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    NSLog(@"------%@---",[TURNSocket proxyCandidates]);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(NSXMLElement *)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

#pragma mark -
#pragma mark XMPPStream Delegate




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
    NSString *xmppJIDString = [NSString stringWithFormat:@"%@@%@",name,KXMPPHostName];
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

    XMPPJID *jid = [XMPPJID jidWithString:[[presence from] user]]; 
    [_xmppRoster acceptPresenceSubscriptionRequestFrom:jid andAddToRoster:YES];
    
    XMPPUserCoreDataStorageObject *user = [_xmppRosterStorage userForJID:[presence from]
	                                                         xmppStream:_xmppStream
	                                               managedObjectContext:[self mgdObjContext_roster]];
	
	NSString *body = nil;
	
	if (![user.displayName isEqualToString:presence.fromStr])
	{
		body = [NSString stringWithFormat:@"Buddy request from %@ <%@>", user.displayName, presence.fromStr];
	}
	else
	{
		body = [NSString stringWithFormat:@"Buddy request from %@", user.displayName];
	}
	
	
	if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
	{
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:user.displayName
		                                                    message:body
		                                                   delegate:nil
		                                          cancelButtonTitle:@"Not implemented"
		                                          otherButtonTitles:nil];
		[alertView show];
	}
	else
	{
		UILocalNotification *localNotification = [[UILocalNotification alloc] init];
		localNotification.alertAction = @"Not implemented";
		localNotification.alertBody = body;
		
		[[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
	}

}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(DDXMLElement *)item
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    NSLog(@"----item--%@",item);
}



- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    if ( ![presence.from.user isEqualToString:sender.myJID.user])
    {
        if ([presence.type isEqualToString:@"available"])
        {
            
        }
        else if ([presence.type isEqualToString:@"unavailable"])
        {
            
        }
    }
    
    if ([[presence type] isEqualToString:@"subscribed"])
    {
        [_xmppRoster acceptPresenceSubscriptionRequestFrom:[presence from] andAddToRoster:YES];
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

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    if ([message isChatMessageWithBody])
	{
//		XMPPUserCoreDataStorageObject *user = [_xmppRosterStorage userForJID:[message from]
//		                                                         xmppStream:_xmppStream
//		                                               managedObjectContext:[self mgdObjContext_roster]];
		
		NSString *body = [[message elementForName:@"body"] stringValue];
		NSString *displayName = message.from.user;
        
		if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
		{
			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:displayName
                                                                message:body
                                                               delegate:nil
                                                      cancelButtonTitle:@"Ok"
                                                      otherButtonTitles:nil];
			[alertView show];
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
