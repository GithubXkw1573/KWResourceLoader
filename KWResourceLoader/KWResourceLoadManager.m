//
//  KWResourceLoadManager.m
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/7/2.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import "KWResourceLoadManager.h"
#import "KWResourceDownloader.h"
#import "KWFileManager.h"
#import "KWLog.h"

@interface KWResourceLoadManager ()<KWResourceDownloaderDelegate>
@property (nonatomic, strong) NSMutableArray<AVAssetResourceLoadingRequest *> *loadRequestArray;
@property (nonatomic, strong) NSMutableArray<NSURLSessionTask *> *downloadTasks;
@property (nonatomic, strong) KWResourceDownloader *downloader;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) NSMutableData *bufferData;
@end

@implementation KWResourceLoadManager

- (instancetype)init {
    if (self = [super init]) {
        self.loadRequestArray = [[NSMutableArray alloc] init];
        self.downloadTasks = [[NSMutableArray alloc] init];
        self.downloader = [[KWResourceDownloader alloc] init];
        self.downloader.delegate = self;
        self.bufferData = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)addResourceLoadReqeust:(AVAssetResourceLoadingRequest *)request {
    [self.loadRequestArray addObject:request];
    if (self.isRunning) {
        //当前有正在加载的资源，新添加进来资源，排队
        return;
    }
    //空闲状态，立即开始加载资源
    [self beginLoadResource:request];
}

- (void)cancelResourceLoadReqeust:(AVAssetResourceLoadingRequest *)request {
    //获取该请求对应的task
    NSURLSessionTask *task = [self taskOfRequest:request];
    if (task) {
        [task cancel];
        [self.downloadTasks removeObject:task];
    }
}

- (void)cancelAllLoadingRequests {
    //清空请求栈
    [self.downloadTasks removeAllObjects];
    [self.loadRequestArray removeAllObjects];
    //取消可能正在下载的请求
    [self.downloader cancelDownloadingTask];
}

#pragma mark - KWResourceDownloaderDelegate

- (void)downloader:(KWResourceDownloader *)downloader informatiion:(KWHttpInfomation *)information task:(NSURLSessionDataTask *)task {
    self.bufferData = [[NSMutableData alloc] init];
    AVAssetResourceLoadingRequest *request = [self loadRequestOfTask:task];
    if ([self.delegate respondsToSelector:@selector(resouceLoadManager:fillContentInfomation:loadReqeust:)]) {
        [self.delegate resouceLoadManager:self fillContentInfomation:information loadReqeust:request];
    }
}

- (void)downloader:(KWResourceDownloader *)downloader didReceiveData:(NSData *)data task:(NSURLSessionDataTask *)task {
    AVAssetResourceLoadingRequest *request = [self loadRequestOfTask:task];
    long long offset = request.dataRequest.requestedOffset;
    @synchronized (self.bufferData) {
        [self.bufferData appendData:data];
        KWHttpInfomation *info = [KWFileManager readContentInfomationFromURL:task.currentRequest.URL];
        long long totalLength = info.contentLength;
        long long haveDownLength = offset + self.bufferData.length;
        float progress = haveDownLength * 1.0 / totalLength;
        if ([self.delegate respondsToSelector:@selector(resouceLoadManager:resourceLoadProgress:loadReqeust:)]) {
            [self.delegate resouceLoadManager:self resourceLoadProgress:progress loadReqeust:request];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(resouceLoadManager:didReceiveData:loadReqeust:)]) {
        [self.delegate resouceLoadManager:self didReceiveData:data loadReqeust:request];
    }
}

- (void)downloader:(KWResourceDownloader *)downloader didCompleteWithError:(NSError *)error task:(NSURLSessionTask *)task {
    
    AVAssetResourceLoadingRequest *request = [self loadRequestOfTask:task];
    if ([self.delegate respondsToSelector:@selector(resouceLoadManager:didCompleteWithError:loadReqeust:)]) {
        [self.delegate resouceLoadManager:self didCompleteWithError:error loadReqeust:request];
    }
    //将本次片段下载的data写入缓存
    NSRange range = [self rangeOfTask:task];
    //如果本次下载收到错误（一般是取消），但是下载的部分数据也是可以缓存下来
    if (self.bufferData.length) {
        range.length = self.bufferData.length;
        [KWFileManager cacheDownloadData:self.bufferData task:task range:range];
    }
    
    [KWLog kwLog:@"开始下一个资源加载"];
    [self loadNextToLoadedResource:request];
}

#pragma mark - 私有方法

//立即开始加载资源
- (void)beginLoadResource:(AVAssetResourceLoadingRequest *)request {
    self.isRunning = YES;
    NSURL *URL = [self originURL:request.request.URL];
    long long offset = request.dataRequest.requestedOffset;
    long long length = request.dataRequest.requestedLength;
    //先尝试从缓存查找资源
    [KWFileManager readLocalBytesOfURL:URL range:NSMakeRange(offset, length) finish:^(NSData * _Nonnull data, NSError * _Nonnull error) {
        if (data && !error) {
            [KWLog kwLog:@"使用缓存"];
            [self finishLoadRequest:request withLocalCacheData:data];
            //加载下一个资源
            [self loadNextToLoadedResource:request];
        }else {
            [KWLog kwLog:@"没有缓存，开始下载资源"];
            NSURLSessionTask *task = [self.downloader downloadURL:URL range:NSMakeRange(offset, length)];
            [self.downloadTasks addObject:task];
        }
    }];
}

//在某个资源加载结束后，获取下一个要加载的资源
- (void)loadNextToLoadedResource:(AVAssetResourceLoadingRequest *)request {
    NSInteger index = [self.loadRequestArray indexOfObject:request];
    index = index + 1;
    if (self.loadRequestArray.count > index) {
        AVAssetResourceLoadingRequest *nextReq = self.loadRequestArray[index];
        [self beginLoadResource:nextReq];
    }else {
        if (request == nil && self.loadRequestArray.count) {
            //说明是切换了视频资源，开始加载新的视频
            AVAssetResourceLoadingRequest *nextReq = [self.loadRequestArray firstObject];
            [self beginLoadResource:nextReq];
        }else {
            [KWLog kwLog:@"没有要加载的资源了，空闲状态"];
            self.isRunning = NO;
        }
    }
}

//本地缓存填充request
- (void)finishLoadRequest:(AVAssetResourceLoadingRequest *)request withLocalCacheData:(NSData *)data {
    NSURL *URL = [self originURL:request.request.URL];
    KWHttpInfomation *info = [KWFileManager readContentInfomationFromURL:URL];
    //1.填充视频头信息
    if ([self.delegate respondsToSelector:@selector(resouceLoadManager:fillContentInfomation:loadReqeust:)]) {
        [self.delegate resouceLoadManager:self fillContentInfomation:info loadReqeust:request];
    }
    //2.塞data
    if ([self.delegate respondsToSelector:@selector(resouceLoadManager:didReceiveData:loadReqeust:)]) {
        [self.delegate resouceLoadManager:self didReceiveData:data loadReqeust:request];
    }
    //3.加载进度
    if ([self.delegate respondsToSelector:@selector(resouceLoadManager:resourceLoadProgress:loadReqeust:)]) {
        long long offset = request.dataRequest.requestedOffset;
        long long totalLength = info.contentLength;
        long long haveDownLength = offset + data.length;
        float progress = haveDownLength * 1.0 / totalLength;
        [self.delegate resouceLoadManager:self resourceLoadProgress:progress loadReqeust:request];
    }
    //4.finish
    if ([self.delegate respondsToSelector:@selector(resouceLoadManager:didCompleteWithError:loadReqeust:)]) {
        [self.delegate resouceLoadManager:self didCompleteWithError:nil loadReqeust:request];
    }
}

- (AVAssetResourceLoadingRequest *)loadRequestOfTask:(NSURLSessionTask *)task {
    AVAssetResourceLoadingRequest *target = nil;
    NSRange range = [self rangeOfTask:task];
    NSString *taskUrl = task.currentRequest.URL.absoluteString;
    NSArray *tmp = [NSArray arrayWithArray:self.loadRequestArray];
    for (AVAssetResourceLoadingRequest *loadReq in tmp) {
        NSString *loadUrl = [self originURL:loadReq.request.URL].absoluteString;
        long long offset = loadReq.dataRequest.requestedOffset;
        long long length = loadReq.dataRequest.requestedLength;
        if ([taskUrl isEqualToString:loadUrl] &&
            range.location == offset &&
            range.length == length) {
            target = loadReq;
            break;
        }
    }
    return target;
}

- (NSURLSessionTask *)taskOfRequest:(AVAssetResourceLoadingRequest *)reqeust {
    NSURLSessionTask *target = nil;
    NSString *loadUrl = [self originURL:reqeust.request.URL].absoluteString;
    long long offset = reqeust.dataRequest.requestedOffset;
    long long length = reqeust.dataRequest.requestedLength;
    NSArray *tmp = [NSArray arrayWithArray:self.downloadTasks];
    for (NSURLSessionTask *task in tmp) {
        NSRange range = [self rangeOfTask:task];
        NSString *taskUrl = task.currentRequest.URL.absoluteString;
        if ([taskUrl isEqualToString:loadUrl] &&
            range.location == offset &&
            range.length == length) {
            target = task;
            break;
        }
    }
    return target;
}

#pragma mark - 辅助方法
- (NSRange)rangeOfTask:(NSURLSessionTask *)task {
    NSDictionary *header = task.currentRequest.allHTTPHeaderFields;
    NSString *rangeStr = [header objectForKey:@"Range"];
    if (rangeStr && [rangeStr containsString:@"bytes="]) {
        rangeStr = [rangeStr stringByReplacingOccurrencesOfString:@"bytes=" withString:@""];
        NSArray *arr = [rangeStr componentsSeparatedByString:@"-"];
        long long start = [arr[0] longLongValue];
        long long end = [arr[1] longLongValue];
        return NSMakeRange(start, end - start + 1);
    }else {
        return NSMakeRange(0, 0);
    }
}

- (NSURL *)assetURLWithURL:(NSURL *)url {
    if (!url) {
        return nil;
    }
    NSURL *assetURL = [NSURL URLWithString:[kCacheScheme stringByAppendingString:[url absoluteString]]];
    return assetURL;
}

- (NSURL *)originURL:(NSURL *)URL {
    NSURL *originURL = nil;
    NSString *originStr = [URL absoluteString];
    originStr = [originStr stringByReplacingOccurrencesOfString:kCacheScheme withString:@""];
    originURL = [NSURL URLWithString:originStr];
    return originURL;
}

@end
