//
//  MLMultiArray+Enumerate.m
//  DynamicCoreMLDemo
//
//  Created by Kyle on 04/07/2017.
//  Copyright © 2017 KyleWong. All rights reserved.
//

#import "MLMultiArray+Enumerate.h"

@implementation MLMultiArray (Enumerate)
+ (void)enumerateToDo:(NSArray *)aToDoAry doneAry:(NSArray *)aDoneAry block:(void (^)(NSArray *))aBlock{
    if(aToDoAry.count==1){
        NSInteger len=[aToDoAry.lastObject integerValue];
        for(NSInteger i=0;i<len;i++){
            NSMutableArray *allAry = [NSMutableArray arrayWithArray:aDoneAry];
            [allAry insertObject:@(i) atIndex:0];
            if(aBlock)
                aBlock(allAry);
        }
    }
    else{
        NSMutableArray *toDoAry = [[NSMutableArray arrayWithArray:aToDoAry] subarrayWithRange:NSMakeRange(0, aToDoAry.count-1)];
        NSInteger len = [toDoAry.lastObject integerValue];
        for(NSInteger i=0;i<len;i++){
            NSMutableArray *doneAry = [NSMutableArray arrayWithArray:aDoneAry];
            [doneAry addObject:@(i)];
            [self enumerateToDo:toDoAry doneAry:doneAry block:aBlock];
        }
    }
}
@end
