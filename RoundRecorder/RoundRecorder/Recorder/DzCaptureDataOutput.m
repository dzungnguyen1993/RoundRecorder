//
//  DzCaptureDataOutput.m
//  RoundRecorder
//
//  Created by Thanh-Dung Nguyen on 4/12/17.
//  Copyright © 2017 Dzung Nguyen. All rights reserved.
//

#import "DzCaptureDataOutput.h"

#define SEGMENT_LENGTH 60 // 60s
#define VIDEO_WIDTH 720
#define VIDEO_HEIGHT 1280
#define VIDEO_LENGTH 30

@interface DzCaptureDataOutput() <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    dispatch_queue_t _sampleQueue;
    
    NSMutableArray *arrayAssetWriter;
    NSMutableArray *arrayAssetWriterInput;
    
    BOOL stopAndSaveVideo;
    
    int videoOrder;
    long lastRecordTimestamp;
}
@end

@implementation DzCaptureDataOutput

- (instancetype) initDataOutput {
    self = [super init];
    if (self) {
        _sampleQueue = dispatch_queue_create("VideoSampleQueue", DISPATCH_QUEUE_SERIAL);
        [self setSampleBufferDelegate:self queue:_sampleQueue];
        self.alwaysDiscardsLateVideoFrames = YES;
        printed = NO;
    }
    return self;
}

#pragma mark - Initialization
- (void)initWriter {
    NSLog(@"Init writer");
    arrayAssetWriter = [[NSMutableArray alloc] initWithCapacity:2];
    arrayAssetWriterInput = [[NSMutableArray alloc] initWithCapacity:2];
    
    [self initWriterWithOrder:0];
    [self initWriterWithOrder:1];
    
    [self deleteAllVideo];
}

- (void)initWriterWithOrder:(int)order {
    [[NSFileManager defaultManager]  removeItemAtURL:[self getVideoUrlWithOrder:order] error:nil];
    
    AVAssetWriter *assetWriter = [[AVAssetWriter alloc] initWithURL:[self getVideoUrlWithOrder:order] fileType:AVFileTypeQuickTimeMovie error:nil];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:VIDEO_WIDTH], AVVideoWidthKey,
                                   [NSNumber numberWithInt:VIDEO_HEIGHT], AVVideoHeightKey,
                                   nil];
    AVAssetWriterInput *assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    assetWriterInput.expectsMediaDataInRealTime = YES;
    [assetWriter addInput:assetWriterInput];
    
    arrayAssetWriter[order] = assetWriter;
    arrayAssetWriterInput[order] = assetWriterInput;
}

- (void)deleteAllVideo {
    [[NSFileManager defaultManager] removeItemAtURL:[self getVideoUrlWithOrder:0] error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:[self getVideoUrlWithOrder:1] error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:[self getRecordedVideoUrlWithOrder:0] error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:[self getRecordedVideoUrlWithOrder:1] error:nil];
}


- (NSURL*)getVideoUrlWithOrder:(int)order {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"video%d.mp4", order]];
    NSURL *url = [NSURL fileURLWithPath:path];
    return url;
}

- (NSURL*)getRecordedVideoUrlWithOrder:(int)order {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"recordedVideo%d.mp4", order]];
    NSURL *url = [NSURL fileURLWithPath:path];
    return url;
}

- (NSURL*)getResultVideoUrl {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"resultVideo.mp4"];
    NSURL *url = [NSURL fileURLWithPath:path];
    return url;
}

BOOL printed = NO;
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (stopAndSaveVideo) {
        return;
    }
    
    if (lastRecordTimestamp == 0) {
        lastRecordTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    }
    
    [self saveBufferToFile:sampleBuffer];
    
    long currentTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    if (currentTimestamp - lastRecordTimestamp >= SEGMENT_LENGTH * 1000) {
        // save video
        //        NSLog(@"Start export video");
        [self saveVideoWithOrder:videoOrder completion:^{
            
        }];
        
        // switch writer
        videoOrder = 1 - videoOrder;
        lastRecordTimestamp = currentTimestamp;
        //        NSLog(@"Timestamp: %ld", lastRecordTimestamp);
    }
}

#pragma mark - Recording

- (void)saveBufferToFile:(CMSampleBufferRef)sampleBuffer {
    if (arrayAssetWriter == nil || arrayAssetWriter.count < 2) {
        return;
    }
    
    AVAssetWriter *assetWriter = arrayAssetWriter[videoOrder];
    AVAssetWriterInput *assetWriterInput = arrayAssetWriterInput[videoOrder];
    
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        if (assetWriter.status != AVAssetWriterStatusWriting && assetWriter.status != AVAssetWriterStatusCancelled && assetWriter.status != AVAssetWriterStatusFailed) {
            NSLog(@"Start writing");
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [assetWriter startWriting];
            [assetWriter startSessionAtSourceTime:startTime];
        }
        if (assetWriterInput.readyForMoreMediaData == YES)
        {
            @try {
                [assetWriterInput appendSampleBuffer:sampleBuffer];
            }
            @catch (NSException * e) {
                NSLog(@"Exception: %@", e);
            }
        }
    }
}

- (void)saveVideoWithOrder:(int)order completion:(void (^)(void))handler {
    AVAssetWriter *assetWriter = arrayAssetWriter[order];
    AVAssetWriterInput *assetWriterInput = arrayAssetWriterInput[order];
    
    [assetWriterInput markAsFinished];
    
    [assetWriter finishWritingWithCompletionHandler:^{
        //        NSLog(@"End export video %d", order);
        if ([assetWriter error] == nil) {
            NSLog(@"Export video %d success", order);
        } else {
            NSLog(@"%@", [assetWriter error]);
        }
        
        NSError * err = NULL;
        NSFileManager * fm = [[NSFileManager alloc] init];
        [[NSFileManager defaultManager]  removeItemAtURL:[self getRecordedVideoUrlWithOrder:order] error:nil];
        [fm moveItemAtPath:[[self getVideoUrlWithOrder:order] path] toPath:[[self getRecordedVideoUrlWithOrder:order] path] error:&err];
        // reinit asset writer
        [self initWriterWithOrder:order];
        
        handler();
    }];
}

- (void)stopRecord {
    NSLog(@"Stop record");
    stopAndSaveVideo = YES;
    
    [self.delegate didStartExporting];
    [self saveVideoWithOrder:videoOrder completion:^{
        [self mergeVideo];
    }];
}

#pragma mark - Video Processing
- (void)mergeVideo {
    NSURL *firstURL = nil;
    NSURL *secondURL = nil;
    
    if (videoOrder == 0) {
        firstURL = [self getRecordedVideoUrlWithOrder:1];
        secondURL = [self getRecordedVideoUrlWithOrder:0];
    } else {
        firstURL = [self getRecordedVideoUrlWithOrder:0];
        secondURL = [self getRecordedVideoUrlWithOrder:1];
    }
    
    // if only 1 video exists
    if (![self checkFileExist:[firstURL path]]) {
        [self trimVideo:secondURL];
        return;
    }
    
    AVAsset *firstAsset = [AVAsset assetWithURL:firstURL];
    AVAsset *secondAsset = [AVAsset assetWithURL:secondURL];
    
    CMTime secondTime = secondAsset.duration;
    
    double secondDuration = CMTimeGetSeconds(secondTime);
    
    if (secondDuration >= VIDEO_LENGTH) {
        // only need to trim second video
        [self trimVideo:secondURL];
        return;
    }
    
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    // 2 - Video track
    AVMutableCompositionTrack *firstTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    [firstTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, firstAsset.duration)
                        ofTrack:[[firstAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    [firstTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, secondAsset.duration)
                        ofTrack:[[secondAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:firstAsset.duration error:nil];
    
    // 4 - Get path
    NSURL *resultUrl = [self getResultVideoUrl];
    
    [[NSFileManager defaultManager] removeItemAtURL:resultUrl error:nil];
    
    // 5 - Create exporter
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                      presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL=resultUrl;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    
    double stopTime = CMTimeGetSeconds(mixComposition.duration);
    double startTime = stopTime - VIDEO_LENGTH;
    
    CMTime start = CMTimeMakeWithSeconds(startTime, mixComposition.duration.timescale);
    CMTime end = CMTimeMakeWithSeconds(stopTime, mixComposition.duration.timescale);
    
    CMTimeRange range = CMTimeRangeMake(start, CMTimeSubtract(end,start));
    exporter.timeRange = range;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        [self finishRecord];
    }];
}

- (void)trimVideo:(NSURL*)videoUrl {
    // 4 - Get result path
    NSURL *resultUrl = [self getResultVideoUrl];
    [[NSFileManager defaultManager] removeItemAtURL:resultUrl error:nil];
    
    // 5 - Create exporter
    AVAsset *videoAsset = [[AVURLAsset alloc] initWithURL:videoUrl options:nil];
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:videoAsset
                                                                      presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL=resultUrl;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    
    double stopTime = CMTimeGetSeconds(videoAsset.duration);
    double startTime = stopTime - VIDEO_LENGTH;
    
    CMTime start = CMTimeMakeWithSeconds(startTime, videoAsset.duration.timescale);
    CMTime end = CMTimeMakeWithSeconds(stopTime, videoAsset.duration.timescale);
    
    CMTimeRange range = CMTimeRangeMake(start, CMTimeSubtract(end,start));
    exporter.timeRange = range;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        [self finishRecord];
    }];
}

- (void)finishRecord {
    [self.delegate didFinishExportingAtUrl:[self getResultVideoUrl]];
}

- (void)reset {
    [self initWriter];
    stopAndSaveVideo = NO;
    videoOrder = 0;
    lastRecordTimestamp = 0;
}

- (void)deallocWriters
{
    [arrayAssetWriter removeAllObjects];
    
    [arrayAssetWriterInput removeAllObjects];
    
    arrayAssetWriter = nil;
    arrayAssetWriterInput = nil;
}

- (BOOL)checkFileExist:(NSString*)path
{
    if (!path)
        return NO;
    NSURL *url = [NSURL fileURLWithPath:path];
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm fileExistsAtPath:url.path];
}
@end
