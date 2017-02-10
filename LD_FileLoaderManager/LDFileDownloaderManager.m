//
//  LDFileDownloaderManager.m
//  LD_FileLoaderManager
//
//  Created by Done.L (liudongdong@qiyoukeji.com) on 2017/2/10.
//  Copyright © 2017年 Done.L (liudongdong@qiyoukeji.com). All rights reserved.
//

#import "LDFileDownloaderManager.h"

#import <UIKit/UIKit.h>

static const NSInteger MAX_DOWNLOAD_TASK_CONCURRENT_COUNT = 2;

static LDFileDownloaderManager *fileDownloadManager = nil;

@interface LDFileDownloaderManager ()

@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroudTaskId;

@property (nonatomic, strong) NSMutableDictionary *downloadTaskDict;

@property (nonatomic, strong) NSMutableArray *downloadTaskQueue;

@end

@implementation LDFileDownloaderManager

+ (LDFileDownloaderManager *)shareManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fileDownloadManager = [[LDFileDownloaderManager alloc] init];
    });
    return fileDownloadManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _backgroudTaskId = UIBackgroundTaskInvalid;
        _downloadTaskDict = [NSMutableDictionary dictionary];
        _downloadTaskQueue = [NSMutableArray array];
        
        //注册程序下载完成的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskDidFinishDownloading:) name:LDDownloadTaskDidFinishNotification object:nil];
        //注册系统内存不足的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(systemSpaceInsufficient:) name:LDSystemSpaceInsufficientNotification object:nil];
        //注册程序即将失去焦点的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskWillResign:) name:UIApplicationWillResignActiveNotification object:nil];
        //注册程序获得焦点的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskDidBecomActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        //注册程序即将被终结的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskWillBeTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void)ld_downloadWithUrlString:(NSString *)url destination:(NSString *)destination progressHandler:(LD_ProgressHandler)progressHandler completionHandler:(LD_CompletionHandler)completionHandler errorHandler:(LD_ErrorHandler)errorHandler {
    
    NSCAssert(url.length == 0 || destination.length == 0 || progressHandler == nil || completionHandler == nil || errorHandler == nil, @"Error: empty paramters input!");
    
    if (self.downloadTaskDict.count >= MAX_DOWNLOAD_TASK_CONCURRENT_COUNT) {
        NSDictionary *cacheTaskDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                       url, @"downloadTaskUrl",
                                       destination, "destination",
                                       progressHandler, "progressHandler",
                                       completionHandler, "completionHandler",
                                       errorHandler, "errorHandler",
                                       nil];
        [self.downloadTaskQueue addObject:cacheTaskDict];
    }
    
    LDFileLoader *fileLoader = [LDFileLoader fileLoader];
    @synchronized (self) {
        [_downloadTaskDict setObject:fileLoader forKey:url];
    }
    [fileLoader ld_downloadWithUrlString:url destination:destination progressHandler:progressHandler completionHandler:completionHandler errorHandler:errorHandler];
}

- (void)ld_cancelDownloadTask:(NSString *)url {
    LDFileLoader *fileLoader = self.downloadTaskDict[url];
    [fileLoader ld_pause];
    @synchronized (self) {
        [_downloadTaskDict removeObjectForKey:url];
    }
    
    if (self.downloadTaskQueue.count > 0) {
        NSDictionary *cacheTaskDict = self.downloadTaskQueue[0];
        [self ld_downloadWithUrlString:cacheTaskDict[@"downloadTaskUrl"] destination:cacheTaskDict[@"destination"] progressHandler:cacheTaskDict[@"progressHandler"] completionHandler:cacheTaskDict[@"completionHandler"] errorHandler:cacheTaskDict[@"errorHandler"]];
        
        [self.downloadTaskQueue removeObject:cacheTaskDict];
    }
}

- (void)ld_cancelAllTasks {
    [self.downloadTaskDict enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[LDFileLoader class]]) {
            LDFileLoader *fileLoader = obj;
            [fileLoader ld_pause];
            [_downloadTaskDict removeObjectForKey:key];
        }
    }];
}

- (void)ld_removeDownloadFile:(NSString *)url {
    LDFileLoader *fileLoader = self.downloadTaskDict[url];
    if (fileLoader) {
        [fileLoader ld_pause];
        [fileLoader ld_cancel];
    }
    @synchronized (self) {
        [_downloadTaskDict removeObjectForKey:url];
    }
}

- (float)ld_lastProgress:(NSString *)url {
    return [LDFileLoader lastProgress:url];
}

- (void)downloadTaskDidFinishDownloading:(NSNotification *)notify {
    
}

- (void)systemSpaceInsufficient:(NSNotification *)notify {
    
}

- (void)downloadTaskWillResign:(NSNotification *)notify {
    
}

- (void)downloadTaskDidBecomActive:(NSNotification *)notify {
    
}

- (void)downloadTaskWillBeTerminate:(NSNotification *)notify {
    
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
