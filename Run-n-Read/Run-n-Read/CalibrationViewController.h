//
//  CalibrationViewController.h
//  SensorTagEX
//
//  Created by Shak on 8/21/13.
//  Copyright (c) 2013 Texas Instruments. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLEDevice.h"
#import "BLEUtility.h"
#import "deviceCellTemplate.h"
#import "Sensors.h"
#import "SensorHistoryData.h"
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>
#import <MessageUI/MessageUI.h>
#import "CorePlot-CocoaTouch.h"
#import "RealTimePlot.h"

#define MIN_ALPHA_FADE 0.2f
#define ALPHA_FADE_STEP 0.05f
#define CALIBRATION_TIME 30.0f
#define MAX_CAL_MEASURES 7
#define MAX_HIST_SAMPLES 50
#define CAL_TIME_INTERVAL 0.033f
#define GRAV_ESTIMATION 0.02f
#define K1_SMOOTHING 0.4f
#define K2_SMOOTHING 0.2f

@interface CalibrationViewController : UITableViewController <CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic,retain) CMMotionManager *devMotionManager;
@property (strong,nonatomic) BLEDevice *d;
@property NSMutableArray *sensorsEnabled;

@property (strong,nonatomic) accelerometerCellTemplate *acc;
@property (strong,nonatomic) accelerometerCellTemplate *mag;
@property (strong, nonatomic) UITableViewCell *headingCell;
@property (strong, nonatomic) UITableViewCell *graphCell;
@property (strong,nonatomic) sensorMAG3110 *magSensor;

@property (strong,nonatomic) sensorTagValues *currentVal;
@property (strong,nonatomic) NSMutableArray *vals;
@property (strong,nonatomic) NSTimer *logTimer;
@property (strong,nonatomic) NSTimer *alphaTimer;
@property (strong,nonatomic) NSTimer *calibrationTimer;
@property (strong,nonatomic) SensorHistoryData *calibrationHistory;
@property (strong,nonatomic) SensorHistoryData *sensorHistory;
@property (strong,nonatomic) RealTimePlot *accXGraph;
@property (strong,nonatomic) RealTimePlot *accYGraph;
@property (strong,nonatomic) RealTimePlot *accZGraph;
@property (nonatomic,retain) CPTGraphHostingView *hostXView;
@property (nonatomic,retain) CPTGraphHostingView *hostYView;
@property (nonatomic,retain) CPTGraphHostingView *hostZView;
@property bool isCalibrationOngoing;
@property NSInteger calibrationCountdown;
@property UILabel *calibrationOngoing;

@property float oldSensorHeading;
@property float oldTabletHeading;
@property UIImageView *tabletHeadingImage;
@property UIImageView *sensorHeadingImage;
@property float iVx, iVy, iVz;
@property float sensorGx, sensorGy, sensorGz;  // Estimates of gravity vector (average of last n accelerometer samples)

-(id) initWithStyle:(UITableViewStyle)style andSensorTag:(BLEDevice *)andSensorTag;

-(void) configureSensorTag;
-(void) deconfigureSensorTag;

- (IBAction) handleCalibrateMag;

-(void) alphaFader:(NSTimer *)timer;
-(void) logValues:(NSTimer *)timer;

@end
