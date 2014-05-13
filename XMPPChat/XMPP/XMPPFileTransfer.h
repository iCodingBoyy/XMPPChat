//
//  XMPPFileTransfer.h
//  XMPPChat
//
//  Created by 马远征 on 14-5-13.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "XMPPModule.h"
#import <XMPP.h>
#import <TURNSocket.h>


#define KMaxBufferLen 4096
#define KMaxReadBytesLen 1024
#define KReadDataTimeOut -1
#define KWriteDataTimeOut -1


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
@property (nonatomic, assign) UInt64      fileSize;
@property (nonatomic, strong) NSString   *mimetype;
@property (nonatomic, strong) NSString   *hashCode;
@property (nonatomic, strong) NSString   *filePath;
@property (nonatomic, strong) NSDate     *timeStamp;
@property (nonatomic, assign) BOOL       isOutGoing;
@property (nonatomic, strong) XMPPJID    *JID;
@property (nonatomic, assign) XMPP_FILE_TYPE fileType;
@end


@interface XMPPSingleFTOperation: NSObject
@property (nonatomic, strong) XMPPIQ *receiveIQ;
@end


@interface XMPPFileTransfer : XMPPModule
- (BOOL)sendImageWithData:(NSData*)imageData toJID:(XMPPJID*)jid;
@end
