//
//  ViewController.m
//  LD_FileLoaderManager
//
//  Created by Done.L (liudongdong@qiyoukeji.com) on 2017/2/10.
//  Copyright © 2017年 Done.L (liudongdong@qiyoukeji.com). All rights reserved.
//

#import "ViewController.h"

#import "LDFileDownloaderManager.h"

@interface ViewController ()

@property (nonatomic, strong) LDFileLoader *fileLoader;

@property (nonatomic, strong) UIProgressView *progress;

@property (nonatomic, strong) UILabel *speed;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIButton *begin = [UIButton buttonWithType:UIButtonTypeSystem];
    begin.frame = CGRectMake(100, 100, 120, 40);
    [begin setTitle:@"开始" forState:UIControlStateNormal];
    [begin addTarget:self action:@selector(beginDownload) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:begin];
    
    UIButton *stop = [UIButton buttonWithType:UIButtonTypeSystem];
    stop.frame = CGRectMake(100, 150, 120, 40);
    [stop setTitle:@"停止" forState:UIControlStateNormal];
    [stop addTarget:self action:@selector(stopDownload) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stop];
    
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.frame = CGRectMake(100, 200, 120, 40);
    [cancel setTitle:@"取消" forState:UIControlStateNormal];
    [cancel addTarget:self action:@selector(cancelDownload) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cancel];
    
    self.progress = [[UIProgressView alloc] initWithFrame:CGRectMake(20, 280, 280, 40)];
    self.progress.tintColor = [UIColor blueColor];
    [self.view addSubview:self.progress];
    
    self.speed = [[UILabel alloc] initWithFrame:CGRectMake(50, 320, 220, 40)];
    self.speed.backgroundColor = [UIColor orangeColor];
    self.speed.textColor = [UIColor blackColor];
    self.speed.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_speed];
}

- (void)beginDownload {
//    @"http://android-mirror.bugly.qq.com:8080/eclipse_mirror/juno/content.jar"
    
    [[LDFileDownloaderManager shareManager] ld_downloadWithUrlString:@"http://android-mirror.bugly.qq.com:8080/eclipse_mirror/juno/content.jar" destination:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] progressHandler:^(float progress, NSString *speed, NSUInteger completedUnitCount, NSUInteger totalUnitCount) {
        NSLog(@"progress = %lf \n speed = %@, \n completedUnitCount = %ld, \n totalUnitCount = %ld",progress, speed, completedUnitCount, totalUnitCount);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progress.progress = progress;
            self.speed.text = [NSString stringWithFormat:@"%@", speed];
        });
    } completionHandler:^(NSString *filePath) {
        NSLog(@"filePath = %@", filePath);
    } errorHandler:^(NSError *error) {
        
    }];
}

- (void)stopDownload {
    [[LDFileDownloaderManager shareManager] ld_cancelDownloadTask:@"http://android-mirror.bugly.qq.com:8080/eclipse_mirror/juno/content.jar"];
}

- (void)cancelDownload {
    [[LDFileDownloaderManager shareManager] ld_removeDownloadFileWithUrl:@"http://android-mirror.bugly.qq.com:8080/eclipse_mirror/juno/content.jar" destination:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
