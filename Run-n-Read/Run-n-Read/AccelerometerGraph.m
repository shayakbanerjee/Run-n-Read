//
//  AccelerometerGraph.m
//  Run-n-Read
//
//  Created by Shak on 9/18/13.
//  Copyright (c) 2013 WearTrons Labs. All rights reserved.
//

#import "AccelerometerGraph.h"

@interface AccelerometerGraph ()

@end

@implementation AccelerometerGraph

@synthesize d;
@synthesize sensorsEnabled;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(id) init
{
    self = [super init];
    self.preferredFramesPerSecond = 60;
    shift_x = shift_y = 0.0;
    x_axis = -1.0;
    self.magSensor = [[sensorMAG3110 alloc] init];
    self.sensorHistory = [[SensorHistoryData alloc] init:3 withSamples:MAX_HIST_SAMPLES];
    
    self.currentVal = [[sensorTagValues alloc]init];
    self.prevVal = [[sensorTagValues alloc] init];
    self.vals = [[NSMutableArray alloc]init];
    
    // Set gravity estimates to 0
    self.sensorGx = self.sensorGy = self.sensorGz = 0.0;
    
    // Set sine wave estimate parameters
    self.renderingStartTime = nil;
    self.estimAmpl = 1.0; self.estimFreq = 0.400; self.estimPhase = 0.0;
    
    //Read Hard Iron EStimates from file
    [self readHIEstimatesFromFile];
    
    self.logTimer = [NSTimer scheduledTimerWithTimeInterval:CAL_TIME_INTERVAL_ACC target:self selector:@selector(logValues:) userInfo:nil repeats:YES];
    [self setupGL];
    
    return self;
}

-(id)init:(BLEDevice *)andSensorTag {
    self = [super init];
    if (self)
        self.d = andSensorTag;
    if(!self.d) NSLog(@"Could not connect to Run-n-Read Device!");
    self.preferredFramesPerSecond = 60;
    shift_x = shift_y = 0.0;
    x_axis = -1.0;
    self.magSensor = [[sensorMAG3110 alloc] init];
    self.sensorHistory = [[SensorHistoryData alloc] init:3 withSamples:MAX_HIST_SAMPLES];
    
    self.currentVal = [[sensorTagValues alloc]init];
    self.prevVal = [[sensorTagValues alloc]init];
    self.vals = [[NSMutableArray alloc]init];
    
    // Set gravity estimates to 0
    self.sensorGx = self.sensorGy = self.sensorGz = 0.0;
    
    //Read Hard Iron EStimates from file
    [self readHIEstimatesFromFile];
    
    // Set the lag
    self.signalLag = SIGNAL_LAG_INIT;
    
    self.logTimer = [NSTimer scheduledTimerWithTimeInterval:CAL_TIME_INTERVAL_ACC target:self selector:@selector(logValues:) userInfo:nil repeats:YES];
    [self setupGL];
    
    return self;
}

-(void)viewWillDisappear:(BOOL)animated {
    [self deconfigureSensorTag];
    [self.logTimer invalidate];
    self.logTimer = nil;
}

-(void)viewDidDisappear:(BOOL)animated {
    self.sensorsEnabled = nil;
    self.d.manager.delegate = nil;
}


- (void)viewDidAppear:(BOOL)animated {
    self.sensorsEnabled = [[NSMutableArray alloc] init];
    if (!self.d.p.isConnected) {
        self.d.manager.delegate = self;
        [self.d.manager connectPeripheral:self.d.p options:nil];
    }
    else {
        self.d.p.delegate = self;
        [self configureSensorTag];
        self.title = @"Accelerometer Graph";
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    imageGLContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    imageView = (GLKView*)self.view;
    imageView.context = imageGLContext;
    imageView.drawableMultisample = GLKViewDrawableMultisample4X;
    imageView.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    imageView.drawableColorFormat = GLKViewDrawableColorFormatRGB565;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Setup GL
typedef struct {
    float Position[3];
    float Color[4];
    //float TexCoord[2];
} VertexAcc;

const GLubyte IndicesAcc[] = {
    0, 1, 2,
    2, 3, 0
};

- (void)setupGL {
    
    [EAGLContext setCurrentContext:imageGLContext];
    imageEffect = [[GLKBaseEffect alloc] init];
    
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1, 1, -100, 100);
    imageEffect.transform.projectionMatrix = projectionMatrix;
    
    self.plotData = [[NSMutableData alloc] init];
    self.numPoints = 0;
    
    // Add a slider to control the delay to peak
    CGFloat slX = self.view.bounds.origin.x + 0.35*self.view.bounds.size.width;
    CGFloat slY = self.view.bounds.origin.y + 0.70*self.view.bounds.size.height;
    CGFloat slW = 0.65*self.view.bounds.size.width;
    CGFloat slH = 0.075*self.view.bounds.size.height;
    UILabel *sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(slX,slY,slW,slH)];
    sliderLabel.text = [NSString stringWithFormat:@"Set Signal Lag (%f)",(float)self.signalLag*CAL_TIME_INTERVAL_ACC];
    sliderLabel.backgroundColor = [UIColor blackColor];
    sliderLabel.textColor = [UIColor whiteColor];
    sliderLabel.adjustsFontSizeToFitWidth = YES;
    sliderLabel.minimumScaleFactor = 0.5;
    
    sliderLabel.tag = 5504;
    [self.view addSubview:sliderLabel];
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(slX,(slY+slH),slW,slH)];
    [slider setBackgroundColor:[UIColor blackColor]];
    slider.minimumValue = 0.0;
    slider.maximumValue = 25.0;
    slider.minimumValueImage = [UIImage imageNamed:@"minus_sign.png"];
    slider.maximumValueImage = [UIImage imageNamed:@"plus_sign.png"];
    slider.continuous = YES;
    slider.value = self.signalLag;
    [slider addTarget:self action:@selector(updateLag:) forControlEvents:UIControlEventValueChanged];
    slider.tag = 5503;
    [self.view addSubview:slider];

}

//Method to update deliberately introduced peak delay
-(IBAction)updateLag:(UISlider*)sender {
    self.signalLag = (NSInteger)sender.value;
    UILabel *sliderLabel = (UILabel*)[self.view viewWithTag:5504];
    sliderLabel.text = [NSString stringWithFormat:@"Set Signal Lag (%f)",(float)self.signalLag*CAL_TIME_INTERVAL_ACC];
    NSLog(@"Updated Lag to %d samples",self.signalLag);
}

- (void)tearDownGL {
    
    [EAGLContext setCurrentContext:imageGLContext];
    
    imageEffect = nil;
    self.plotData = nil;

    [[self.view viewWithTag:5504] removeFromSuperview];
    [[self.view viewWithTag:5503] removeFromSuperview];

}

#pragma mark - GLKViewDelegate

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    
    NSDate* renderStart = [NSDate date];
    if(!self.renderingStartTime) self.renderingStartTime = renderStart;
    
/////////////////////////////////////////////
    // All processing of data values happens here
    /////////////////////////////////////////////
    
    sensorTagValues *newVal = [[sensorTagValues alloc]init];
    NSTimeInterval curTime = [[NSDate date] timeIntervalSince1970];
    NSString *dbg = @"Blank";
    if(self.prevVal.timeStamp <= curTime && self.prevVal.timeStamp>curTime-CAL_TIME_INTERVAL_ACC) {
        newVal.accX = self.prevVal.accX;
        newVal.accY = self.prevVal.accY;
        newVal.accZ = self.prevVal.accZ;
        newVal.magX = self.prevVal.magX;
        newVal.magY = self.prevVal.magY;
        newVal.magZ = self.prevVal.magZ;
        newVal.timeStamp = self.prevVal.timeStamp;
        dbg = @"Previous";
    } else {
        newVal.accX = self.currentVal.accX;
        newVal.accY = self.currentVal.accY;
        newVal.accZ = self.currentVal.accZ;
        newVal.magX = self.currentVal.magX;
        newVal.magY = self.currentVal.magY;
        newVal.magZ = self.currentVal.magZ;
        newVal.timeStamp = self.currentVal.timeStamp;
        dbg = @"Current";
    }
    // Find new sensor accln. and add to history
    NSMutableArray *sensorVals = [[NSMutableArray alloc] init];
    [sensorVals addObject:[NSNumber numberWithFloat:newVal.accX]];
    [sensorVals addObject:[NSNumber numberWithFloat:newVal.accY]];
    [sensorVals addObject:[NSNumber numberWithFloat:newVal.accZ]];
    float currentAccX = newVal.accX;
    float currentAccY = newVal.accY;
    float currentAccZ = newVal.accZ;
    //NSLog(@",%@,%f,%f,%f,%f",dbg,newVal.timeStamp,currentAccX,currentAccY,currentAccZ);
    
    //Enable this block of code for complementary filter based gravity estimation
    self.sensorGx = GRAV_ESTIMATION*currentAccX + (1.0-GRAV_ESTIMATION)*self.sensorGx;
    self.sensorGy = GRAV_ESTIMATION*currentAccY + (1.0-GRAV_ESTIMATION)*self.sensorGy;
    self.sensorGz = GRAV_ESTIMATION*currentAccZ + (1.0-GRAV_ESTIMATION)*self.sensorGz;
    
    [self.sensorHistory enqueueData:sensorVals];
    
    // Find sensor magnetometer readings
    [sensorVals addObject:[NSNumber numberWithFloat:(newVal.magX-self.iVx)]];
    [sensorVals addObject:[NSNumber numberWithFloat:(newVal.magY-self.iVy)]];
    [sensorVals addObject:[NSNumber numberWithFloat:(newVal.magZ-self.iVz)]];
    
    // Get sensor heading
    if(self.sensorHistory.numSamples >= self.signalLag+SAMPLES_MOVING_AVG) {
        
        NSMutableArray *rec2 = [self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples-self.signalLag-3)];
        NSMutableArray *rec1 =[self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples-self.signalLag-2)];
        float w1 = K1_SMOOTHING_ACC, w2 = K2_SMOOTHING_ACC; // a_smooth = [a(k) + w1*a(k-1) + w2*a(k-2)]/(1+w1+w2)
        float accXFiltered = (currentAccX + w1*[[rec1 objectAtIndex:0] floatValue] + w2*[[rec2 objectAtIndex:0] floatValue])/(1.0+w1+w2) - self.sensorGx;
        float accYFiltered = (currentAccY + w1*[[rec1 objectAtIndex:1] floatValue] + w2*[[rec2 objectAtIndex:1] floatValue])/(1.0+w1+w2) - self.sensorGy;
        float accZFiltered = (currentAccZ + w1*[[rec1 objectAtIndex:2] floatValue] + w2*[[rec2 objectAtIndex:2] floatValue])/(1.0+w1+w2) - self.sensorGz;
        /*
        // Do n-sample moving average here
        NSArray* accFilter = [self nSampleMovingAvg:SAMPLES_MOVING_AVG];
        float accXFiltered = [[accFilter objectAtIndex:0] floatValue]-self.sensorGx;
        float accYFiltered = [[accFilter objectAtIndex:1] floatValue]-self.sensorGy;
        float accZFiltered = [[accFilter objectAtIndex:2] floatValue]-self.sensorGz;
         */
        
        // Below lines are the simplest model - ever
        float accXTrans = accXFiltered;
        float accYTrans = 0.0;
        if(!PREDICTION_ON) { // Below line sets to current accln. sample value
            //accYTrans = -accYFiltered;  //-ve because negative Y value displaces text up -> corresponds to +ve accln. upwards for head
            accYTrans = accYFiltered;   //+ve because we are cheating and deliberately delaying the whole sine wave
        } else { // Below line sets to sine wave based prediction
            accYTrans = -self.estimAmpl*sin(2*M_PI*self.estimFreq*[[NSDate date] timeIntervalSinceDate:self.renderingStartTime]+self.estimPhase);
        }
        shift_x = accXTrans*0.5;
        prev_shift_y = shift_y;
        shift_y = accYTrans*0.5;
    } else {
        // Just generate a sine wave
        float accYTrans = 1.0*sin(2*M_PI*fmod((double)[[NSDate date] timeIntervalSince1970]*1e3,2000.0)/2000.0);  //Time period of 600 ms
        shift_y = accYTrans;
    }
    
    ///////////////////////////////
    // All rendering happens here
    ////////////////////////////////
    glClearColor(0.1, 0.0, 0.1, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
        
    // Below code for drawing triangles
    //float vertices[] = {x_axis+0.05,shift_y,
    //    x_axis-0.05, shift_y,
    //    x_axis, shift_y+0.05};
    //[self.plotData appendBytes:vertices length:6*sizeof(float)];
    //self.numPoints+=3;
    
    // Below code sor drawing lines
    float vertices[] = {x_axis-X_AXIS_STEP, prev_shift_y, 0.0, x_axis, shift_y, 0.0};
    [self.plotData appendBytes:vertices length:6*sizeof(float)];
    self.numPoints+=2;
    
    /*
    // New lines
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    // Old stuff
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(IndicesAcc), IndicesAcc, GL_STATIC_DRAW);*/
    
    // New line
    //glBindVertexArrayOES(0);
    
    [imageEffect prepareToDraw];
    
    //glBindVertexArrayOES(_vertexArray);
    //glDrawElements(GL_TRIANGLES, sizeof(IndicesAcc)/sizeof(IndicesAcc[0]), GL_UNSIGNED_BYTE, 0);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    //glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, 0, [self.plotData mutableBytes]);
    //glDrawArrays(GL_TRIANGLES, 0, self.numPoints);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, [self.plotData mutableBytes]);
    glLineWidth(1.0);
    glDrawArrays(GL_LINE_LOOP, 0, self.numPoints);
    glDisableVertexAttribArray(GLKVertexAttribPosition);
    glFlush();
    
    //double tS = [[NSDate date] timeIntervalSinceDate:renderStart];
    //NSLog(@"Rendering Delay: %f,%f",tS*1000,(-shift_y*2.0+self.sensorGy));
    //double tS = [[NSDate date] timeIntervalSince1970];
    //NSLog(@"Rendered at: %f,%f",(tS-floor(tS))*1000,(-shift_y*2.0+self.sensorGy));
    
    x_axis += X_AXIS_STEP;
    if(x_axis>=1.0) {
        [self tearDownGL];
        [self setupGL];
        x_axis = -1.0;
    }
}


-(void) logValues:(NSTimer *)timer {
    
    //Estimate the sine wave in this timer
    if(self.sensorHistory.numSamples>=3) {
        NSMutableArray *rec2 = [self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples-1)];
        NSMutableArray *rec1 =[self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples-2)];
        NSMutableArray *rec0 = [self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples-3)];
        NSArray* yvals = [NSArray arrayWithObjects:[rec0 objectAtIndex:1],[rec1 objectAtIndex:1],[rec2 objectAtIndex:2], nil];
        //[self estimateSineParams:yvals];     // Turn this on for prediction
    }
}

-(void) configureSensorTag {
    // Configure sensortag, turning on Sensors and setting update period for sensors etc ...
    
    if ([self sensorEnabled:@"Accelerometer active"]) {
        CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer service UUID"]];
        CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer config UUID"]];
        CBUUID *pUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer period UUID"]];
        //NSInteger period = [[self.d.setupData valueForKey:@"Accelerometer period"] integerValue];
        //uint8_t periodData = (uint8_t)(CAL_TIME_INTERVAL_ACC*1000);
        //uint8_t periodData = (uint8_t)period;
        uint8_t periodData = (uint8_t)(1*15);
        NSLog(@"Accelerometer Period = %d",periodData);
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:pUUID data:[NSData dataWithBytes:&periodData length:1]];
        uint8_t data = 0x01;
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
        cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer data UUID"]];
        [BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:YES];
        //[BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:NO];
        
        [self.sensorsEnabled addObject:@"Accelerometer"];
    }
    
    if ([self sensorEnabled:@"Magnetometer active"]) {
        CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer service UUID"]];
        CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer config UUID"]];
        CBUUID *pUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer period UUID"]];
        NSInteger period = [[self.d.setupData valueForKey:@"Magnetometer period"] integerValue];
        //uint8_t periodData = (uint8_t)(period / 10);
        uint8_t periodData = (uint8_t)period;
        NSLog(@"Magnetometer Period = %d",periodData);
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:pUUID data:[NSData dataWithBytes:&periodData length:1]];
        uint8_t data = 0x01;
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
        cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer data UUID"]];
        [BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:YES];
        [self.sensorsEnabled addObject:@"Magnetometer"];
    }
    
}

-(void) deconfigureSensorTag {
    if ([self sensorEnabled:@"Accelerometer active"]) {
        CBUUID *sUUID =  [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer service UUID"]];
        CBUUID *cUUID =  [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer config UUID"]];
        uint8_t data = 0x00;
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
        cUUID =  [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer data UUID"]];
        [BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:NO];
    }
    if ([self sensorEnabled:@"Magnetometer active"]) {
        CBUUID *sUUID =  [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer service UUID"]];
        CBUUID *cUUID =  [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer config UUID"]];
        uint8_t data = 0x00;
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
        cUUID =  [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer data UUID"]];
        [BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:NO];
    }
}

-(bool)sensorEnabled:(NSString *)Sensor {
    NSString *val = [self.d.setupData valueForKey:Sensor];
    if (val) {
        if ([val isEqualToString:@"1"]) return TRUE;
    }
    return FALSE;
}

-(int)sensorPeriod:(NSString *)Sensor {
    NSString *val = [self.d.setupData valueForKey:Sensor];
    return [val integerValue];
}



#pragma mark - CBCentralManager delegate function

-(void) centralManagerDidUpdateState:(CBCentralManager *)central {
    
}

-(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}


#pragma mark - CBperipheral delegate functions

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    NSLog(@"..");
    if ([service.UUID isEqual:[CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer service UUID"]]]) {
        [self configureSensorTag];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSLog(@".");
    for (CBService *s in peripheral.services) [peripheral discoverCharacteristics:nil forService:s];
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didUpdateNotificationStateForCharacteristic %@, error = %@",characteristic.UUID, error);
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    self.prevVal.timeStamp = self.currentVal.timeStamp;
    self.prevVal.accX = self.currentVal.accX;
    self.prevVal.accY = self.currentVal.accY;
    self.prevVal.accZ = self.currentVal.accZ;
    self.prevVal.magX = self.currentVal.magX;
    self.prevVal.magY = self.currentVal.magY;
    self.prevVal.magZ = self.currentVal.magZ;
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer data UUID"]]]) {
        float x = [sensorKXTJ9 calcXValue:characteristic.value];
        float y = [sensorKXTJ9 calcYValue:characteristic.value];
        float z = [sensorKXTJ9 calcZValue:characteristic.value];
        self.currentVal.timeStamp = [[NSDate date] timeIntervalSince1970];
        self.currentVal.accX = x;
        self.currentVal.accY = y;
        self.currentVal.accZ = z;
    }
    
    double tS = [[NSDate date] timeIntervalSince1970];
    NSLog(@"Received val: %f,%f,%f,%f",(tS-floor(tS))*1000,self.currentVal.accX, self.currentVal.accY, self.currentVal.accZ);
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer data UUID"]]]) {
        
        float x = [self.magSensor calcXValue:characteristic.value];
        float y = [self.magSensor calcYValue:characteristic.value];
        float z = [self.magSensor calcZValue:characteristic.value];
        self.currentVal.magX = x;
        self.currentVal.magY = y;
        self.currentVal.magZ = z;
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didWriteValueForCharacteristic %@ error = %@",characteristic.UUID,error);
}


-(void)readHIEstimatesFromFile
{
    NSFileManager *filemgr;
    NSString *dataFile;
    NSArray *dirPaths;
    filemgr = [NSFileManager defaultManager];
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    dataFile = [[dirPaths objectAtIndex:0] stringByAppendingPathComponent: @"RR_Hard_Iron_Estimates.dat"];
    if (![filemgr fileExistsAtPath:dataFile]) {
        self.iVx = self.iVy = self.iVz = 0.0;
    } else {
        NSArray *hIronEst = [NSArray arrayWithContentsOfFile:dataFile];
        self.iVx = [[hIronEst objectAtIndex:0] floatValue];
        self.iVy = [[hIronEst objectAtIndex:1] floatValue];
        self.iVz = [[hIronEst objectAtIndex:2] floatValue];
        NSLog(@"Read HI Estimates from File - Vx:%f Vy:%f Vz:%f",self.iVx,self.iVy,self.iVz);
    }
}

-(void)estimateSineParams:(NSArray*)sineVals
{
    float x0 = [[sineVals objectAtIndex:0] floatValue];
    float x1 = [[sineVals objectAtIndex:1] floatValue];
    float x2 = [[sineVals objectAtIndex:2] floatValue];
    //NSLog(@"Last 3 Values: %f, %f, %f",x0,x1,x2);
    float secondDiffX = (x2+x0)-2*x1/powf(CAL_TIME_INTERVAL_ACC, 2);
    float diffX = (x2-x1)/CAL_TIME_INTERVAL_ACC;
    self.estimFreq = 0.9*self.estimFreq + 0.1*sqrtf(-secondDiffX/x1)/(2*M_PI);
    self.estimAmpl = 0.9*self.estimAmpl + sqrtf(x1*x1+powf(diffX/(2*M_PI*self.estimFreq),2));
    self.estimPhase = asinf(x1/self.estimAmpl)-2*M_PI*self.estimFreq*([[NSDate date] timeIntervalSinceDate:self.renderingStartTime]);
    //NSLog(@"Updated Ampl: %f, Phase: %f, Freq: %f",self.estimAmpl, self.estimPhase, self.estimFreq);
}

-(NSArray*)nSampleMovingAvg:(NSInteger)numSamples {
    float accXFiltered = 0.0;
    float accYFiltered = 0.0;
    float accZFiltered = 0.0;
    for(int i=0; i<numSamples; i++) {
        NSMutableArray *rec = [self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples - self.signalLag - i)];
        accXFiltered += [[rec objectAtIndex:1] floatValue];
        accYFiltered += [[rec objectAtIndex:2] floatValue];
        accZFiltered += [[rec objectAtIndex:3] floatValue];
    }
    accXFiltered /= numSamples; accYFiltered /= numSamples; accZFiltered /= numSamples;
    NSArray* retVal = [NSArray arrayWithObjects:[NSNumber numberWithFloat:accXFiltered], [NSNumber numberWithFloat:accYFiltered], [NSNumber numberWithFloat:accZFiltered], nil];
    return retVal;
}

@end
