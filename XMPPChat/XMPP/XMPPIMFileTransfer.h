//
//  XMPPIMFileTransfer.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-23.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "XMPPModule.h"
#import <XMPP.h>

typedef enum XMPP_FILE_TYPE
{
    xmpp_FILE_UNKNOWN,
    XMPP_FILE_IMAGE,
    XMPP_FILE_VOICE,
    XMPP_FILE_VIDEO,
    XMPP_FILE_FILE,
    XMPP_FILE_OTHER,
    
}XMPP_FILE_TYPE;

@interface XmppFileModel : NSObject
@property (nonatomic, strong) NSString   *uuid;
@property (nonatomic, strong) NSString   *fileName;
@property (nonatomic, assign) NSUInteger fileSize;
@property (nonatomic, strong) NSString   *mimetype;
@property (nonatomic, strong) NSString   *hashCode;
@property (nonatomic, strong) NSDate     *timeStamp;
@property (nonatomic, strong) XMPPJID    *JID;
@property (nonatomic, assign) BOOL       isOutGoing;
@property (nonatomic, assign) XMPP_FILE_TYPE fileType;
@end


#pragma mark -
#pragma mark xmppSocksConnect
///////////////////////////xep-065 xmpp socks协商///////////////////////////////////////////

@class xmppSocksConnect;

@protocol xmppSKConnectDelegate <NSObject>

- (void)xmppSocks:(xmppSocksConnect*)sender didSucceed:(GCDAsyncSocket*)socket;
- (void)xmppSocksDidFail:(xmppSocksConnect *)sender;
@end
@interface xmppSocksConnect : NSObject
@property (nonatomic, strong) GCDAsyncSocket *asyncSocket;
@property (nonatomic, OBJ_WEAK) id<xmppSKConnectDelegate> delegate;

+ (BOOL)isNewStartSocksRequest:(XMPPIQ*)inIQ;
+ (NSArray*)proxyCandidates;
+ (void)setProxyCandidates:(NSArray*)candidates;
- (id)initWithStream:(XMPPStream*)xmppStream toJID:(XMPPJID*)jid;
- (id)initWithStream:(XMPPStream *)xmppStream inIQRequest:(XMPPIQ *)inIQ;
- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue;
- (void)abort;
@end


#pragma mark -
#pragma mark XMPPFileTransfer
///////////////////////////xep-096 xmpp文件传输///////////////////////////////////////////
@class XMPPFileTransfer;
@protocol xmppFileDelegate <NSObject>

- (void)xmppFileTrans:(XMPPFileTransfer*)sender willSendFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPFileTransfer*)sender didSendFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPFileTransfer*)sender didFailSendFile:(XmppFileModel *)file;
- (void)xmppFileTrans:(XMPPFileTransfer*)sender willReceiveFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPFileTransfer*)sender didReceiveFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPFileTransfer*)sender didFailRecFile:(XmppFileModel *)file;
- (void)xmppFileTrans:(XMPPFileTransfer*)sender didRejectFile:(XmppFileModel*)file;
- (void)xmppFileTrans:(XMPPFileTransfer*)sender didUpdateUI:(NSUInteger)progressValue;
@end

@interface XMPPFileTransfer : NSObject
@property (nonatomic, OBJ_WEAK) id<xmppFileDelegate> delegate;
@property (nonatomic, strong) XmppFileModel *fileModel;

- (id)initWithStream:(XMPPStream*)xmppStream toJID:(XMPPJID*)jid;
- (id)initWithStream:(XMPPStream *)xmppStream inIQRequest:(XMPPIQ *)inIQ;
- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue;
@end


#pragma mark -
#pragma mark XMPPIMFileManager
///////////////////////////xmpp文件传输管理///////////////////////////////////////////

@interface XMPPIMFileManager : XMPPModule

@end
