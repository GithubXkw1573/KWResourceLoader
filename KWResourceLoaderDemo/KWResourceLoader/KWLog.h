//
//  KWLog.h
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/7/3.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KWLog : NSObject

@property (nonatomic, assign) BOOL debugOpen;

+ (KWLog *)instance;

+ (void)kwLog:(NSString *)format, ...;

@end

NS_ASSUME_NONNULL_END
