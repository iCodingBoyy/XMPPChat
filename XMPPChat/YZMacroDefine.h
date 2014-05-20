//
//  YZMacroDefine.h
//  XMPPChat
//
//  Created by 马远征 on 14-4-2.
//  Copyright (c) 2014年 马远征. All rights reserved.
//

#ifndef XMPPChat_YZMacroDefine_h
#define XMPPChat_YZMacroDefine_h

static inline CGFloat width(UIView *view) { return view.frame.size.width; }
static inline CGFloat height(UIView *view) { return view.frame.size.height; }
static inline int ScreenHeight(){ return [UIScreen mainScreen].bounds.size.height; }
static inline int ScreenWidth(){ return [UIScreen mainScreen].bounds.size.width; }
static inline int AppFrameHeight(){ return [UIScreen mainScreen].applicationFrame.size.height; }


#define IS_IPHONE_5   (fabs((double)[[UIScreen mainScreen] bounds].size.height - (double )568) < DBL_EPSILON )
#define KScreenWidth  [[UIScreen mainScreen]bounds].size.width
#define KScreenHeight [[UIScreen mainScreen]bounds].size.height
#define iOS7 [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0

#define RGBColor(r,g,b,a) [UIColor colorWithRed:r green:g blue:b alpha:a]

#define KStretchImage(image,x,y) [image stretchableImageWithLeftCapWidth:x topCapHeight:y]
#define KStretchImageEdge(image,top,left,bottom,right) [image resizableImageWithCapInsets:UIEdgeInsetsMake(top, left, bottom, right)]

#define RADIANS(angle) ((angle) / 180.0 * M_PI)

#define KResignFirstResponder(obj) if ([obj isFirstResponder])\
                                    {\
                                        [obj resignFirstResponder];\
                                    }

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
#   define MSTextAlignmentCenter    NSTextAlignmentCenter
#   define MSTextAlignmentLeft      NSTextAlignmentLeft
#   define MSTextAlignmentRight     NSTextAlignmentRight
#   define MSTruncationTail         NSLineBreakByTruncatingTail
#   define MSTruncationMiddle       NSLineBreakByTruncatingMiddle
#   define MSBreakModeCharacterWrap NSLineBreakByCharWrapping
#   define MSLineBreakModeWordWrap  NSLineBreakByWordWrapping
#else // older versions
#   define MSTextAlignmentCenter        UITextAlignmentCenter
#   define MSTextAlignmentLeft          UITextAlignmentLeft
#   define MSTextAlignmentRight         UITextAlignmentRight
#   define MSTruncationTail         UILineBreakModeTailTruncation
#   define MSTruncationMiddle       UILineBreakModeMiddleTruncation
#   define MSBreakModeCharacterWrap UILineBreakModeCharacterWrap
#   define MSLineBreakModeWordWrap  UILineBreakModeWordWrap
#endif

#ifdef DEBUG
#   define DEBUG_STR(...) NSLog(__VA_ARGS__);
#   define DEBUG_METHOD(format, ...) NSLog(format, ##__VA_ARGS__);
#else
#   define DEBUG_STR(...) NSLog(__VA_ARGS__);
#   define DEBUG_METHOD(format, ...) NSLog(format, ##__VA_ARGS__);
#endif



#if __has_feature(objc_arc_weak)
#   define OBJ_WEAK weak
#   define __OBJ_WEAK __weak
#   define OBJ_STRONG strong
#elif __has_feature(objc_arc)
#   define OBJ_WEAK unsafe_unretained
#   define __OBJ_WEAK __unsafe_unretained
#   define OBJ_STRONG strong
#else
#   define OBJ_WEAK assign
#   define __OBJ_WEAK
#   define OBJ_STRONG retain
#endif



#endif
