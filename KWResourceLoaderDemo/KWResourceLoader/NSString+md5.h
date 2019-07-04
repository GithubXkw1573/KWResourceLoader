//
//  NSString+md5.h
//  Kevin_Study
//
//  Created by kaiwei Xu on 2019/6/27.
//  Copyright © 2019 kaiwei Xu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (md5)

- (NSString *)md5To32bit:(NSString *)str;

@end

NS_ASSUME_NONNULL_END
