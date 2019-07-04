//
//  KWResourceLoader.h
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/6/26.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "KWFileManager.h"

NS_ASSUME_NONNULL_BEGIN
@class KWResourceLoader;
@protocol KWResourceLoaderDelegate <NSObject>

@optional
- (void)resourceLoader:(KWResourceLoader *)loadManager didLoadProgress:(float)loadProgress;

@end

@interface KWResourceLoader : NSObject

@property (nonatomic, weak) id<KWResourceLoaderDelegate> delegate;

//是否打开debug日志输出，默认关闭
@property (nonatomic, assign) BOOL openDebugLog;

/**
 外部调用API
 
 @param url 请求的多媒体URL
 @return 返回一个PlayItem
 */
- (AVPlayerItem *)playerItemWithURL:(NSURL *)url;


@end

NS_ASSUME_NONNULL_END
