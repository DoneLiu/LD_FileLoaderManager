//
//  LDFileDownloaderManager.h
//  LD_FileLoaderManager
//
//  Created by Done.L (liudongdong@qiyoukeji.com) on 2017/2/10.
//  Copyright © 2017年 Done.L (liudongdong@qiyoukeji.com). All rights reserved.
//

#import <Foundation/Foundation.h>

#import "LDFileLoader.h"

@interface LDFileDownloaderManager : NSObject

+ (LDFileDownloaderManager *)shareManager;

- (void)ld_downloadWithUrlString:(NSString *)url destination:(NSString *)destination progressHandler:(LD_ProgressHandler)progressHandler completionHandler:(LD_CompletionHandler)completionHandler errorHandler:(LD_ErrorHandler)errorHandler;

- (void)ld_cancelDownloadTask:(NSString *)url;

- (void)ld_cancelAllTasks;

- (void)ld_removeDownloadFileWithUrl:(NSString *)url destination:(NSString *)destination;

- (float)ld_lastProgress:(NSString *)url;

@end
