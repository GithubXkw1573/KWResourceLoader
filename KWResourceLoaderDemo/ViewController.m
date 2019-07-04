//
//  ViewController.m
//  KWResourceLoaderDemo
//
//  Created by kaiwei Xu on 2019/7/4.
//  Copyright © 2019 NanjingYunWo technology co.LTD. All rights reserved.
//

#import "ViewController.h"
#import <KWResourceLoader/KWResourceLoader.h>

@interface ViewController ()<KWResourceLoaderDelegate>
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, copy) NSArray *mediaList;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, strong) KWResourceLoader *resourceLoader;
@property (nonatomic, strong) AVPlayerLayer *playLayer;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UIView *loadProgressLayer;
@property (nonatomic, copy) NSString *totalTime;
@property (nonatomic, copy) NSString *currPlayTime;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UILabel *currTimeLabel;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, assign) BOOL isSeeking;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"边下边播";
    
    [self initData];
    
    [self initButtons];
    
    [self initViews];
    
    [self preparePlay];
    
    [self play];
}

- (void)initData {
    self.mediaList = @[@"http://flv3.bn.netease.com/tvmrepo/2018/6/H/9/EDJTRBEH9/SD/EDJTRBEH9-mobile.mp4",
                       @"https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4",
                       @"https://www.apple.com/105/media/cn/mac/family/2018/46c4b917_abfd_45a3_9b51_4e3054191797/films/bruce/mac-bruce-tpl-cn-2018_1280x720h.mp4"];
    self.totalTime = @"-:-";
    self.currPlayTime = @"-:-";
    //初始化player
    self.player = [[AVPlayer alloc] init];
    //监听播放状态
    [self.player addObserver:self forKeyPath:@"status"
                     options:NSKeyValueObservingOptionNew context:nil];
    [self.player.currentItem addObserver:self forKeyPath:@"currentTime"
                                 options:NSKeyValueObservingOptionNew context:nil];
    //播放进度监听
    __weak typeof(self) weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(120, 600) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        if (weakSelf.isSeeking == NO) {
            Float64 current = CMTimeGetSeconds(time);
            [weakSelf updatePlayProgress:current];
        }
    }];
}

- (void)initButtons {
    UIButton *nextBtn = [[UIButton alloc] initWithFrame:CGRectMake(50, 150, 60, 30)];
    [nextBtn setTitle:@"下一首" forState:UIControlStateNormal];
    nextBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [nextBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [nextBtn addTarget:self action:@selector(switchMedia:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:nextBtn];
    
    UIButton *refreshBtn = [[UIButton alloc] initWithFrame:CGRectMake(120, 150, 70, 30)];
    [refreshBtn setTitle:@"重新播放" forState:UIControlStateNormal];
    refreshBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [refreshBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [refreshBtn addTarget:self action:@selector(refreshMedia:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:refreshBtn];
    
    self.playBtn = [[UIButton alloc] initWithFrame:CGRectMake(200, 150, 50, 30)];
    [_playBtn setTitle:@"播放" forState:UIControlStateNormal];
    _playBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [_playBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [_playBtn addTarget:self action:@selector(playMedia:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_playBtn];
    
    UIButton *clearCacheBtn = [[UIButton alloc] initWithFrame:CGRectMake(250, 150, 70, 30)];
    [clearCacheBtn setTitle:@"清除缓存" forState:UIControlStateNormal];
    [clearCacheBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    clearCacheBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [clearCacheBtn addTarget:self action:@selector(clearMedia:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearCacheBtn];
}

- (void)initViews {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = screenWidth * 0.60;
    UIView *pannel = [[UIView alloc] initWithFrame:CGRectMake(10, 200, screenWidth - 20, height)];
    pannel.backgroundColor = [UIColor blackColor];
    self.playLayer = [[AVPlayerLayer alloc] init];
    self.playLayer.frame = pannel.bounds;
    [self.view addSubview:pannel];
    [pannel.layer insertSublayer:self.playLayer atIndex:0];
    
    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(10, pannel.frame.origin.y + pannel.frame.size.height + 23, screenWidth - 20, 15)];
    [self.slider addTarget:self action:@selector(seek:) forControlEvents:UIControlEventTouchUpInside];
    [self.slider addTarget:self action:@selector(beginSeek) forControlEvents:UIControlEventTouchDown];
    [self.view addSubview:self.slider];
    
    //添加加载进度
    self.loadProgressLayer = [[UIView alloc] init];
    self.loadProgressLayer.backgroundColor = [UIColor greenColor];
    [self.view addSubview:self.loadProgressLayer];
    //    [self.slider.layer insertSublayer:self.loadProgressLayer atIndex:0];
    CGRect frame = pannel.frame;
    frame.size.width = 0;
    frame.size.height = 2;
    frame.origin.y = CGRectGetMaxY(pannel.frame) - 2;
    self.loadProgressLayer.frame = frame;
    
    self.currTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.slider.frame.origin.x, self.slider.frame.origin.y - 20, 100, 20)];
    self.currTimeLabel.text = self.currPlayTime;
    self.currTimeLabel.textColor = [UIColor grayColor];
    self.currTimeLabel.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:self.currTimeLabel];
    
    self.durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(screenWidth - 110, self.slider.frame.origin.y - 20, 100, 20)];
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.text = self.totalTime;
    self.durationLabel.textColor = [UIColor grayColor];
    self.durationLabel.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:self.durationLabel];
}

#pragma mark - Action -

- (void)switchMedia:(UIButton *)btn {
    if (self.index == self.mediaList.count - 1) {
        self.index = 0;
    }else {
        self.index ++;
    }
    [self preparePlay];
    
    [self play];
}

- (void)refreshMedia:(UIButton *)btn {
    [self.player seekToTime:CMTimeMake(0, 600)];
    [self play];
}

- (void)playMedia:(UIButton *)btn {
    if ([btn.currentTitle containsString:@"播放"]) {
        [self play];
    }else {
        [self pause];
    }
}

- (void)clearMedia:(UIButton *)btn {
    [KWFileManager clearAllCache:^(NSError * _Nonnull error) {
        if (error) {
            [self alert:error.localizedDescription];
        }else {
            [self alert:@"清理成功！"];
        }
    }];
}

- (void)beginSeek {
    self.isSeeking = YES;
}

- (void)seek:(UISlider *)slider {
    long long duration = [self totalDurationSecs];
    if (duration > 0) {
        CMTime duration = self.player.currentItem.duration;
        CMTime newTime = CMTimeMake(duration.value*slider.value, duration.timescale);
        __weak typeof(self) weakSelf = self;
        [self.player seekToTime:newTime toleranceBefore:kCMTimeZero
                 toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
                     weakSelf.isSeeking = NO;
                     [weakSelf play];
                 }];
        //    [self.player seekToTime:newTime];
    }else {
        //不允许seek
    }
}


#pragma mark - 私有方法

- (void)preparePlay {
    NSString *url = self.mediaList[self.index];
    NSURL *URL = [[NSURL alloc] initWithString:url];
    if (!URL) {
        [self alert:@"无效的URL"];
        return;
    }
    if (self.player.currentItem) {
        [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    }
    AVPlayerItem *item = [self.resourceLoader playerItemWithURL:URL];
    [self.player replaceCurrentItemWithPlayerItem:item];
    [self.player.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    if (@available(iOS 10.0, *)) {
        self.player.automaticallyWaitsToMinimizeStalling = NO;
    } else {
        // Fallback on earlier versions
    }
    self.playLayer.player = self.player;
}

- (void)play {
    [self.player play];
    [self.playBtn setTitle:@"暂停" forState:UIControlStateNormal];
}

- (void)pause {
    [self.player pause];
    [self.playBtn setTitle:@"播放" forState:UIControlStateNormal];
}

#pragma mark - 属性 Getter

- (KWResourceLoader *)resourceLoader {
    if (!_resourceLoader) {
        _resourceLoader = [[KWResourceLoader alloc] init];
        _resourceLoader.delegate = self;
        //开启debug日志，release环境建议关闭
        _resourceLoader.openDebugLog = YES;
    }
    return _resourceLoader;
}

#pragma mark - KWResourceLoaderManagerDelegate

- (void)resourceLoader:(KWResourceLoader *)loadManager didLoadProgress:(float)loadProgress {
    CGRect frame = self.loadProgressLayer.frame;
    frame.size.width = self.slider.frame.size.width * MIN(loadProgress, 1);
    self.loadProgressLayer.frame = frame;
}

#pragma mark - KVO 监听播放状态

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.player && [keyPath isEqualToString:@"status"]) {
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        if (status == AVPlayerStatusReadyToPlay) {
            //获取播放时长
            long long totalSecs = [self totalDurationSecs];
            if (totalSecs > 0) {
                self.totalTime = [self formatTime:totalSecs];
            }
        }
    }else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        //计算缓存进度
        NSTimeInterval loadProgress = [self availableDuration];
        //当前播放进度
        NSTimeInterval currPlayTime = self.player.currentTime.value / self.player.currentTime.timescale;
        
        if (loadProgress > currPlayTime + 3) {
            [self play];
        }else if (currPlayTime > loadProgress) {
            [self pause];
        }
    }
}

#pragma mark - Timer回调

- (void)updatePlayProgress:(Float64)currSecs {
    long long duration = [self totalDurationSecs];
    if (duration > 0) {
        self.slider.value = currSecs * 1.0 / duration;
        self.currPlayTime = [self formatTime:currSecs];
        self.totalTime = [self formatTime:duration];
    }else {
        self.slider.value =  0;
        self.currPlayTime = @"-:-";
        self.totalTime = @"-:-";
    }
    self.currTimeLabel.text = self.currPlayTime;
    self.durationLabel.text = self.totalTime;
}

#pragma mark - 公共方法

- (void)alert:(NSString *)text {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:text preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *act = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [alert dismissViewControllerAnimated:YES completion:nil];
    }];
    [alert addAction:act];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)formatTime:(long long)secs {
    if (secs < 60) {
        return [NSString stringWithFormat:@"%llds",secs];
    }else if (secs < 3600) {
        NSInteger fens = secs / 60;
        NSInteger s = secs % 60;
        return [NSString stringWithFormat:@"%ldm %lds",fens,s];
    }else {
        long long hours = secs / 3600;
        NSInteger leftSecs = secs % 3600;
        NSInteger fens = leftSecs / 60;
        NSInteger s = leftSecs % 60;
        return [NSString stringWithFormat:@"%lldh %ldm %lds",hours,fens,s];
    }
}

- (Float64)totalDurationSecs {
    CMTime totalTime = self.player.currentItem.duration;
    Float64 sec = CMTimeGetSeconds(totalTime);
    if (isnan(sec)) {
        return 0;
    }
    return sec;
}

- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [[self.player currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
    
    return result;
}

#pragma mark - 销毁 -

- (void)dealloc {
    //移除监听
    [self.player removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
    }
}


@end
