//
//  RunReadPNGViewController.h
//  Run_Read_PNG
//
//  Created by Shak on 6/22/13.
//  Copyright (c) 2013 Shak. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <GLKit/GLKit.h>
#import "BLEDevice.h"
#import "BLEUtility.h"
#import "Sensors.h"
#import "SensorHistoryData.h"
#import "AccelerometerGraph.h"

#define MAX_MEASURES 7
#define MAX_SAMPLES 400
#define RR_PERIOD 0.016f
#define ACCELEROMETER_PERIOD 0.015f    // Can be a minimum of 10ms
#define MAX_X_SHIFT 10.0
#define MAX_Y_SHIFT 25.0
#define NUM_SAMPLES_PER_TABLET_UPDATE 100
#define SMOOTHING_WEIGHT_K1 0.0f  //These two weights will be used for accelerometer value smoothing
#define SMOOTHING_WEIGHT_K2 0.0f
#define K_GRAV_ESTIMATION 0.02f
#define NUM_SAMPLES_FOR_PD_HISTORY = 10;
#define NUM_SAMPLES_FOR_OR_HISTORY = 10;
#define TAP_THRESHOLD 1.6*M_PI/3.0  // For algorithm 2 based on angular change
#define SWIPE_THRESHOLD 0.06f
#define SWIPE_DETECTION_PAUSE 50  // In number of samples - multiply by sampling time period
#define TAP_DETECTION_PAUSE 5
#define TAP_DETECTION_WINDOW 25   // Taps (single/double) must happen within this window
#define IMAGE_SCALE_X 1.0     // Scale down size of image by this factor
#define IMAGE_SCALE_Y 0.9
#define DEFAULT_SIGNAL_LAG 6
#define MOVING_AVG_SAMPLES 3

@interface RunReadPNGViewController : GLKViewController {
    GLKView* imageView;
    EAGLContext* imageGLContext;
    GLKBaseEffect* imageEffect;
    GLuint _vertexBuffer, _indexBuffer, _vertexArray;
    
    NSInteger storyNum;
    NSInteger maxPages;
    NSInteger pageNum;
    CGFloat shift_x;
    CGFloat shift_y;
    bool MenuActivated;
}

@property (strong,nonatomic) BLEDevice *d;
@property NSMutableArray *sensorsEnabled;
@property (strong,nonatomic) NSThread* timerThread;

@property (strong,nonatomic) sensorMAG3110 *magSensor;

@property (strong,nonatomic) sensorTagValues *currentVal;
@property (strong,nonatomic) sensorTagValues *prevVal;
@property (strong,nonatomic) NSMutableArray *vals;
@property (strong,nonatomic) NSTimer *rrTimer;
@property (strong,nonatomic) NSTimer *menuTimer; // Starts when menu activated, counts down and then removes menu
@property float xSensitivity, ySensitivity;   // Parameters to control x,y displ. of screen
@property NSInteger signalLag;   // Parameter to control the lag of movement to screen display

@property float iVx, iVy, iVz;  // Hard Iron estimates
@property float sensorGx, sensorGy, sensorGz;  // Estimates of gravity vector (average of last n accelerometer samples)
@property float tabletPhi, tabletTheta, tabletPsi; // Orientation angles about X, Y & Z. X is horiz., Y is vert., Z is into plane of tablet
@property bool isWebView;
@property NSString* webURL;
@property bool isRunReadEnabled;
@property NSInteger tabletOrientationCountdown;
@property NSInteger swipeDetectCountdown, tapDetectCountdown, tapDetectWindow, numTapsDetected;
@property bool isSwipeDetectionEnabled, isTapDetectionEnabled;
@property (strong,nonatomic) SensorHistoryData *sensorHistory;
@property (strong,nonatomic) SensorHistoryData *peakDetectHistory;
@property (strong,nonatomic) SensorHistoryData *orientHistory;
@property (nonatomic,retain) CMMotionManager *devMotionManager;

-(id) init:(BLEDevice *)andSensorTag;

-(void) configureSensorTag;
-(void) deconfigureSensorTag;
-(void) setWebView:(bool)v withURL:(NSString*)u;
-(void) setStoryNumber:(NSInteger)snum withPages:(NSInteger)maxp;
-(void) setPageNumber:(NSInteger)pnum;

@end
