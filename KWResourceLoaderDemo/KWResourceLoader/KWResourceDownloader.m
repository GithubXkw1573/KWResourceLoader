//
//  KWResourceDownloader.m
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/6/26.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//  资源下载器

#import "KWResourceDownloader.h"
#import "KWFileManager.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "KWLog.h"

@interface KWResourceDownloader ()<NSURLSessionDelegate,NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionTask *task;
@property (nonatomic, assign) long long offset;
@property (nonatomic, assign) long long length;
@property (nonatomic, assign) BOOL isDownloading;
@end

@implementation KWResourceDownloader

- (instancetype)init {
    if (self = [super init]) {
        self.session = [NSURLSession sessionWithConfiguration:
                        [NSURLSessionConfiguration defaultSessionConfiguration]
                                                     delegate:self delegateQueue:nil];
    }
    return self;
}

- (NSURLSessionTask *)downloadURL:(NSURL *)URL range:(NSRange)range {
    self.URL = URL;
    self.offset = range.location;
    self.length = range.length;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    long long endOffset = self.offset + self.length - 1;
    NSString *httpRange = [NSString stringWithFormat:@"bytes=%lld-%lld",self.offset,endOffset];
    [request setValue:httpRange forHTTPHeaderField:@"Range"];
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
    self.isDownloading = YES;
    self.task = task;
    return task;
}

/**
 取消正在下载的请求
 */
- (void)cancelDownloadingTask {
    if (self.isDownloading) {
        [self.task cancel];
        [KWLog kwLog:@"取消下载"];
    }
}

#pragma mark - NSURLSessionDelegate

//开始接受数据
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    //设置contentInformation
    KWHttpInfomation *info = [[KWHttpInfomation alloc] init];
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
        NSString *acceptRange = HTTPURLResponse.allHeaderFields[@"Accept-Ranges"];
        info.byteRangeAccessSupported = [acceptRange isEqualToString:@"bytes"];
        //考虑到绝大部分服务器都支持bytes,这里就全部设置为支持
        info.byteRangeAccessSupported = YES;
        info.contentLength = [[[HTTPURLResponse.allHeaderFields[@"Content-Range"]
                                componentsSeparatedByString:@"/"] lastObject] longLongValue];
        if (info.contentLength == 0) {
            info.contentLength = [HTTPURLResponse.allHeaderFields[@"Content-Length"] longLongValue];
        }
    }
    NSString *mimeType = response.MIMEType;
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,
                                                                    (__bridge CFStringRef)(mimeType),
                                                                    NULL);
    info.contentType = CFBridgingRelease(contentType);
    if ([self.delegate respondsToSelector:@selector(downloader:informatiion:task:)]) {
        [self.delegate downloader:self informatiion:info task:dataTask];
    }
    [KWLog kwLog:@"%@",info.debugDescription];
    //缓存info
    [KWFileManager saveContentInfomation:info URL:dataTask.originalRequest.URL];
    
    completionHandler(NSURLSessionResponseAllow);
    
}


- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if ([self.delegate respondsToSelector:@selector(downloader:didReceiveData:task:)]) {
        [self.delegate downloader:self didReceiveData:data task:dataTask];
    }
}


//下载完成
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    [KWLog kwLog:@"下载结束"];
    self.isDownloading = NO;
    if ([self.delegate respondsToSelector:@selector(downloader:didCompleteWithError:task:)]) {
        [self.delegate downloader:self didCompleteWithError:error task:task];
    }
}

//证书信任
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    NSURLCredential *card = [[NSURLCredential alloc] initWithTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential,card);
}

- (void)dealloc {
    [self cancelDownloadingTask];
}


@end
