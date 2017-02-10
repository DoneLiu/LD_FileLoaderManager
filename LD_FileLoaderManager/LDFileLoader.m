//
//  LDFileLoader.m
//  LD_FileLoaderManager
//
//  Created by Done.L (liudongdong@qiyoukeji.com) on 2017/2/10.
//  Copyright © 2017年 Done.L (liudongdong@qiyoukeji.com). All rights reserved.
//

#import "LDFileLoader.h"

#import "AFNetworking.h"

static NSInteger CAPATICY_SCALE = 1024;

@interface LDFileLoader ()

@property (nonatomic, strong) AFURLSessionManager *sessionManager;

@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;

@property(nonatomic,copy,readonly)LD_ProgressHandler progressHandler;
@property(nonatomic,copy,readonly)LD_CompletionHandler completionHandler;
@property(nonatomic,copy,readonly)LD_ErrorHandler errorHandler;

@property (nonatomic, strong) NSTimer *downloadSpeedTimer;

@property (nonatomic, assign) NSUInteger fileLengthGrowthPerSecond;
@property (nonatomic, assign) NSUInteger bytesWritten;
@property (nonatomic, assign) NSUInteger lastBytesWritten;

@property (nonatomic, assign) float progress;

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
    if (url && destination) {
        if (!self.downloadSpeedTimer) {
            self.downloadSpeedTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(fileLengthGrowth) userInfo:nil repeats:YES];
        } else {
            [self.downloadSpeedTimer setFireDate:[NSDate distantPast]];
        }
        
        self.fileURL = url;
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        
        NSData *resumeData = [[NSUserDefaults standardUserDefaults] objectForKey:url];
        if (!resumeData) {
            self.downloadTask = [self.sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
                NSUInteger completedUnitCount = downloadProgress.completedUnitCount;
                NSUInteger totalUnitCount = downloadProgress.totalUnitCount;
                self.progress = 1.0 * completedUnitCount / totalUnitCount;
                if (progressHandler) {
                    progressHandler(self.progress, [self convertFileLengthGrowthToSpeed:_fileLengthGrowthPerSecond], completedUnitCount, totalUnitCount);
                }
            } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                NSString *savePath = [destination stringByAppendingPathComponent:response.suggestedFilename];
                return [NSURL fileURLWithPath:savePath];
            } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                if (!error) {
                    if (completionHandler) {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:self.fileURL];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        
                        completionHandler(filePath.path);
                    }
                } else {
                    if (errorHandler) {
                        errorHandler(error);
                    }
                }
                
            }];
        } else {
            self.downloadTask = [self.sessionManager downloadTaskWithResumeData:resumeData progress:^(NSProgress * _Nonnull downloadProgress) {
                NSUInteger completedUnitCount = downloadProgress.completedUnitCount;
                NSUInteger totalUnitCount = downloadProgress.totalUnitCount;
                self.progress = 1.0 * completedUnitCount / totalUnitCount;
                if (progressHandler) {
                    progressHandler(self.progress, [self convertFileLengthGrowthToSpeed:_fileLengthGrowthPerSecond], completedUnitCount, totalUnitCount);
                }
            } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                NSString *savePath = [destination stringByAppendingPathComponent:response.suggestedFilename];
                return [NSURL fileURLWithPath:savePath];
            } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                if (!error) {
                    if (completionHandler) {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:self.fileURL];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        
                        completionHandler(filePath.path);
                    }
                } else {
                    if (errorHandler) {
                        errorHandler(error);
                    }
                }
            }];
        }
        
        [self.downloadTask resume];
        
        [self.sessionManager setDownloadTaskDidWriteDataBlock:^(NSURLSession * _Nonnull session, NSURLSessionDownloadTask * _Nonnull downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
            _bytesWritten = totalBytesWritten;
        }];
    }
}

- (void)ld_pause {
    if (_downloadTask.state == NSURLSessionTaskStateRunning) {
        [_downloadTask suspend];
        
        __weak LDFileLoader *weakSelf = self;
        [_downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            [weakSelf regenerateResumeData:resumeData];
            
            [[NSUserDefaults standardUserDefaults] setObject:resumeData forKey:self.fileURL];
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:self.progress] forKey:[NSString stringWithFormat:@"%@_last_progress", self.fileURL]];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
        
        if (self.downloadSpeedTimer) {
            [self.downloadSpeedTimer setFireDate:[NSDate distantFuture]];
        }
    }
}

- (void)ld_cancel {
    if (self.downloadTask.state != NSURLSessionTaskStateCompleted) {
        [self.downloadTask cancel];
        self.downloadTask = nil;
        
        if (_downloadSpeedTimer) {
            [_downloadSpeedTimer invalidate];
            _downloadSpeedTimer = nil;
        }
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:self.fileURL];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_last_progress", self.fileURL]];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (float)lastProgress:(NSString *)url {
    float progress = 0.0;
    if(url) {
        progress = [[NSUserDefaults standardUserDefaults] floatForKey:[NSString stringWithFormat:@"%@_last_progress",url]];
    }
    return progress;
}

#pragma mark - Private

- (void)fileLengthGrowth {
    _fileLengthGrowthPerSecond = _bytesWritten - _lastBytesWritten;
    _lastBytesWritten = _bytesWritten;
}

- (NSString *)convertFileLengthGrowthToSpeed:(NSUInteger)fileLengthGrowth {
    if(fileLengthGrowth < CAPATICY_SCALE) {
        return [NSString stringWithFormat:@"%ldB/s",(NSUInteger)fileLengthGrowth];
    } else if (fileLengthGrowth >= CAPATICY_SCALE && fileLengthGrowth < CAPATICY_SCALE * CAPATICY_SCALE) {
        return [NSString stringWithFormat:@"%.0fK/s",(float)fileLengthGrowth / CAPATICY_SCALE];
    } else if (fileLengthGrowth >= CAPATICY_SCALE * CAPATICY_SCALE && fileLengthGrowth < CAPATICY_SCALE * CAPATICY_SCALE * CAPATICY_SCALE) {
        return [NSString stringWithFormat:@"%.1fM/s",(float)fileLengthGrowth / (CAPATICY_SCALE * CAPATICY_SCALE)];
    } else {
        return [NSString stringWithFormat:@"%.1fG/s",(float)fileLengthGrowth / (CAPATICY_SCALE * CAPATICY_SCALE * CAPATICY_SCALE)];
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

@end
