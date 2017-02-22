//
//  ViewController.m
//  LD_FileLoaderManager
//
//  Created by Done.L (liudongdong@qiyoukeji.com) on 2017/2/10.
//  Copyright © 2017年 Done.L (liudongdong@qiyoukeji.com). All rights reserved.
//

#import "ViewController.h"

#import "LDFileDownloaderManager.h"

static NSInteger CAPATICY_SCALE = 1024;

static NSString *url1 = @"http://dota2.dl.wanmei.com/dota2/client/DOTA2Setup20160329.zip";
static NSString *url2 = @"http://imgcache.qq.com/qzone/biz/gdt/dev/sdk/ios/release/GDT_iOS_SDK.zip";

@interface ViewController ()

@property (nonatomic, strong) UIProgressView *progress1;
@property (nonatomic, strong) UIProgressView *progress2;

@property (nonatomic, strong) UILabel *progressText1;
@property (nonatomic, strong) UILabel *progressText2;

@property (nonatomic, strong) UILabel *percent1;
@property (nonatomic, strong) UILabel *percent2;

@property (nonatomic, strong) UILabel *speed1;
@property (nonatomic, strong) UILabel *speed2;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIButton *begin1 = [UIButton buttonWithType:UIButtonTypeSystem];
    begin1.frame = CGRectMake(100, 20, 120, 40);
    [begin1 setTitle:@"开始1" forState:UIControlStateNormal];
    [begin1 addTarget:self action:@selector(beginDownload1) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:begin1];
    
    UIButton *stop1 = [UIButton buttonWithType:UIButtonTypeSystem];
    stop1.frame = CGRectMake(100, 60, 120, 40);
    [stop1 setTitle:@"停止1" forState:UIControlStateNormal];
    [stop1 addTarget:self action:@selector(stopDownload1) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stop1];
    
    UIButton *cancel1 = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel1.frame = CGRectMake(100, 100, 120, 40);
    [cancel1 setTitle:@"取消1" forState:UIControlStateNormal];
    [cancel1 addTarget:self action:@selector(cancelDownload1) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cancel1];
    
    self.percent1 = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 100, 40)];
    self.percent1.text = [NSString stringWithFormat:@"%@/%@", [[NSUserDefaults standardUserDefaults] objectForKey:Cache_completedUnitCount(url1)] ? [[NSUserDefaults standardUserDefaults] objectForKey:Cache_completedUnitCount(url1)] : @"0B", [[NSUserDefaults standardUserDefaults] objectForKey:Cache_totalUnitCount(url1)] ? [[NSUserDefaults standardUserDefaults] objectForKey:Cache_totalUnitCount(url1)] : @"0B"];
    self.percent1.textColor = [UIColor blackColor];
    self.percent1.backgroundColor = [UIColor greenColor];
    self.percent1.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.percent1];
    
    self.progressText1 = [[UILabel alloc] initWithFrame:CGRectMake(220, 100, 80, 40)];
    self.progressText1.text = [NSString stringWithFormat:@"%.2f%%", [[[NSUserDefaults standardUserDefaults] objectForKey:Cache_last_progress(url1)] floatValue] * 100];
    self.progressText1.textColor = [UIColor blackColor];
    self.progressText1.backgroundColor = [UIColor orangeColor];
    self.progressText1.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.progressText1];
    
    self.progress1 = [[UIProgressView alloc] initWithFrame:CGRectMake(20, 140, 280, 40)];
    self.progress1.tintColor = [UIColor blueColor];
    [self.view addSubview:self.progress1];
    
    self.speed1 = [[UILabel alloc] initWithFrame:CGRectMake(50, 180, 220, 40)];
    self.speed1.backgroundColor = [UIColor orangeColor];
    self.speed1.textColor = [UIColor blackColor];
    self.speed1.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_speed1];
    
    UIButton *begin2 = [UIButton buttonWithType:UIButtonTypeSystem];
    begin2.frame = CGRectMake(100, 250, 120, 40);
    [begin2 setTitle:@"开始2" forState:UIControlStateNormal];
    [begin2 addTarget:self action:@selector(beginDownload2) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:begin2];
    
    UIButton *stop2 = [UIButton buttonWithType:UIButtonTypeSystem];
    stop2.frame = CGRectMake(100, 290, 120, 40);
    [stop2 setTitle:@"停止2" forState:UIControlStateNormal];
    [stop2 addTarget:self action:@selector(stopDownload2) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stop2];
    
    UIButton *cancel2 = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel2.frame = CGRectMake(100, 330, 120, 40);
    [cancel2 setTitle:@"取消2" forState:UIControlStateNormal];
    [cancel2 addTarget:self action:@selector(cancelDownload2) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cancel2];
    
    self.percent2 = [[UILabel alloc] initWithFrame:CGRectMake(20, 330, 100, 40)];
    self.percent2.text = [NSString stringWithFormat:@"%@/%@", [[NSUserDefaults standardUserDefaults] objectForKey:Cache_completedUnitCount(url2)] ? [[NSUserDefaults standardUserDefaults] objectForKey:Cache_completedUnitCount(url2)] : @"0B", [[NSUserDefaults standardUserDefaults] objectForKey:Cache_totalUnitCount(url2)] ? [[NSUserDefaults standardUserDefaults] objectForKey:Cache_totalUnitCount(url2)] : @"0B"];
    self.percent2.textColor = [UIColor blackColor];
    self.percent2.backgroundColor = [UIColor greenColor];
    self.percent2.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.percent2];
    
    self.progressText2 = [[UILabel alloc] initWithFrame:CGRectMake(220, 330, 80, 40)];
    self.progressText2.text = [NSString stringWithFormat:@"%.2f%%", [[[NSUserDefaults standardUserDefaults] objectForKey:Cache_last_progress(url2)] floatValue] * 100];
    self.progressText2.textColor = [UIColor blackColor];
    self.progressText2.backgroundColor = [UIColor greenColor];
    self.progressText2.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.progressText2];
    
    self.progress2 = [[UIProgressView alloc] initWithFrame:CGRectMake(20, 370, 280, 40)];
    self.progress2.tintColor = [UIColor blueColor];
    [self.view addSubview:self.progress2];
    
    self.speed2 = [[UILabel alloc] initWithFrame:CGRectMake(50, 410, 220, 40)];
    self.speed2.backgroundColor = [UIColor greenColor];
    self.speed2.textColor = [UIColor blackColor];
    self.speed2.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_speed2];
}

- (void)beginDownload1 {
    [[LDFileDownloaderManager shareManager] ld_downloadWithUrlString:url1 destination:[NSHomeDirectory() stringByAppendingPathComponent:@"/Download"] progressHandler:^(float progress, NSString *speed, NSUInteger completedUnitCount, NSUInteger totalUnitCount) {
        NSLog(@"progress = %lf \n speed = %@, \n completedUnitCount = %ld, \n totalUnitCount = %ld",progress, speed, completedUnitCount, totalUnitCount);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progress1.progress = progress;
            self.speed1.text = [NSString stringWithFormat:@"%@/s", speed];
            self.progressText1.text = [NSString stringWithFormat:@"%.2f%%", progress * 100];
            self.percent1.text = [NSString stringWithFormat:@"%@/%@", [self convertFileLengthGrowthToSpeed:completedUnitCount], [self convertFileLengthGrowthToSpeed:totalUnitCount]];
        });
    } completionHandler:^(NSString *filePath) {
        NSLog(@"filePath = %@", filePath);
    } errorHandler:^(NSError *error) {
        
    }];
}

- (void)stopDownload1 {
    [[LDFileDownloaderManager shareManager] ld_cancelDownloadTask:url1];
}

- (void)cancelDownload1 {
    [[LDFileDownloaderManager shareManager] ld_removeDownloadFileWithUrl:url1 destination:[NSHomeDirectory() stringByAppendingPathComponent:@"/Download"]];
}

- (void)beginDownload2 {
    [[LDFileDownloaderManager shareManager] ld_downloadWithUrlString:url2 destination:[NSHomeDirectory() stringByAppendingPathComponent:@"/Download"] progressHandler:^(float progress, NSString *speed, NSUInteger completedUnitCount, NSUInteger totalUnitCount) {
        NSLog(@"progress = %lf \n speed = %@, \n completedUnitCount = %ld, \n totalUnitCount = %ld",progress, speed, completedUnitCount, totalUnitCount);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progress2.progress = progress;
            self.speed2.text = [NSString stringWithFormat:@"%@/s", speed];
            self.progressText2.text = [NSString stringWithFormat:@"%.2f%%", progress * 100];
            self.percent2.text = [NSString stringWithFormat:@"%@/%@", [self convertFileLengthGrowthToSpeed:completedUnitCount], [self convertFileLengthGrowthToSpeed:totalUnitCount]];
        });
    } completionHandler:^(NSString *filePath) {
        NSLog(@"filePath = %@", filePath);
    } errorHandler:^(NSError *error) {
        
    }];
}

- (void)stopDownload2 {
    [[LDFileDownloaderManager shareManager] ld_cancelDownloadTask:url2];
}

- (void)cancelDownload2 {
    [[LDFileDownloaderManager shareManager] ld_removeDownloadFileWithUrl:url2 destination:[NSHomeDirectory() stringByAppendingPathComponent:@"/Download"]];
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
