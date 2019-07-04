//
//  KWHttpInfomation.h
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/6/27.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KWHttpInfomation : NSObject <NSCoding>

@property (nonatomic, copy) NSString *contentType;
@property (nonatomic, assign) BOOL byteRangeAccessSupported;//是否支持range分片下载
@property (nonatomic, assign) unsigned long long contentLength;
@property (nonatomic) unsigned long long downloadedContentLength;

@end

NS_ASSUME_NONNULL_END
