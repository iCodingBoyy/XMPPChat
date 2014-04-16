//
//  XMPPFileTransfer.m
//  XMPPChat
//
//  Created by 马远征 on 14-4-9.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import "XMPPFileTransfer.h"
#import <XMPPLogging.h>
#import <XMPPMessage.h>
#import <NSXMLElement+XMPP.h>

@interface XMPPFileTransfer() <UIAlertViewDelegate>
{
    XMPPSIFileTransferState _state;
    XMPPJID *senderJID;
}

@property (nonatomic, strong) NSMutableArray *fileSocketsArray;
@property (nonatomic, strong) NSMutableData *receiveData;
@property (nonatomic, strong) NSData *sendData;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *recvFileSize;
@property (nonatomic, strong) XMPPIQ *receiveIQ;
@end

@implementation XMPPFileTransfer

- (id)init
{
    return [self initWithDispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	if ((self = [super initWithDispatchQueue:queue]))
    {
        _state = kXMPPSIFileTransferStateNone;
        _receiveData = [[NSMutableData alloc] init];
        _fileSocketsArray = [[NSMutableArray alloc]init];
	}
	return self;
}

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

- (void)sendNegotiationRequest:(XMPPJID*)toJID fileName:(NSString*)fileName mimeType:(NSString*)mimeType
{
    NSString *uuid = [xmppStream generateUUID];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" elementID:uuid];
    [iq addAttributeWithName:@"to" stringValue:toJID.full];
    [iq addAttributeWithName:@"from" stringValue:[[xmppStream myJID] full]];
    
    _sid = [xmppStream generateUUID];
    NSXMLElement *si = [NSXMLElement elementWithName:@"si" xmlns:@"http://jabber.org/protocol/si"];
    [si addAttributeWithName:@"id" stringValue:_sid];
    [si addAttributeWithName:@"mime-type" stringValue:mimeType];
    [si addAttributeWithName:@"profile" stringValue:@"http://jabber.org/protocol/si/profile/file-transfer"];
    [iq addChild:si];
    
    NSXMLElement *file = [NSXMLElement elementWithName:@"file" xmlns:@"http://jabber.org/protocol/si/profile/file-transfer"];
    [file addAttributeWithName:@"name" stringValue:fileName];
    [file addAttributeWithName:@"size" stringValue:[[NSString alloc] initWithFormat:@"%lu", (unsigned long)[_sendData length]]];
    [si addChild:file];
    
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
- (BOOL)sendNegotiationResponse:(XMPPIQ*)inIq
{
    NSString *iqId = [inIq attributeStringValueForName:@"id"];
    NSString *from = [inIq fromStr];
    NSString *to = [inIq toStr];
    
    // 获取接收得文件名和文件大小
    NSXMLElement *si = [inIq elementForName:@"si"];
    NSXMLElement *file = [si elementForName:@"file"];
    self.recvFileSize = [[file attributeForName:@"size"] stringValue];
    self.fileName = [[file attributeForName:@"name"] stringValue];
    
   
    NSXMLElement *riq = [XMPPIQ iqWithType:@"result" elementID:iqId];
    [riq addAttributeWithName:@"from" stringValue:to];
    [riq addAttributeWithName:@"to" stringValue:from];
    
    NSXMLElement *rsi = [NSXMLElement elementWithName:@"si" xmlns:@"http://jabber.org/protocol/si"];
    [riq addChild:rsi];
    
    NSXMLElement *rfeature = [NSXMLElement elementWithName:@"feature" xmlns:@"http://jabber.org/protocol/feature-neg"];
    [rsi addChild:rfeature];
    
    NSXMLElement *rx = [NSXMLElement elementWithName:@"x" xmlns:@"jabber:x:data"];
    [rx addAttributeWithName:@"type" stringValue:@"submit"];
    [rfeature addChild:rx];
    
    NSXMLElement *rfield = [NSXMLElement elementWithName:@"field"];
    [rfield addAttributeWithName:@"var" stringValue:@"stream-method"];
    [rx addChild:rfield];
    
    NSXMLElement *rvalue = [NSXMLElement elementWithName:@"value" stringValue:@"http://jabber.org/protocol/bytestreams"];
    [rfield addChild:rvalue];
    
    [xmppStream sendElement:riq];
    
    return YES;
}

// 发送拒绝文件传输响应信息
/*
  <iq id='' to='' from='' type='error'>
     <error code='403' type='AUTH'>
        <forbidden xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'>
     </error>
 </iq>
 */

- (BOOL)sendRejectNegotiationResponse:(XMPPIQ*)inIq
{
    NSString *iqId = [inIq attributeStringValueForName:@"id"];
    NSString *from = [inIq fromStr];
    NSString *to = [inIq toStr];
    
    NSXMLElement *riq = [XMPPIQ iqWithType:@"error" elementID:iqId];
    [riq addAttributeWithName:@"from" stringValue:to];
    [riq addAttributeWithName:@"to" stringValue:from];
    
    NSXMLElement *rError = [NSXMLElement elementWithName:@"error"];
    [rError addAttributeWithName:@"code" stringValue:@"403"];
    [rError addAttributeWithName:@"type" stringValue:@"AUTH"];
    [riq addChild:rError];
    
    NSXMLElement *rForbidden = [NSXMLElement elementWithName:@"forbidden" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
    [rError addChild:rForbidden];
    
    [xmppStream sendElement:riq];
    return NO;
}

- (BOOL)sendStreamHostNegotiationError:(XMPPIQ*)inIq
{
    NSString *to = [inIq fromStr];
    NSString *from = [inIq toStr];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"error" elementID:[inIq elementID]];
    [iq addAttributeWithName:@"to" stringValue:to];
    [iq addAttributeWithName:@"from" stringValue:from];
    
    NSXMLElement *error = [NSXMLElement elementWithName:@"error"];
    [error addAttributeWithName:@"type" stringValue:@"modify"];
    [iq addChild:error];
    
    NSXMLElement *notAcc = [NSXMLElement elementWithName:@"not-acceptable" xmlns:@"urn:ietf:params:xml:ns:xmpp-stanzas"];
    [error addChild:notAcc];
    
    [xmppStream sendElement:iq];
    return YES;
}

#pragma mark-
#pragma mark- XMPPStream Delegate

- (void)initiateFileTransferTo:(XMPPJID*)to fileName:(NSString*)fileName fileData:(NSData*)fileData
{
    _sendData = fileData;
    _state = kXMPPSIFileTransferStateSending;
    [self sendNegotiationRequest:to fileName:fileName mimeType:@"image/png"];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)inIq
{
    
//    NSLog(@"---%s--%@",__FUNCTION__,inIq.description);
    NSString *type = [inIq type];
    if ([@"set" isEqualToString:type])// 接收文件传输响应
    {
        NSXMLElement *si = [inIq elementForName:@"si"];
        if (si != nil)
        {
            if ([@"http://jabber.org/protocol/si" isEqualToString:[si xmlns]])
            {
                NSXMLElement *file = [si elementForName:@"file"];
                if ([@"http://jabber.org/protocol/si/profile/file-transfer" isEqualToString:[file xmlns]])
                {
                    NSXMLElement *feature = [[inIq elementForName:@"si"] elementForName:@"feature"];
                    NSString *xmlns = [feature xmlns];
                    if ([@"http://jabber.org/protocol/feature-neg" isEqualToString:xmlns])
                    {
                        _receiveIQ = inIq;
                        NSString *from = [inIq fromStr];
                        self.fileName = [[file attributeForName:@"name"] stringValue];
                        UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:from
                                                                           message:_fileName
                                                                          delegate:self
                                                                 cancelButtonTitle:@"拒绝"
                                                                 otherButtonTitles:@"接收", nil];
                        [alertView setTag:10000];
                        [alertView show];
                        return YES;
                    }
                }
            }
        }
        else
        {
            NSXMLElement *query = [inIq elementForName:@"query"];
            if (query != nil)
            {
                if ([@"http://jabber.org/protocol/bytestreams" isEqualToString:[query xmlns]])
                {
                    NSString *querySid = [[query attributeForName:@"sid"] stringValue];
                    if ([_sid isEqualToString:querySid])
                    {
                        return YES;
                    }
                    else
                    {
                        NSLog(@"----流主机代理错误----");
                        return [self sendStreamHostNegotiationError:inIq];
                    }
                }
            }
        }
    }
    else if ([@"error" isEqualToString:type])// 对方中断文件传输，文件传输被禁止
    {
        NSXMLElement *error = [inIq elementForName:@"error"];
        if (error)
        {
            NSString *code =  [[error attributeForName:@"code"] stringValue];
            if ([@"403" isEqualToString:code])
            {
                NSLog(@"-%s-文件传输被禁止",__FUNCTION__);
                return NO;
            }
        }
    }
    else if ([@"result" isEqualToString:type]) // 对方接收文件传输，开始查询服务
    {
        NSXMLElement *si = [inIq elementForName:@"si"];
        if (si != nil)
        {
            if ([@"http://jabber.org/protocol/si" isEqualToString:[si xmlns]])
            {
                NSXMLElement *feature = [[inIq elementForName:@"si"] elementForName:@"feature"];
                if ([@"http://jabber.org/protocol/feature-neg" isEqualToString:[feature xmlns]])
                {
                    NSLog(@"-%s-对方接受文件传输",__FUNCTION__);
                    XMPPFileSKConnect *connect = [[XMPPFileSKConnect alloc]initWithStream:xmppStream toJID:inIq.from];
                    [connect startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
                    [_fileSocketsArray addObject:connect];
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        [self sendRejectNegotiationResponse:_receiveIQ];
    }
    else
    {
        [self sendNegotiationResponse:_receiveIQ];
        XMPPFileSKConnect *connect = [[XMPPFileSKConnect alloc]initWithStream:xmppStream inComingSKRequest:_receiveIQ];
        [connect startWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        [_fileSocketsArray addObject:connect];
    }
}


@end
