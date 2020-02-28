//
//  VideoHandle.m
//  videoTape
//
//  Created by Vito on 2020/2/28.
//  Copyright © 2020 inspur. All rights reserved.
//

#import "VideoHandle.h"
#import <AVKit/AVKit.h>

#import <Photos/Photos.h>
#import <AssetsLibrary/ALAsset.h>

#import <AssetsLibrary/ALAssetsLibrary.h>

#import <AssetsLibrary/ALAssetsGroup.h>

#import <AssetsLibrary/ALAssetRepresentation.h>

//弱引用
#define kWeakSelf(weakSelf) __weak __typeof(&*self)weakSelf = self;


@interface VideoHandle ()<RPPreviewViewControllerDelegate>
/**开始录制*/
@property (nonatomic,strong)UIButton *startBt;
/**结束录制*/
@property (nonatomic,strong)UIButton *endBt;
@property(strong,nonatomic)UIWindow *window;

@property (nonatomic,copy)NSString *videoPath;
@property (nonatomic,copy)NSString *compressVideoPath;
@property(strong,nonatomic)AVAssetWriter *assetWriter;
@property(strong,nonatomic)AVAssetWriterInput *AudioInput;
@property(strong,nonatomic)AVAssetWriterInput *assetWriterAudioInput;

@end



@implementation VideoHandle

#pragma mark ---懒加载

-(UIButton*)startBt{
    if(!_startBt){
        _startBt=[[UIButton alloc] initWithFrame:CGRectMake(0,0,80,50)];
        _startBt.backgroundColor=[UIColor redColor];
        [_startBt setTitle:@"开始录制" forState:UIControlStateNormal];
        _startBt.titleLabel.font=[UIFont systemFontOfSize:14];
        [_startBt addTarget:self action:@selector(startAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _startBt;
}
-(UIButton*)endBt{
    if(!_endBt){
        _endBt=[[UIButton alloc] initWithFrame:CGRectMake(0,60,80,50)];
        _endBt.backgroundColor=[UIColor redColor];
        [_endBt setTitle:@"结束录制" forState:UIControlStateNormal];
        _endBt.titleLabel.font=[UIFont systemFontOfSize:14];
        [_endBt addTarget:self action:@selector(endAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _endBt;
}

/**
 是否显示录制按钮
 
 */
-(void)isShowBtn:(BOOL)iscate{
    if (!iscate) return;
    [self performSelector:@selector(createWidow) withObject:nil afterDelay:1];
}
-(void)createWidow{
    self.window =[[UIWindow alloc]initWithFrame:CGRectMake(0, 100, 80, 120)];
    self.window.backgroundColor=[UIColor clearColor];
    self.window.windowLevel = UIWindowLevelAlert+1;
    [self.window makeKeyAndVisible];
    
    [self.window addSubview:self.startBt];
    [self.window addSubview:self.endBt];
    
}
//单例化对象
+(instancetype)sharedReplay{
    static VideoHandle *replay=nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        replay=[[VideoHandle alloc] init];
    });
    return replay;
}
-(void)startAction{
    
    [self.startBt setTitle:@"初始化中" forState:UIControlStateNormal];
    [[VideoHandle sharedReplay] startRecord];
}
-(void)endAction{
    [self.startBt setTitle:@"开始录制" forState:UIControlStateNormal];
    [[VideoHandle sharedReplay] stopRecordAndShowVideoPreviewController:YES];
}
//是否正在录制
-(BOOL)isRecording{
    return [RPScreenRecorder sharedRecorder].recording;
}

- (NSString *)videoPath {
    if (!_videoPath) {
        NSArray *pathDocuments = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *outputURL = pathDocuments[0];
        uint32_t random = arc4random() % 1000;
        _videoPath = [[outputURL stringByAppendingPathComponent:[NSString stringWithFormat:@"%u", random]] stringByAppendingPathExtension:@"mp4"];
        self.compressVideoPath = [[outputURL stringByAppendingPathComponent:[NSString stringWithFormat:@"%u_compress", random]] stringByAppendingPathExtension:@"mp4"];
        NSLog(@"%@", _videoPath);
        NSLog(@"%@", self.compressVideoPath);
    }
    return _videoPath;
}

- (AVAssetWriterInput *)AudioInput{
    if (_AudioInput) {
        return _AudioInput;
    }
    
    // 音频设置
    NSDictionary *dic  = @{ AVEncoderBitRatePerChannelKey : @(28000),
                            AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                            AVNumberOfChannelsKey : @(1),
                            AVSampleRateKey : @(22050) };
    
    _AudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:dic];
    _AudioInput.expectsMediaDataInRealTime = YES;
    return _AudioInput;
}

- (AVAssetWriterInput *)assetWriterAudioInput{
    //写入视频大小
    if (_assetWriterAudioInput){
        return _assetWriterAudioInput;
    }
    NSInteger numPixels = [UIScreen mainScreen].bounds.size.width * [UIScreen mainScreen].bounds.size.height ;
    //每像素比特
    CGFloat bitsPerPixel = 6.0;
    NSInteger bitsPerSecond = numPixels * bitsPerPixel;
    
    // 码率和帧率设置
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                             AVVideoExpectedSourceFrameRateKey : @(15),
                                             AVVideoMaxKeyFrameIntervalKey : @(15),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
    
    //视频属性
    NSDictionary *dic = @{ AVVideoCodecKey : AVVideoCodecTypeH264,
                           AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                           AVVideoWidthKey : @([UIScreen mainScreen].bounds.size.height * 2),
                           AVVideoHeightKey : @([UIScreen mainScreen].bounds.size.width * 2),
                           AVVideoCompressionPropertiesKey : compressionProperties };
    
    _assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:dic];
    //expectsMediaDataInRealTime 必须设为yes，需要从capture session 实时获取数据
    _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
    _assetWriterAudioInput.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
    
    return _assetWriterAudioInput;
}

- (AVAssetWriter *)assetWriter {
    if (!_assetWriter) {
        NSError *error = nil;
        _assetWriter = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:self.videoPath]
                                                fileType:AVFileTypeMPEG4
                                                   error:&error];
        
        if (error) {
            NSLog(@"初始化 AVAssetWriter 失败：%@", error);
        }
        
        
        
        if ([_assetWriter canAddInput:self.AudioInput]) {
            [_assetWriter addInput:self.AudioInput];
        }
        
        if ([_assetWriter canAddInput:self.assetWriterAudioInput]) {
            [_assetWriter addInput:self.assetWriterAudioInput];
        }
    }
    return _assetWriter;
}
#pragma mark - 开始/结束录制
//开始录制
-(void)startRecord{
    if ([RPScreenRecorder sharedRecorder].recording==YES) {
        NSLog(@"VideoHandle:已经开始录制");
        return;
    }
    if ([self systemVersionOK]) {
        if (![RPScreenRecorder sharedRecorder].isMicrophoneEnabled) {
            [RPScreenRecorder sharedRecorder].microphoneEnabled = YES;
        }
        
        
//        iOS 11以上
        // 开始录屏
        //        [[RPScreenRecorder sharedRecorder] startCaptureWithHandler:^(CMSampleBufferRef  _Nonnull sampleBuffer, RPSampleBufferType bufferType, NSError * _Nullable error) {
        //
        //            if (self.assetWriter.status == AVAssetWriterStatusWriting) {
        //                if (bufferType == RPSampleBufferTypeAudioMic) {
        //                    NSLog(@"声音来了");
        //                    if (self.AudioInput.isReadyForMoreMediaData) {
        //                        CFRetain(sampleBuffer);
        //                        // 将sampleBuffer添加进视频输入源
        //                        [self.AudioInput appendSampleBuffer:sampleBuffer];
        //                        CFRelease(sampleBuffer);
        //                    }
        //
        //                }
        //            }
        //
        //
        //            if (self.assetWriter.status == AVAssetWriterStatusUnknown && bufferType == RPSampleBufferTypeVideo) {
        //                [self.assetWriter startWriting];
        //                CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        //                int64_t videopts  = CMTimeGetSeconds(pts) * 1000;
        //
        //                // 丢掉无用帧
        //                if (videopts < 0) {
        //                    NSLog(@"无用帧");
        //                    return ;
        //                }
        //
        //                [self.assetWriter startSessionAtSourceTime:pts];
        //            }
        //
        //
        //            if (self.assetWriter.status == AVAssetWriterStatusFailed) {
        //                NSLog(@"An error occured: %@", self.assetWriter.error);
        //                [self stopRecordAndShowVideoPreviewController:YES];
        //                return;
        //            }
        //
        //            if (bufferType == RPSampleBufferTypeVideo) {
        //                if (self.assetWriterAudioInput.isReadyForMoreMediaData) {
        //                    CFRetain(sampleBuffer);
        //                    // 将sampleBuffer添加进视频输入源
        //                    [self.assetWriterAudioInput appendSampleBuffer:sampleBuffer];
        //                    CFRelease(sampleBuffer);
        //                } else {
        //                    NSLog(@"Not ready for video");
        //                }
        //            }
        //        } completionHandler:^(NSError * _Nullable error) {
        //            if (error) {
        //                NSLog(@"开始录制error %@",error);
        //            } else {
        //                NSLog(@"开始录制");
        //                [self.startBt setTitle:@"录制..." forState:UIControlStateNormal];
        //            }
        //        }];
        //        return;
        
        //        iOS 10以上
        kWeakSelf(weakSelf);
        [[RPScreenRecorder sharedRecorder] startRecordingWithHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"VideoHandle:开始录制error %@",error);
                if ([weakSelf.delegate respondsToSelector:@selector(replayRecordFinishWithVC:errorInfo:)]) {
                    [weakSelf.delegate replayRecordFinishWithVC:nil errorInfo:[NSString stringWithFormat:@"VideoHandle:开始录制error %@",error]];
                }
            }else{
                NSLog(@"VideoHandle:开始录制");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.startBt setTitle:@"正在录制" forState:UIControlStateNormal];
                });
                if ([weakSelf.delegate respondsToSelector:@selector(replayRecordStart)]) {
                    [weakSelf.delegate replayRecordStart];
                }
            }
        }];
    }
}
-(void)ios_10{
    kWeakSelf(weakSelf);
    
    [[RPScreenRecorder sharedRecorder] startRecordingWithHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"VideoHandle:开始录制error %@",error);
            if ([weakSelf.delegate respondsToSelector:@selector(replayRecordFinishWithVC:errorInfo:)]) {
                [weakSelf.delegate replayRecordFinishWithVC:nil errorInfo:[NSString stringWithFormat:@"VideoHandle:开始录制error %@",error]];
            }
        }else{
            NSLog(@"VideoHandle:开始录制");
            [self.startBt setTitle:@"正在录制" forState:UIControlStateNormal];
            if ([weakSelf.delegate respondsToSelector:@selector(replayRecordStart)]) {
                [weakSelf.delegate replayRecordStart];
            }
        }
    }];
}
-(void)ios9_ios10 API_DEPRECATED("Use microphoneEnabaled property", ios(9.0, 10.0)){
    
    kWeakSelf(weakSelf);
    
    [[RPScreenRecorder sharedRecorder] startRecordingWithMicrophoneEnabled:YES handler:^(NSError *error){
        if (error) {
            NSLog(@"VideoHandle:开始录制error %@",error);
            
            if ([weakSelf.delegate respondsToSelector:@selector(replayRecordFinishWithVC:errorInfo:)]) {
                [weakSelf.delegate replayRecordFinishWithVC:nil errorInfo:[NSString stringWithFormat:@"VideoHandle:开始录制error %@",error]];
            }
        }else{
            NSLog(@"VideoHandle:开始录制");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.startBt setTitle:@"正在录制" forState:UIControlStateNormal];
            });
            
            if ([weakSelf.delegate respondsToSelector:@selector(replayRecordStart)]) {
                [weakSelf.delegate replayRecordStart];
            }
        }
    }];
    
}
//结束录制
-(void)stopRecordAndShowVideoPreviewController:(BOOL)isShow{
    NSLog(@"VideoHandle:正在结束录制");
    kWeakSelf(weakSelf);
    
//    iOS11以上
    // 结束录屏
    //    [[RPScreenRecorder sharedRecorder] stopCaptureWithHandler:^(NSError * _Nullable error) {
    //        if (error) {
    //            NSLog(@"stopCaptureWithHandler: %@", error);
    //        }
    //
    //        [self.startBt setTitle:@"开始" forState:UIControlStateNormal];
    //        // 结束写入
    //        __weak typeof(self) weakSelf = self;
    //        [self.assetWriter finishWritingWithCompletionHandler:^{
    //            // 结束录屏
    //            {
    //                self.assetWriter = nil;
    //                self.assetWriterAudioInput = nil;
    //            }
    //            __strong typeof(self) strongSelf = weakSelf;
    //            NSLog(@"屏幕录制结束，视频地址: %@", strongSelf.videoPath);
    //        }];
    //    }];
    //
    //    return;
    
    //    iOS9以上
    [[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController *previewViewController, NSError *  error){
        [self.startBt setTitle:@"开始录制" forState:UIControlStateNormal];
        if (error) {
            NSLog(@"VideoHandle:结束录制error %@", error);
            if ([weakSelf.delegate respondsToSelector:@selector(replayRecordFinishWithVC:errorInfo:)]) {
                [weakSelf.delegate replayRecordFinishWithVC:nil errorInfo:[NSString stringWithFormat:@"VideoHandle:结束录制error %@",error]];
            }
        }
        else {
            NSLog(@"VideoHandle:录制完成");
            if ([weakSelf.delegate respondsToSelector:@selector(replayRecordFinishWithVC:errorInfo:)]) {
                [weakSelf.delegate replayRecordFinishWithVC:previewViewController errorInfo:@""];
            }
            
            NSURL *movieURL = [previewViewController valueForKey:@"movieURL"];
            
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc]init];
            [library writeVideoAtPathToSavedPhotosAlbum:movieURL completionBlock:^(NSURL *assetURL, NSError *error) {
                if (error) {
                    
                    NSLog(@"Save video to system Album failed:%@",error);
                }else{
                    AVURLAsset *asset =[[AVURLAsset alloc] initWithURL:assetURL options:nil];
                    
                    // 这里是原本的图片url
                    NSString * path = @"assets-library://asset/asset.JPG?id=9581C151-4582-4ABD-A581-1F34E037E1A0&ext=JPG";
                    // 取出要使用的 LocalIdentifiers
                    NSString * usePath = @"9581C151-4582-4ABD-A581-1F34E037E1A0";
                    
                    
                    PHFetchResult * fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil];
                    PHAsset *assetsss = fetchResult.firstObject;
                    [self getVideoPathFromPHAsset:assetsss];

                    NSLog(@"Save video to system album success!");
                    
                }
            }];
            
            
            if (isShow) {
                //                [self showVideoPreviewController:previewViewController animation:YES];
            }
        }
    }];
}

//获取视频data
- (void)getVideoPathFromPHAsset:(PHAsset *)asset {
    NSArray *assetResources = [PHAssetResource assetResourcesForAsset:asset];
    PHAssetResource *resource;
    
    for (PHAssetResource *assetRes in assetResources) {
        if (assetRes.type == PHAssetResourceTypePairedVideo ||
            assetRes.type == PHAssetResourceTypeVideo) {
            resource = assetRes;
        }
    }
    NSString *fileName = @"tempAssetVideo.mov";
    if (resource.originalFilename) {
        fileName = resource.originalFilename;
    }
    
    if (asset.mediaType == PHAssetMediaTypeVideo || asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) {
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.version = PHImageRequestOptionsVersionCurrent;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        
        NSString *PATH_MOVIE_FILE = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtPath:PATH_MOVIE_FILE error:nil];
        [[PHAssetResourceManager defaultManager] writeDataForAssetResource:resource
                                                                    toFile:[NSURL fileURLWithPath:PATH_MOVIE_FILE]
                                                                   options:nil
                                                         completionHandler:^(NSError * _Nullable error) {
                                                             if (error) {
                                                                 
                                                             } else {
                                                                 NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:PATH_MOVIE_FILE]];
                                                                 NSData *datas = [NSData dataWithContentsOfFile:PATH_MOVIE_FILE];
                                                                 NSLog(@"sdf");
                                                                 
                                                                 NSArray *pathDocuments = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                                                                 NSString *outputURL = pathDocuments[0];
                                                                 uint32_t random = arc4random() % 1000;
                                                                 NSString * Path = [[outputURL stringByAppendingPathComponent:[NSString stringWithFormat:@"abcd%u", random]] stringByAppendingPathExtension:@"mp4"];
                                                                 NSLog(@"=====%@",Path);
                                                                 [datas writeToFile:Path atomically:YES];
                                                                 
                                                                 
                                                                 
                                                                 NSLog(@"%@",[NSThread currentThread]);
                                                             }
                                                         }];
    } else {
        
    }
}
#pragma mark - 显示/关闭视频预览页
//显示视频预览页面
-(void)showVideoPreviewController:(RPPreviewViewController *)previewController animation:(BOOL)animation {
    previewController.previewControllerDelegate=self;
    
    __weak UIViewController *rootVC=[self getRootVC];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect rect = [UIScreen mainScreen].bounds;
        
        if (animation) {
            rect.origin.x+=rect.size.width;
            previewController.view.frame=rect;
            rect.origin.x-=rect.size.width;
            [UIView animateWithDuration:0.3 animations:^(){
                previewController.view.frame=rect;
            }];
        }
        else{
            previewController.view.frame=rect;
        }
        
        [rootVC.view addSubview:previewController.view];
        [rootVC addChildViewController:previewController];
    });
    
}
//关闭视频预览页面
-(void)hideVideoPreviewController:(RPPreviewViewController *)previewController animation:(BOOL)animation {
    previewController.previewControllerDelegate=nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect rect = previewController.view.frame;
        
        if (animation) {
            rect.origin.x+=rect.size.width;
            [UIView animateWithDuration:0.3 animations:^(){
                previewController.view.frame=rect;
            }completion:^(BOOL finished){
                [previewController.view removeFromSuperview];
                [previewController removeFromParentViewController];
            }];
            
        }
        else{
            [previewController.view removeFromSuperview];
            [previewController removeFromParentViewController];
        }
    });
}
#pragma mark - 视频预览页回调
//关闭的回调
- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController {
    [self hideVideoPreviewController:previewController animation:YES];
}
//选择了某些功能的回调（如分享和保存）
- (void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet <NSString *> *)activityTypes {
    if ([activityTypes containsObject:@"com.apple.UIKit.activity.SaveToCameraRoll"]) {
        NSLog(@"VideoHandle:保存到相册成功");
        if ([_delegate respondsToSelector:@selector(saveSuccess)]) {
            [_delegate saveSuccess];
        }
    }
    if ([activityTypes containsObject:@"com.apple.UIKit.activity.CopyToPasteboard"]) {
        NSLog(@"VideoHandle:复制成功");
    }
}
#pragma mark - 其他方法
//判断对应系统版本是否支持ReplayKit
-(BOOL)systemVersionOK{
    if ([[UIDevice currentDevice].systemVersion floatValue]<9.0) {
        return NO;
    } else {
        return YES;
    }
}
//获取rootVC
-(UIViewController *)getRootVC{
    return [UIApplication sharedApplication].delegate.window.rootViewController;
}

@end
