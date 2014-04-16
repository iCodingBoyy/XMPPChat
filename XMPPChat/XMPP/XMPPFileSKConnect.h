//
//  XMPPFileSKConnect.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-15.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

// XMPP XEP-065

#import "XMPPModule.h"
#import "XMPPModule.h"
#import <XMPP.h>


@protocol XmppfileSKDeleagte;

@interface XMPPFileSKConnect : NSObject
- (id)initWithStream:(XMPPStream*)xmppStream toJID:(XMPPJID*)jid;
- (id)initWithStream:(XMPPStream *)xmppStream inComingSKRequest:(XMPPIQ*)iq;
- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue;
- (BOOL)isClient;
@end


@protocol XmppfileSKDeleagte <NSObject>

- (void)XMPPFileSKConnect:(XMPPFileSKConnect*)sender didSucceed:(GCDAsyncSocket*)socket;
- (void)XMPPFileSKConnectDidFail:(XMPPFileSKConnect *)sender;

@end