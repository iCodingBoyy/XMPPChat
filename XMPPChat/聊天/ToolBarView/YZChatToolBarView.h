//
//  YZChatToolBarView.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-1.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol  YZChatToolBarDeleagte <NSObject>

- (void)YZChatTextViewDidSend:(NSString*)text;
- (void)YZChatToolBoxButtonClick:(NSUInteger)buttonIndex;
@end

@interface YZChatToolBarView : UIView
/*!
 *
 */
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, unsafe_unretained) id<YZChatToolBarDeleagte> delegate;
@end
