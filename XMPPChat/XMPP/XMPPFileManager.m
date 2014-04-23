//
//  XMPPFileManager.m
//  XMPPChat
//
//  Created by 马远征 on 14-4-21.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "XMPPFileManager.h"
#import <NSXMLElement+XMPP.h>
#import <NSData+XMPP.h>
#import <NSNumber+XMPP.h>

#pragma mark -////////////////////////////xmppFileModel///////////////////////////////////

@implementation xmppFileModel
- (id)initWithXMPPIQ:(XMPPIQ*)inIQ
{
    self = [super init];
    if (self)
    {
        _senderJID = inIQ.from;
        _timeStamp = [NSDate date];
        
        NSXMLElement *si = [inIQ elementForName:@"si"];
        NSXMLElement *file = [si elementForName:@"file"];
        _uuid = [[inIQ attributeForName:@"id"]stringValue];
        _mimeType = [[si elementForName:@"mime-type"]stringValue];
        _fileName = [[file elementForName:@"name"]stringValue];
        _fileSize = [[[file elementForName:@"size"]stringValue]integerValue];
        _hashValue = [[file elementForName:@"hash"]stringValue];
        _outGoing = NO;
    }
    return self;
}

@end


#pragma mark -////////////////////////////XMPPFileManager///////////////////////////////////

@interface XMPPFileManager()
{
    
}
@property (nonatomic,strong) NSMutableArray *fileTransQueueArray;
@end

@implementation XMPPFileManager

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

- (xmppFileModel*)fetchFileModelByUUID:(NSString*)uuid
{
    if ( !_fileQueueArray || _fileQueueArray.count <= 0 || uuid == nil)
    {
        return nil;
    }
    
    for (xmppFileModel *model in _fileQueueArray)
    {
        if ([model.uuid isEqualToString:uuid])
        {
            return model;
        }
    }
    return nil;
}

#pragma mark -
#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)inIq
{
    NSString *type = inIq.type;
    if ([type isEqualToString:@"set"])
    {
        NSXMLElement *si = [inIq elementForName:@"si"];
        if (si && [si.xmlns isEqualToString:@"http://jabber.org/protocol/si"])
        {
            NSXMLElement *file = [si elementForName:@"file"];
            if ([file.xmlns isEqualToString:@"http://jabber.org/protocol/feature-neg"])
            {
                NSLog(@"---目标方收到%@文件传输请求--",inIq.from);
                
                xmppFileModel *fileModel = [[xmppFileModel alloc]initWithXMPPIQ:inIq];
                [_fileQueueArray addObject:fileModel];
                
                if (_delegate && [_delegate respondsToSelector:@selector(xmppFileMgr:willReceiveFile:)])
                {
                    [_delegate xmppFileMgr:self willReceiveFile:fileModel];
                }
                // 目标方进入xep-065协商
                return YES;
            }
        }// if <si>
    }
    
    if ([type isEqualToString:@"error"])
    {
        if (_delegate && [_delegate respondsToSelector:@selector(xmppFileMgr:didFailToSendFile:error:)])
        {
            NSString *iqID = [[inIq attributeForName:@"id"]stringValue];
            xmppFileModel *fileModel = [self fetchFileModelByUUID:iqID];
            NSXMLElement *error = [inIq elementForName:@"error"];
            [_delegate xmppFileMgr:self didFailToSendFile:fileModel error:error];
        }
        return NO;
    }
    
    if ([type isEqualToString:@"result"])
    {
        NSXMLElement *si = [inIq elementForName:@"si"];
        if (si && [si.xmlns isEqualToString:@"http://jabber.org/protocol/si"])
        {
            NSXMLElement *feature = [si elementForName:@"feature"];
            if (feature && [feature.xmlns isEqualToString:@"http://jabber.org/protocol/feature-neg"])
            {
                if (_delegate && [_delegate respondsToSelector:@selector(xmppFileMgr:didSendFile:)])
                {
                    NSString *iqID = [[inIq attributeForName:@"id"]stringValue];
                    xmppFileModel *fileModel = [self fetchFileModelByUUID:iqID];
                    [_delegate xmppFileMgr:self didSendFile:fileModel];
                }
                
                // 初始方进入xep-065协商
                return NO;
            }
        }//if <si>
    }
    return NO;
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
    NSString *uuid = [xmppStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:uuid];
    [iq addAttributeWithName:@"to" stringValue:toJID.full];
    
    NSXMLElement *si = [NSXMLElement elementWithName:@"si" xmlns:@"http://jabber.org/protocol/si"];
    [si addAttributeWithName:@"id" stringValue:[xmppStream generateUUID]];
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
    
    [xmppStream sendElement:iq];
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
    
    [xmppStream sendElement:iq];
    
    // 进入xep-065协商阶段
    xmppFileModel *fileModel = [self fetchFileModelByUUID:iqId];
    if (_delegate && [_delegate respondsToSelector:@selector(xmppFileMgr:didReceiveFile:)])
    {
        [_delegate xmppFileMgr:self didReceiveFile:fileModel];
    }
    
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
    
    [xmppStream sendElement:iq];
    
    // 删除数据库的当前文件记录
    if (_delegate && [_delegate respondsToSelector:@selector(xmppFileMgr:didRejectReceiveFile:)])
    {
        xmppFileModel *fileModel = [self fetchFileModelByUUID:iqId];
        [_delegate xmppFileMgr:self didRejectReceiveFile:fileModel];
    }
}
@end





#pragma mark -////////////////////////////xmpp文件传输，包含xep-065协议///////////////////////////////////

#define STATE_INIT                0

#define STATE_PROXY_DISCO_0096   8
#define STATE_PROXY_DISCO_EXTRA  9
#define STATE_PROXY_DISCO_ITEMS  10
#define STATE_PROXY_DISCO_INFO   11
#define STATE_PROXY_DISCO_ADDR   12
#define STATE_REQUEST_SENT       13
#define STATE_INITIATOR_CONNECT  14
#define STATE_ACTIVATE_SENT      15
#define STATE_TARGET_CONNECT     20
#define STATE_DONE               30
#define STATE_FAILURE            31

@interface XMPPFileTransfer()
{
    dispatch_queue_t delegateQueue;
    dispatch_queue_t fileTransQueue;
    
    // gcd定时器
    dispatch_source_t turnTimer;
	dispatch_source_t discoTimer;
    
    NSDate *_startTime, *_finishTime;
    
    void *fileTransQueueTag;
    
    NSString *_proxyJID;
    NSString *_proxyHost;
    NSString *_proxyPort;
    
    int state;
    
    // 存储目标方获取的IP和端口
    NSMutableArray *_streamHost;
    NSMutableArray *_candidateJIDsArray;
    NSArray *_proxyCandidates;
    
    NSInteger _proxyCandidatesIndex;
    NSInteger _candidateJIDIndex;
}
@property (nonatomic, strong) XMPPStream *xmppStream;
@property (nonatomic, strong) XMPPJID *receiverJID;
@property (nonatomic, strong) XMPPJID *senderJID;
@property (nonatomic, assign) BOOL isSendingFile;
@property (nonatomic, strong) NSString *sid;
@property (nonatomic, strong) NSString *discoUUID;
@end

@implementation XMPPFileTransfer

static NSMutableArray *proxyCandidates;

#pragma mark -
#pragma mark proxyCandidates

+ (void)initialize
{
    static BOOL initialized = NO;
    if (!initialized)
    {
        initialized = YES;
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


#pragma mark -
#pragma mark init

- (id)initWithStream:(XMPPStream *)xmppStream xmppFile:(xmppFileModel *)file toJID:(XMPPJID *)jid
{
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _fileModel = file;
        _isSendingFile = YES;
        _receiverJID = jid;
        _sid = [_xmppStream generateUUID];
        
        // 数组中的每一个代理proxy都将被查询是否能用作代理
        _proxyCandidates = [[self class]proxyCandidates];
        
        [self performPostInitSetup];
    }
    return self;
}

- (id)initWithStream:(XMPPStream *)xmppStream xmppFile:(xmppFileModel *)file iqRequest:(XMPPIQ *)inIQ
{
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _fileModel = file;
        _isSendingFile = NO;
        _senderJID = inIQ.from;
        
        [self performPostInitSetup];
    }
    return self;
}

- (void)performPostInitSetup
{
    fileTransQueue = dispatch_queue_create("TURNSocket", NULL);
	fileTransQueueTag = &fileTransQueueTag;
	dispatch_queue_set_specific(fileTransQueue, fileTransQueueTag, fileTransQueueTag, NULL);
}

- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue
{
    NSParameterAssert(aDelegate != nil);
    NSParameterAssert(aDelegateQueue != NULL);
    
    dispatch_async(fileTransQueue, ^{ @autoreleasepool {
        
        _delegate = aDelegate;
		delegateQueue = aDelegateQueue;
		
#if !OS_OBJECT_USE_OBJC
		dispatch_retain(delegateQueue);
#endif
        [_xmppStream addDelegate:self delegateQueue:fileTransQueue];
        
        _startTime = [[NSDate alloc] init];
        
        turnTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, fileTransQueue);
		
		dispatch_source_set_event_handler(turnTimer, ^{ @autoreleasepool {
			
//			[self doTotalTimeout];
			
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
            
        }

    }});
}

- (void)queryProxyCandidates
{
    _proxyCandidatesIndex = -1;
    _streamHost = [[NSMutableArray alloc]initWithCapacity:_proxyCandidates.count];
    [self queryNextProxyCandidates];
}

- (void)queryNextProxyCandidates
{
    XMPPJID *proxyCandidateJID = nil;
    // 至少发现2个streamHost端口和ip才进行交互初始化
    if (_streamHost.count < 2)
    {
        while ((proxyCandidateJID == nil) && (++_proxyCandidatesIndex < _proxyCandidates.count))
        {
            NSString *proxyCandidate = [_proxyCandidates objectAtIndex:_proxyCandidatesIndex];
            proxyCandidateJID = [XMPPJID jidWithString:proxyCandidate];
            if (proxyCandidateJID == nil)
            {
                DEBUG_STR(@"-----空的代理JID---");
            }
        }
    }
    
    if (proxyCandidateJID)
    {
        // 发送服务发现请求
    }
    else
    {
        if (_streamHost.count > 0)
        {
            // 发送流主机端口和ip
        }
        else
        {
            // 查询代理失败
            [self fail];
        }
    }
}

- (void)queryCandidatesJIDs
{
    // 通常的代理都会包含一个proxy的前缀，优先使用有此前缀的代理
    for (NSUInteger i; i < _candidateJIDsArray.count; i++ )
    {
        XMPPJID *candidateJID = [_candidateJIDsArray objectAtIndex:i];
        NSRange proxyRange = [[candidateJID domain] rangeOfString:@"proxy" options:NSCaseInsensitiveSearch];
        if (proxyRange.length > 0)
		{
			[_candidateJIDsArray removeObjectAtIndex:i];
			[_candidateJIDsArray insertObject:candidateJID atIndex:0];
		}
    }
    _candidateJIDIndex = -1;
    [self queryNextCandidateJID];
}

- (void)queryNextCandidateJID
{
    _candidateJIDIndex++;
    if (_candidateJIDIndex < _candidateJIDsArray.count)
    {
        // 发送服务发现请求
    }
    else
    {
        
    }
}

#pragma mark -
#pragma mark gcd 定时器

- (void)setUpDispatchTimer:(dispatch_source_t)timer timeout:(NSTimeInterval)timeout
{
    NSAssert(dispatch_get_specific(fileTransQueueTag), @"Invoked on incorrect queue");
    if (timer == nil)
    {
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, fileTransQueue);
        dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout*NSEC_PER_SEC));
        dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0.1);
        dispatch_resume(timer);
    }
    else
    {
        dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		dispatch_source_set_timer(timer, tt, DISPATCH_TIME_FOREVER, 0.1);
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
#pragma mark -
#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)inIQ
{
    NSString *type = inIQ.type;
    if ([type isEqualToString:@"result"])
    {
        NSXMLElement *query = [inIQ elementForName:@"query"];
        if (query && [query.xmlns isEqualToString:@"http://jabber.org/protocol/disco#info"])
        {
            if ([_discoUUID isEqualToString:inIQ.elementID])
            {
                DEBUG_METHOD(@"初始方收到目标方应答服务发现请求");
            }
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
- (BOOL)sendfetchProxyServerRequest
{
    XMPPJID *toJID = [XMPPJID jidWithString:@"www.savvy-tech.net"];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:toJID elementID:@"server_items"];
    
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

- (BOOL)sendNetworkAddress:(XMPPJID*)proxyjid host:(NSString*)host port:(NSString*)port
{
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:_receiverJID elementID:@"initiate"];
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/bytestreams"];
    [query addAttributeWithName:@"sid" stringValue:_sid];
    [query addAttributeWithName:@"mode" stringValue:@"tcp"];
    [iq addChild:query];
    
    NSXMLElement *streamhost = [NSXMLElement elementWithName:@"streamhost"];
    [streamhost addAttributeWithName:@"jid" stringValue:proxyjid.full];
    [streamhost addAttributeWithName:@"host" stringValue:host];
    [streamhost addAttributeWithName:@"port" stringValue:port];
    [query addChild:streamhost];
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
    XMPPJID *proxyJID = [XMPPJID jidWithString:_proxyJID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:proxyJID elementID:@"activate"];
    
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
				// The size field was actually the first byte of the port field
				// We just have to read in that last byte
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
			//发送流激活消息
		}
		else
		{
			// 发送确认与成功信息
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
		
        if (_isSendingFile)
        {
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTransfer:didSuccessSendFile:)])
            {
                [_delegate xmppFileTransfer:self didSuccessSendFile:_fileModel];
            }
        }
        else
        {
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTransfer:didSuccessReceiveFile:)])
            {
                [_delegate xmppFileTransfer:self didSuccessReceiveFile:_fileModel];
            }
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
		
        if (_isSendingFile)
        {
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTransfer:didFailSendFile:)])
            {
                [_delegate xmppFileTransfer:self didFailSendFile:_fileModel];
            }
        }
        else
        {
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTransfer:didFailReceiveFile:)])
            {
                [_delegate xmppFileTransfer:self didFailReceiveFile:_fileModel];
            }
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
	
    [self releaseDispatchSource:turnTimer flag:YES];
	[self releaseDispatchSource:discoTimer flag:YES];
	[_xmppStream removeDelegate:self delegateQueue:fileTransQueue];
}


- (void)dealloc
{
	if ((state > STATE_INIT) && (state < STATE_DONE))
	{
		
	}
    
	[self releaseDispatchSource:turnTimer flag:YES];
    [self releaseDispatchSource:discoTimer flag:YES];
    
	
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
