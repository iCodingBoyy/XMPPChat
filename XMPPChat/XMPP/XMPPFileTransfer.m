//
//  XMPPFileTransfer.m
//  XMPPChat
//
//  Created by 马远征 on 14-5-13.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "XMPPFileTransfer.h"
#import <NSXMLElement+XMPP.h>
#import <NSData+XMPP.h>
#import <NSNumber+XMPP.h>

typedef  NS_ENUM( NSInteger, IQStateType)
{
    IQUnknownState,
    IQStreamMethodListSingleState = 10,
    iQStreamMethodReceiveFileInfoState,
    IQStreamMethodSubmitState,
    IQStreamMethodAUTNErrorState,
    IQServerDiscoInfoState,
    IQServerDiscoResponseState,
    IQStreamXEP065FileTransState,
};

typedef enum XMPP_FILE_TYPE
{
    xmpp_FILE_UNKNOWN,
    XMPP_FILE_IMAGE,
    XMPP_FILE_VOICE,
    XMPP_FILE_VIDEO,
    XMPP_FILE_FILE,
    XMPP_FILE_OTHER,
    
}XMPP_FILE_TYPE;

@class XmppFileModel;
@class XMPPSingleFTOperation;

@protocol xmppFileDelegate <NSObject>

- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender willSendFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender didSendFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender didSuccessSendFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender didFailSendFile:(XmppFileModel *)file;
- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender willReceiveFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender didReceiveFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender didSuccessReceiveFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender didFailRecFile:(XmppFileModel *)file;
- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender didRejectFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPSingleFTOperation*)sender didUpdateUI:(CGFloat)progressValue;
@end


#pragma mark -
#pragma mark ////////////////////////XmppFileModel//////////////////////////////////

@interface XmppFileModel : NSObject
@property (nonatomic, strong) NSString   *uuid;
@property (nonatomic, strong) NSString   *fileName;
@property (nonatomic, assign) UInt64      fileSize;
@property (nonatomic, strong) NSString   *mimetype;
@property (nonatomic, strong) NSString   *hashCode;
@property (nonatomic, strong) NSString   *filePath;
@property (nonatomic, strong) NSDate     *timeStamp;
@property (nonatomic, assign) BOOL       isOutGoing;
@property (nonatomic, strong) XMPPJID    *JID;
@property (nonatomic, assign) XMPP_FILE_TYPE fileType;
@end

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
        _fileSize = (UInt64)[[[file attributeForName:@"size"]stringValue]longLongValue];
//        _hashCode = [[file attributeForName:@"hash"]stringValue];
        _isOutGoing = NO;
    }
    return self;
}
@end

#pragma mark -
#pragma mark ////////////////////////XMPPSingleFTOperation//////////////////////////////////

@interface XMPPSingleFTOperation: NSObject
@property (nonatomic, strong) XMPPIQ *receiveIQ;
@end


@interface XMPPSingleFTOperation() <TURNSocketDelegate>
{
    dispatch_queue_t delegateQueue;
    dispatch_queue_t fileTransQueue;
    void *fileTransQueueTag;
    
    dispatch_source_t discoTimer;
    
    BOOL _isSendingFile;
    BOOL _isDoneTransFile;
    
    NSFileHandle *_writehandle;
    NSFileHandle *_readhandle;
    
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
    
    // 接收的长度
    NSUInteger _receiveLen;
    
    // 写入的长度
    NSUInteger _writeLen;
    
    IQStateType _iqState;
}
@property (nonatomic, strong) NSString      *serverUUID;
@property (nonatomic, strong) XMPPJID       *senderJID;
@property (nonatomic, strong) XMPPJID       *receiverJID;
@property (nonatomic, strong) XMPPStream    *xmppStream;
@property (nonatomic, strong) XmppFileModel *fileModel;
@property (nonatomic, strong) TURNSocket    *turnSocket;
@property (nonatomic, OBJ_WEAK) id<xmppFileDelegate> delegate;
@end

@implementation XMPPSingleFTOperation

#pragma mark -
#pragma mark init

- (id)init
{
    self = [super init];
    if (self)
    {
        _iqState = IQUnknownState;
    }
    return self;
}

- (id)initWithStream:(XMPPStream*)xmppStream toJID:(XMPPJID*)jid
{
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _isSendingFile = YES;
        _receiverJID = jid;
        _iqState = IQStreamMethodListSingleState;
        
        [self performPostInitSetup];
    }
    return self;
}

- (id)initWithStream:(XMPPStream *)xmppStream inIQRequest:(XMPPIQ *)inIQ
{
    DEBUG_METHOD(@"-----%@---",inIQ.description);
    self = [super init];
    if (self)
    {
        _xmppStream = xmppStream;
        _isSendingFile = NO;
        _receiveIQ = inIQ;
        _senderJID = inIQ.from;
        _iqState = iQStreamMethodReceiveFileInfoState;
        
        _fileModel = [[XmppFileModel alloc]initWithReceiveIQ:inIQ];
        [self performPostInitSetup];
        
        // 目标方三分钟未接受文件传输则超时
        [self setupTimerForReceiveFile];
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
#pragma mark Timer

- (void)setupDiscoTimer:(NSTimeInterval)timeout
{
	if (discoTimer == NULL)
	{
		discoTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, fileTransQueue);
		
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		
		dispatch_source_set_timer(discoTimer, tt, DISPATCH_TIME_FOREVER, 0.1);
		dispatch_resume(discoTimer);
	}
	else
	{
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
		dispatch_source_set_timer(discoTimer, tt, DISPATCH_TIME_FOREVER, 0.1);
	}
}

// 初始方等待目标方接收超时<三分钟传输超时>
- (void)setupTimerForSendFile
{
    [self setupDiscoTimer:180.0];
    dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
		[self didFailSendFile];
        
	}});
}

// 目标方接收文件传输超时《三分钟未接收则超时》
- (void)setupTimerForReceiveFile
{
    [self setupDiscoTimer:180.0];
    dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
		[self didFailRecFile];
        
	}});
}

// 目标方等待接收流主机超时
- (void)setupDiscoTimerForStreamHost
{
    [self setupDiscoTimer:60.0];
    dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
        
        // 等待接收流主机超时<30s传输超时>
		[self didFailRecFile];
        
	}});
}

// 初始方请求服务发现超时，目标方等待服务发现超时
- (void)setupTimerForServerDisco
{
    [self setupDiscoTimer:30.0];
    dispatch_source_set_event_handler(discoTimer, ^{ @autoreleasepool {
        
        if (_isSendingFile)
        {
            [self didFailSendFile];
        }
		else
        {
            [self didFailRecFile];
        }
        
	}});
}

- (void)cancelTimer
{
    if (discoTimer != NULL)
	{
		dispatch_source_cancel(discoTimer);
		dispatch_release(discoTimer);
	}
}

- (void)cleanUpTimer
{
    if (discoTimer != NULL)
	{
		dispatch_source_cancel(discoTimer);
		dispatch_release(discoTimer);
		discoTimer = NULL;
	}
}

- (void)sendServerDiscoRequest:(XMPPIQ*)inIq
{
    _iqState = IQServerDiscoInfoState;
    _serverUUID = _xmppStream.generateUUID;
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" elementID:_serverUUID];
    [iq addAttributeWithName:@"to" stringValue:inIq.fromStr];
    [iq addAttributeWithName:@"from" stringValue:_xmppStream.myJID.full];
    _serverUUID = iq.elementID;
    
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
    [iq addChild:query];
    
    [_xmppStream sendElement:iq];
}


- (void)responseServerDiscoRequest:(XMPPIQ*)inIQ
{
    _iqState = IQServerDiscoResponseState;
    
    NSXMLElement *identity = [NSXMLElement elementWithName:@"identity"];
    [identity addAttributeWithName:@"category" stringValue:@"proxy"];
    [identity addAttributeWithName:@"type" stringValue:@"bytestreams"];
    [identity addAttributeWithName:@"name" stringValue:@"SOCKS5 Bytestreams Service"];
    
    NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
    [feature addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/si/profile/file-transfer"];
    
    NSXMLElement *feature1 = [NSXMLElement elementWithName:@"feature"];
    [feature1 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/disco#items"];
    
    NSXMLElement *feature2 = [NSXMLElement elementWithName:@"feature"];
    [feature2 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/ibb"];
    
    NSXMLElement *feature3 = [NSXMLElement elementWithName:@"feature"];
    [feature3 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/si"];
    
    NSXMLElement *feature4 = [NSXMLElement elementWithName:@"feature"];
    [feature4 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/bytestreams"];
    
    NSXMLElement *feature5 = [NSXMLElement elementWithName:@"feature"];
    [feature5 addAttributeWithName:@"var" stringValue:@"http://jabber.org/protocol/disco#info"];
    
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"];
    [query addChild:identity];
    [query addChild:feature];
    [query addChild:feature1];
    [query addChild:feature2];
    [query addChild:feature3];
    [query addChild:feature4];
    [query addChild:feature5];
    
    
    XMPPIQ *iq = [XMPPIQ iqWithType:@"result" to:inIQ.from elementID:inIQ.elementID child:query];
    
    [_xmppStream sendElement:iq];
}

#pragma mark -
#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)inIq
{
    DEBUG_METHOD(@"----%s--%@",__FUNCTION__,inIq.description);
    if (_serverUUID == nil)
    {
        _serverUUID = inIq.elementID;
    }
    
    // 初始方收到目标方接收文件传输应答
    if (_iqState == IQStreamMethodListSingleState)
    {
        if ([_serverUUID isEqualToString:inIq.elementID])
        {
            if ([inIq.type isEqualToString:@"result"])
            {
                NSXMLElement *si = [inIq elementForName:@"si"];
                if (si && [si.xmlns isEqualToString:@"http://jabber.org/protocol/si"])
                {
                    NSXMLElement *feature = [si elementForName:@"feature"];
                    if (feature && [feature.xmlns isEqualToString:@"http://jabber.org/protocol/feature-neg"])
                    {
                        DEBUG_METHOD(@"---初始方发送服务发现请求给目标方--");
                        [self sendServerDiscoRequest:inIq];
                        [self setupTimerForServerDisco];
                    }
                }
            }//if type
            
            if ([inIq.type isEqualToString:@"error"])
            {
                DEBUG_METHOD(@"--目标方拒绝接受文件传输--");
                [self cleanUpTimer];
                _iqState = IQStreamMethodAUTNErrorState;
                [self didFailSendFile];
                
            }// if type
            
        }//if
    }
    
    
    // 目标方接收初始方主机端口和ip进入文件传输状态
    if (_iqState == IQServerDiscoResponseState)
    {
        _iqState = IQStreamXEP065FileTransState;
        
        NSXMLElement *query = [inIq elementForName:@"query"];
        if ( query && [@"http://jabber.org/protocol/bytestreams" isEqualToString:[query xmlns]])
        {
            [self cleanUpTimer];
            DEBUG_METHOD(@"--目标方接受主机端口和ip--");
            if ([TURNSocket isNewStartTURNRequest:inIq])
            {
                _turnSocket = [[TURNSocket alloc]initWithStream:_xmppStream incomingTURNRequest:inIq];
                [_turnSocket startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
            }
            else
            {
                DEBUG_METHOD(@"--socket已经存在，无需建立连接--");
            }
        }
    }
    
    // 初始方接收到目标方服务发现应答，进入文件xep-065传输状态
    if (_iqState == IQServerDiscoInfoState)
    {
        if ([_serverUUID isEqualToString:inIq.elementID])
        {
            if ([inIq.type isEqualToString:@"result"])
            {
                NSXMLElement *query = [inIq elementForName:@"query"];
                if (query && [query.xmlns isEqualToString:@"http://jabber.org/protocol/disco#info"])
                {
                    NSArray *featureArray = [query elementsForName:@"feature"];
                    for (NSXMLElement *feature in featureArray)
                    {
                        NSString *var = [feature attributeStringValueForName:@"var"];
                        if ([var isEqualToString:@"http://jabber.org/protocol/bytestreams"])
                        {
                            DEBUG_METHOD(@"--初始方接收目标方服务发现请求应答，开始发送文件--");
                            _iqState = IQStreamXEP065FileTransState;
                            
                            [self cleanUpTimer];
                            [self didSendFile];
                            
                            [TURNSocket initialize];
                            [TURNSocket setProxyCandidates:[NSArray arrayWithObjects:@"www.savvy-tech.net", nil]];
                            _turnSocket = [[TURNSocket alloc]initWithStream:_xmppStream toJID:inIq.from];
                            [_turnSocket startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
                            break;
                        }

                    }
                }
            }// if type
        }
    }
    
    // 目标方接收并响应服务发现请求
    if (_iqState == IQStreamMethodSubmitState)
    {
        if ([inIq.type isEqualToString:@"get"])
        {
            NSXMLElement *query = [inIq elementForName:@"query"];
            if (query && [query.xmlns isEqualToString:@"http://jabber.org/protocol/disco#info"])
            {
                DEBUG_METHOD(@"---目标方接收到服务发现请求---");
                [self responseServerDiscoRequest:inIq];
                [self setupDiscoTimerForStreamHost];
            }
        }
    }
    return YES;
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
#pragma mark TurnSocksDelegate

- (void)turnSocket:(TURNSocket *)sender didSucceed:(GCDAsyncSocket *)socket
{
    DEBUG_METHOD(@"--%s--",__FUNCTION__);
    [socket setDelegate:self delegateQueue:fileTransQueue];
    
    if (_isSendingFile)
    {
        _writeLen = 0;
        _inputStream = [[NSInputStream alloc]initWithFileAtPath:_fileModel.filePath];
        [_inputStream open];
        
        uint8_t buffer[KMaxBufferLen];
        NSInteger len =  [_inputStream read:buffer maxLength:KMaxReadBytesLen];
        if (len == -1)
        {
            DEBUG_STR(@"----数据读取错误-----");
            [_inputStream close];
            [socket disconnect];
            [self didFailSendFile];
        }
        else
        {
            DEBUG_METHOD(@"---开始写数据---");
            NSData *data = [NSData dataWithBytes:buffer length:len];
            [socket writeData:data withTimeout:-1 tag:1];
        }
    }
    else
    {
        _receiveLen = 0;
        NSString *fullPath = [self fullPath:[self documentPath] fileName:_fileModel.fileName];
        if (fullPath == nil || ![self writeFileToPath:fullPath])
        {
            DEBUG_STR(@"----创建文件失败--无法写文件---");
            [socket disconnect];
            [self didFailRecFile];
        }
        else
        {
            DEBUG_STR(@"----开始读数据-----");
            _outputStream = [[NSOutputStream alloc]initToFileAtPath:fullPath append:YES];
            [_outputStream open];
            [socket readDataWithTimeout:-1 tag:2];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == 2)
    {
        NSInteger writelen =  [_outputStream write:[data bytes] maxLength:data.length];
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
            
            // 更新进度条
            CGFloat progressValue = (CGFloat)_receiveLen/(_fileModel.fileSize);
            DEBUG_METHOD(@"----progressValue:%f",progressValue);
            dispatch_async(delegateQueue, ^{
                @autoreleasepool {
                    
                    if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didUpdateUI:)])
                    {
                        [_delegate xmppFileTrans:self didUpdateUI:progressValue];
                    }
                }
            });
            
            if (_receiveLen == _fileModel.fileSize)
            {
                DEBUG_STR(@"---接收数据完成---");
                _isDoneTransFile = YES;
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
        
        NSInteger len =  [_inputStream read:buffer maxLength:1024];
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
            _isDoneTransFile = YES;
            [_inputStream close];
            [sock disconnect];
            [self didSuccessSendFile];
        }
        else
        {
            _writeLen += len;
            
            NSData *data = [NSData dataWithBytes:buffer length:len];
            [sock writeData:data withTimeout:-1 tag:1];
            
            // 更新进度条
            CGFloat progressValue = (CGFloat)_writeLen/_fileModel.fileSize;
            dispatch_async(delegateQueue, ^{
                @autoreleasepool {
                    
                    if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didUpdateUI:)])
                    {
                        [_delegate xmppFileTrans:self didUpdateUI:progressValue];
                    }
                }});//dispatch_async
        }
        
    }//if tag
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    DEBUG_METHOD(@"--%s--",__FUNCTION__);
    if (!_isDoneTransFile)
    {
        if (_isSendingFile)
        {
            [self didFailSendFile];
        }
        else
        {
            [self didFailRecFile];
        }
    }
}

- (void)turnSocketDidFail:(TURNSocket *)sender
{
    DEBUG_METHOD(@"--%s--",__FUNCTION__);
    _turnSocket = nil;
    if (_isSendingFile)
    {
        [self didFailSendFile];
    }
    else
    {
        [self didFailRecFile];
    }
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
            
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didSendFile:)])
            {
                [_delegate xmppFileTrans:self didSendFile:_fileModel];
            }
            
        }});
}

// 成功发送文件
- (void)didSuccessSendFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didSuccessSendFile:)])
            {
                [_delegate xmppFileTrans:self didSuccessSendFile:_fileModel];
            }
            
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didUpdateUI:)])
            {
                [_delegate xmppFileTrans:self didUpdateUI:1.0];
            }
            
        }});
    [self cleanUp];
}

// 发送文件失败
- (void)didFailSendFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didFailSendFile:)])
            {
                [_delegate xmppFileTrans:self didFailSendFile:_fileModel];
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
            
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didReceiveFile:)])
            {
                [_delegate xmppFileTrans:self didReceiveFile:_fileModel];
            }
        }});
}

// 成功接收文件
- (void)didSuccessReceiveFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didSuccessReceiveFile:)])
            {
                [_delegate xmppFileTrans:self didSuccessReceiveFile:_fileModel];
            }
            
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didUpdateUI:)])
            {
                [_delegate xmppFileTrans:self didUpdateUI:1.0];
            }
        }});
    [self cleanUp];
}

// 接收文件失败
- (void)didFailRecFile
{
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didFailRecFile:)])
            {
                [_delegate xmppFileTrans:self didFailRecFile:_fileModel];
            }
            
        }});
    [self cleanUp];
}

- (void)cleanUp
{
    [_xmppStream removeDelegate:self delegateQueue:fileTransQueue];
    [self cleanUpTimer];
}

#pragma mark -
#pragma mark XEP-096

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
    _iqState = IQStreamMethodListSingleState;
    NSString *uuid = [_xmppStream generateUUID];
    _serverUUID = uuid;
    
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
//    [file addAttributeWithName:@"hash" stringValue:hashCode];
//    [file addAttributeWithName:@"date" stringValue:fileDate];
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
    
//    NSXMLElement *option2 = [NSXMLElement elementWithName:@"option"];
//    [field addChild:option2];
//    
//    NSXMLElement *value2 = [NSXMLElement elementWithName:@"value" stringValue:@"http://jabber.org/protocol/ibb"];
//    [option2 addChild:value2];
    
    [_xmppStream sendElement:iq];
    
    // 初始方等待目标方接收文件传输超时定时器
    [self setupTimerForSendFile];
}



/**
 * @method 目标方接收文件传输
 * @param  inIQ 目标方式收到的IQ请求
 * @return
 */
- (void)sendReceiveFiletransferResponse:(XMPPIQ*)inIQ
{
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
    
    DEBUG_METHOD(@"---%s---",__FUNCTION__);
    
    _iqState = IQStreamMethodSubmitState;
    
    NSString *iqId = [inIQ attributeStringValueForName:@"id"];
    
    NSXMLElement *iq = [XMPPIQ iqWithType:@"result" elementID:iqId];
    [iq addAttributeWithName:@"to" stringValue:inIQ.fromStr];
    
    NSXMLElement *si = [NSXMLElement elementWithName:@"si" xmlns:@"http://jabber.org/protocol/si"];
    [iq addChild:si];
    
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
    
    DEBUG_METHOD(@"--inIQ---%@",iq.description);
    
    [_xmppStream sendElement:iq];
    
    // 目标方等待服务发现请求超时定时器
    [self setupTimerForServerDisco];
    
    // 目标方接收文件传输
    dispatch_async(delegateQueue, ^{
        @autoreleasepool {
            if (_delegate && [_delegate respondsToSelector:@selector(xmppFileTrans:didReceiveFile:)])
            {
                [_delegate xmppFileTrans:self didReceiveFile:_fileModel];
            }
        }
    });
    
    
}



/**
 * @method 目标方拒绝文件传输
 * @param  inIQ 目标方式收到的IQ请求
 * @return
 */
- (void)sendRejectFileTransferResponse:(XMPPIQ*)inIQ
{
    // 发送拒绝文件传输响应信息
    /*
     <iq id='' to='' from='' type='error'>
         <error code='403' type='AUTH'>
            <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'>
         </error>
     </iq>
     */
    
    DEBUG_METHOD(@"---%s---",__FUNCTION__);
    _iqState = IQStreamMethodAUTNErrorState;
    
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
    
    [self cleanUpTimer];
    
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
#pragma mark ////////////////////////XMPPFileTransfer//////////////////////////////////

@interface XMPPFileTransfer() <xmppFileDelegate>
{
    
}
@property (nonatomic, strong) NSMutableArray *fileTsQueueArray;
@end

@implementation XMPPFileTransfer

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
        _fileTsQueueArray = [[NSMutableArray alloc]init];
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

- (UIImage*)scaleImage:(UIImage*)image
{
    if (image == nil)
    {
        return nil;
    }
    CGFloat maxSize = (image.size.width > image.size.height) ? image.size.width : image.size.height;
    CGFloat scaleSize = KThumbnailImageMaxSideLen/maxSize;
    CGSize size = CGSizeMake(image.size.width*scaleSize, image.size.height*scaleSize);
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0, 0, image.size.width*scaleSize, image.size.height*scaleSize)];
    UIImage *scaleImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaleImage;
}

- (NSString*)xmppResourcePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES);
    if (paths && paths.count > 0)
    {
        NSString *path = [paths objectAtIndex:0];
        NSString *extensionPath = [NSString stringWithFormat:@"xmppChat/%@",xmppStream.myJID.full];
        NSString *filePath = [path stringByAppendingPathComponent:extensionPath];
        return filePath;
    }
    return nil;
}

- (BOOL)sendImageWithData:(NSData*)imageData toJID:(XMPPJID*)jid
{
    DEBUG_METHOD(@"---%s---",__func__);
    
    NSString *fileName = [NSString stringWithFormat:@"%@.png",xmppStream.generateUUID];
    
    // 将大图像写入fullImage
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *path = [paths objectAtIndex:0];
    
//    NSString *myResourcePath = [self xmppResourcePath];
//    NSString *extensionpath = [NSString stringWithFormat:@"%@/fullImage/%@",jid.full,fileName];
    NSString *filePath = [path stringByAppendingPathComponent:fileName];
    
    NSFileManager *filemanager = [NSFileManager defaultManager];
    if (![filemanager fileExistsAtPath:filePath])
    {
        if (![filemanager createFileAtPath:filePath contents:imageData attributes:nil])
        {
            DEBUG_METHOD(@"创建fullImage出错");
            return NO;
        }
    }
    
    // 将小图像写入thumbnail
//    UIImage *image = [UIImage imageWithData:imageData];
//    UIImage *scaleImage = [self scaleImage:image];
//    NSData *scaleData = UIImagePNGRepresentation(scaleImage);
//    
//    NSString *appendPath = [NSString stringWithFormat:@"%@/thumbnail/%@",jid.full,fileName];
//    NSString *thumbnailPath = [myResourcePath stringByAppendingPathComponent:appendPath];
//    if (![filemanager fileExistsAtPath:thumbnailPath])
//    {
//        if (![filemanager createFileAtPath:thumbnailPath contents:scaleData attributes:nil])
//        {
//            DEBUG_METHOD(@"创建thumailPath出错");
//            return NO;
//        }
//    }

    
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
    
    XMPPSingleFTOperation *fileTrans = [[XMPPSingleFTOperation alloc]initWithStream:xmppStream toJID:jid];
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
    [_fileTsQueueArray addObject:fileTrans];
    DEBUG_METHOD(@"发送文件");
    return YES;
}


#pragma mark -
#pragma mark XMPPStream Delegate

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)inIq
{
    DEBUG_METHOD(@"----%s--%@",__FUNCTION__,inIq.description);
    if ([inIq.type isEqualToString:@"set"])
    {
        NSXMLElement *si = [inIq elementForName:@"si"];
        if (si && [si.xmlns isEqualToString:@"http://jabber.org/protocol/si"])
        {
            NSXMLElement *feature = [si elementForName:@"feature"];
            if ([feature.xmlns isEqualToString:@"http://jabber.org/protocol/feature-neg"])
            {
                DEBUG_STR(@"----目标方接收到文件传输请求----");
                // 接收方初始化文件传输
                XMPPSingleFTOperation *fileTrans = [[XMPPSingleFTOperation alloc]initWithStream:xmppStream inIQRequest:inIq];
                [fileTrans startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
                [_fileTsQueueArray addObject:fileTrans];
            }
        }
    }
    return YES;
}

#pragma mark -
#pragma mark 文件传输协议

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender didFailRecFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    if ([_fileTsQueueArray containsObject:sender])
    {
        [_fileTsQueueArray removeObject:sender];
    }
}

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender didFailSendFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    if ([_fileTsQueueArray containsObject:sender])
    {
        [_fileTsQueueArray removeObject:sender];
    }
}

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender didReceiveFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
}

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender didRejectFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
}

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender didSendFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
}

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender didSuccessReceiveFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    if ([_fileTsQueueArray containsObject:sender])
    {
        [_fileTsQueueArray removeObject:sender];
        sender = nil;
    }
}

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender didSuccessSendFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    if ([_fileTsQueueArray containsObject:sender])
    {
        [_fileTsQueueArray removeObject:sender];
        sender = nil;
    }
}

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender didUpdateUI:(CGFloat)progressValue
{
    if (sender.fileModel.isOutGoing)
    {
         DEBUG_METHOD(@"--%s--发送-%f",__FUNCTION__,progressValue);
    }
    else
    {
         DEBUG_METHOD(@"--%s--接收-%f",__FUNCTION__,progressValue);
    }
   
}

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender willReceiveFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
    if (sender.fileModel.fileType == XMPP_FILE_IMAGE)
    {
        //自动接收图片
    }
    [sender sendReceiveFiletransferResponse:sender.receiveIQ];
}

- (void)xmppFileTrans:(XMPPSingleFTOperation *)sender willSendFile:(XmppFileModel *)file
{
    DEBUG_METHOD(@"--%s---",__FUNCTION__);
}

@end
