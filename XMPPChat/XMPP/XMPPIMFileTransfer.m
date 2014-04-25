//
//  XMPPIMFileTransfer.m
//  XMPPChat
//
//  Created by 马远征 on 14-4-23.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "XMPPIMFileTransfer.h"
#import <NSXMLElement+XMPP.h>
#import <NSData+XMPP.h>
#import <NSNumber+XMPP.h>

#pragma mark -
#pragma mark XmppFileModel
//////////////////////////////////////XmppFileModel//////////////////////////////////////////////

@implementation XmppFileModel
- (id)initWithReceiveIQ:(XMPPIQ*)inIQ
{
    self = [super init];
    if (self)
    {
        _JID = inIQ.from;
        _timeStamp = [NSDate date];
        
        NSXMLElement *si = [inIQ elementForName:@"si"];
        NSXMLElement *file = [si elementForName:@"file"];
        
        _uuid = [[inIQ attributeForName:@"id"]stringValue];
        _mimetype = [[si attributeForName:@"mime-type"]stringValue];
        _fileName = [[file attributeForName:@"name"]stringValue];
        _fileSize = (UInt32)[[[file attributeForName:@"size"]stringValue]longLongValue];
        _hashCode = [[file attributeForName:@"hash"]stringValue];
        _isOutGoing = NO;
    }
    return self;
}
@end


#pragma mark -
#pragma mark xmppSocksConnect
//////////////////////////////////////xep-065 socks5协商//////////////////////////////////////////////

@interface xmppSocksConnect()
{
    BOOL _isSendingFile;
    NSString *_sid;
    NSString *_discoUUID;
    NSString *_uuid;
    
    dispatch_queue_t delegateQueue;
    dispatch_queue_t fileTransQueue;
    void *fileTransQueueTag;
    
    dispatch_source_t turnTimer;
    dispatch_source_t discoTimer;
    
    NSDate *_startTime,*_finishTime;
    
    XMPPJID  *_proxyJID;
    NSString *_proxyHost;
    UInt16   _proxyPort;
    
    NSMutableArray *_streamHostArray;
    NSMutableArray *_proxyJIDsArray;
    NSArray *_proxyURLArray;
    
    NSInteger _streamHostIndex;
    NSInteger _proxyURLIndex;
    NSInteger _proxyJIDIndex;
}
@property (nonatomic, strong) XMPPStream *xmppStream;
@property (nonatomic, strong) XMPPJID *receiverJID;
@property (nonatomic, strong) XMPPJID *senderJID;
@end

@implementation xmppSocksConnect
static NSMutableDictionary *existingTurnSockets;
static NSMutableArray *proxyCandidates;
#pragma mark -
#pragma mark proxyCandidates

+ (void)initialize
{
    static BOOL initialized = NO;
    if (!initialized)
    {
        initialized = YES;
        existingTurnSockets = [[NSMutableDictionary alloc] init];
        proxyCandidates = [[NSMutableArray alloc] initWithObjects:@"jabber.org", nil];
    }
}

+ (NSArray*)proxyCandidates
{
    NSArray *result = nil;
    @synchronized(proxyCandidates)
    {
        result = [proxyCandidates copy];
    }
    return  result;
}

+ (void)setProxyCandidates:(NSArray*)candidates
{
    @synchronized(proxyCandidates)
    {
        [proxyCandidates removeAllObjects];
        [proxyCandidates addObjectsFromArray:candidates];
    }
}

+ (BOOL)isNewStartSocksRequest:(XMPPIQ*)inIQ
{
    NSString *uuid = [inIQ elementID];
    @synchronized(existingTurnSockets)
    {
        if ([existingTurnSockets objectForKey:uuid])
            return NO;
        else
            return YES;
    }
}
#pragma mark -
#pragma mark init

- (id)initWithStream:(XMPPStream *)xmppStream toJID:(XMPPJID *)jid
{
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _isSendingFile = YES;
        _receiverJID = jid;
        _sid = [_xmppStream generateUUID];
         _uuid = [xmppStream generateUUID];
        
        _proxyURLArray = [[self class]proxyCandidates];
        _streamHostArray = [[NSMutableArray alloc]initWithCapacity:_proxyURLArray.count];
        
        [self performPostInitSetup];
    }
    return self;
}

- (id)initWithStream:(XMPPStream *)xmppStream inIQRequest:(XMPPIQ *)inIQ
{
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _isSendingFile = NO;
        _senderJID = inIQ.from;
        _uuid = [[inIQ elementID] copy];
        
        [self performPostInitSetup];
    }
    return self;
}

- (void)performPostInitSetup
{
    NSString *queueName = NSStringFromClass([self class]);
    fileTransQueue = dispatch_queue_create([queueName UTF8String], NULL);
	fileTransQueueTag = &fileTransQueueTag;
	dispatch_queue_set_specific(fileTransQueue, fileTransQueueTag, fileTransQueueTag, NULL);
    @synchronized(existingTurnSockets)
	{
		[existingTurnSockets setObject:self forKey:_uuid];
	}
}

- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue
{
    dispatch_async(fileTransQueue, ^{ @autoreleasepool {
        
        _delegate = aDelegate;
		delegateQueue = aDelegateQueue;
		
#if !OS_OBJECT_USE_OBJC
		dispatch_retain(delegateQueue);
#endif
        [_xmppStream addDelegate:self delegateQueue:fileTransQueue];
        
        _startTime = [[NSDate alloc] init];
        
        // 超时定时器
        turnTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, fileTransQueue);
		dispatch_source_set_event_handler(turnTimer, ^{ @autoreleasepool {
            
            [self fail];
			
		}});
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (8000.00 * NSEC_PER_SEC));
		dispatch_source_set_timer(turnTimer, tt, DISPATCH_TIME_FOREVER, 0.1);
		dispatch_resume(turnTimer);
        
		
		if (_isSendingFile)
        {
            // 发送服务发现请求
			[self sendByteStreamsSupportQueryRequest:_receiverJID];
            
            // 等待目标方应答服务发现请求超时则失败
            [self setUpBSSupportQueryTimer];
        }
        else
        {
            // 目标方等待初始方服务发现请求失败
             [self setUpBSSupportQueryTimer];
        }
    }});
}


#pragma mark -
#pragma mark gcd 定时器

- (void)cancelTimer
{
    if (discoTimer)
    {
        dispatch_source_cancel(discoTimer);
    }
}

- (void)setUpDispatchTimer:(dispatch_source_t)timer timeout:(NSTimeInterval)timeout
{
    NSAssert(dispatch_get_specific(fileTransQueueTag), @"Invoked on incorrect queue");
    if (discoTimer == NULL)
    {
        discoTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, fileTransQueue);
        dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout*NSEC_PER_SEC));
        dispatch_source_set_timer(discoTimer, tt, DISPATCH_TIME_FOREVER, 0.1);
        dispatch_resume(discoTimer);
    }
    else
    {
        dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		dispatch_source_set_timer(discoTimer, tt, DISPATCH_TIME_FOREVER, 0.1);
    }
}

/**
 * @method 初始方发送服务发现请求给目标方,目标方应答服务发现请求超时（8s未收到回复则超时）
 * @return
 */
- (void)setUpBSSupportQueryTimer
{
    DEBUG_METHOD(@"--%s--",__FUNCTION__);
    [self setUpDispatchTimer:discoTimer timeout:8.0];
    
    dispatch_source_set_event_handler(discoTimer, ^{@autoreleasepool{
        
		[self fail];
        
	}});
}

- (BOOL)queryNextProxyURL
{
    XMPPJID *proxyUrlJID = nil;
    if (_streamHostArray.count < 2)
    {
        while (proxyUrlJID == nil &&  ++ _proxyURLIndex < _proxyURLArray.count)
        {
            NSString *candidateUrl = [_proxyURLArray objectAtIndex:_proxyURLIndex];
            proxyUrlJID = [XMPPJID jidWithString:candidateUrl];
        }
    }
    
    if (proxyUrlJID)
    {
        // 等待服务器响应超时
        [self setUpDispatchTimer:discoTimer timeout:8.0];
        dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
            
                [self queryNextProxyURL];
        }});
        return [self sendfetchProxyServerRequest:proxyUrlJID];
    }
    else
    {
        if (_streamHostArray.count > 0)
        {
            return [self sendNetWorkAddress];
        }
        else
        {
            // 没有设置代理服务器
            [self fail];
            return NO;
        }
    }
}

- (BOOL)queryProxyJID:(NSArray*)itemsArray
{
    _proxyJIDsArray = [[NSMutableArray alloc]initWithCapacity:itemsArray.count];
    for (NSXMLElement *item in itemsArray)
    {
        NSString *jid = [[item attributeForName:@"jid"]stringValue];
        XMPPJID *xmppJID = [XMPPJID jidWithString:jid];
        if (xmppJID)
        {
            [_proxyJIDsArray addObject:xmppJID];
        }
    }//for
    
    // 优先使用proxy前缀代理
    for (int j = 0; j < _proxyJIDsArray.count; j++)
    {
        XMPPJID *candidateJID = [_proxyJIDsArray objectAtIndex:j];
        NSRange proxyRange = [[candidateJID domain] rangeOfString:@"proxy"
                                                          options:NSCaseInsensitiveSearch];
        if (proxyRange.length > 0)
        {
            [_proxyJIDsArray removeObjectAtIndex:j];
            [_proxyJIDsArray insertObject:candidateJID atIndex:0];
        }
    }//for
    
    _proxyJIDIndex = -1;
    return [self queryNextProxyJID];
    
}

- (BOOL)queryNextProxyJID
{
    _proxyJIDIndex++;
    if (_proxyJIDIndex < _proxyJIDsArray.count)
    {
        XMPPJID *proxyJID = [_proxyJIDsArray objectAtIndex:_proxyJIDIndex];
        [self setUpDispatchTimer:discoTimer timeout:8.0];
        dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
            
            [self queryNextProxyURL];
        }});
        
        return [self sendServiceDiscoRequest:proxyJID];
    }
    else
    {
        return [self queryNextProxyURL];
    }
}

- (BOOL)connectNextStreamHost
{
    _streamHostIndex ++;
    if(_streamHostIndex < [_streamHostArray count])
	{
		NSXMLElement *streamhost = [_streamHostArray objectAtIndex:_streamHostIndex];
		_proxyJID = [XMPPJID jidWithString:[[streamhost attributeForName:@"jid"] stringValue]];
		_proxyHost = [[streamhost attributeForName:@"host"] stringValue];
		if([_proxyHost isEqualToString:@"0.0.0.0"])
		{
			_proxyHost = [_proxyJID full];
		}
		_proxyPort = [[[streamhost attributeForName:@"port"] stringValue] intValue];
		
		if (_asyncSocket == nil)
		{
			_asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:fileTransQueue];
		}
		else
		{
			NSAssert([_asyncSocket isDisconnected], @"Expecting the socket to be disconnected at this point...");
		}
		
		NSError *err = nil;
		if (![_asyncSocket connectToHost:_proxyHost onPort:_proxyPort withTimeout:8.0 error:&err])
		{
			return [self connectNextStreamHost];
		}
        else
        {
            return YES;
        }
	}
	else
	{
		[self sendInitiateSocket5Error:_senderJID];
		[self fail];
        return NO;
	}
}

#pragma mark -
#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)inIQ
{
    DEBUG_METHOD(@"--%s---%@",__FUNCTION__,inIQ.description);
    NSString *type = inIQ.type;
    if ([type isEqualToString:@"error"])
    {
        [self fail];
        return NO;
    }
    
    if ([type isEqualToString:@"get"])
    {
        NSXMLElement *query = [inIQ elementForName:@"query"];
        if (query && [query.xmlns isEqualToString:@"http://jabber.org/protocol/disco#info"])
        {
            NSLog(@"--目标方应答服务发现请求---");
            [self cancelTimer];
            return [self sendByteStreamsSupportReponse:inIQ];
        }
    }
    
    if ([type isEqualToString:@"set"])
    {
        NSXMLElement *query = [inIQ elementForName:@"query"];
        if (query && [query.xmlns isEqualToString:@"http://jabber.org/protocol/bytestreams"])
        {
            if ([@"initiate" isEqualToString:inIQ.elementID])
            {
                _sid = [[query attributeForName:@"sid"]stringValue];
                _streamHostArray = [[query elementsForName:@"streamhost"]mutableCopy];
                _streamHostIndex = -1;
                return [self connectNextStreamHost];
            }
        }
    }
    if ([type isEqualToString:@"result"])
    {
        if ([inIQ.elementID isEqualToString:@"activate"])
        {
            [self succeed];
            return NO;
        }
        NSXMLElement *query = [inIQ elementForName:@"query"];
        if (query && [query.xmlns isEqualToString:@"http://jabber.org/protocol/disco#info"])
        {
            if ([_discoUUID isEqualToString:inIQ.elementID])
            {
                [self cancelTimer];
                DEBUG_METHOD(@"初始方收到目标方应答服务发现请求");
                _proxyURLIndex = -1;
                return [self queryNextProxyURL];
            }
            
            if ([inIQ.elementID isEqualToString:@"proxy_info"])
            {
                DEBUG_METHOD(@"初服务器响应服务发现请求--返回是否能够代理");
                [self cancelTimer];
                
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
                }//for
                
                XMPPJID *proxyJID = [_proxyJIDsArray objectAtIndex:_proxyJIDIndex];
                if (found)
                {
                    DEBUG_METHOD(@"---查询网络地址---");
                    [self setUpDispatchTimer:discoTimer timeout:8.0];
                    dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
                        [self queryNextProxyURL];
                    }});

                    return [self sendQueryNetworkAddressRequest:proxyJID];
                }
                else
                {
                    if ([proxyJID.domain hasPrefix:@"proxy"])
                    {
                        DEBUG_METHOD(@"查询下一个代理url");
                        return [self queryNextProxyURL];
                    }
                    else
                    {
                        DEBUG_METHOD(@"查询下一个代理JID");
                        return [self queryNextProxyJID];
                    }
                }
            }//if
        }
        
        if (query && [query.xmlns isEqualToString:@"http://jabber.org/protocol/disco#items"])
        {
            if ([inIQ.elementID isEqualToString:@"server_items"])
            {
                DEBUG_STR(@"--服务器应答返回代理item--");
                [self cancelTimer];
                NSArray *itemsArray = (NSArray*)[query elementsForName:@"item"];
                return [self queryProxyJID:itemsArray];
            }//if<ele--ID>
        }
        
        if (query && [query.xmlns isEqualToString:@"http://jabber.org/protocol/bytestreams"])
        {
            if ([inIQ.elementID isEqualToString:@"discover"])
            {
                [self cancelTimer];
                DEBUG_STR(@"--服务器应答返回网络地址--");
                NSXMLElement *streamhost = [query elementForName:@"streamhost"];
                NSString *jid = [[streamhost attributeForName:@"jid"]stringValue];
                NSString *host = [[streamhost attributeForName:@"host"] stringValue];
                UInt16 port = [[[streamhost attributeForName:@"port"] stringValue] intValue];
                XMPPJID *streamhostJID = [XMPPJID jidWithString:jid];
                if(streamhostJID != nil || host != nil || port > 0)
                {
                    [streamhost detach];
                    [_streamHostArray addObject:streamhost];
                }
                return [self queryNextProxyURL];
            }
            
            if ([inIQ.elementID isEqualToString:@"initiate"])
            {
                DEBUG_STR(@"--目标方确认连接--");
                NSXMLElement *streamHostUsed = [query elementForName:@"streamhost-used"];
                NSString *jid = [[streamHostUsed attributeForName:@"jid"]stringValue];
                BOOL found = NO;
                for(NSInteger i = 0; i < [_streamHostArray count] && !found; i++)
                {
                    NSXMLElement *streamhost = [_streamHostArray objectAtIndex:i];
                    NSString *streamhostJID = [[streamhost attributeForName:@"jid"] stringValue];
                    if([streamhostJID isEqualToString:jid])
                    {
                        NSAssert(_proxyJID == nil && _proxyHost == nil, @"proxy and proxyHost are expected to be nil");
                        _proxyJID = [XMPPJID jidWithString:streamhostJID];
                        
                        _proxyHost = [[streamhost attributeForName:@"host"] stringValue];
                        if([_proxyHost isEqualToString:@"0.0.0.0"])
                        {
                            _proxyHost = [_proxyJID full];
                        }
                        _proxyPort = [[[streamhost attributeForName:@"port"] stringValue] intValue];
                        found = YES;
                    }
                    
                    if (found)
                    {
                        _asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:fileTransQueue];
                        NSError *err = nil;
                        if (![_asyncSocket connectToHost:_proxyHost onPort:_proxyPort withTimeout:8.00 error:&err])
                        {
                            DEBUG_STR(@"--初始方建立socket连接失败--");
                            [self fail];
                            return NO;
                        }
                        else
                        {
                            DEBUG_STR(@"--初始方建立socket连接--");
                        }
                    }
                    else
                    {
                        [self fail];
                        return NO;
                    }
                }
            }// if <initiate>
        }
    }
    return YES;
}


#pragma mark -
#pragma mark XEP-065协商
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
    _discoUUID = [_xmppStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" elementID:_discoUUID];
    [iq addAttributeWithName:@"to" stringValue:toJId.full];
    
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
 <identity category='proxy'
 type='bytestreams'
 name='SOCKS5 Bytestreams Service'/>
 ...
 <feature var='http://jabber.org/protocol/bytestreams'/>
 ...
 </query>
 </iq>
 */
- (BOOL)sendByteStreamsSupportReponse:(XMPPIQ*)inIQ
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
- (BOOL)sendfetchProxyServerRequest:(XMPPJID*)proxyUrlJID
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:proxyUrlJID elementID:@"server_items"];
    
    NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                  xmlns:@"http://jabber.org/protocol/disco#items"];
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
    
    NSXMLElement *query = [NSXMLElement elementWithName:@"query"
                                                  xmlns:@"http://jabber.org/protocol/disco#info"];
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
 <streamhost jid='streamhostproxy.example.net'
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
    <streamhost jid='initiator@example.com/foo'
                host='192.168.4.1'
                port='5086'/>
    <streamhost jid='streamhostproxy.example.net'
                host='24.24.24.1'
                zeroconf='_jabber.bytestreams'/>
    </query>
 </iq>
 */
- (BOOL)sendNetWorkAddress
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:_receiverJID elementID:@"initiate"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
    [query addAttributeWithName:@"sid" stringValue:_sid];
    [query addAttributeWithName:@"mode" stringValue:@"tcp"];
    [iq addChild:query];
    
    for(int i = 0; i < [_streamHostArray count]; i++)
	{
		[query addChild:[_streamHostArray objectAtIndex:i]];
	}
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
    
    [_xmppStream sendElement:iq];
    return YES;
}

#pragma mark -
#pragma mark GCDAsyncSocket

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    DEBUG_METHOD(@"--%s--",__FUNCTION__);
    [sock performBlock:^{
        [sock enableBackgroundingOnSocket];
    }];
    [self socksOpen];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    DEBUG_METHOD(@"--%s--",__FUNCTION__);
    
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    DEBUG_METHOD(@"----%s---%ld:%@",__FUNCTION__,tag,data);
    if (tag == 101)
	{
		// See socksOpen method for socks reply format
		UInt8 ver = [NSNumber xmpp_extractUInt8FromData:data atOffset:0];
		UInt8 mtd = [NSNumber xmpp_extractUInt8FromData:data atOffset:1];
		
		if(ver == 5 && mtd == 0)
		{
            // 收到 | 05 00 | 可以代理，进一步建立连接
			[self socksConnect];
		}
		else
		{
			[_asyncSocket disconnect];
		}
	}
    else if (tag == 103)
	{
		UInt8 ver = [NSNumber xmpp_extractUInt8FromData:data atOffset:0];
		UInt8 rep = [NSNumber xmpp_extractUInt8FromData:data atOffset:1];
		
		if(ver == 5 && rep == 0)
		{
            // 收到服务器 5 0 0 3
			// However, some servers don't follow the protocol, and send a atyp value of 0.
			
			UInt8 atyp = [NSNumber xmpp_extractUInt8FromData:data atOffset:3];
			if (atyp == 3)
			{
				UInt8 addrLength = [NSNumber xmpp_extractUInt8FromData:data atOffset:4];
				UInt8 portLength = 2;
				[_asyncSocket readDataToLength:(addrLength+portLength) withTimeout:5.00 tag:104];
			}
			else if (atyp == 0)
			{
				[_asyncSocket readDataToLength:1 withTimeout:5.00 tag:104];
			}
			else
			{
				[_asyncSocket disconnect];
			}
		}
		else
		{
			[_asyncSocket disconnect];
		}
    }
    else if (tag == 104)
	{
		if (_isSendingFile)
		{
            DEBUG_METHOD(@"-----发送流激活信息---");
            [self sendActivateRequest:_receiverJID];
		}
		else
		{
            DEBUG_METHOD(@"-----成功连接流主机---");
            [self sendinitiateSocket5Finished:_senderJID hostJID:_proxyJID];
            [self succeed];
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
	
	[_asyncSocket writeData:data withTimeout:-1 tag:101];
    
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
	
	[_asyncSocket readDataToLength:2 withTimeout:5.00 tag:101];
}

- (void)socksConnect
{
	XMPPJID *myJID = [_xmppStream myJID];
	
	// From XEP-0065:
	//
	// The [address] MUST be SHA1(SID + Initiator JID + Target JID) and
	// the output is hexadecimal encoded (not binary).
	
	XMPPJID *initiatorJID = _isSendingFile ? myJID : _senderJID;
	XMPPJID *targetJID    = _isSendingFile ? _receiverJID  : myJID;
	
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
	[_asyncSocket writeData:data withTimeout:-1 tag:102];
	
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
	
	[_asyncSocket readDataToLength:5 withTimeout:5.0 tag:103];
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Finish and Cleanup

- (void)succeed
{
	NSAssert(dispatch_get_specific(fileTransQueueTag), @"Invoked on incorrect queue");
    
	_finishTime = [[NSDate alloc] init];
	
	dispatch_async(delegateQueue, ^{ @autoreleasepool {
		
        if (_delegate && [_delegate respondsToSelector:@selector(xmppSocks:didSucceed:)])
        {
            [_delegate xmppSocks:self didSucceed:_asyncSocket];
        }
    }});
	
	[self cleanup];
}

- (void)fail
{
    NSAssert(dispatch_get_specific(fileTransQueueTag), @"Invoked on incorrect queue");
    
	// Record finish time
	_finishTime = [[NSDate alloc] init];
	
		dispatch_async(delegateQueue, ^{ @autoreleasepool {
		
        if (_delegate && [_delegate respondsToSelector:@selector(xmppSocksDidFail:)])
        {
            [_delegate xmppSocksDidFail:self];
        }
    }});
	[self cleanup];
}

- (void)abort
{
	dispatch_block_t block = ^{ @autoreleasepool {
        [self cleanup];
	}};
	
	if (dispatch_get_specific(fileTransQueueTag))
    {
        block();
    }
	else
    {
		dispatch_async(fileTransQueue, block);
    }
}

- (void)releaseDispatchSource:(dispatch_source_t)source flag:(BOOL)flag
{
    if (source)
	{
		dispatch_source_cancel(source);
#if !OS_OBJECT_USE_OBJC
		dispatch_release(source);
#endif
        if (flag)
        {
            source = NULL;
        }
	}
}

- (void)cleanup
{
	NSAssert(dispatch_get_specific(fileTransQueueTag), @"Invoked on incorrect queue.");
	
    if (turnTimer)
    {
        dispatch_source_cancel(turnTimer);
#if !OS_OBJECT_USE_OBJC
		dispatch_release(turnTimer);
#endif
            turnTimer = NULL;
	}
    if (discoTimer)
    {
        dispatch_source_cancel(discoTimer);
#if !OS_OBJECT_USE_OBJC
		dispatch_release(discoTimer);
#endif
        discoTimer = NULL;
	}
    
	[_xmppStream removeDelegate:self delegateQueue:fileTransQueue];
    
    @synchronized(existingTurnSockets)
	{
		[existingTurnSockets removeObjectForKey:_uuid];
	}
}


- (void)dealloc
{
	if (turnTimer)
    {
        dispatch_source_cancel(turnTimer);
#if !OS_OBJECT_USE_OBJC
		dispatch_release(turnTimer);
#endif
        turnTimer = NULL;
	}
    
    if (discoTimer)
    {
        dispatch_source_cancel(discoTimer);
#if !OS_OBJECT_USE_OBJC
		dispatch_release(discoTimer);
#endif
        discoTimer = NULL;
	}
    
	
#if !OS_OBJECT_USE_OBJC
	if (fileTransQueue)
		dispatch_release(fileTransQueue);
	
	if (delegateQueue)
		dispatch_release(delegateQueue);
#endif
	
	if ([_asyncSocket delegate] == self)
	{
		[_asyncSocket setDelegate:nil delegateQueue:NULL];
		[_asyncSocket disconnect];
	}
}

@end


#pragma mark -
#pragma mark XMPPFileTransfer
//////////////////////////////////////xep-096 文件传输//////////////////////////////////////////////
@interface XMPPFileTransfer() <xmppSKConnectDelegate,GCDAsyncSocketDelegate>
{
    dispatch_queue_t delegateQueue;
    dispatch_queue_t fileTransQueue;
    void *fileTransQueueTag;
    BOOL _isSendingFile;
    
    NSMutableArray *_fileSKConnectArray;
    NSFileHandle *_writehandle;
    NSFileHandle *_readhandle;
    NSUInteger _receiveLen;
    
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
    
    int receivelen;
}
@property (nonatomic, strong) XMPPJID *senderJID;
@property (nonatomic, strong) XMPPJID *receiverJID;
@property (nonatomic, strong) XMPPStream *xmppStream;
@end
@implementation XMPPFileTransfer

- (id)init
{
    self = [super init];
    if (self)
    {
        _fileSKConnectArray = [[NSMutableArray alloc]init];
    }
    return self;
}

- (id)initWithStream:(XMPPStream *)xmppStream toJID:(XMPPJID *)jid
{
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _isSendingFile = YES;
        _receiverJID = jid;
        [self performPostInitSetup];
    }
    return self;
}

- (id)initWithStream:(XMPPStream *)xmppStream inIQRequest:(XMPPIQ *)inIQ
{
    NSLog(@"-----%@---",inIQ.description);
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _isSendingFile = NO;
        _receiveIQ = inIQ;
        _senderJID = inIQ.from;
        _fileModel = [[XmppFileModel alloc]initWithReceiveIQ:inIQ];
         [self performPostInitSetup];
    }
    return self;
}

- (void)performPostInitSetup
{
    NSString *queueName = NSStringFromClass([self class]);
    fileTransQueue = dispatch_queue_create([queueName UTF8String], NULL);
	fileTransQueueTag = &fileTransQueueTag;
	dispatch_queue_set_specific(fileTransQueue, fileTransQueueTag, fileTransQueueTag, NULL);
}

- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue
{
    dispatch_async(fileTransQueue, ^{
        
        _delegate = aDelegate;
        delegateQueue = aDelegateQueue;
        
#if !OS_OBJECT_USE_OBJC
		dispatch_retain(delegateQueue);
#endif
        [_xmppStream addDelegate:self delegateQueue:fileTransQueue];
        
        if (_isSendingFile)
        {
            [self willSendFile];
        }
        else
        {
            [self willReceiveFile];
        }
    });
    
}

#pragma mark -
#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)inIq
{
    DEBUG_METHOD(@"--%s--%@",__FUNCTION__,inIq.description);
    NSString *type = inIq.type;
    if ([type isEqualToString:@"error"])
    {
        [self didFailSendFile];
    }
    
    if ([type isEqualToString:@"result"])
    {
        NSXMLElement *si = [inIq elementForName:@"si"];
        if (si && [si.xmlns isEqualToString:@"http://jabber.org/protocol/si"])
        {
            NSXMLElement *feature = [si elementForName:@"feature"];
            if (feature && [feature.xmlns isEqualToString:@"http://jabber.org/protocol/feature-neg"])
            {
                DEBUG_METHOD(@"--初始方开始发送文件--");
                // 初始方开始发送文件
                [self didSendFile];
                
                // 进入xep-065协商
                [xmppSocksConnect initialize];
                [xmppSocksConnect setProxyCandidates:[NSArray arrayWithObjects:@"www.savvy-tech.net", nil]];
                xmppSocksConnect *socketConnect = [[xmppSocksConnect alloc]initWithStream:_xmppStream toJID:inIq.from];
                [socketConnect startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
                [_fileSKConnectArray addObject:socketConnect];
            }
        }
    }
    return NO;
}

#pragma mark -
#pragma mark delegate

// 将会发送文件
- (void)willSendFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:willSendFile:)])
            {
                [_delegate xmppFileTrans:self willSendFile:_fileModel];
            }
        }
    });
}

// 开始发送文件
- (void)didSendFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_isSendingFile)
            {
                if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didSendFile:)])
                {
                    [_delegate xmppFileTrans:self didSendFile:_fileModel];
                }
            }
            
        }});
}

// 成功发送文件
- (void)didSuccessSendFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_isSendingFile)
            {
                if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didSuccessSendFile:)])
                {
                    [_delegate xmppFileTrans:self didSuccessSendFile:_fileModel];
                }
            }
        }});
     [self cleanUp];
}

// 发送文件失败
- (void)didFailSendFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_isSendingFile)
            {
                if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didFailSendFile:)])
                {
                    [_delegate xmppFileTrans:self didFailSendFile:_fileModel];
                }
            }
        }});
     [self cleanUp];
}

//将会接收文件
- (void)willReceiveFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:willReceiveFile:)])
            {
                [_delegate xmppFileTrans:self willReceiveFile:_fileModel];
            }
        }
    });
}

// 开始接收文件
- (void)didReceiveFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_isSendingFile)
            {
                if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didReceiveFile:)])
                {
                    [_delegate xmppFileTrans:self didReceiveFile:_fileModel];
                }
            }
        }});
}

// 成功接收文件
- (void)didSuccessReceiveFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_isSendingFile)
            {
                if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didSuccessReceiveFile:)])
                {
                    [_delegate xmppFileTrans:self didSuccessReceiveFile:_fileModel];
                }
            }
        }});
    [self cleanUp];
}

// 接收文件失败
- (void)didFailRecFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_isSendingFile)
            {
                if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didFailRecFile:)])
                {
                    [_delegate xmppFileTrans:self didFailRecFile:_fileModel];
                }
            }
        }});
     [self cleanUp];
}

- (void)cleanUp
{
    [_xmppStream removeDelegate:self delegateQueue:fileTransQueue];
    [self removeAllSocks];
}

- (void)removeAllSocks
{
    @synchronized(_fileSKConnectArray)
    {
        for (GCDAsyncSocket *socket in _fileSKConnectArray)
        {
            [socket disconnect];
        }
        
        if ([_fileSKConnectArray count] > 0)
        {
            [_fileSKConnectArray removeAllObjects];
        }
    }
}

- (void)removeSocks:(GCDAsyncSocket*)socket
{
    @synchronized(_fileSKConnectArray)
    {
        if ([_fileSKConnectArray containsObject:socket])
        {
            [_fileSKConnectArray removeObject:socket];
        }
    }
}

#pragma mark -
#pragma mark filePath

- (NSString*)documentPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *docDir = [paths objectAtIndex:0];
    return docDir;
}

- (NSString*)fullPath:(NSString*)superPath fileName:(NSString*)filename
{
    if (superPath == nil || filename == nil)
    {
        DEBUG_STR(@"---父路径为空或者文件名为空--");
        return nil;
    }
    NSString *fullPath = [superPath stringByAppendingPathComponent:filename];
    return fullPath;
}

- (BOOL)writeFileToPath:(NSString*)fullPath
{
    if (fullPath == nil)
    {
        DEBUG_STR(@"---文件路径为空--");
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:fullPath])
    {
        NSError *error = nil;
        if (![fileManager removeItemAtPath:fullPath error:&error])
        {
            DEBUG_METHOD(@"--重复文件删除错误---%@",error);
            return NO;
        }
    }
    if (![fileManager createFileAtPath:fullPath contents:nil attributes:nil])
    {
        DEBUG_METHOD(@"---创建文件失败---");
        return NO;
    }
    return YES;
}

#pragma mark -
#pragma mark xmppSKConnectDelegate

- (void)xmppSocks:(xmppSocksConnect *)sender didSucceed:(GCDAsyncSocket *)socket
{
    DEBUG_METHOD(@"--%s--",__FUNCTION__);
    [socket setDelegate:self delegateQueue:fileTransQueue];
    
    if (_isSendingFile)
    {
        _inputStream = [[NSInputStream alloc]initWithFileAtPath:_fileModel.filePath];
        [_inputStream open];
        uint8_t buffer[KMaxBufferLen];
        int len =  [_inputStream read:buffer maxLength:KMaxReadBytesLen];
        if (len == -1)
        {
            DEBUG_STR(@"----数据读取错误-----");
            [_inputStream close];
            [socket disconnect];
            [self didFailSendFile];
        }
        else
        {
            DEBUG_METHOD(@"---开始写数据--[totalLen:%ld--writeLen:%d]",_fileModel.fileSize,len);
            NSData *data = [NSData dataWithBytes:buffer length:len];
            [socket writeData:data withTimeout:-1 tag:1];
        }
    }
    else
    {
        NSString *fullPath = [self fullPath:[self documentPath] fileName:_fileModel.fileName];
        if (fullPath == nil || ![self writeFileToPath:fullPath])
        {
            DEBUG_STR(@"----创建文件失败--无法写文件---");
            [socket disconnect];
            [self didFailRecFile];
        }
        else
        {
            DEBUG_STR(@"----开始读数据-----%ld",_fileModel.fileSize);
            _outputStream = [[NSOutputStream alloc]initToFileAtPath:fullPath append:YES];
            [_outputStream open];
            _receiveLen = 0;
            [socket readDataWithTimeout:-1 tag:2];
        }
    }
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == 2)
    {
        int writelen =  [_outputStream write:[data bytes] maxLength:data.length];
        if (writelen == -1)
        {
            DEBUG_STR(@"---接收数据写入出错---");
            [_outputStream close];
            [sock disconnect];
            [self didFailRecFile];
        }
        else
        {
            [sock readDataWithTimeout:-1 tag:2];
            _receiveLen += writelen;
            
            NSLog(@"--%d-%d",_receiveLen,data.length);
            
            if (_receiveLen == _fileModel.fileSize)
            {
                NSLog(@"---接收数据完成---");
                [_outputStream close];
                [sock disconnect];
                [self didSuccessReceiveFile];
            }
        }//else
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    if (tag == 1)
    {
        uint8_t buffer[4096];
        
        int len =  [_inputStream read:buffer maxLength:1024];
        if (len == -1)
        {
            DEBUG_STR(@"---写数据出错---");
            [_inputStream close];
            [sock disconnect];
            [self didFailSendFile];
        }
        else  if (len == 0)
        {
            DEBUG_STR(@"---写数据完成---");
            [_inputStream close];
            [sock disconnect];
            [self didSuccessSendFile];
        }
        else
        {
            DEBUG_STR(@"---写数据---%d",len);
            NSData *data = [NSData dataWithBytes:buffer length:len];
            [sock writeData:data withTimeout:-1 tag:1];
        }
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    
}

- (void)xmppSocksDidFail:(xmppSocksConnect *)sender
{
    DEBUG_METHOD(@"--%s--",__FUNCTION__);
    [self cleanUp];
    
    if (_isSendingFile)
    {
        [self didFailSendFile];
    }
    else
    {
        [self didReceiveFile];
    }
}

#pragma mark -
#pragma mark XEP-096

// 发送协商请求<请求发送文件>
/*
 <iq type='set' id='offer1' to='receiver@jabber.org/resource'>
     <si xmlns='http://jabber.org/protocol/si'
         id='a0'
         mime-type='text/plain'
         profile='http://jabber.org/protocol/si/profile/file-transfer'>
     <file xmlns='http://jabber.org/protocol/si/profile/file-transfer'
           name='test.txt'
           size='1022'/>
         <feature xmlns='http://jabber.org/protocol/feature-neg'>
             <x xmlns='jabber:x:data' type='form'>
                 <field var='stream-method' type='list-single'>
                     <option><value>http://jabber.org/protocol/bytestreams</value></option>
                     <option><value>http://jabber.org/protocol/ibb</value></option>
                 </field>
             </x>
         </feature>
     </si>
 </iq>
 */
/**
 * @method
 * @brief 发送请求传输文件，请求携带文件信息
 * @param  toJID 目标方JID
 * @param  fileName 待发送的文件名称{ eg. image.png }
 * @param  fileSize 待发送的文件大小
 * @param  fileDesc 待发送的文件描述
 * @param  mimetype MIME类型<具体可见常用MIME文件类型定义>
 * @param  hashValue 待发送文件的hash,用于校验文件的完整性
 * @param  fileDate 文件的最后修改日期。日期格式使用XMPP Date and Time Profiles指定的格式
 * @see
 * @warning toJID 必须是一个完整的fullJID，否则文件传输失败{myz00@www.savvy-tech.net/Server}
 * @exception
 * @discussion
 * @return
 */
- (void)sendFileTransferRequest:(XMPPJID*)toJID
                       fileName:(NSString*)fileName
                       fileSize:(NSString*)fileSize
                       fileDesc:(NSString*)fileDesc
                       mimeType:(NSString*)mimeType
                           hash:(NSString*)hashCode
                           date:(NSString*)fileDate
{
    NSString *uuid = [_xmppStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:uuid];
    [iq addAttributeWithName:@"to" stringValue:toJID.full];
    
    NSXMLElement *si = [NSXMLElement elementWithName:@"si" xmlns:@"http://jabber.org/protocol/si"];
    [si addAttributeWithName:@"id" stringValue:[_xmppStream generateUUID]];
    [si addAttributeWithName:@"mime-type" stringValue:mimeType];
    [si addAttributeWithName:@"profile" stringValue:@"http://jabber.org/protocol/si/profile/file-transfer"];
    [iq addChild:si];
    
    NSXMLElement *file = [NSXMLElement elementWithName:@"file" xmlns:@"http://jabber.org/protocol/si/profile/file-transfer"];
    [file addAttributeWithName:@"name" stringValue:fileName];
    [file addAttributeWithName:@"size" stringValue:fileSize];
    [file addAttributeWithName:@"hash" stringValue:hashCode];
    [file addAttributeWithName:@"date" stringValue:fileDate];
    [si addChild:file];
    
    // 添加文件描述
    NSXMLElement *desc = [NSXMLElement elementWithName:@"desc" stringValue:fileDesc];
    [file addChild:desc];
    
    NSXMLElement *feature = [NSXMLElement elementWithName:@"feature" xmlns:@"http://jabber.org/protocol/feature-neg"];
    [si addChild:feature];
    
    NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
    [x addAttributeWithName:@"type" stringValue:@"form"];
    [feature addChild:x];
    
    NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
    [field addAttributeWithName:@"var" stringValue:@"stream-method"];
    [field addAttributeWithName:@"type" stringValue:@"list-single"];
    [x addChild:field];
    
    NSXMLElement *option = [NSXMLElement elementWithName:@"option"];
    [field addChild:option];
    
    NSXMLElement *value = [NSXMLElement elementWithName:@"value" stringValue:@"http://jabber.org/protocol/bytestreams"];
    [option addChild:value];
    
    NSXMLElement *option2 = [NSXMLElement elementWithName:@"option"];
    [field addChild:option2];
    
    NSXMLElement *value2 = [NSXMLElement elementWithName:@"value" stringValue:@"http://jabber.org/protocol/ibb"];
    [option2 addChild:value2];
    
    [_xmppStream sendElement:iq];
}

// 发送代理响应<接受文件传输>
/*
 <iq type='result' to='sender@jabber.org/resource' id='offer1'>
     <si xmlns='http://jabber.org/protocol/si'>
        <feature xmlns='http://jabber.org/protocol/feature-neg'>
            <x xmlns='jabber:x:data' type='submit'>
                <field var='stream-method'>
                    <value>http://jabber.org/protocol/bytestreams</value>
                </field>
            </x>
        </feature>
    </si>
 </iq>
 */
/**
 * @method 目标方接收文件传输
 * @param  inIQ 目标方式收到的IQ请求
 * @return
 */
- (void)sendReceiveFiletransferResponse:(XMPPIQ*)inIQ
{
    DEBUG_METHOD(@"---%s---",__FUNCTION__);
    
    NSString *iqId = [inIQ attributeStringValueForName:@"id"];
    
    NSXMLElement *iq = [XMPPIQ iqWithType:@"result" elementID:iqId];
    [iq addAttributeWithName:@"to" stringValue:inIQ.fromStr];
    
    NSXMLElement *si = [NSXMLElement elementWithName:@"si" xmlns:@"http://jabber.org/protocol/si"];
    [iq addChild:si];
    
    NSXMLElement *file = [NSXMLElement elementWithName:@"file" xmlns:@"http://jabber.org/protocol/si/profile/file-transfer"];
    [si addChild:file];
    
    NSXMLElement *feature = [NSXMLElement elementWithName:@"feature" xmlns:@"http://jabber.org/protocol/feature-neg"];
    [si addChild:feature];
    
    NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
    [x addAttributeWithName:@"type" stringValue:@"submit"];
    [feature addChild:x];
    
    NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
    [field addAttributeWithName:@"var" stringValue:@"stream-method"];
    [x addChild:field];
    
    NSXMLElement *value = [NSXMLElement elementWithName:@"value" stringValue:@"http://jabber.org/protocol/bytestreams"];
    [field addChild:value];
    
    [_xmppStream sendElement:iq];
    
    // 目标方接收文件传输
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didReceiveFile:)])
            {
                [_delegate xmppFileTrans:self didReceiveFile:_fileModel];
            }
        }
    });
    
    // 进入xep-065协商阶段
    xmppSocksConnect *socksConnect = [[xmppSocksConnect alloc]initWithStream:_xmppStream inIQRequest:inIQ];
    [socksConnect startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    [_fileSKConnectArray addObject:socksConnect];
}

// 发送拒绝文件传输响应信息
/*
 <iq id='' to='' from='' type='error'>
    <error code='403' type='AUTH'>
        <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'>
    </error>
 </iq>
 */
/**
 * @method 目标方拒绝文件传输
 * @param  inIQ 目标方式收到的IQ请求
 * @return
 */
- (void)sendRejectFileTransferResponse:(XMPPIQ*)inIQ
{
    NSString *iqId = [inIQ attributeStringValueForName:@"id"];
    
    NSXMLElement *iq = [XMPPIQ iqWithType:@"error" elementID:iqId];
    [iq addAttributeWithName:@"to" stringValue:inIQ.fromStr];
    
    NSXMLElement *error = [NSXMLElement elementWithName:@"error"];
    [error addAttributeWithName:@"code" stringValue:@"403"];
    [error addAttributeWithName:@"type" stringValue:@"AUTH"];
    [iq addChild:error];
    
    NSXMLElement *forbidden = [NSXMLElement elementWithName:@"forbidden" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
    [error addChild:forbidden];
    
    [_xmppStream sendElement:iq];
    
    // 目标方拒绝文件传输
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didRejectFile:)])
            {
                [_delegate xmppFileTrans:self didRejectFile:_fileModel];
            }
        }
    });
}

@end


#pragma mark -
#pragma mark XMPPFileTransfer
//////////////////////////////////////xmpp 文件传输管理//////////////////////////////////////////////
@interface XMPPIMFileManager() <xmppFileDelegate>
@property (nonatomic, strong) NSMutableArray *fileQueueArray;
@end
@implementation XMPPIMFileManager
#pragma mark -
#pragma mark init

- (id)init
{
    return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
    self = [super initWithDispatchQueue:queue];
    if (self)
    {
        _fileQueueArray = [[NSMutableArray alloc]init];
    }
    return self;
}

#pragma mark -
#pragma mark active/deactive

- (BOOL)activate:(XMPPStream *)aXmppStream
{
    if ([super activate:aXmppStream])
    {
        return YES;
    }
    return NO;
}

- (void)deactivate
{
    [super deactivate];
}

- (BOOL)sendImageWithData:(NSData*)imageData toJID:(XMPPJID*)jid
{
    NSString *fileName = [NSString stringWithFormat:@"%@.png",xmppStream.generateUUID];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *docDir = [paths objectAtIndex:0];
    NSString *filePath = [docDir stringByAppendingPathComponent:fileName];
    
    NSFileManager *filemanager = [NSFileManager defaultManager];
    if (![filemanager fileExistsAtPath:filePath])
    {
        if (![filemanager createFileAtPath:filePath contents:imageData attributes:nil])
        {
            return NO;
        }
    }
    
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSUInteger fileSize = [handle availableData].length;
    [handle closeFile];
    
    XmppFileModel *fileModel = [[XmppFileModel alloc]init];
    fileModel.fileName = fileName;
    fileModel.fileSize = fileSize;
    fileModel.filePath = filePath;
    fileModel.mimetype = @"image/png";
    fileModel.timeStamp = [NSDate date];
    fileModel.JID = jid;
    fileModel.isOutGoing = YES;
    fileModel.fileType = XMPP_FILE_IMAGE;
    
    XMPPFileTransfer *fileTrans = [[XMPPFileTransfer alloc]initWithStream:xmppStream toJID:jid];
    [fileTrans setFileModel:fileModel];
    [fileTrans startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSString *fileSizeStr = [NSString stringWithFormat:@"%ld",(unsigned long)fileSize];
    [fileTrans sendFileTransferRequest:jid
                              fileName:fileName
                              fileSize:fileSizeStr
                              fileDesc:@"Sending"
                              mimeType:@"image/png"
                                  hash:@"552da749930852c69ae5d2141d3766b1"
                                  date:@"1969-07-21T02:56:15Z"];
    [_fileQueueArray addObject:fileTrans];
    return YES;
}

#pragma mark -
#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)inIq
{
    DEBUG_METHOD(@"----%s--",__FUNCTION__);
    NSString *type = inIq.type;
    if ([type isEqualToString:@"set"])
    {
        NSXMLElement *si = [inIq elementForName:@"si"];
        if (si && [si.xmlns isEqualToString:@"http://jabber.org/protocol/si"])
        {
            NSXMLElement *feature = [si elementForName:@"feature"];
            if ([feature.xmlns isEqualToString:@"http://jabber.org/protocol/feature-neg"])
            {
                DEBUG_STR(@"----目标方接收到文件传输请求----");
                XMPPFileTransfer *fileTransfer = [[XMPPFileTransfer alloc]initWithStream:xmppStream inIQRequest:inIq];
                [fileTransfer startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
                if (![_fileQueueArray containsObject:fileTransfer])
                {
                    [_fileQueueArray addObject:fileTransfer];
                }
            }
        }
    }
    return NO;
}

- (void)xmppFileTrans:(XMPPFileTransfer *)sender didFailRecFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    if ([_fileQueueArray containsObject:sender])
    {
        [_fileQueueArray removeObject:sender];
    }
}

- (void)xmppFileTrans:(XMPPFileTransfer *)sender didFailSendFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    if ([_fileQueueArray containsObject:sender])
    {
        [_fileQueueArray removeObject:sender];
    }
}

- (void)xmppFileTrans:(XMPPFileTransfer *)sender didReceiveFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
}

- (void)xmppFileTrans:(XMPPFileTransfer *)sender didRejectFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
}

- (void)xmppFileTrans:(XMPPFileTransfer *)sender didSendFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
}

- (void)xmppFileTrans:(XMPPFileTransfer *)sender didSuccessReceiveFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    if ([_fileQueueArray containsObject:sender])
    {
        [_fileQueueArray removeObject:sender];
    }
}

- (void)xmppFileTrans:(XMPPFileTransfer *)sender didSuccessSendFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    if ([_fileQueueArray containsObject:sender])
    {
        [_fileQueueArray removeObject:sender];
    }
}

- (void)xmppFileTrans:(XMPPFileTransfer *)sender didUpdateUI:(NSUInteger)progressValue
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
}
- (void)xmppFileTrans:(XMPPFileTransfer *)sender willReceiveFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    [sender sendReceiveFiletransferResponse:sender.receiveIQ];
}
- (void)xmppFileTrans:(XMPPFileTransfer *)sender willSendFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
}
@end
