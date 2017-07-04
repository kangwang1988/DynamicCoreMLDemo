//
//  MLMultiArray+Enumerate.h
//  DynamicCoreMLDemo
//
//  Created by Kyle on 04/07/2017.
//  Copyright © 2017 KyleWong. All rights reserved.
//

#import <CoreML/CoreML.h>

@interface MLMultiArray (Enumerate)
+ (void)enumerateToDo:(NSArray *)aToDoAry doneAry:(NSArray *)aDoneAry block:(void (^)(NSArray *))aBlock;
@end
