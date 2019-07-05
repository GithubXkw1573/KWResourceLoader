//
//  KWFileManager.m
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/6/27.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import "KWFileManager.h"
#import "NSString+md5.h"
#import "KWHttpInfomation.h"
#import "KWLog.h"

#define kMediaCachePath @"KWMediaCachePath" //所有媒体资源缓存的根目录

@implementation KWFileManager

//片段缓存
+ (void)cacheDownloadData:(NSData *)data task:(NSURLSessionTask *)task
                    range:(NSRange)range {
    long long offset = range.location;
    long long length = range.length;
    //缓存根目录
    NSString *mediaPath = [self cacheRootPath];
    //创建根目录，如果没有的话
    [self createDirIfNotExist:mediaPath];
    
    //将URL字符串的md5值作为该音视频文件夹名称
    NSString *md5Dir = [self mediaDirByURL:task.originalRequest.URL];
    //判断有没有md5Dir目录
    [self createDirIfNotExist:md5Dir];
    
    long long endOffset = offset + length - 1;
    NSString *fileName = [NSString stringWithFormat:@"%lld_%lld_%@",offset,
                          endOffset,task.response.suggestedFilename];
    NSString *fullFilePath = [md5Dir stringByAppendingPathComponent:fileName];
    //开辟子线程将二进制写入文件
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        //创建文件,并写入文件
        BOOL succ = [[NSFileManager defaultManager] createFileAtPath:fullFilePath contents:data attributes:nil];
        if (succ) {
            [KWLog kwLog:@"写入成功"];
        }
    });
    
}

+ (NSString *)cacheRootPath {
    //将下载默认存放地址移到缓存目录下
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                               NSUserDomainMask, YES) lastObject];
    //缓存根目录
    NSString *mediaPath = [cachePath stringByAppendingPathComponent:kMediaCachePath];
    return mediaPath;
}

+ (BOOL)existPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:path isDirectory:nil];
}

+ (void)createDirIfNotExist:(NSString *)dir {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![self existPath:dir]) {
        //不存在，则创建目录
        [fileManager createDirectoryAtPath:dir
               withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

+ (NSString *)md5ForURL:(NSURL *)URL {
    NSString *assetUrl = URL.absoluteString;
    //获取md5
    NSString *urlMd5 = [assetUrl md5To32bit:assetUrl];
    return urlMd5;
}

+ (NSString *)mediaDirByURL:(NSURL *)URL {
    NSString *mediaPath = [self cacheRootPath];
    NSString *assetUrl = URL.absoluteString;
    //获取md5
    NSString *urlMd5 = [assetUrl md5To32bit:assetUrl];
    //将资源的md5作为目录
    NSString *md5Dir = [mediaPath stringByAppendingPathComponent:urlMd5];
    return md5Dir;
}

+ (NSArray<NSString *> *)fragementsFilenameOfMedia:(NSURL *)URL {
    if (![self existPath:[self cacheRootPath]]) {
        //根目录都没有，返回空
        return nil;
    }
    
    if (![self existPath:[self mediaDirByURL:URL]]) {
        //该资源没有缓存目录，返回空
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *mediaDir = [self mediaDirByURL:URL];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:mediaDir error:nil];
    
    return files;
}

+ (NSArray<NSString *> *)canRadLocalCachesForURL:(NSURL *)URL range:(NSRange)range {
    NSArray *files = [self fragementsFilenameOfMedia:URL];
    if (files.count == 0) {
        return nil;
    }
    
    NSString *targetFileName = nil;
    long long start = range.location;
    long long end = start + range.length - 1;
    for (NSString *fileName in files) {
        NSArray *components = [fileName componentsSeparatedByString:@"_"];
        if (components.count >= 3) {
            NSString *offset = [components firstObject];
            NSString *endOffset = components[1];
            if(start == 0 && end == 1) {
                if (start == [offset longLongValue] &&
                    end == [endOffset longLongValue]) {
                    //落在本地某个片段内
                    targetFileName = fileName;
                    break;
                }
            }else if (start >= [offset longLongValue] && end <= [endOffset longLongValue] &&
                      (start != 0 && end != 1)) {
                //落在本地某个片段内
                targetFileName = fileName;
                break;
            }
        }
    }
    NSMutableArray *readFiles = [NSMutableArray array];
    if (!targetFileName) {
        //按文件名排序
        files = [self sortFiles:files];
        //尝试垮碎片查找
        NSString *firstFileName = [self fileNameOffset:start files:files];
        if (firstFileName) {
            NSRange firstRange = [self fileRange:firstFileName];
            if (firstRange.length != 0) {
                long long firstEnd = firstRange.location + firstRange.length - 1;
                NSMutableArray *sequentFiles = [NSMutableArray arrayWithObject:firstFileName];
                [self getNextSequentFileNameByLastEnd:firstEnd files:files output:&sequentFiles];
                if (sequentFiles.count > 1) {
                    NSString *lastFileName = [sequentFiles lastObject];
                    NSRange lastRange = [self fileRange:lastFileName];
                    if (lastRange.location + lastRange.length - 1 >= end) {
                        [readFiles addObjectsFromArray:sequentFiles];
                    }
                }
            }
        }
        
    }else {
        [readFiles addObject:targetFileName];
    }
    return readFiles;
}



+ (void)getNextSequentFileNameByLastEnd:(long long)lastEnd files:(NSArray *)files output:(NSMutableArray **)outputArray {
    NSString *findFileName = nil;
    for (NSString *fileName in files) {
        NSRange range = [self fileRange:fileName];
        if (range.length != 0) {
            if (range.location == lastEnd + 1) {
                findFileName = fileName;
                break;
            }
        }
    }
    if (findFileName) {
        NSRange fileRange = [self fileRange:findFileName];
        if (fileRange.length != 0) {
            long long end = fileRange.location + fileRange.length - 1;
            NSMutableArray *outPut = *outputArray;
            [outPut addObject:findFileName];
            [self getNextSequentFileNameByLastEnd:end files:files output:&outPut];
        }
    }
}

/**
 根据资源URL取本地缓存的二进制数据，如果没有，data将为nil

 @param URL URL description
 @param range range description
 @param block block description
 */
+ (void)readLocalBytesOfURL:(NSURL *)URL range:(NSRange)range
                     finish:(void(^)(NSData *data, NSError *error))block {
    NSArray *files = [self canRadLocalCachesForURL:URL range:range];
    if (files.count == 0) {
        if (block) {
            block(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:-1 userInfo:nil]);
        }
        return;
    }
    NSMutableArray *filePaths = [NSMutableArray array];
    NSString *mediaDir = [self mediaDirByURL:URL];
    if (!mediaDir.length) {
        if (block) {
            block(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:-2 userInfo:nil]);
        }
        return;
    }
    long long firstOffset = 0;
    long long endOffset = 0;
    for (NSString *name in files) {
        if ([files indexOfObject:name] == 0) {
            NSRange r = [self fileRange:name];
            firstOffset = r.location;
        }
        if ([files indexOfObject:name] == files.count - 1) {
            NSRange r = [self fileRange:name];
            endOffset = r.location + r.length - 1;
        }
        NSString *path = [mediaDir stringByAppendingPathComponent:name];
        [filePaths addObject:path];
    }
    //读取data耗时操作，开辟子线程处理
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSMutableData *totalData = [[NSMutableData alloc] init];
        if (filePaths.count > 1) {
            [KWLog kwLog:@"有多个资源拼接"];
        }
        for (NSString *path in filePaths) {
            NSData *data = [NSData dataWithContentsOfFile:path];
            [totalData appendData:data];
        }
        NSData *data = [[NSData alloc] initWithData:totalData];
        //截取
        long long newOffset = range.location - firstOffset;
        if (newOffset >= 0 && data.length >= newOffset + range.length) {
            data = [data subdataWithRange:NSMakeRange(newOffset, range.length)];
        }else {
            [KWLog kwLog:@"从%lld-%lld中截取data长度:%lu, 资源要求：%lu-%lu",
                  newOffset,endOffset,(unsigned long)data.length,(unsigned long)range.location,range.location + range.length - 1];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block) {
                block(data, nil);
            }
        });
    });
}

+ (NSArray *)sortFiles:(NSArray *)files {
    files = [files sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSString *filename1 = obj1;
        NSString *filename2 = obj2;
        NSString *offset1 = [[filename1 componentsSeparatedByString:@"_"] firstObject];
        NSString *offset2 = [[filename2 componentsSeparatedByString:@"_"] firstObject];
        if ([offset1 longLongValue] <= [offset2 longLongValue]) {
            return NSOrderedAscending;
        }else {
            return NSOrderedDescending;
        }
    }];
    return files;
}

+ (NSString *)fileNameOffset:(long long)offset files:(NSArray *)files{
    NSString *findName = nil;
    for (NSString *fileName in files) {
        NSArray *components = [fileName componentsSeparatedByString:@"_"];
        if (components.count >= 3) {
            NSString *startOffset = [components firstObject];
            NSString *endOffset = components[1];
            if (offset >= [startOffset longLongValue] && offset <= [endOffset longLongValue]) {
                findName = fileName;
                break;
            }
        }
    }
    return findName;
}

+ (NSRange)fileRange:(NSString *)fileName {
    NSArray *components = [fileName componentsSeparatedByString:@"_"];
    if (components.count >= 3) {
        NSString *startOffset = [components firstObject];
        NSString *endOffset = components[1];
        return NSMakeRange([startOffset longLongValue],
                           [endOffset longLongValue] - [startOffset longLongValue] + 1);
    }else {
        return NSMakeRange(0, 0);
    }
}

+ (void)saveContentInfomation:(KWHttpInfomation *)info URL:(NSURL *)URL {
    NSString *key = [self md5ForURL:URL];
    if (key.length) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:info];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (KWHttpInfomation *)readContentInfomationFromURL:(NSURL *)URL {
    NSString *key = [self md5ForURL:URL];
    if (key.length) {
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        KWHttpInfomation *info = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        return info;
    }else {
        return nil;
    }
}

+ (NSNumber *)getAllMediaCachesSize {
    NSString *cacheRootPath = [self cacheRootPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheRootPath]) {
        NSDictionary *attr = [[NSFileManager defaultManager]
                              attributesOfItemAtPath:cacheRootPath error:nil];
        if (attr) {
            NSNumber *size = [attr objectForKey:@"NSFileSize"];
            return size;
        }else {
            return [NSNumber numberWithLong:0];
        }
    }else {
        return [NSNumber numberWithLong:0];
    }
}


/**
 清除指定的资源缓存

 @param URL URL description
 */
+ (void)clearCacheOfURL:(NSURL *)URL {
    NSString *cachePath = [self mediaDirByURL:URL];
    [self removeCachePath:cachePath error:nil];
}

+ (void)removeCachePath:(NSString *)cachePath error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:cachePath error:error];
    for (NSString *name in files) {
        NSString* fileAbsolutePath = [cachePath stringByAppendingPathComponent:name];
        [fileManager removeItemAtPath:fileAbsolutePath error:error];
    }
    //最后再移除文件夹
    [fileManager removeItemAtPath:cachePath error:error];
}


/**
 清除所有媒体资源缓存

 @param complete complete description
 */
+ (void)clearAllCache:(void(^)(NSError *error))complete {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *error = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *rootPath = [self cacheRootPath];
        NSArray *files = [fileManager contentsOfDirectoryAtPath:rootPath error:&error];
        for (NSString *path in files) {
            NSString* fileAbsolutePath = [rootPath stringByAppendingPathComponent:path];
            [self removeCachePath:fileAbsolutePath error:&error];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) {
                complete(error);
            }
        });
    });
}

+ (BOOL)isCompleteCacheForURL:(NSURL *)URL {
    KWHttpInfomation *info = [self readContentInfomationFromURL:URL];
    if (info) {
        long long contentLength = info.contentLength;
        NSArray *files = [self canRadLocalCachesForURL:URL range:NSMakeRange(0, contentLength)];
        return files.count;
    }else {
        return NO;
    }
}

@end
