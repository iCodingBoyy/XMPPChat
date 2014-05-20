//
//  YZEnumDefine.h
//  XMPPChat
//
//  Created by 马远征 on 14-5-20.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#ifndef XMPPChat_YZEnumDefine_h
#define XMPPChat_YZEnumDefine_h

typedef NS_ENUM(NSInteger, YZMessageMark)
{
    YZMessageOutGoing,
    YZMessageInComing,
};

typedef NS_ENUM(NSInteger, YZMessageState)
{
    YZMessageStateTransferring = 1,
    YZMessageStateTransferOK,
    YZMessageStateTransferError,
};

typedef NS_ENUM(NSInteger, YZMessageType)
{
    YZMessageText = 0,
    YZMessagePhoto,
    YZMessageVoice,
    YZMessageVideo,
    YZMessageLocation,
    YZMessageVCard,
};

#endif
