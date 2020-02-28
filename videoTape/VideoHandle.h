//
//  VideoHandle.h
//  videoTape
//
//  Created by Vito on 2020/2/28.
//  Copyright © 2020 inspur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ReplayKit/ReplayKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VideoHandleDelegate <NSObject>

@optional

/**
 *  开始录制回调
 */
-(void)replayRecordStart;

/**
 *  录制结束或错误回调
 */
-(void)replayRecordFinishWithVC:(RPPreviewViewController *)previewViewController errorInfo:(NSString *)errorInfo;
/**
 *  保存到系统相册成功回调
 */
-(void)saveSuccess;

@end

@interface VideoHandle : NSObject

/**
 *  代理
 */
@property (nonatomic,weak) id <VideoHandleDelegate> delegate;

/**
 *  是否正在录制
 */
@property (nonatomic,assign,readonly) BOOL isRecording;

/**
 *  单例对象
 */
+(instancetype)sharedReplay;

/**
 是否显示录制按钮
 
 */
-(void)isShowBtn:(BOOL)iscate;
/**
 *  开始录制
 */
-(void)startRecord;

/**
 *  结束录制
 *  isShow是否录制完后自动展示视频预览页
 */
-(void)stopRecordAndShowVideoPreviewController:(BOOL)isShow;

@end

NS_ASSUME_NONNULL_END
