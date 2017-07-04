//
//  JSCCoreMLWrapper.m
//  DynamicCoreMLDemo
//
//  Created by Kyle on 30/06/2017.
//  Copyright © 2017 KyleWong. All rights reserved.
//

#import "JSCCoreMLWrapper.h"
#import <ZipArchive/ZipArchive.h>
#import <CoreML/CoreML.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <UIKit/UIKit.h>
#import "MLMultiArray+Enumerate.h"

@interface JSCCoreMLFeatureProvider:NSObject<MLFeatureProvider>
@property (nonatomic,assign) JSCCoreMLType mlType;
@property (nonatomic,copy) NSDictionary *jsJson;
@property (nonatomic,strong) JSContext *context;
@property (nonatomic,strong) NSArray *inputAry;
@property (nonatomic,strong) NSMutableDictionary *ftValueDict;
@end

@implementation JSCCoreMLFeatureProvider
- (instancetype)initWithType:(JSCCoreMLType)aMLType jsPath:(NSString *)aJSPath inputs:(NSArray *)aInputAry{
    if(self = [super init]){
        _context = [JSContext new];
        _jsJson = [NSDictionary dictionaryWithContentsOfFile:aJSPath];
        _inputAry = aInputAry;
        _ftValueDict = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSSet<NSString *> *)featureNames{
    NSString *funcName = @"in_featureNames";
    [self.context evaluateScript:self.jsJson[funcName]];
    return [NSSet setWithArray:[[self.context[funcName] callWithArguments:@[]] toArray]];
}

/// Returns nil if the provided featureName is not in the set of featureNames
- (nullable MLFeatureValue *)featureValueForName:(NSString *)featureName{
    NSString *infoFtFuncName = @"in_info_featureValueForName";
    [self.context evaluateScript:self.jsJson[infoFtFuncName]];
    NSDictionary *infoFtValue = [[self.context[infoFtFuncName] callWithArguments:@[featureName]] toDictionary];
    if(self.ftValueDict[featureName]){
        return self.ftValueDict[featureName];
    }
    switch (self.mlType) {
        case JSCCoreMLTypeImg:
        {
            UIImage *img = [[UIImage alloc] initWithContentsOfFile:self.inputAry.firstObject];
            UInt8 *pData = CFDataGetBytePtr(CGDataProviderCopyData(CGImageGetDataProvider(img.CGImage)));
            NSMutableArray *dataAry = [NSMutableArray array];
            for(NSInteger i=0;i<img.size.width*img.size.height;i++){
                for(NSInteger j=0;j<4;j++)
                    dataAry[4*i+j]=@(pData[4*i+j]);
            }
            NSString *ftValueFuncName = @"in_featureValueForName";
            [self.context evaluateScript:self.jsJson[ftValueFuncName]];
            NSDictionary *ftValueDict = [[self.context[ftValueFuncName] callWithArguments:@[featureName,@(img.size.width),@(img.size.height),dataAry]] toDictionary];
            NSError *err;
            MLMultiArray *mlMulAry = [[MLMultiArray alloc] initWithShape:infoFtValue[@"shape"] dataType:[infoFtValue[@"dataType"] integerValue] error:&err];
            [MLMultiArray enumerateToDo:mlMulAry.shape doneAry:nil block:^(NSArray *aSubscriptAry) {
                NSString *key = [[aSubscriptAry valueForKey:@"stringValue"] componentsJoinedByString:@"-"];
                [mlMulAry setObject:ftValueDict[key] forKeyedSubscript:aSubscriptAry];
            }];
            MLFeatureValue *ftValue = [MLFeatureValue featureValueWithMultiArray:mlMulAry];
            self.ftValueDict[featureName] = ftValue;
            return ftValue;
            break;
        }
        default:
            break;
    }
    return nil;
}

- (NSString *)formatReadableDesc:(id<MLFeatureProvider>)predication{
    NSString *funcName = @"out_featureNames";
    [self.context evaluateScript:self.jsJson[funcName]];
    NSArray *fts = [[self.context[funcName] callWithArguments:@[]] toArray];
    NSMutableDictionary *ftValueDict = [NSMutableDictionary dictionary];
    for(NSString *ftName in fts){
        MLFeatureValue *ftValue = [predication featureValueForName:ftName];
        NSDictionary *typeSelDict = @{@(MLFeatureTypeInt64):@"int64Value",@(MLFeatureTypeDouble):@"doubleValue",@(MLFeatureTypeString):@"stringValue",@(MLFeatureTypeDictionary):@"dictionaryValue"};
        if(typeSelDict[@(ftValue.type)]){
            ftValueDict[ftName]=[ftValue performSelector:NSSelectorFromString(typeSelDict[@(ftValue.type)])];
        }
        else if(ftValue.type == MLFeatureTypeMultiArray){
            MLMultiArray *mlMulAry = [ftValue multiArrayValue];
            NSMutableDictionary *multiValueDict = [NSMutableDictionary dictionary];
            [MLMultiArray enumerateToDo:mlMulAry.shape doneAry:nil block:^(NSArray *aSubscriptAry) {
                NSString *key = [[aSubscriptAry valueForKey:@"stringValue"] componentsJoinedByString:@"-"];
                [multiValueDict setObject:[mlMulAry objectForKeyedSubscript:aSubscriptAry] forKeyedSubscript:key];
            }];
            ftValueDict[ftName]=multiValueDict;
        }
    }
    funcName = @"out_formatPrediction";
    [self.context evaluateScript:self.jsJson[funcName]];
    return [[self.context[funcName] callWithArguments:@[ftValueDict]] toString];
}
@end

@interface JSCCoreMLWrapper()
@property (nonatomic,strong) JSCCoreMLFeatureProvider *ftProvider;
@property (nonatomic,strong) MLModel *model;
@end

@implementation JSCCoreMLWrapper
+ (instancetype)wrapperWithModel:(NSString *)aModelName type:(JSCCoreMLType)aType inputs:(NSArray *)aInputAry{
    if([self checkIfDownloadModelWithName:aModelName]){
        return nil;
    }
    JSCCoreMLWrapper *wrapper = [[JSCCoreMLWrapper alloc] initWithModel:aModelName type:aType inputs:aInputAry];
    return wrapper;
}

- (instancetype)initWithModel:(NSString *)aModelName type:(JSCCoreMLType)aType inputs:(NSArray *)aInputAry{
    if(self = [super init]){
        NSString *modelPrefix = [NSString stringWithFormat:@"%@/%@",[[self class] modelBaseDir],aModelName];
        _model = [MLModel modelWithContentsOfURL:[NSURL fileURLWithPath:[modelPrefix stringByAppendingString:@".mlmodelc"]] error:nil];
        _ftProvider = [[JSCCoreMLFeatureProvider alloc] initWithType:aType jsPath:[modelPrefix stringByAppendingString:@".js.plist"] inputs:aInputAry];
    }
    return self;
}

+ (NSString *)modelBaseDir{
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDir = dirs.firstObject;
    return [documentDir stringByAppendingPathComponent:@"Models"];
}

- (NSString *)recognize{
    NSError *error;
    id<MLFeatureProvider> predication = [self.model predictionFromFeatures:self.ftProvider error:&error];
    return [self.ftProvider formatReadableDesc:predication];
}

+ (BOOL)checkIfDownloadModelWithName:(NSString *)aModelName{
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libDir = dirs.firstObject;
    NSString *jsPath = [NSString stringWithFormat:@"%@/%@.js.plist",[self modelBaseDir],aModelName];
    NSString *modelPath = [NSString stringWithFormat:@"%@/%@.mlmodelc",[self modelBaseDir],aModelName];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL bFolder;
    if([fm fileExistsAtPath:jsPath] && [fm fileExistsAtPath:modelPath isDirectory:&bFolder] && bFolder){
        return NO;
    }
    NSString *modelUrl = [NSString stringWithFormat:@"https://raw.githubusercontent.com/kangwang1988/kangwang1988.github.io/master/others/%@.zip",aModelName];
    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:modelUrl] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(!error){
            NSString *zipFile = [NSString stringWithFormat:@"%@/%@.zip",libDir,aModelName];
            [data writeToFile:zipFile atomically:YES];
            ZipArchive *za = [[ZipArchive alloc] init];
            NSError *err = nil;
            if([za UnzipOpenFile:zipFile]){
                if(![fm fileExistsAtPath:[self modelBaseDir]]){
                    [fm createDirectoryAtPath:[self modelBaseDir] withIntermediateDirectories:YES attributes:nil error:&err];
                }
                [za UnzipFileTo:libDir overWrite:YES];
                NSString *tmpJSPath = [NSString stringWithFormat:@"%@/%@/%@.js.plist",libDir,aModelName,aModelName];
                [fm copyItemAtPath:tmpJSPath toPath:jsPath error:&err];
                NSString *tmpModelPath = [NSString stringWithFormat:@"%@/%@/%@.mlmodelc",libDir,aModelName,aModelName];
                [fm copyItemAtPath:tmpModelPath toPath:modelPath error:&err];
                [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",libDir,aModelName] error:&err];
            }
            [fm removeItemAtPath:zipFile error:&err];
            [za UnzipCloseFile];
        }
        else{
            
        }
    }] resume];
    return YES;
}
@end
