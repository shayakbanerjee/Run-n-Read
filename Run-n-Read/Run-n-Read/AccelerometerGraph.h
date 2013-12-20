//
//  AccelerometerGraph.h
//  Run-n-Read
//
//  Created by Shak on 9/18/13.
//  Copyright (c) 2013 WearTrons Labs. All rights reserved.
//

#import <GLKit/GLKit.h>
#import "BLEDevice.h"
#import "BLEUtility.h"
#import "deviceCellTemplate.h"
#import "Sensors.h"
#import "SensorHistoryData.h"

#define PREDICTION_ON 0         // Set to 1 if you want to predict signal values, 0 if not
#define MAX_CAL_MEASURES 7
#define MAX_HIST_SAMPLES 50
#define CAL_TIME_INTERVAL_ACC 0.0167f
#define GRAV_ESTIMATION 0.02f
#define K1_SMOOTHING_ACC 0.0f
#define K2_SMOOTHING_ACC 0.0f
#define X_AXIS_STEP 0.02f
#define SIGNAL_LAG_INIT 6   // Lag = SIGNAL_LAG * Time Period
#define SAMPLES_MOVING_AVG 5

@interface AccelerometerGraph : GLKViewController <CBCentralManagerDelegate,CBPeripheralDelegate> {
    GLKView* imageView;
    EAGLContext* imageGLContext;
    GLKBaseEffect* imageEffect;
    GLuint _vertexBuffer, _indexBuffer, _vertexArray;
    float shift_x;
    float shift_y;
    float prev_shift_y;
    float x_axis;
}

@property NSMutableData *plotData;
@property NSInteger numPoints;
@property (strong,nonatomic) BLEDevice *d;
@property NSMutableArray *sensorsEnabled;
@property (strong,nonatomic) sensorMAG3110 *magSensor;

@property (strong,nonatomic) sensorTagValues *currentVal;
@property (strong,nonatomic) sensorTagValues *prevVal;
@property (strong,nonatomic) NSMutableArray *vals;
@property (strong,nonatomic) NSTimer *logTimer;
@property (strong,nonatomic) SensorHistoryData *calibrationHistory;
@property (strong,nonatomic) SensorHistoryData *sensorHistory;

@property float iVx, iVy, iVz;
@property float sensorGx, sensorGy, sensorGz;  // Estimates of gravity vector (average of last n accelerometer samples)
@property float estimFreq, estimAmpl, estimPhase;   // Estimates of sine wave used when predicting
@property NSInteger signalLag;   // How much to delay the signal by (in number of samples). Init to SIGNAL_LAG
@property NSDate* renderingStartTime;

-(id) init:(BLEDevice *)andSensorTag;

-(void) configureSensorTag;
-(void) deconfigureSensorTag;

@end
