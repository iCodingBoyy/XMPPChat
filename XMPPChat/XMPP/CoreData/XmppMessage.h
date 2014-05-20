//
//  XmppMessage.h
//  XMPPChat
//
//  Created by 马远征 on 14-5-20.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface XmppMessage : NSManagedObject

@property (nonatomic, retain) NSString * receiverJID;
@property (nonatomic, retain) NSString * senderJID;
@property (nonatomic, retain) NSDate * timeStamp;
@property (nonatomic, retain) NSNumber * outGoing;
@property (nonatomic, retain) NSNumber * messageType;
@property (nonatomic, retain) NSNumber * messageState;
@property (nonatomic, retain) NSString * fileSize;
@property (nonatomic, retain) NSNumber * fileName;
@property (nonatomic, retain) NSString * messageBody;
@property (nonatomic, retain) NSString * location;
@property (nonatomic, retain) NSString * voicePath;
@property (nonatomic, retain) NSString * videoThumbPath;
@property (nonatomic, retain) NSString * videoPath;
@property (nonatomic, retain) NSString * photoPath;
@property (nonatomic, retain) NSString * photoThumbPath;

@end
