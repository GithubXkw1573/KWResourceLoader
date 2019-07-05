//
//  KWResourceLoadManager.h
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/7/2.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "KWHttpInfomation.h"

#define kCacheScheme @"__kCacheScheme__"

NS_ASSUME_NONNULL_BEGIN

@class KWResourceLoadManager;
@protocol KWResourceLoadManagerDelegate <NSObject>

@required
//开始填充头部信息
- (void)resouceLoadManager:(KWResourceLoadManager *)manager
     fillContentInfomation:(KWHttpInfomation *)infomation
               loadReqeust:(AVAssetResourceLoadingRequest *)request;
//接收数据
- (void)resouceLoadManager:(KWResourceLoadManager *)manager
            didReceiveData:(NSData *)data
               loadReqeust:(AVAssetResourceLoadingRequest *)request;
//加载资源结束
- (void)resouceLoadManager:(KWResourceLoadManager *)manager
      didCompleteWithError:(nullable NSError *)error
               loadReqeust:(AVAssetResourceLoadingRequest *)request;

@optional
//资源加载进度
- (void)resouceLoadManager:(KWResourceLoadManager *)manager
      resourceLoadProgress:(float)progress
               loadReqeust:(AVAssetResourceLoadingRequest *)request;

@end

@interface KWResourceLoadManager : NSObject

@property (nonatomic, weak) id<KWResourceLoadManagerDelegate> delegate;

- (void)addResourceLoadReqeust:(AVAssetResourceLoadingRequest *)request;

- (void)cancelResourceLoadReqeust:(AVAssetResourceLoadingRequest *)request;

- (void)cancelAllLoadingRequests;

- (NSURL *)assetURLWithURL:(NSURL *)url;
- (NSURL *)originURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
