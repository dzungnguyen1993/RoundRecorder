//
//  DzCaptureDataOutput.h
//  RoundRecorder
//
//  Created by Thanh-Dung Nguyen on 4/12/17.
//  Copyright © 2017 Dzung Nguyen. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@protocol DzCaptureDataOutputDelegate <NSObject>
- (void) didStartExporting;
- (void) didFinishExportingAtUrl:(NSURL*)url;
@end

@interface DzCaptureDataOutput : AVCaptureVideoDataOutput

@property (strong, nonatomic) id delegate;
- (instancetype) initDataOutput;
- (void)stopRecord;
- (NSURL*)getResultVideoUrl;
- (void)reset;
- (void)deallocWriters;
@end
