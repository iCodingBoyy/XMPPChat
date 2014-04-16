//
//  XMPPFileTransfer.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-9.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "XMPPModule.h"
#import <XMPP.h>
#import <GCDAsyncSocket.h>
#import "XMPPFileSKConnect.h"

typedef enum
{
    kXMPPSIFileTransferStateNone,
    kXMPPSIFileTransferStateSending,
    kXMPPSIFileTransferStateReceiving
} XMPPSIFileTransferState;

@interface XMPPFileTransfer : XMPPModule <GCDAsyncSocketDelegate>
@property (nonatomic,strong) NSString *sid;
- (void)initiateFileTransferTo:(XMPPJID*)to fileName:(NSString*)fileName fileData:(NSData*)fileData;
@end
