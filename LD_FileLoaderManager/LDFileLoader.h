//
//  LDFileLoader.h
//  LD_FileLoaderManager
//
//  Created by Done.L (liudongdong@qiyoukeji.com) on 2017/2/10.
//  Copyright © 2017年 Done.L (liudongdong@qiyoukeji.com). All rights reserved.
//

#import <Foundation/Foundation.h>

#define Cache_resumeData(url) [NSString stringWithFormat:@"%@_resumeData", url]
#define Cache_completedUnitCount(url) [NSString stringWithFormat:@"%@_completedUnitCount", url]
#define Cache_totalUnitCount(url) [NSString stringWithFormat:@"%@_totalUnitCount", url]
#define Cache_last_progress(url) [NSString stringWithFormat:@"%@_last_progress", url]

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

/**
 *  下载操作的进度回调
 */
typedef void(^LD_ProgressHandler)(float progress, NSString *speed, NSUInteger completedUnitCount, NSUInteger totalUnitCount);
/**
 *  下载操作的完成回调
 */
typedef void(^LD_CompletionHandler)(NSString *filePath);
/**
 *  下载操作的错误回调
 */
typedef void(^LD_ErrorHandler)(NSError *error);

@interface LDFileLoader : NSObject

/**
 *  下载操作对象的实例化方法
 */
+ (instancetype)fileLoader;

/**
 *  下载操作的进度回调
 *  url                     文件的地址链接
 *  destination             文件的保存路径目录
 *  progressHandler         下载进度回调
 *  completionHandler       下载完成回调
 *  errorHandler            下载失败回调
 */
- (void)ld_downloadWithUrlString:(NSString *)url destination:(NSString *)destination progressHandler:(LD_ProgressHandler)progressHandler completionHandler:(LD_CompletionHandler)completionHandler errorHandler:(LD_ErrorHandler)errorHandler;

/**
 *  取消下载
 */
- (void)ld_cancel:(void(^)())completion;

/**
 *  获取某个url对应的下载进度 (NSUserDefaults)
 */
+ (float)lastProgress:(NSString *)url;

@end
