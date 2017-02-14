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
    [fileLoader ld_cancel];
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
    [self.downloadTaskDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[LDFileLoader class]]) {
            LDFileLoader *fileLoader = obj;
            [fileLoader ld_cancel];
            [_downloadTaskDict removeObjectForKey:key];
        }
    }];
}

- (void)ld_removeDownloadFileWithUrl:(NSString *)url destination:(NSString *)destination {
    LDFileLoader *fileLoader = self.downloadTaskDict[url];
    if (fileLoader) {
        [fileLoader ld_cancel];
    }
    @synchronized (self) {
        [_downloadTaskDict removeObjectForKey:url];
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [destination stringByAppendingPathComponent:[[NSURL URLWithString:url] lastPathComponent]];
    BOOL fileExist = [fileManager fileExistsAtPath:filePath];
    if (fileExist) {
        [fileManager removeItemAtPath:filePath error:nil];
    }
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_resumeData(url)];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_completedUnitCount(url)];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_totalUnitCount(url)];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_last_progress(url)];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (float)ld_lastProgress:(NSString *)url {
    return [LDFileLoader lastProgress:url];
}

- (void)downloadTaskDidFinishDownloading:(NSNotification *)notify {
    if (notify && notify.userInfo) {
        NSString *downloadTaskUrl = notify.userInfo[@"downloadTaskUrl"];
        [self.downloadTaskDict removeObjectForKey:downloadTaskUrl];
        
        if (self.downloadTaskDict.count < MAX_DOWNLOAD_TASK_CONCURRENT_COUNT) {
            if (self.downloadTaskQueue.count > 0) {
                NSDictionary *cacheTaskDict = self.downloadTaskQueue[0];
                [self ld_downloadWithUrlString:cacheTaskDict[@"downloadTaskUrl"] destination:cacheTaskDict[@"destination"] progressHandler:cacheTaskDict[@"progressHandler"] completionHandler:cacheTaskDict[@"completionHandler"] errorHandler:cacheTaskDict[@"errorHandler"]];
                
                [self.downloadTaskQueue removeObject:cacheTaskDict];
            }
        }
    }
}

- (void)systemSpaceInsufficient:(NSNotification *)notify {
    if (notify && notify.userInfo) {
        NSString *downloadTaskUrl = notify.userInfo[@"downloadTaskUrl"];
        [self ld_cancelDownloadTask:downloadTaskUrl];
    }
}

- (void)downloadTaskWillResign:(NSNotification *)notify {
    if (self.downloadTaskDict.count > 0) {
        self.backgroudTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
    }
}

- (void)downloadTaskDidBecomActive:(NSNotification *)notify {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.backgroudTaskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroudTaskId];
            self.backgroudTaskId = UIBackgroundTaskInvalid;
        }
    });
}

- (void)downloadTaskWillBeTerminate:(NSNotification *)notify {
    [self ld_cancelAllTasks];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
