//
//  KWResourceDownloader.h
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/6/26.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//  资源下载器

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "KWHttpInfomation.h"

NS_ASSUME_NONNULL_BEGIN

@class KWResourceDownloader,KWHttpInfomation;
@protocol KWResourceDownloaderDelegate <NSObject>

@optional

- (void)downloader:(KWResourceDownloader *)downloader informatiion:(KWHttpInfomation *)information task:(NSURLSessionDataTask *)task;

- (void)downloader:(KWResourceDownloader *)downloader didReceiveData:(NSData *)data  task:(NSURLSessionDataTask *)task;

- (void)downloader:(KWResourceDownloader *)downloader didCompleteWithError:(NSError *)error task:(NSURLSessionTask *)task;

@end

@interface KWResourceDownloader : NSObject

@property (nonatomic, weak) id<KWResourceDownloaderDelegate> delegate;


/**
 分片下载

 @param URL 资源URL
 @param range 指定下载的位置、长度
 @return 返回该下载的Task
 */
- (NSURLSessionTask *)downloadURL:(NSURL *)URL range:(NSRange)range;


/**
 取消正在下载的任务
 */
- (void)cancelDownloadingTask;

@end

NS_ASSUME_NONNULL_END
