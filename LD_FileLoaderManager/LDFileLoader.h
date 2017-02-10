//
//  LDFileLoader.h
//  LD_FileLoaderManager
//
//  Created by Done.L (liudongdong@qiyoukeji.com) on 2017/2/10.
//  Copyright © 2017年 Done.L (liudongdong@qiyoukeji.com). All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  下载完成的通知名
 */
static NSString * const LDDownloadTaskDidFinishNotification = @"LDDownloadTaskDidFinishNotification";
/**
 *  系统存储空间不足的通知名
 */
static NSString * const LDSystemSpaceInsufficientNotification = @"LDSystemSpaceInsufficientNotification";
/**
 *  下载进度改变的通知
 */
static NSString * const LDProgressDidChangeNotificaiton = @"LDProgressDidChangeNotificaiton";

typedef void(^LD_ProgressHandler)(float progress, NSString *speed, NSUInteger completedUnitCount, NSUInteger totalUnitCount);
typedef void(^LD_CompletionHandler)(NSString *filePath);
typedef void(^LD_ErrorHandler)(NSError *error);

@interface LDFileLoader : NSObject

@property (nonatomic, copy) NSString *fileURL;

+ (instancetype)fileLoader;

- (void)ld_downloadWithUrlString:(NSString *)url destination:(NSString *)destination progressHandler:(LD_ProgressHandler)progressHandler completionHandler:(LD_CompletionHandler)completionHandler errorHandler:(LD_ErrorHandler)errorHandler;

- (void)ld_pause;

- (void)ld_cancel;

+ (float)lastProgress:(NSString *)url;

@end
