//
//  XMPPFileSKConnect.m
//  XMPPChat
//
//  Created by 马远征 on 14-4-15.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "XMPPFileSKConnect.h"
#import <NSXMLElement+XMPP.h>
#import <NSData+XMPP.h>
#import <NSNumber+XMPP.h>

@interface XMPPFileSKConnect() <GCDAsyncSocketDelegate>
{
    dispatch_queue_t delegateQueue;
    dispatch_queue_t fileSKQueue;
    void *fileSKQueueTag;
    GCDAsyncSocket *asyncSocket;
    
    NSString *_uuid;
    NSString *_sid;
    
    // 代理主机信息
    NSString *_proxyHost;
    UInt16    _proxyPort;
    XMPPJID  *_proxyJID;
    
    NSMutableArray *streamHost;
    
    NSString *discoUUID;
}
@property (nonatomic, OBJ_WEAK) id<XmppfileSKDeleagte> delegate;
@property (nonatomic, strong) XMPPStream *xmppStream;
@property (nonatomic, strong) XMPPJID *receiveJID;
@property (nonatomic, strong) XMPPJID *senderJID;
@property (nonatomic, assign) BOOL isClient;
@property (nonatomic, strong) NSMutableArray *candidateJIDsArray;
@end

@implementation XMPPFileSKConnect
+(void)initialize
{
    static BOOL initialized = NO;
    if (!initialized)
    {
        initialized = YES;
    }
}

// 文件发送方调用此方法
- (id)initWithStream:(XMPPStream *)xmppStream toJID:(XMPPJID *)jid
{
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _receiveJID = jid;
        _isClient = YES;
        _uuid = [_xmppStream generateUUID];
        _sid = [_xmppStream generateUUID];
        
        fileSKQueue = dispatch_queue_create("fileSKQueue", NULL);
        fileSKQueueTag = &fileSKQueueTag;
        dispatch_queue_set_specific(fileSKQueue, fileSKQueueTag, fileSKQueueTag, NULL);
    }
    return self;
}

// 文件接收方调用此方法
- (id)initWithStream:(XMPPStream *)xmppStream inComingSKRequest:(XMPPIQ *)iq
{
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _isClient = NO;
        _uuid = [_xmppStream generateUUID];
        _senderJID = [iq from];
        
        fileSKQueue = dispatch_queue_create("fileSKQueue", NULL);
        fileSKQueueTag = &fileSKQueueTag;
        dispatch_queue_set_specific(fileSKQueue, fileSKQueueTag, fileSKQueueTag, NULL);
    }
    return self;
}

- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue
{
    NSParameterAssert(aDelegate != nil);
    NSParameterAssert(aDelegateQueue != NULL);
    
    _delegate = aDelegate;
    delegateQueue = aDelegateQueue;
    
    [_xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    if (_isClient)
    {
        // 初始方发送服务发现请求给目标方
        [self sendByteStreamsSupportQueryRequest:_receiveJID];
    }
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    NSLog(@"-%s---%@",__FUNCTION__,iq.description);
    
    NSString *type = [iq type];
    if ([@"get" isEqualToString:type])
    {
        NSXMLElement *query = [iq elementForName:@"query"];
        if (query && [query.xmlns isEqualToString:@"http://jabber.org/protocol/disco#info"])
        {
            NSLog(@"--目标方应答服务发现请求---");
            return [self sendByteStreamsSupportQueryReponse:iq];
        }
    }
    
    if ([@"result" isEqualToString:type])
    {
        NSXMLElement *query = [iq elementForName:@"query"];
        if (query != nil)
        {
            if ([query.xmlns isEqualToString:@"http://jabber.org/protocol/disco#info"])
            {
                NSString *elementID = [iq elementID];
                if ( [discoUUID isEqualToString:elementID])
                {
                    NSLog(@"--初始方发送服务发现请求给服务器--");
                    return [self sendFindProxyServerRequest];
                }
                
                // 服务器响应服务发现请求
                if ([@"proxy_info" isEqualToString:elementID])
                {
                    NSArray *identities = [query elementsForName:@"identity"];
                    BOOL found = NO;
                    for (int i= 0; i < identities.count && !found; i++)
                    {
                        NSXMLElement *identity = [identities objectAtIndex:i];
                        NSString *category = [[identity attributeForName:@"category"] stringValue];
                        NSString *type = [[identity attributeForName:@"type"] stringValue];
                        if ([category isEqualToString:@"proxy"] && [type isEqualToString:@"bytestreams"] )
                        {
                            found = YES;
                        }
                    }
                    
                    if (found) // 发现了代理
                    {
                        NSLog(@"----发现了代理，查询网络地址---");
                        // 初始方从代理方那里请求网络地址
                        return [self sendQueryNetworkAddressRequest:iq.from];
                    }
                    else // 没有发现代理，继续查询
                    {
                        if (_candidateJIDsArray.count > 0)
                        {
                            [_candidateJIDsArray removeObjectAtIndex:0];
                        }
                        
                        if (_candidateJIDsArray.count > 0)
                        {
                            XMPPJID *candidateJID = [_candidateJIDsArray objectAtIndex:0];
                            return [self sendServiceDiscoRequest:candidateJID];
                        }
                    }
                }
            }// if
            
            // 服务器应答服务发现请求
            if ([query.xmlns isEqualToString:@"http://jabber.org/protocol/disco#items"])
            {
                NSString *elementID = [iq elementID];
                if ( [@"server_items" isEqualToString:elementID])
                {
                    NSLog(@"--服务器应答服务发现请求--");
                    NSArray *itemsArray = (NSArray*)[query elementsForName:@"item"];
                    _candidateJIDsArray = [[NSMutableArray alloc]initWithCapacity:itemsArray.count];
                    
                    for (NSXMLElement *item in itemsArray)
                    {
                        NSString *jid = [[item attributeForName:@"jid"]stringValue];
                        XMPPJID *xmppJID = [XMPPJID jidWithString:jid];
                        if (xmppJID)
                        {
                            [_candidateJIDsArray addObject:xmppJID];
                        }
                    }
                    
                    for (int j = 0; j < _candidateJIDsArray.count; j++)
                    {
                        XMPPJID *candidateJID = [_candidateJIDsArray objectAtIndex:j];
                        NSRange proxyRange = [[candidateJID domain] rangeOfString:@"proxy"
                                                                          options:NSCaseInsensitiveSearch];
                        if (proxyRange.length > 0)
                        {
                            [_candidateJIDsArray removeObjectAtIndex:j];
                            [_candidateJIDsArray insertObject:candidateJID atIndex:0];
                        }
                    }
                    
                    if (_candidateJIDsArray.count > 0)
                    {
                        XMPPJID *candidateJID = [_candidateJIDsArray objectAtIndex:0];
                        NSLog(@"--初始方发送服务发现请求给代理--");
                        return [self sendServiceDiscoRequest:candidateJID];
                    }
                }
            }// if

            
            // 代理通知初始方网络地址<发现代理主机host和port>
            if ([query.xmlns isEqualToString:@"http://jabber.org/protocol/bytestreams"])
            {
                NSString *elementID = [iq elementID];
                if ([@"discover" isEqualToString:elementID])
                {
                    
                    NSXMLElement *streamhost = [query elementForName:@"streamhost"];
                    NSString *jid = [[streamhost attributeForName:@"jid"]stringValue];
                    _proxyJID = [XMPPJID jidWithString:jid];
                    _proxyHost = [[streamhost attributeForName:@"host"]stringValue];
                    NSString *port = [[streamhost attributeForName:@"port"]stringValue];
                    _proxyPort = [port integerValue];
                    
                    if (_proxyJID != nil || _proxyHost != nil || _proxyPort > 0)
                    {
                        NSLog(@"-----发信了网络地址-----");
                        return  [self sendNetworkAddressToReceiver:_proxyJID host:_proxyHost port:port];
                    }
                }
                
                if ([@"initiate" isEqualToString:elementID])
                {
                    NSXMLElement *streamHostEle = [query elementForName:@"streamhost-used"];
                    NSString *jid = [[streamHostEle attributeForName:@"jid"]stringValue];
                    _proxyJID = [XMPPJID jidWithString:jid];
                    
                    asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
                    NSError *err = nil;
                    if (![asyncSocket connectToHost:_proxyHost onPort:7777 withTimeout:8.00 error:&err])
                    {
                        NSLog(@"-----初始方socket连接错误---");
                    }
                    else
                    {
                        NSLog(@"----初始方连接到主机----");
                    }
                }
            }//if
        }
    }
    
    // 目标方接收初始方网络主机信息，建立连接
    if ([@"set" isEqualToString:type])
    {
        NSXMLElement *query = [iq elementForName:@"query"];
        if (query != nil)
        {
            if ([query.xmlns isEqualToString:@"http://jabber.org/protocol/bytestreams"])
            {
                NSString *elementID = [iq elementID];
                if ([@"initiate" isEqualToString:elementID])
                {
                    NSLog(@"----目标方获取到网络地址----");
                    _sid = [[query attributeForName:@"sid"]stringValue];
                    NSXMLElement *streamhost = [query elementForName:@"streamhost"];
                    _proxyHost = [[streamhost attributeForName:@"host"]stringValue];
                    NSString *port = [[streamhost attributeForName:@"port"]stringValue];
                    NSString *jid = [[streamhost attributeForName:@"jid"]stringValue];
                    _proxyJID = [XMPPJID jidWithString:jid];
                    _proxyPort = [port integerValue];
                    
                    asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
                    NSError *err = nil;
                    if (![asyncSocket connectToHost:_proxyHost onPort:7777  withTimeout:8.00 error:&err])
                    {
                        NSLog(@"----目标方无法连接到主机----");
                        return [self sendInitiateSocket5Error:iq.from];
                    }
                    else
                    {
                        NSLog(@"----目标方连接到主机----");
                    }
                }
            }
        }//if
    }
    
    if ([@"error" isEqualToString:type])
    {
        NSLog(@"---socketl连接建立失败----");
    }
    return YES;
}


#pragma mark -
#pragma mark XEP-065

//////////////////////////////////////////// 初始方查询目标方是否支持字节流//////////////////////////////////////////////////////////////////////

// 初始方发送服务发现请求给目标方
/*
 <iq type='get'
    from='initiator@example.com/foo'
    to='target@example.org/bar'
    id='hello'>
    <query xmlns='http://jabber.org/protocol/disco#info'/>
 </iq>
 */
- (BOOL)sendByteStreamsSupportQueryRequest:(XMPPJID*)toJId
{
    discoUUID = [_xmppStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" elementID:discoUUID];
    [iq addAttributeWithName:@"to" stringValue:toJId.full];
    [iq addAttributeWithName:@"from" stringValue:[[_xmppStream myJID] full]];
    NSXMLElement *feature = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
    [iq addChild:feature];
    [_xmppStream sendElement:iq];
    return YES;
}

// 目标方应答服务发现请求
/*
 <iq type='result'
     from='target@example.org/bar'
     to='initiator@example.com/foo'
     id='hello'>
     <query xmlns='http://jabber.org/protocol/disco#info'>
         <identity
         category='proxy'
         type='bytestreams'
         name='SOCKS5 Bytestreams Service'/>
         ...
         <feature var='http://jabber.org/protocol/bytestreams'/>
         ...
     </query>
 </iq>
 */
- (BOOL)sendByteStreamsSupportQueryReponse:(XMPPIQ*)inIQ
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"result" to:inIQ.from elementID:inIQ.elementID];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
    [iq addChild:query];
    
    NSXMLElement *identity = [NSXMLElement elementWithName:@"identity"];
    [identity addAttributeWithName:@"category" stringValue:@"client"];
    [identity addAttributeWithName:@"type" stringValue:@"pc"];
    [identity addAttributeWithName:@"name" stringValue:@"Psi"];
    [query addChild:identity];
    
    NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
    [feature addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/bytestreams"];
    [query addChild:feature];
    
    NSXMLElement *feature1 = [NSXMLElement elementWithName:@"feature"];
    [feature1 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/si"];
    [query addChild:feature1];
    
    NSXMLElement *feature2 = [NSXMLElement elementWithName:@"feature"];
    [feature2 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/si/profile/file-transfer"];
    [query addChild:feature2];
    
    NSXMLElement *feature3 = [NSXMLElement elementWithName:@"feature"];
    [feature3 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/commands"];
    [query addChild:feature3];
    
    NSXMLElement *feature4 = [NSXMLElement elementWithName:@"feature"];
    [feature4 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/rosterx"];
    [query addChild:feature4];
    
    NSXMLElement *feature5 = [NSXMLElement elementWithName:@"feature"];
    [feature5 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/muc"];
    [query addChild:feature5];
    
    NSXMLElement *feature6 = [NSXMLElement elementWithName:@"feature"];
    [feature6 addAttributeWithName:@"var" stringValue:@"jabber:x:data"];
    [query addChild:feature6];
    
    NSXMLElement *feature7 = [NSXMLElement elementWithName:@"feature"];
    [feature7 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/disco#info"];
    [query addChild:feature7];
    
    [_xmppStream sendElement:iq];
    
    return YES;
}

//////////////////////////////////////////// 初始方查找代理服务//////////////////////////////////////////////////////////////////////

// 初始方发送服务发现请求给服务器
/*
 <iq type='get'
    from='initiator@example.com/foo'
    to='example.com'
    id='server_items'>
    <query xmlns='http://jabber.org/protocol/disco#items'/>
 </iq>
 */

//  服务器应答服务发现请求
/*
 <iq type='result'
     from='example.com'
     to='initiator@example.com/foo'
     id='server_items'>
        <query xmlns='http://jabber.org/protocol/disco#items'>
            ...
            <item jid='streamhostproxy.example.net' name='Bytestreams Proxy'/>
            ...
        </query>
 </iq>
 */
#warning 这里的www.savvy-tech.net是我们的服务器，实际使用可能有多个
- (BOOL)sendFindProxyServerRequest
{
    XMPPJID *toJID = [XMPPJID jidWithString:@"www.savvy-tech.net"];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:toJID elementID:@"server_items"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#items"];
    [iq addChild:query];
    [_xmppStream sendElement:iq];
    return YES;
}


//////////////////////////////////////////// 初始方查询确定是否代理//////////////////////////////////////////////////////////////////////

/* 对于disco#items结果的每一项，初始方必须查询并确定其是否是字节流代理*/
// 初始方发送服务发现请求给代理
/*
<iq type='get'
    from='initiator@example.com/foo'
    to='streamhostproxy.example.net'
    id='proxy_info'>
    <query xmlns='http://jabber.org/protocol/disco#info'/>
</iq>
 */

// 服务器响应服务发现请求
/*
 <iq type='result'
     from='streamhostproxy.example.net'
     to='initiator@example.com/foo'
     id='proxy_info'>
        <query xmlns='http://jabber.org/protocol/disco#info'>
            ...
            <identity category='proxy'
                        type='bytestreams'
                        name='SOCKS5 Bytestreams Service'/>
            ...
            <feature var='http://jabber.org/protocol/bytestreams'/>
            ...
        </query>
 </iq>
 */
- (BOOL)sendServiceDiscoRequest:(XMPPJID*)jid
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:jid elementID:@"proxy_info"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
    [iq addChild:query];
    [_xmppStream sendElement:iq];
    return YES;
}


//////////////////////////////////////////// 初始方查询流主机的网络地址//////////////////////////////////////////////////////////////////////

// 初始方从代理方那里请求网络地址
/*
 <iq type='get'
     from='initiator@example.com/foo'
     to='streamhostproxy.example.net'
     id='discover'>
     <query xmlns='http://jabber.org/protocol/bytestreams'/>
 </iq>
 */

//  代理通知初始方网络地址
/*
 <iq type='result'
     from='streamhostproxy.example.net'
     to='initiator@example.com/foo'
     id='discover'>
     <query xmlns='http://jabber.org/protocol/bytestreams'>
        <streamhost
            jid='streamhostproxy.example.net'
            host='24.24.24.1'
            zeroconf='_jabber.bytestreams'/>
     </query>
 </iq>
 */
// 代理返回错误给初始方 <不能初始流字节>
/*
<iq type='error'
    from='initiator@example.com/foo'
    to='streamhostproxy.example.net'
    id='discover'>
    <query xmlns='http://jabber.org/protocol/bytestreams'/>
    <error code='403' type='auth'>
        <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
    </error>
</iq>
 */

// 代理返回错误给初始方 <不能作为流主机>
/*
 <iq type='error'
 from='initiator@example.com/foo'
 to='streamhostproxy.example.net'
 id='discover'>
 <query xmlns='http://jabber.org/protocol/bytestreams'/>
 <error code='405' type='cancel'>
 <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
 </error>
 </iq>
 */
- (BOOL)sendQueryNetworkAddressRequest:(XMPPJID*)hostJID
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:hostJID elementID:@"discover"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
    [iq addChild:query];
    [_xmppStream sendElement:iq];
    return YES;
}


//////////////////////////////////////////// 初始方通知目标方流主机//////////////////////////////////////////////////////////////////////
// 交互的初始化<初始方提供关于流主机的网络地址给目标方>
/*
 <iq type='set'
     from='initiator@example.com/foo'
     to='target@example.org/bar'
     id='initiate'>
     <query xmlns='http://jabber.org/protocol/bytestreams'
            sid='mySID'
            mode='tcp'>
            <streamhost
                jid='initiator@example.com/foo'
                host='192.168.4.1'
                port='5086'/>
            <streamhost
                jid='streamhostproxy.example.net'
                host='24.24.24.1'
                zeroconf='_jabber.bytestreams'/>
     </query>
 </iq>
 */

- (BOOL)sendNetworkAddressToReceiver:(XMPPJID*)jid host:(NSString*)host port:(NSString*)port
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:_receiveJID elementID:@"initiate"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
    [query addAttributeWithName:@"sid" stringValue:_sid];
    [query addAttributeWithName:@"mode" stringValue:@"tcp"];
    [iq addChild:query];
    
    NSXMLElement *streamhost = [NSXMLElement elementWithName:@"streamhost"];
    [streamhost addAttributeWithName:@"jid" stringValue:jid.full];
    [streamhost addAttributeWithName:@"host" stringValue:host];
    [streamhost addAttributeWithName:@"port" stringValue:port];
    [query addChild:streamhost];
    NSLog(@"------address---%@",iq.description);
    [_xmppStream sendElement:iq];
    return YES;
}

// 目标方拒绝字节流
/*
 <iq type='error'
     from='target@example.org/bar'
     to='initiator@example.com/foo'
     id='initiate'>
    <error code='406' type='auth'>
        <not-acceptable xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
    </error>
 </iq>
 */
- (BOOL)sendRejectSocket5ByteStream:(XMPPJID*)jid
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"error" to:jid elementID:@"initiate"];
    
    NSXMLElement *error = [NSXMLElement elementWithName:@"error"];
    [error addAttributeWithName:@"code" stringValue:@"406"];
    [error addAttributeWithName:@"type" stringValue:@"auth"];
    [iq addChild:error];
    
    NSXMLElement *notAcceptable = [NSXMLElement elementWithName:@"not-acceptable" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
    [error addChild:notAcceptable];
    
    [_xmppStream sendElement:iq];
    
    return YES;
}

//////////////////////////////////////////// 目标方使用流主机建立SOCKS5连接//////////////////////////////////////////////////////////////////////
// 目标方不能连接任何流主机并且终止该事物
/*
 <iq type='error'
     from='target@example.org/bar'
     to='initiator@example.com/foo'
     id='initiate'>
    <error code='404' type='cancel'>
        <item-not-found xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
    </error>
 </iq>
 */
- (BOOL)sendInitiateSocket5Error:(XMPPJID*)jid
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"error" to:jid elementID:@"initiate"];
    NSXMLElement *error = [NSXMLElement elementWithName:@"error"];
    [error addAttributeWithName:@"code" stringValue:@"404"];
    [error addAttributeWithName:@"type" stringValue:@"cancel"];
    [iq addChild:error];
    
    NSXMLElement *item_not_found = [NSXMLElement elementWithName:@"item-not-found" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
    [error addChild:item_not_found];
    
    [_xmppStream sendElement:iq];
    return YES;
}

//////////////////////////////////////////// 目标方确认SOCKS5连接//////////////////////////////////////////////////////////////////////
// 目标方通知初始方关于连接的信息
/*
 <iq type='result'
     from='target@example.org/bar'
     to='initiator@example.com/foo'
     id='initiate'>
    <query xmlns='http://jabber.org/protocol/bytestreams'>
        <streamhost-used jid='streamhostproxy.example.net'/>
    </query>
 </iq>
 */
- (BOOL)sendinitiateSocket5Finished:(XMPPJID*)jid hostJID:(XMPPJID*)hostJID
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"result" to:jid elementID:@"initiate"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
    [iq addChild:query];
    
    NSXMLElement *streamhost_used = [NSXMLElement elementWithName:@"streamhost-used"];
    [streamhost_used addAttributeWithName:@"jid" stringValue:hostJID.full];
    [query addChild:streamhost_used];
    NSLog(@"----%s---%@",__FUNCTION__,iq.description);
    [_xmppStream sendElement:iq];
    return YES;
}

//////////////////////////////////////////// 激活字节流//////////////////////////////////////////////////////////////////////
// 初始方请求激活流
/*
 <iq type='set'
     from='initiator@example.com/foo'
     to='streamhostproxy.example.net'
     id='activate'>
        <query xmlns='http://jabber.org/protocol/bytestreams' sid='mySID'>
            <activate>target@example.org/bar</activate>
        </query>
 </iq>
 */

// 代理通知初始方有关激活的信息
/*
 <iq type='result'
     from='streamhostproxy.example.net'
     to='initiator@example.com/foo'
     id='activate'/>
 */
- (BOOL)sendActivateRequest:(XMPPJID*)jid
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:_proxyJID elementID:@"activate"];
    
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
    [query addAttributeWithName:@"sid" stringValue:_sid];
    [iq addChild:query];
    
    NSXMLElement *activate = [NSXMLElement elementWithName:@"activate" stringValue:jid.full];
    [query addChild:activate];
    NSLog(@"---iq---%@",iq.description);
    [_xmppStream sendElement:iq];
    return YES;
}



#pragma mark -
#pragma mark GCDAsyncSocket

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    NSLog(@"--%s--",__FUNCTION__);
    [self socksOpen];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"--%s--",__FUNCTION__);
    
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSLog(@"----%s---%@",__FUNCTION__,data);
    
    NSLog(@"--%s--%ld",__FUNCTION__,tag);
    if (tag == 101)
	{
		// See socksOpen method for socks reply format
		UInt8 ver = [NSNumber xmpp_extractUInt8FromData:data atOffset:0];
		UInt8 mtd = [NSNumber xmpp_extractUInt8FromData:data atOffset:1];
		
		if(ver == 5 && mtd == 0)
		{
            // 收到 | 05 00 | 可以代理，进一步建立连接
            NSLog(@"----建立代理--");
			[self socksConnect];
		}
		else
		{
			[asyncSocket disconnect];
		}
	}
    else if (tag == 103)
	{
		UInt8 ver = [NSNumber xmpp_extractUInt8FromData:data atOffset:0];
		UInt8 rep = [NSNumber xmpp_extractUInt8FromData:data atOffset:1];
		
		if(ver == 5 && rep == 0)
		{
            NSLog(@"---收到服务器--5 0 0 3--");
            // 收到服务器 5 0 0 3
			// We read in 5 bytes which we expect to be:
			// 0: ver  = 5
			// 1: rep  = 0
			// 2: rsv  = 0
			// 3: atyp = 3
			// 4: size = size of addr field
			//
			// However, some servers don't follow the protocol, and send a atyp value of 0.
			
			UInt8 atyp = [NSNumber xmpp_extractUInt8FromData:data atOffset:3];
			
			if (atyp == 3)
			{
				UInt8 addrLength = [NSNumber xmpp_extractUInt8FromData:data atOffset:4];
				UInt8 portLength = 2;
				[asyncSocket readDataToLength:(addrLength+portLength) withTimeout:5.00 tag:104];
			}
			else if (atyp == 0)
			{
				// The size field was actually the first byte of the port field
				// We just have to read in that last byte
				[asyncSocket readDataToLength:1 withTimeout:5.00 tag:104];
			}
			else
			{
				[asyncSocket disconnect];
			}
		}
		else
		{
			[asyncSocket disconnect];
		}
    }
    else if (tag == 104)
	{
		if (_isClient)
		{
            DEBUG_METHOD(@"-----发送流激活信息---");
			//发送流激活消息
            [self sendActivateRequest:_receiveJID];
		}
		else
		{
			// 发送确认与成功信息
            [self sendinitiateSocket5Finished:_senderJID hostJID:_proxyJID];
            DEBUG_METHOD(@"-----成功连接流主机---");
		}
	}

}

#pragma mark -
#pragma mark SOCKS

- (void)socksOpen
{
    // SOCKS Server 缺省侦听在1080/TCP端口，SOCKS Client连接到SOKCS Server之后发送第一个报文
    //      +-----+-----------+---------+
	// NAME | VER | NMETHODS  | METHODS |
	//      +-----+-----------+---------+
	// SIZE |  1  |    1      | 1 - 255 |
	//      +-----+-----------+---------+
	//
	// Note: Size is in bytes
	//
	// Version    = 5 (for SOCKS5)
	// NumMethods = 1
	// Method     = 0 (No authentication, anonymous access)
    void *byteBuffer = malloc(3);
	
	UInt8 ver = 5;
	memcpy(byteBuffer+0, &ver, sizeof(ver));
	
	UInt8 nMethods = 1;
	memcpy(byteBuffer+1, &nMethods, sizeof(nMethods));
	
	UInt8 method = 0;
	memcpy(byteBuffer+2, &method, sizeof(method));
	
	NSData *data = [NSData dataWithBytesNoCopy:byteBuffer length:3 freeWhenDone:YES];
	
	[asyncSocket writeData:data withTimeout:-1 tag:101];
    
    // socks Server从METHOD 方法中选中一个字节（一种认证机制），并向SOCKS Client发送响应报文
    //      +-----+--------+
	// NAME | VER | METHOD |
	//      +-----+--------+
	// SIZE |  1  |   1    |
	//      +-----+--------+
	//
	// Note: Size is in bytes
	//
	// Version = 5 (for SOCKS5)
	// Method  = 0 (No authentication, anonymous access)
    // Method 可用值
    /*
     0x00 NO AUTHENTICATION REQUEIRED （无需认证）
     0x01 GSSAPI
     0x02 USERNAME/PASSWORD（用户名/口令认证机制）
     0x03-0x7F IANA ASSIGNED
     0x80-0xFE RESERVED FOR PRIVATE METHODS（私有认证机制）
     0xFF NO ACCEPTABLE METHODS（完全不兼容）
     
     如果SOCKS Server响应0xFF,表示SOCKS Server与SOCKS Client 完全不兼容，
     SOCKS Client必须关闭TCP连接。认证机制协商完成后，SOCKS Clent与SOCKS 
     Server 进行认证机制相关的子协商，参看其他文档。为保持最广泛的兼容性，
     SOCKS Client、SOCKS Server必须支持0x01,同事应该支持0x02.

     */
	
	[asyncSocket readDataToLength:2 withTimeout:5.00 tag:101];
}

- (void)socksConnect
{
	XMPPJID *myJID = [_xmppStream myJID];
	
	// From XEP-0065:
	//
	// The [address] MUST be SHA1(SID + Initiator JID + Target JID) and
	// the output is hexadecimal encoded (not binary).
	
	XMPPJID *initiatorJID = _isClient ? myJID : _senderJID;
	XMPPJID *targetJID    = _isClient ? _receiveJID  : myJID;
	
	NSString *hashMe = [NSString stringWithFormat:@"%@%@%@", _sid, [initiatorJID full], [targetJID full]];
	NSData *hashRaw = [[hashMe dataUsingEncoding:NSUTF8StringEncoding] xmpp_sha1Digest];
	NSData *hash = [[hashRaw xmpp_hexStringValue] dataUsingEncoding:NSUTF8StringEncoding];
	
    // 认证机制相关的子协商完成后，SOCKS Client提交转发请求
	//      +-----+-----+-----+------+------+------+
	// NAME | VER | CMD | RSV | ATYP | ADDR | PORT |
	//      +-----+-----+-----+------+------+------+
	// SIZE |  1  |  1  |  1  |  1   | var  |  2   |
	//      +-----+-----+-----+------+------+------+
	//
	// Note: Size is in bytes
	//
	// Version      = 5 (for SOCKS5)
	// Command      = 1 (for Connect)
	// Reserved     = 0
	// Address Type = 3 (1=IPv4, 3=DomainName 4=IPv6)
	// Address      = P:D (P=LengthOfDomain D=DomainWithoutNullTermination)
	// Port         = 0
    
	// CMD可取值如下：
    //   +------+-----------------+
    //   | 0x01 |     CONNECT     |
    //   +------+-----------------+
    //   | 0x02 |       BIND      |
    //   +------+-----------------+
    //   | 0x03 |  UDP ASSOCIATE  |
    //   +------+-----------------+
    
    // RSV 保留字段，必须为0x00
    
    // ATYP 用于指明DST.ADDR域的类型，可取如下值：
    //   +------+-----------------+
    //   | 0x01 |     IPV4 地址    |
    //   +------+-----------------+
    //   | 0x03 |  FQDN(全称域名)  |
    //   +------+-----------------+
    //   | 0x04 |      IPV6地址    |
    //   +------+-----------------+
    
    
	uint byteBufferLength = (uint)(4 + 1 + [hash length] + 2);
	void *byteBuffer = malloc(byteBufferLength);
	
	UInt8 ver = 5;
	memcpy(byteBuffer+0, &ver, sizeof(ver));
	
	UInt8 cmd = 1;
	memcpy(byteBuffer+1, &cmd, sizeof(cmd));
	
	UInt8 rsv = 0;
	memcpy(byteBuffer+2, &rsv, sizeof(rsv));
	
	UInt8 atyp = 3;
	memcpy(byteBuffer+3, &atyp, sizeof(atyp));
	
	UInt8 hashLength = [hash length];
	memcpy(byteBuffer+4, &hashLength, sizeof(hashLength));
	
	memcpy(byteBuffer+5, [hash bytes], [hash length]);
	
	UInt16 port = 0;
	memcpy(byteBuffer+5+[hash length], &port, sizeof(port));
	
	NSData *data = [NSData dataWithBytesNoCopy:byteBuffer length:byteBufferLength freeWhenDone:YES];
	NSLog(@"----%s--%@",__FUNCTION__,data);
	[asyncSocket writeData:data withTimeout:-1 tag:102];
	
	//      +-----+-----+-----+------+------+------+
	// NAME | VER | REP | RSV | ATYP | ADDR | PORT |
	//      +-----+-----+-----+------+------+------+
	// SIZE |  1  |  1  |  1  |  1   | var  |  2   |
	//      +-----+-----+-----+------+------+------+
	//
	// Note: Size is in bytes
	//
	// Version      = 5 (for SOCKS5)
	// Reply        = 0 (0=Succeeded, X=ErrorCode)
	// Reserved     = 0
	// Address Type = 3 (1=IPv4, 3=DomainName 4=IPv6)
	// Address      = P:D (P=LengthOfDomain D=DomainWithoutNullTermination)
	// Port         = 0
	//
	// It is expected that the SOCKS server will return the same address given in the connect request.
	// But according to XEP-65 this is only marked as a SHOULD and not a MUST.
	// So just in case, we'll read up to the address length now, and then read in the address+port next.
	
	[asyncSocket readDataToLength:5 withTimeout:5.0 tag:103];
}

@end
