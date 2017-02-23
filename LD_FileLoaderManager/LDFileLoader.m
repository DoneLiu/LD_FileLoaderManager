//
//  LDFileLoader.m
//  LD_FileLoaderManager
//
//  Created by Done.L (liudongdong@qiyoukeji.com) on 2017/2/10.
//  Copyright © 2017年 Done.L (liudongdong@qiyoukeji.com). All rights reserved.
//

#import "LDFileLoader.h"

#import "AFNetworking.h"
#import "LDFileDownloaderManager.h"

static NSInteger CAPATICY_SCALE = 1024;

static NSInteger AUTOMIC_CANCEL_DURATION = 0;

/**
 *  系统可用磁盘空间阈值 (20MB)
 */
static NSInteger SYSTEM_AVAILABLE_SPACE = 1024 * 1024 * 20;

@interface LDFileLoader ()

@property (nonatomic, strong) AFURLSessionManager *sessionManager;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;

@property (nonatomic, copy) LD_ProgressHandler progressHandler;
@property (nonatomic, copy) LD_CompletionHandler completionHandler;
@property (nonatomic, copy) LD_ErrorHandler errorHandler;

// 下载文件的url
@property (nonatomic, copy) NSString *fileURL;
// 下载文件的保存路径
@property (nonatomic, copy) NSString *destination;
// 计算下载速率的定时器
@property (nonatomic, strong) NSTimer *downloadSpeedTimer;
// 每秒下载的文件大小
@property (nonatomic, assign) NSUInteger fileLengthGrowthPerSecond;
// 当前定时器周期已下载的文件大小
@property (nonatomic, assign) NSUInteger bytesWritten;
// 上次定时器周期已下载的文件大小
@property (nonatomic, assign) NSUInteger lastBytesWritten;
// 实时下载进度
@property (nonatomic, assign) float progress;
// 实时下载的大小
@property (nonatomic, assign) NSUInteger completedUnitCount;
// 文件的总大小
@property (nonatomic, assign) NSUInteger totalUnitCount;


@end

@implementation LDFileLoader

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _sessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    }
    return self;
}

+ (instancetype)fileLoader {
    return [[[self class] alloc] init];
}

#pragma mark - Public

- (void)ld_downloadWithUrlString:(NSString *)url destination:(NSString *)destination progressHandler:(LD_ProgressHandler)progressHandler completionHandler:(LD_CompletionHandler)completionHandler errorHandler:(LD_ErrorHandler)errorHandler {
    NSAssert(url, @"下载路径是空的啊！！！");
    if (url && destination) {
        // 文件下载url
        self.fileURL = url;
        self.destination = destination;
        
        self.progressHandler = progressHandler;
        self.completionHandler = completionHandler;
        self.errorHandler = errorHandler;
        
        // 下载速率定时器设置
        if (!self.downloadSpeedTimer) {
            self.downloadSpeedTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(fileLengthGrowth) userInfo:nil repeats:YES];
        }
        
        // 从缓存中读取resumeData，判断是否是同一个文件的第一次点击操作
        NSData *resumeData = [[NSUserDefaults standardUserDefaults] objectForKey:Cache_resumeData(url)];
        if (!resumeData) {
            [self downloadTaskWithUrl:url destination:destination];
        } else {
            [self downloadTaskWithResumeData:resumeData url:url destination:destination];
        }
        
        [self.sessionManager setDownloadTaskDidWriteDataBlock:^(NSURLSession * _Nonnull session, NSURLSessionDownloadTask * _Nonnull downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            _bytesWritten = totalBytesWritten;
        }];
    }
}

- (void)ld_cancel:(void(^)())completion {
    if (_downloadTask.state == NSURLSessionTaskStateRunning) {
        [_downloadTask suspend];
        
        __weak LDFileLoader *weakSelf = self;
        [_downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            NSLog(@"cancelByProducingResumeData thread = %@", [NSThread currentThread]);
            
            [weakSelf regenerateResumeData:resumeData];
            
            [[NSUserDefaults standardUserDefaults] setObject:resumeData forKey:Cache_resumeData(weakSelf.fileURL)];
            [[NSUserDefaults standardUserDefaults] setObject:[weakSelf convertFileLengthGrowthToSpeed:weakSelf.completedUnitCount] forKey:Cache_completedUnitCount(weakSelf.fileURL)];
            [[NSUserDefaults standardUserDefaults] setObject:[weakSelf convertFileLengthGrowthToSpeed:weakSelf.totalUnitCount] forKey:Cache_totalUnitCount(weakSelf.fileURL)];
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:weakSelf.progress] forKey:Cache_last_progress(weakSelf.fileURL)];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            weakSelf.downloadTask = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion();
                }
            });
        }];
        
        if (self.downloadSpeedTimer) {
            [self.downloadSpeedTimer invalidate];
            self.downloadSpeedTimer = nil;
        }
    }
}

+ (float)lastProgress:(NSString *)url {
    float progress = 0.0;
    if(url) {
        progress = [[[NSUserDefaults standardUserDefaults] objectForKey:Cache_last_progress(url)] floatValue];
    }
    return progress;
}

#pragma mark - Private

- (void)downloadTaskWithUrl:(NSString *)url destination:(NSString *)destination {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    __weak LDFileLoader *weakSelf = self;
    self.downloadTask = [self.sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        
        // 实时判断系统磁盘空间是否充足，发送系统空间不足通知
        NSUInteger systemAvailableSpace = [weakSelf systemAvailableSpace];
        if (systemAvailableSpace <= SYSTEM_AVAILABLE_SPACE) {
            [[NSNotificationCenter defaultCenter] postNotificationName:LDSystemSpaceInsufficientNotification object:nil userInfo:@{@"downloadTaskUrl" : weakSelf.fileURL}];
        };
        
        weakSelf.completedUnitCount = downloadProgress.completedUnitCount;
        weakSelf.totalUnitCount = downloadProgress.totalUnitCount;
        weakSelf.progress = 1.0 * weakSelf.completedUnitCount / weakSelf.totalUnitCount;
        
        // 获取下载实时进度，发送进度变化通知
        NSDictionary *userInfo = @{@"downloadTaskUrl" : url, @"download_progress" : @(weakSelf.progress), @"completedUnitCount" : @(weakSelf.completedUnitCount), @"totalUnitCount" : @(weakSelf.totalUnitCount)};
        [[NSNotificationCenter defaultCenter] postNotificationName:LDProgressDidChangeNotificaiton object:nil userInfo:userInfo];
        
        if (weakSelf.progressHandler) {
            weakSelf.progressHandler(weakSelf.progress, [weakSelf convertFileLengthGrowthToSpeed:_fileLengthGrowthPerSecond], weakSelf.completedUnitCount, weakSelf.totalUnitCount);
        }
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        // 创建保存下载文件的文件夹
        BOOL isDir = NO;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL existed = [fileManager fileExistsAtPath:destination isDirectory:&isDir];
        if (!(isDir == YES && existed == YES)) {
            [fileManager createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:nil];
        }

        NSString *savePath = [destination stringByAppendingPathComponent:response.suggestedFilename];
        return [NSURL fileURLWithPath:savePath];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if (!error) {
            if (weakSelf.completionHandler) {
                // 发送下载完成通知
                [[NSNotificationCenter defaultCenter] postNotificationName:LDDownloadTaskDidFinishNotification object:nil userInfo:@{@"downloadTaskUrl":weakSelf.fileURL}];
                
                // 下载完成，删除缓存（包括resumeData缓存、进度缓存）
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_resumeData(weakSelf.fileURL)];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_completedUnitCount(weakSelf.fileURL)];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_totalUnitCount(weakSelf.fileURL)];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_last_progress(weakSelf.fileURL)];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                weakSelf.completionHandler(filePath.path);
            }
        } else {
            if (weakSelf.errorHandler) {
                weakSelf.errorHandler(error);
            }
        }
    }];
    [self.downloadTask resume];
}

- (void)downloadTaskWithResumeData:(NSData *)resumeData url:(NSString *)url destination:(NSString *)destination {
    NSAssert(resumeData, @"缓存数据是空的啊！！！");
    
    __weak LDFileLoader *weakSelf = self;
    self.downloadTask = [self.sessionManager downloadTaskWithResumeData:resumeData progress:^(NSProgress * _Nonnull downloadProgress) {
        
        // 实时判断系统磁盘空间是否充足，发送系统空间不足通知
        NSUInteger systemAvailableSpace = [self systemAvailableSpace];
        if (systemAvailableSpace <= SYSTEM_AVAILABLE_SPACE) {
            [[NSNotificationCenter defaultCenter] postNotificationName:LDSystemSpaceInsufficientNotification object:nil userInfo:@{@"downloadTaskUrl" : weakSelf.fileURL}];
        };
        
        weakSelf.completedUnitCount = downloadProgress.completedUnitCount;
        weakSelf.totalUnitCount = downloadProgress.totalUnitCount;
        self.progress = 1.0 * weakSelf.completedUnitCount / weakSelf.totalUnitCount;
        
        // 获取下载实时进度，发送进度变化通知
        NSDictionary *userInfo = @{@"downloadTaskUrl" : url, @"download_progress" : @(weakSelf.progress), @"completedUnitCount" : @(weakSelf.completedUnitCount), @"totalUnitCount" : @(weakSelf.totalUnitCount)};
        [[NSNotificationCenter defaultCenter] postNotificationName:LDProgressDidChangeNotificaiton object:nil userInfo:userInfo];
        
        if (weakSelf.progressHandler) {
            weakSelf.progressHandler(weakSelf.progress, [weakSelf convertFileLengthGrowthToSpeed:_fileLengthGrowthPerSecond], weakSelf.completedUnitCount, weakSelf.totalUnitCount);
        }
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        // 创建保存下载文件的文件夹
        BOOL isDir = NO;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL existed = [fileManager fileExistsAtPath:destination isDirectory:&isDir];
        if (!(isDir == YES && existed == YES)) {
            [fileManager createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        NSString *savePath = [destination stringByAppendingPathComponent:response.suggestedFilename];
        return [NSURL fileURLWithPath:savePath];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if (!error) {
            if (weakSelf.completionHandler) {
                // 发送下载完成通知
                [[NSNotificationCenter defaultCenter] postNotificationName:LDDownloadTaskDidFinishNotification object:nil userInfo:@{@"downloadTaskUrl":weakSelf.fileURL}];
                
                // 下载完成，删除缓存（包括resumeData缓存、进度缓存）
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_resumeData(weakSelf.fileURL)];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_completedUnitCount(weakSelf.fileURL)];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_totalUnitCount(weakSelf.fileURL)];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:Cache_last_progress(weakSelf.fileURL)];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                weakSelf.completionHandler(filePath.path);
            }
        } else {
            if (weakSelf.errorHandler) {
                weakSelf.errorHandler(error);
            }
        }
    }];
    [self.downloadTask resume];
}

- (void)fileLengthGrowth {
    _fileLengthGrowthPerSecond = _bytesWritten - _lastBytesWritten;
    _lastBytesWritten = _bytesWritten;
    
    AUTOMIC_CANCEL_DURATION += 1;
    if (AUTOMIC_CANCEL_DURATION == 5) {
        AUTOMIC_CANCEL_DURATION = 0;
        [self ld_cancel:^{
            NSLog(@"%s [NSThread currentThread] = %@", __FUNCTION__, [NSThread currentThread]);
            
            // 下载速率定时器设置
            if (!self.downloadSpeedTimer) {
                self.downloadSpeedTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(fileLengthGrowth) userInfo:nil repeats:YES];
            }
            
            // 从缓存中读取resumeData，判断是否是同一个文件的第一次点击操作
            NSData *resumeData = [[NSUserDefaults standardUserDefaults] objectForKey:Cache_resumeData(self.fileURL)];
            if (!resumeData) {
                [self downloadTaskWithUrl:self.fileURL destination:self.destination];
            } else {
                [self downloadTaskWithResumeData:resumeData url:self.fileURL destination:self.destination];
            }
        }];
    }
}

- (NSString *)convertFileLengthGrowthToSpeed:(NSUInteger)fileLengthGrowth {
    if(fileLengthGrowth < CAPATICY_SCALE) {
        return [NSString stringWithFormat:@"%ldB",(NSUInteger)fileLengthGrowth];
    } else if (fileLengthGrowth >= CAPATICY_SCALE && fileLengthGrowth < CAPATICY_SCALE * CAPATICY_SCALE) {
        return [NSString stringWithFormat:@"%.0fK",(float)fileLengthGrowth / CAPATICY_SCALE];
    } else if (fileLengthGrowth >= CAPATICY_SCALE * CAPATICY_SCALE && fileLengthGrowth < CAPATICY_SCALE * CAPATICY_SCALE * CAPATICY_SCALE) {
        return [NSString stringWithFormat:@"%.1fM",(float)fileLengthGrowth / (CAPATICY_SCALE * CAPATICY_SCALE)];
    } else {
        return [NSString stringWithFormat:@"%.1fG",(float)fileLengthGrowth / (CAPATICY_SCALE * CAPATICY_SCALE * CAPATICY_SCALE)];
    }
}

- (NSData *)regenerateResumeData:(NSData *)originData {
    NSError *error;
    NSPropertyListFormat format;
    NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithDictionary:[NSPropertyListSerialization propertyListWithData:originData options:NSPropertyListImmutable format:&format error:&error]];
    
    NSData *currentRequestData = [plist objectForKey:@"NSURLSessionResumeCurrentRequest"];
    NSURLRequest *request = (NSURLRequest *)[NSKeyedUnarchiver unarchiveObjectWithData:currentRequestData];
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    [mutableRequest addValue:[plist objectForKey:@"NSURLSessionResumeEntityTag"] forHTTPHeaderField:@"If-Match"];
    [mutableRequest addValue:[NSString stringWithFormat:@"bytes=%@-", [plist objectForKey:@"NSURLSessionResumeBytesReceived"]] forHTTPHeaderField:@"Range"];
    request = [mutableRequest copy];
    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:request];
    
    [plist removeObjectForKey:@"NSURLSessionResumeCurrentRequest"];
    [plist setValue:archivedData forKey:@"NSURLSessionResumeCurrentRequest"];
    
    return [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                       
- (NSUInteger)systemAvailableSpace {
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:docPath error:nil];
    return [[dict objectForKey:NSFileSystemFreeSize] integerValue];
}

@end
