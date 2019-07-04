//
//  KWResourceLoader.m
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/6/26.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import "KWResourceLoader.h"
#import "KWResourceLoadManager.h"
#import "KWLog.h"

@interface KWResourceLoader ()<AVAssetResourceLoaderDelegate,KWResourceLoadManagerDelegate>
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, strong) KWResourceLoadManager *loadManager;
@property (nonatomic, strong) KWHttpInfomation *contentInformation;
@end

@implementation KWResourceLoader

- (instancetype)init {
    if (self = [super init]) {
        self.loadManager = [[KWResourceLoadManager alloc] init];
        self.loadManager.delegate = self;
    }
    return self;
}

- (void)dealloc {
    [self.asset.resourceLoader setDelegate:nil queue:dispatch_get_main_queue()];
    [self.loadManager cancelAllLoadingRequests];
}


/**
 外部调用API

 @param url 请求的多媒体URL
 @return 返回一个PlayItem
 */
- (AVPlayerItem *)playerItemWithURL:(NSURL *)url {
    if (!url) {
        return nil;
    }
    
    //播放新的视频前，先取消之前所有请求
    [self.loadManager cancelAllLoadingRequests];
    
    //将URL拼接特定标识，目的是让AVURLAsset不能自行下载，从而触发shouldwait
    url = [self.loadManager assetURLWithURL:url];
    self.asset = [AVURLAsset URLAssetWithURL:url options:nil];
    [self.asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
    
    //新建对应资源的playItem
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:self.asset];
    if ([item respondsToSelector:@selector(setCanUseNetworkResourcesForLiveStreamingWhilePaused:)]) {
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;
    }
    
    return item;
}


#pragma mark - AVAssetResourceLoaderDelegate
//开始等待加载资源
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest NS_AVAILABLE(10_9, 6_0) {
    NSURL *resourceURL = [loadingRequest.request URL];
    [KWLog kwLog:@"开始等待资源：%lld-%ld",loadingRequest.dataRequest.requestedOffset,
     (long)loadingRequest.dataRequest.requestedLength];
    if ([resourceURL.absoluteString hasPrefix:kCacheScheme]) {
        //将该资源请求放入待下载列表里
        [self.loadManager addResourceLoadReqeust:loadingRequest];
        return YES;
    }else {
        return NO;
    }
}


//取消下载触发
- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest NS_AVAILABLE(10_9, 7_0) {
    [KWLog kwLog:@"取消加载的资源：%lld-%ld",loadingRequest.dataRequest.requestedOffset,
          (long)loadingRequest.dataRequest.requestedLength];
    //取消下载
    [self.loadManager cancelResourceLoadReqeust:loadingRequest];
}

#pragma mark - KWResourceLoadManagerDelegate

//开始填充头部信息
- (void)resouceLoadManager:(KWResourceLoadManager *)manager
     fillContentInfomation:(KWHttpInfomation *)infomation
               loadReqeust:(AVAssetResourceLoadingRequest *)request {
    [self fillContentInfomation:request with:infomation];
}

//接收数据
- (void)resouceLoadManager:(KWResourceLoadManager *)manager
            didReceiveData:(NSData *)data
               loadReqeust:(AVAssetResourceLoadingRequest *)request {
    [request.dataRequest respondWithData:data];
}

//加载资源结束
- (void)resouceLoadManager:(KWResourceLoadManager *)manager
      didCompleteWithError:(NSError *)error
               loadReqeust:(AVAssetResourceLoadingRequest *)request {
    if (error) {
        [request finishLoadingWithError:error];
        [KWLog kwLog:@"finishLoadingWithError"];
    }else {
        [request finishLoading];
        [KWLog kwLog:@"finishLoading"];
    }
}

//资源加载进度
- (void)resouceLoadManager:(KWResourceLoadManager *)manager
      resourceLoadProgress:(float)progress
               loadReqeust:(AVAssetResourceLoadingRequest *)request {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(resourceLoader:didLoadProgress:)]) {
            [self.delegate resourceLoader:self didLoadProgress:progress];
        }
    });
}

#pragma mark - 属性 Setter
- (void)setOpenDebugLog:(BOOL)openDebugLog {
    _openDebugLog = openDebugLog;
    KWLog *log = [KWLog instance];
    log.debugOpen = openDebugLog;
}

#pragma mark - 私有方法

- (void)fillContentInfomation:(AVAssetResourceLoadingRequest *)request with:(KWHttpInfomation *)info {
    self.contentInformation = info;
    AVAssetResourceLoadingContentInformationRequest *contentInfomation = request.contentInformationRequest;
    if (info && !contentInfomation.contentType) {
        contentInfomation.contentType = info.contentType;
        contentInfomation.contentLength = info.contentLength;
        contentInfomation.byteRangeAccessSupported = info.byteRangeAccessSupported;
    }
}



@end
