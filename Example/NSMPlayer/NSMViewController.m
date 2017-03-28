//
//  NSMViewController.m
//  NSMPlayer
//
//  Created by migrant on 02/10/2017.
//  Copyright (c) 2017 migrant. All rights reserved.
//
@import Bolts;
@import NSMPlayer;
@import MediaPlayer;

#import "NSMViewController.h"
#import "NSMVideoSourceController.h"
#import "NSMVideoPlayerViewController.h"

@interface NSMViewController () <NSMVideoSourceControllerDelegate>

@property (nonatomic, strong) NSMVideoPlayerViewController *playerViewController;
@property (weak, nonatomic) IBOutlet UILabel *failReasonLabel;
@property (nonatomic, strong) NSMVideoPlayerController *playerController;
@property (weak, nonatomic) IBOutlet UILabel *playerStateLabel;
@property (weak, nonatomic) IBOutlet UILabel *playerTypeLabel;
@property (weak, nonatomic) IBOutlet UISlider *volumSlider;
@property (weak, nonatomic) IBOutlet UISlider *playHeadSlider;
@property (weak, nonatomic) IBOutlet UIProgressView *loadProgress;
@property (nonatomic, strong) NSMPlayerRestoration *saveConfig;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (nonatomic, strong) UISlider *volumSliderView;
@property (nonatomic, assign) BOOL allowWWAN;
@property (weak, nonatomic) IBOutlet UIButton *immerseButton;

@end

@implementation NSMViewController

- (NSMVideoPlayerController *)playerController {
    if (!_playerController) {
        _playerController = [[NSMVideoPlayerController alloc] init];
    }
    return _playerController;
}

- (IBAction)immerse:(UIButton *)sender {
    CGSize videoSize = [self.playerController.videoPlayer videoSize];
    if (videoSize.width / videoSize.height > (9 / 16.0)) {
        NSLog(@"横屏播放");
    } else {
        NSLog(@"竖屏播放");
    }
}

- (IBAction)retry:(UIButton *)sender {
    if (NSMVideoPlayerStatusFailed == [self.playerController.videoPlayer currentStatus]) {
        NSMPlayerError *playerError = [self.playerController.videoPlayer playerError];
        if (playerError != nil) {
            NSMPlayerRestoration *restoration = playerError.restoration;
            [self.playerController.videoPlayer restorePlayerWithRestoration:restoration];
        }
    }
}

- (IBAction)chooseSource:(UIBarButtonItem *)sender {
    NSMVideoSourceController *meauVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"source"];
    meauVC.delegate = self;
    meauVC.modalPresentationStyle = UIModalPresentationPopover;
    UIPopoverPresentationController *detailPopover = meauVC.popoverPresentationController;
    detailPopover.barButtonItem = sender;
    detailPopover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    [self presentViewController:meauVC animated:YES completion:nil];
}

- (IBAction)allowMobileNetworkChange:(UISwitch *)sender {
    self.allowWWAN = sender.isOn;
    if (NSMVideoPlayerStatusFailed == [self.playerController.videoPlayer currentStatus]) {
        NSMPlayerError *playerError = [self.playerController.videoPlayer playerError];
        if (playerError != nil) {
            NSMPlayerRestoration *restoration = playerError.restoration;
            restoration.allowWWAN = sender.isOn;
            [self.playerController.videoPlayer restorePlayerWithRestoration:restoration];
        }
    } else {
        [self.playerController.videoPlayer setAllowWWAN:sender.isOn];
    }
}

- (IBAction)ciclePlayChange:(UISwitch *)sender {
    [self.playerController.videoPlayer setLoopPlayback:sender.isOn];
}

- (IBAction)mutedChange:(UISwitch *)sender {
    [self.playerController.videoPlayer setMuted:sender.isOn];
}

- (IBAction)volumChange:(UISlider *)sender {
    [self.playerController.videoPlayer setVolume:sender.value];
    self.volumSliderView.value = sender.value;
}
- (IBAction)play:(UIButton *)sender {
    [self.playerController.videoPlayer play];
}

- (IBAction)pause:(UIButton *)sender {
    
    [self.playerController.videoPlayer pause];
}


- (IBAction)releasePlayer:(UIButton *)sender {
    if (self.playerController.videoPlayer.currentStatus != NSMVideoPlayerStatusIdle) {
        NSMPlayerRestoration *saveConfig = [self.playerController.videoPlayer savePlayerState];
        self.saveConfig = saveConfig;
    }
    [self.playerController.videoPlayer releasePlayer];
    NSLog(@"releasePlayer");
}

- (IBAction)restore:(UIButton *)sender {
    self.saveConfig.allowWWAN = self.allowWWAN;
    [self.playerController.videoPlayer restorePlayerWithRestoration:self.saveConfig];
    NSLog(@"restore");
}

- (IBAction)playHeaderChange:(UISlider *)sender {
    [[self.playerController.videoPlayer seekToTime:sender.value] continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:^id _Nullable(BFTask * _Nonnull t) {
        if ([self.playerController.videoPlayer currentStatus] != NSMVideoPlayerStatusPaused) {
            [self.playerController.videoPlayer setRate:1.0];
        }
        return nil;
    }];
}
- (IBAction)separate:(UISwitch *)sender {
    ((NSMAVPlayerView *)self.playerController.videoPlayer.playerView).hidden = sender.isOn;
}

- (IBAction)playerTypeChange:(UISwitch *)sender {
    if (sender.isOn) {
        self.playerController.videoPlayer.playerType = NSMVideoPlayerAVPlayer;
    } else {
        NSLog(@"IJKPlayer还没有添加");
        self.playerController.videoPlayer.playerType = NSMVideoPlayerIJKPlayer;
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        //should add observer before initilize NSMVideoPlayerController object
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoPlayerStatusDidChange) name:NSMVideoPlayerStatusDidChange object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActiveNotification) name:UIApplicationDidBecomeActiveNotification object:nil];
    self.title = [NSString stringWithFormat:@"Build:#%@",[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]];
    self.volumSlider.value = [AVAudioSession sharedInstance].outputVolume;
    [self setupVolumeView];
    self.playHeadSlider.continuous = NO;
    [self.playHeadSlider addTarget:self action:@selector(beginSrubbing:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchCancel];
    
    
    [[AVAudioSession sharedInstance] addObserver:self forKeyPath:NSStringFromSelector(@selector(outputVolume)) options:NSKeyValueObservingOptionNew context:nil];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChanged:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];

}

- (void)applicationDidBecomeActiveNotification {
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    self.volumSlider.value = [AVAudioSession sharedInstance].outputVolume;
}

//- (void)volumeChanged:(NSNotification *)notification
//{
//    float volume =
//    [[[notification userInfo]
//      objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"]
//     floatValue];
//    self.volumSlider.value = volume;
//    // Do stuff with volume
//}


- (void)setupVolumeView {
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    [volumeView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if([obj isKindOfClass:[UISlider class]]){
            _volumSliderView = obj;
        }
    }];
}
    
- (void)beginSrubbing:(UISlider *)sender {
    [self.playerController.videoPlayer setRate:0.0];
}

- (void)videoPlayerStatusDidChange {
    [self updateView];
}

- (void)updateView {
    if (self.playerController.videoPlayer.currentStatus == NSMVideoPlayerStatusFailed) {
        self.failReasonLabel.text = [self.playerController.videoPlayer.playerError.error localizedDescription];
    } else {
        self.failReasonLabel.text = @"";
    }
    
    self.playerStateLabel.text = NSMVideoPlayerStatusDescription(self.playerController.videoPlayer.currentStatus);
    if (self.playerController.videoPlayer.currentStatus & NSMVideoPlayerStatusLevelReadyToPlay) {
        self.immerseButton.hidden = NO;
        self.playerController.videoPlayer.playerView = self.playerViewController.playerRenderingView;
        
    } else {
        self.immerseButton.hidden = YES;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"videoPlayer"]) {
        NSMVideoPlayerViewController *playerViewController = segue.destinationViewController;
        if ([playerViewController isKindOfClass:[NSMVideoPlayerViewController class]]) {
            self.playerViewController = playerViewController;
            NSMPlayerAsset *playerAsset = [[NSMPlayerAsset alloc] init];
            playerAsset.assetURL = [NSURL URLWithString:@"http://qiniu.vmagic.vmoviercdn.com/57aad69c25a41_lower.mp4"];
            [self.playerController.videoPlayer replaceCurrentAssetWithAsset:playerAsset];
            [self.playerController.videoPlayer.playbackProgress addObserver:self forKeyPath:NSStringFromSelector(@selector(totalUnitCount)) options:0 context:nil];
            [self.playerController.videoPlayer.playbackProgress addObserver:self forKeyPath:NSStringFromSelector(@selector(completedUnitCount)) options:0 context:nil];
            [self.playerController.videoPlayer.bufferProgress addObserver:self forKeyPath:NSStringFromSelector(@selector(completedUnitCount)) options:0 context:nil];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    //playbackProgress
    if (object == self.playerController.videoPlayer.playbackProgress) {
        NSProgress *playbackProgress = (NSProgress *)object;
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(totalUnitCount))]) {
            NSTimeInterval douration = playbackProgress.totalUnitCount;
            NSInteger wholeMinutes = (int)trunc(douration / 60);
            self.durationLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)wholeMinutes, (long)((int)trunc(douration) - wholeMinutes * 60)];
            self.playHeadSlider.maximumValue = playbackProgress.totalUnitCount;
            
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(completedUnitCount))]) {
            if(self.playerController.videoPlayer.currentStatus & NSMVideoPlayerStatusLevelReadyToPlay) {
                NSTimeInterval currentTime = playbackProgress.completedUnitCount;
                NSInteger currentMinutes = (int)trunc(currentTime / 60);
                self.currentTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)currentMinutes, (long)((int)trunc(currentTime) - currentMinutes * 60)];
                self.playHeadSlider.value = playbackProgress.completedUnitCount;
            }
        }
        
    } else {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(completedUnitCount))]) {
            if(self.playerController.videoPlayer.currentStatus & NSMVideoPlayerStatusLevelReadyToPlay){
                NSProgress *bufferProgress = (NSProgress *)object;
                self.loadProgress.progress = bufferProgress.fractionCompleted;
            }
        }
    }
    
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(outputVolume))]) {
        self.volumSlider.value = [AVAudioSession sharedInstance].outputVolume;
        NSLog(@"outputVolume %@",@([AVAudioSession sharedInstance].outputVolume));
    }
}

#pragma mark - NSMVideoSourceControllerDelegate

- (void)videoSourceControllerDidSelectedPlayerItem:(NSMPlayerAsset *)playerAsset {
    [self.playerController.videoPlayer replaceCurrentAssetWithAsset:playerAsset];
}


@end
