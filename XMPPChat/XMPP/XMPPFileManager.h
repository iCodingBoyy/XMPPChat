//
//  XMPPFileManager.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-21.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "XMPPModule.h"
#import <XMPP.h>

typedef  enum XMPP_FILE_TYPE
{
    XMPP_FILE_TEXT = 0, /* 传输文本消息*/
    XMPP_FILE_IMAGE, /* 传输图片文件*/
    XMPP_FILE_VOICE, /* 传输语音文件*/
    XMPP_FILE_VIDEO, /* 传输视频文件*/
    XMPP_FILE_VCARD, /* 传输VCARD文件*/
    XMPP_FILE_LOCATION, /* 传输一个位置*/
    XMPP_FILE_FILE, /* 传输已知类型文件*/
    XMPP_FILE_OTHER, /* 传输非常用类型文件*/
    
}XMPP_FILE_TYPE;

@interface xmppFileModel : NSObject
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, assign) NSUInteger fileSize;
@property (nonatomic, strong) NSDate *timeStamp;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic, assign) XMPP_FILE_TYPE fileType;
@property (nonatomic, strong) NSString *hashValue;
@property (nonatomic, strong) XMPPJID *senderJID;
@property (nonatomic, strong) NSData *dataBytes;
@property (nonatomic, assign) BOOL outGoing;
@end


@class XMPPFileManager;
@class XMPPFileTransfer;

@protocol xmppFileMgrDelegate <NSObject>

/* xmpp文件传输管理协议*/
// 文件传输开始

// <失败>
// 对方拒绝接收文件
// 服务器返回错误，文件传输失败
// 开始建立连接
// 文件传输超时
// 查询代理错误
// socks5流建立失败
// 流激活失败
// hash校验不正确

// <正在传输，更新进度>
// 建立连接，文件传输开始，并更新进度
- (void)xmppFileMgr:(XMPPFileManager *)fileMgr wilSendFile:(xmppFileModel*)file;
- (void)xmppFileMgr:(XMPPFileManager *)fileMgr didSendFile:(xmppFileModel*)file;
- (void)xmppFileMgr:(XMPPFileManager *)fileMgr didFailToSendFile:(xmppFileModel*)file error:(NSXMLElement*)error;
- (void)xmppFileMgr:(XMPPFileManager *)fileMgr willReceiveFile:(xmppFileModel*)file;
- (void)xmppFileMgr:(XMPPFileManager *)fileMgr didReceiveFile:(xmppFileModel*)file;
- (void)xmppFileMgr:(XMPPFileManager *)fileMgr didRejectReceiveFile:(xmppFileModel*)file;
@end


@interface XMPPFileManager : XMPPModule
@property (nonatomic, strong, readonly) NSMutableArray *fileQueueArray;
@property (nonatomic, OBJ_WEAK) id<xmppFileMgrDelegate> delegate;

- (void)sendReceiveFiletransferResponse:(XMPPIQ*)inIQ;
- (void)sendRejectFileTransferResponse:(XMPPIQ*)inIQ;
- (void)sendImagetoJID:(XMPPJID*)toJID imageName:(NSString*)imageName data:(NSData*)imageData mimeType:(NSString*)mimetype;
@end



@protocol xmppFileTransDelegate <NSObject>
- (void)xmppFileTransfer:(XMPPFileTransfer*)sender didSuccessSendFile:(xmppFileModel*)file;
- (void)xmppFileTransfer:(XMPPFileTransfer*)sender didFailSendFile:(xmppFileModel*)file;
- (void)xmppFileTransfer:(XMPPFileTransfer*)sender didSuccessReceiveFile:(xmppFileModel*)file;
- (void)xmppFileTransfer:(XMPPFileTransfer*)sender didFailReceiveFile:(xmppFileModel*)file;
@end

@interface XMPPFileTransfer : NSObject
@property (nonatomic, strong) GCDAsyncSocket *asyncSocket;
@property (nonatomic, strong) xmppFileModel *fileModel;
@property (nonatomic, OBJ_WEAK) id<xmppFileTransDelegate> delegate;
+ (void)initialize;
+ (NSArray*)proxyCandidates;
+ (void)setProxyCandidates:(NSArray*)candidates;

- (id)initWithStream:(XMPPStream*)xmppStream xmppFile:(xmppFileModel*)file toJID:(XMPPJID*)jid;
- (id)initWithStream:(XMPPStream *)xmppStream xmppFile:(xmppFileModel *)file iqRequest:(XMPPIQ*)inIQ;
- (void)startWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)aDelegateQueue;
@end
