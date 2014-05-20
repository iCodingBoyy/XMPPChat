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


#define KThumbnailImageMaxSideLen 80.0f


@interface XMPPFileTransfer : XMPPModule
{
    
}
- (BOOL)sendImageWithData:(NSData*)imageData toJID:(XMPPJID*)jid;
@end
