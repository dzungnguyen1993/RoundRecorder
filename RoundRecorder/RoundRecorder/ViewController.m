//
//  ViewController.m
//  RoundRecorder
//
//  Created by Thanh-Dung Nguyen on 4/12/17.
//  Copyright © 2017 Dzung Nguyen. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "DzCaptureDataOutput.h"

@interface ViewController () <DzCaptureDataOutputDelegate>
{
    AVCaptureSession *_captureSession;
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    DzCaptureDataOutput *dataOutput;
    NSTimer *recordAnimationTimer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupCameraSession];
}

#pragma mark - Initialization
- (void)setupCameraSession {
    // Create the AVCaptureSession
    _captureSession = [[AVCaptureSession alloc] init];
    
    // Create video device input
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if (videoDevice) {
        
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        [_captureSession addInput:videoDeviceInput];
        
        [self configureCameraForHighestFrameRate:videoDevice];
        
        // Setup the preview view
        captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [captureVideoPreviewLayer setBackgroundColor:[UIColor greenColor].CGColor];
        [self.previewView.layer addSublayer:captureVideoPreviewLayer];
        
        // Create output
        dataOutput = [[DzCaptureDataOutput alloc] initDataOutput];
        
        dataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        
        dataOutput.delegate = self;
        
        [_captureSession addOutput:dataOutput];
    } else {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:@"No video device" preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:ok];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
{
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if ( range.maxFrameRate > bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
            }
        }
    }
    if ( bestFormat ) {
        if ( [device lockForConfiguration:NULL] == YES ) {
            device.activeFormat = bestFormat;
            device.activeVideoMinFrameDuration = CMTimeMake(1, 120);//bestFrameRateRange.maxFrameDuration;
            device.activeVideoMaxFrameDuration = CMTimeMake(1, 120);//bestFrameRateRange.maxFrameDuration;
            [device unlockForConfiguration];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    captureVideoPreviewLayer.frame = CGRectMake(0,0, self.previewView.frame.size.width, self.previewView.frame.size.height);
    
    AVCaptureConnection *connection = [dataOutput connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    [dataOutput reset];
    [_captureSession startRunning];
    [self startRecordAnimation];
}

- (void)startRecordAnimation {
    recordAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(flashAnimation:) userInfo:nil repeats:YES];
}

- (void)flashAnimation:(NSTimer*)timer {
    if (self.btnStop.tag == 0) {
        self.btnStop.tag = 1;
        [self.btnStop setBackgroundImage:[UIImage imageNamed:@"Restart-Green"] forState:UIControlStateNormal];
    } else {
        self.btnStop.tag = 0;
        [self.btnStop setBackgroundImage:[UIImage imageNamed:@"Restart-Red"] forState:UIControlStateNormal];
    }
}


#pragma mark - Record
- (IBAction)stopRecord:(id)sender {
    [self.indicator startAnimating];
    [dataOutput stopRecord];
    
    // stop animation
    [recordAnimationTimer invalidate];
    [self.btnStop setBackgroundImage:[UIImage imageNamed:@"Restart-Green"] forState:UIControlStateNormal];
}

#pragma mark - DzCaptureDataOutputDelegate
- (void) didStartExporting {
    [_captureSession stopRunning];
}

- (void) didFinishExportingAtUrl:(NSURL*)url {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.indicator stopAnimating];
    });
    
    AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc] init];
    playerViewController.player = [AVPlayer playerWithURL:url];
    
    [self presentViewController:playerViewController animated:YES completion:^{
        [playerViewController.player play];
    }];
}

@end
