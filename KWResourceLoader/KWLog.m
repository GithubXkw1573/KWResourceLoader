//
//  KWLog.m
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/7/3.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import "KWLog.h"

@interface KWLog ()

@end

@implementation KWLog

static KWLog *sharedInstance = nil;
static dispatch_once_t onceToken;

+ (KWLog *)instance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[KWLog alloc] init];
        sharedInstance.debugOpen = NO;
    });
    return sharedInstance;
}

+ (void)kwLog:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2) {
    KWLog *log = [self instance];
    if (log.debugOpen) {
        va_list args;
        va_start(args, format);
        NSString *rst = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSLog(@"%@", rst);
    }
}

@end
