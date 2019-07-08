# KWResourceLoader
iOS 视频缓存播放器-利用AVResourceLoaderDelegate实现

####前言
iOS多媒体播放主要有2个技术层框架可以实现：
- AVFoundation库：OC语言对底层进行封装的高级层接口，其中处理音频、视频播放功能的是AVPlayer。优点：由于AVPlayer已经对底层诸如音视频采集、解编码等细节封装了，应用层不需要关心这些实现细节，所以**使用简单**，普通开发者可以不用知道什么是码率、采样率等音视频专业知识，即可实现音视频播放的功能。缺点就是：由于**高度封装，灵活性较差，例如没有开放诸如缓存的存取的API**，给开发者控制视频缓存带来了难度。

- AudioToolBox: 采用较底层的C语音实现的音视频的采集、I/O处理、解码、编码、PCM等处理的API集合。优点是：灵活度高，开发者可以开发出专业的音视频播放软件，主要是供音视频专业技术开发者使用。但对于非音视频专业的普通iOS开发者并不友好，对音视频领域不是很了解的话，有一定的门槛。

作为非音视频专业领域，只是个APP应用的iOS开发者，AudioToolBox是没有把握的，写出来也是一堆bug哈哈~
所以主要还是利用AVPlayer实现播放器，可是如果想播放完一次视频后，下次可以利用缓存播放，AVPlayer并不提供缓存API，我们没法知道AVPlayer的缓存在哪里。经过研究发现，目前实现带缓存功能的AVPlayer播放器主要从2个方向：
- 在播放视频的同时，开启一个线程下载该视频URL。
- 利用AVAssetResourceLoaderDelegate控制视频数据流的请求。

毫无疑问，第一种方案播放一个视频，需要耗费用户2倍的流量；而第二种方案只要一遍的流量，既播放了视频、又缓存了视频，所以，我的技术方案就是采用AVAssetResourceLoaderDelegate实现。

####方案思路
**AVAssetResourceLoaderDelegate**
首先了解一下AVAssetResourceLoaderDelegate所在的层：
![ResouceLoader层次图](https://upload-images.jianshu.io/upload_images/1413134-07531887fb66a884.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

其中核心类：
- AVAssetResourceLoader：这个类负责多媒体（音视频）二进制数据的加载（下载），然后回调给上层Asset,让视频播放。但是**这个类作为AVURLAsset是只读属性**，但是它允许下面这个代理去如何加载数据资源。

- AVAssetResourceLoaderDelegate：它是一个协议，那么任何实现了该协议的对象都可以充当AVAssetResourceLoader的代理来指示视频数据的加载，既然数据资源可以有开发人员自行加载然后再回填给播放器，那么缓存就可以有自己控制了，OK，这就是我们这个方案的思路。

**注意：通过测试发现，如果给AVURLAssert设置成正常可以下载的URL时，AVAssetResourceLoaderDelegate的代理是不触发的**，很可能的推测就是AVAssetResourceLoader解析资源URL做了判断（伪码）：
> if (URL可以自行解析下载) {
> 
    内部自己解析...
> } else {
> 
   由外部AVAssetResourceLoaderDelegate解析
> 
> }

所以，我们为了让AVURLAssert强行走外部代理解析，我们可以故意给AVURLAssert传一个不合法的URL（为了让AVAssetResourceLoader不能正常解析URL），我们可以在正确的URL前面拼接约定好的标识，然后在后面我们真正去下载前，再将特定的标识去掉即可得到能正常下载的URL了。大意是这样：
![拼接URL示意图](https://upload-images.jianshu.io/upload_images/1413134-5014ca7a7d08cfbe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


####架构设计
- KWResourceLoader:该类负责AVAssetResourceLoaderDelegate代理的2个实现方法：

> resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
>

> resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest

上面shouldWait代理表示要等待加载的资源，在播放中会触发多次，以便于分片加载资源，resourceLoader中5个我们需要关心的：

1.**request**：请求资源的URL

2.**contentInfomationRequest**：这个里面包含了该音视频资源的头部信息，如视频的格式、总长度字节数、是否支持分片下载等重要信息。**这些信息需要我们下载视频的时候自行填充这些信息**，以便AVPlayer 播放前知道视频的duration和格式信息，如果我们不填充视频头信息，视频是无法播放的，这点是需要注意的地方。

3.**dataRequest**:这个里面含有每次分片加载资源的位置offset和请求的长度length信息，以便于我们下载器分片下载对应的data.

4.**finishWithLoading/withError**: 每次音视频data片段加载加载完毕后，我们要finishLoading ,目的是通知播放器本次资源加载结束，那么AVAssetResourceLoaderDelegate就又会触发shouldWait方法让我们继续加载后面的data,如此反复，直到资源data全部加载完毕。

5.**responseWithData:** 在finishLoading之前，我们要将不断下载得到的data数据不断的塞给resouceLoader，以便播放器在一边下载数据的同时一边开始播放。

整体架构流程图如下：

![架构流程图](https://upload-images.jianshu.io/upload_images/1413134-c9d03e4178fd7971.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

####实现细节：
######KWResouceLoader
- **给AVURLAsset的URL添加特定头部**，以便resouceLoader不能正常解析，从而触发shouldWait。

```
- (NSURL *)assetURLWithURL:(NSURL *)url {
    if (!url) {
        return nil;
    }
    NSURL *assetURL = [NSURL URLWithString:[kCacheScheme stringByAppendingString:[url absoluteString]]];
    return assetURL;
}
```
然后把拼接的URL传给AVURLAsset：

```
//将URL拼接特定标识，目的是让AVURLAsset不能自行下载，从而触发shouldwait
    url = [self.loadManager assetURLWithURL:url];
    self.asset = [AVURLAsset URLAssetWithURL:url options:nil];
    [self.asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
```

设置resouceLoader的delegate, 即可触发下面代理方法：

```
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
```

上面第一个是将要加载加载某个URL片段，这个会多次触发，而且可能一次可能会触发多次片段请求，所以我们应该用一个数组来保存每次的request，最后在全部加载完后移除。

第二个是触发取消下载的委托：通过大量的测试发现，这个取消触发一般有2种情况下回出现：
- 当前request片段较长，一般是一个请求至尾的大片段，而当前网络加载data资源网速欠佳，resouceLoader会取消这次请求，然后改成多个小分片请求，以保证播放的流畅性。

- 用户进行seek操作。当用户拖动进度至一个尚未下载（加载）的进度的时候，为了立即加载新的进度的资源，会把之前正在加载的请求取消掉。

当触发了取消代理时，我们应该把正在下载的Task cancel掉，以节省用户的流量。当然，如果你不取消之前的Task也是可以的，这里我还是遵从Apple的代理，将正在下载的Task取消吧。

KWResouceLoader这个类不负责具体资源的加载、取消逻辑，它委托了KWResouceLoaderManager这个类负责：

```
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

```
fillContentInfomation: 得到资源的头信息，为播放做准备
didReceiveData：得到的data调用responseWithData塞给播放器播放。
completeWithError: 本次request结束，触发下一轮资源请求。

######KWResouceLoaderManager
该类是整个框架的核心，它维护了一个所有要加载资源的队列，并实现了一个消费-生产模式，以保证了加载的顺序，以及判断从本地缓存还是网络下载该片段。

**消费-生产模式**
当shouldWait触发时，说明有新的请求过来了，我们首先将request加到队列中，然后判断当前是否繁忙（由于同一时刻只能有一个资源请求，所以我们应该按顺序请求资源）：

```
- (void)addResourceLoadReqeust:(AVAssetResourceLoadingRequest *)request {
    [self.loadRequestArray addObject:request];
    if (self.isRunning) {
        //当前有正在加载的资源，新添加进来资源，排队
        return;
    }
    //空闲状态，立即开始加载资源
    [self beginLoadResource:request];
}
```
我用了isRunning标识表示当前是否有别的资源正在加载，如果有，将返回true,新的资源只能待定，否则即时“空闲状态”，可以立刻加载新的资源。

**判断从缓存还是下载获取资源**
根据request我们获取要请求的Range：

```
NSURL *URL = [self originURL:request.request.URL];
long long offset = request.dataRequest.requestedOffset;
long long length = request.dataRequest.requestedLength;
```

然后根据range判断本地是否有该判断缓存，如果没有，则下载：

```
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
```

如果本地缓存获取到data，（缓存存取由KWFileManager实现，后面再具体说）则将data和头信息回调给上层，然后继续加载下一个资源；如果没有缓存，则开启一个下载任务。

downloader是由KWResouceDowloader实现：

下载我主要是采用NSURLSessionTask实现，由于要指定下载片段，所以我们request要设置HTTPHeaderField字段range:

```
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
```

这样，就会下载该音视频指定位置长度的二进制文件，而不是整部下载，所以这是一个分片下载器。
然后有SessionDelegate代理得到下载的结果：

```
#pragma mark - NSURLSessionDelegate

//开始接受数据
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    //设置contentInformation
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
```

**关于contentInfomation**
在上面didResponse开始返回数据前，我们可以提取该资源的格式、长度信息：

```
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
```

注意点：
1.info.byteRangeAccessSupported 这里我本来是根据headerFields获取是否支持分片下载，后面我发现很多视频headerField并没有指明是否支持分片下载，但是测试发现，这些未指明的视频都是可以分片下载的，然后我网上查了一下，发现基本95%以上的服务器是支持分片下载的，所以这里我全部默认为可分片下载了。

2.获取的头信息由于以便于下次不用下载，所以这里要写入本地缓存。

3.提供Task cancel功能，以便于外部可随时取消该资源下载。

######KWFileManager
**该文件负责缓存的读取、存储、清理等功能。**

由于是缓存，所以，我放在了Cache主目录下，然后新建了音视频根目录：

```
+ (NSString *)cacheRootPath {
    //将下载默认存放地址移到缓存目录下
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                               NSUserDomainMask, YES) lastObject];
    //缓存根目录
    NSString *mediaPath = [cachePath stringByAppendingPathComponent:kMediaCachePath];
    return mediaPath;
}
```

**1.将URL的Md5值作为某个资源的文件夹名称**
由于每个每个资源URL长度不一，考虑到Md5唯一性和长度一致的特性，所以讲md5值作为key是非常合适的。

**2.某个片段文件名以“startOffset_endOffset_sugguestName”命名**

```
NSString *fileName = [NSString stringWithFormat:@"%lld_%lld_%@",offset,
                          endOffset,task.response.suggestedFilename];
```

这样存储的文件最终形态如下图所示：

![缓存目录结构](https://upload-images.jianshu.io/upload_images/1413134-a075cbd03f7c8fa9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我是以每个下载请求的Range+name作为文件名，这样文件名称就包含了资源的位置长度，以便于下次快速检索从缓存读取的文件。

那么，由于下次请求的位置和长度不可能刚好和缓存中的一样长，那么这里采取了2种方式：
- 1.优先单个碎片文件，取子集：

```
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
```

- 跨碎片拼接：有些碎片头尾是可以连接成一个大的碎片的，然后再去子集：

```
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
```
上面在查找下一个连续的碎片采取了递归方式：

```
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
```

以上是缓存处理文件的主要难点。其他的文件写入、删除常规操作，故不再叙述。


以上就是我这个项目的主要细节。

####项目评价

- **优点**

1.实现了边播放边缓存资源

2.支持seek操作，可立即从新的进度继续播放，较流畅

3.支持片段缓存，而不是仅仅整体缓存，节省了用户流量

4.支持缓存自定义清理，可以清理单个资源文件

- **待优化点**

1.某些资源频繁cancel请求的问题，当第一次触发了cancel请求后，第二次请求过程中，即便有部分缓存，视频不会立即播放，必须等待本次片段全部请求完毕才开始播放。这个原因尚不明确，因为resouceLoader是个黑匣子，理论上，下载过程中是不必等到finishLoading完毕后才播放资源，只要resonseWithData:给缓冲区塞给了足够可播放的data即可播放，但是第一次cancel后新价值的资源总是要带到加载完毕才播放，用户等待较长，但是一般出现该请求都是弱网络产生，一般情况下流畅度不错。

2.缓存获取我的方案理论上不是最优解，因为我没有考虑本地有部分缓存，另外部分需要下载的情况。但是，这中方案理论上会多出很多的请求次数，增加了请求次数和复杂度，所以最终没有采用，不排除后续会优化这一处。


- **总结**

整体项目前后花了大约1星期的时间完成，由于以前对AVAssetResourceLoader并没有接触过，很多属性和方法都是自己摸索着尝试，通过大量的测试，基本上摸清了resouceLoaderDelegate的”脾气“。

整体效果比较满意，当然，网上也研究了别的同学的方案，最终我还是采用了自己的缓存思路实现，锻炼了能力，虽然不是最优解，但是**经过了大量优化测试，bug较少，现在将项目开源出来，和大家一起分享，如果有觉得这个方案对自己有用，就给个star 吧**，同时以热烈欢迎对音视频有兴趣的同学和我留言，继续探讨更优化的方案哦，谢谢~

[KWResourceLoader](https://github.com/GithubXkw1573/KWResourceLoader)

demo效果图：

![demo截图](https://upload-images.jianshu.io/upload_images/1413134-21ac1976a49b42fd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)