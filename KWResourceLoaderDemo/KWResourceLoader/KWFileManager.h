//
//  KWFileManager.h
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/6/27.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class KWHttpInfomation;
@interface KWFileManager : NSObject

/**
 分片缓存

 @param data 要缓存的字节data
 @param task 对应的下载任务task
 @param range 资源缓存的位置、长度
 */
+ (void)cacheDownloadData:(NSData *)data task:(NSURLSessionTask *)task
                     range:(NSRange)range;


/**
 读取指定资源位置的缓存

 @param URL 资源URL
 @param range 读取的位置、长度
 @param block 读取的回调结果
 */
+ (void)readLocalBytesOfURL:(NSURL *)URL range:(NSRange)range
                     finish:(void(^)(NSData *data, NSError *error))block;

/**
 缓存多媒体资源的头部信息（0-2字节里的信息）

 @param info 多媒体头部信息
 @param URL 资源的URL
 */
+ (void)saveContentInfomation:(KWHttpInfomation *)info URL:(NSURL *)URL;

/**
 读取指定多媒体资源的头部信息（0-2字节里的信息）

 @param URL URL
 @return 返回多媒体头部信息（若没有缓存，返回nil）
 */
+ (KWHttpInfomation *)readContentInfomationFromURL:(NSURL *)URL;

/**
 获取多媒体资源缓存的总体大小（字节数）

 @return 返回size
 */
+ (NSNumber *)getAllMediaCachesSize;

/**
 清空指定资源的缓存

 @param URL 要清除缓存的URL
 */
+ (void)clearCacheOfURL:(NSURL *)URL;

/**
 清除所有多媒体缓存的资源

 @param complete 清空结束后的回调
 */
+ (void)clearAllCache:(void(^)(NSError *error))complete;

/**
 判断指定URL资源data是否全部缓存完毕

 @param URL 要播放的多媒体URL
 @return YES：表示全部缓存到本地（可离线本地播放）
 */
+ (BOOL)isCompleteCacheForURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
