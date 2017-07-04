//
//  JSCCoreMLWrapper.h
//  DynamicCoreMLDemo
//
//  Created by Kyle on 30/06/2017.
//  Copyright © 2017 KyleWong. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger,JSCCoreMLType) {
    JSCCoreMLTypeImg,
};

@interface JSCCoreMLWrapper : NSObject
+ (instancetype)wrapperWithModel:(NSString *)aModelName type:(JSCCoreMLType)aType inputs:(NSArray *)aInputAry;
- (NSString *)recognize;
@end
