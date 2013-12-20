//
//  RunReadPNGViewController.m
//  Run_Read_PNG
//
//  Created by Shak on 6/22/13.
//  Copyright (c) 2013 Shak. All rights reserved.
//

#import "RunReadPNGViewController.h"
#import "deviceSelector.h"
#import "deSimpleChartViewController.h"

@interface RunReadPNGViewController ()

@end

@implementation RunReadPNGViewController

@synthesize d;
@synthesize sensorsEnabled;
@synthesize sensorHistory;
@synthesize peakDetectHistory;
@synthesize orientHistory;
@synthesize iVx, iVy, iVz;

-(id) init {
    self = [super init];
    [self setPageNumber:1];
    self.isRunReadEnabled = NO;
    self.timerThread = nil;
    self.sensorGx = self.sensorGz = 0.0; self.sensorGy = 1.0;
    [self readHIEstimatesFromFile];
    //[self setTabletOrientationSimple];
    self.xSensitivity = self.ySensitivity = 0.0; self.signalLag = 0;
    MenuActivated = NO;
    return self;
}

-(id) init:(BLEDevice *)andSensorTag {
    self = [super init];
    if (self)
        self.d = andSensorTag;
    self.preferredFramesPerSecond = 60;
    self.timerThread = nil;
    self.magSensor = [[sensorMAG3110 alloc] init];
    
    self.currentVal = [[sensorTagValues alloc]init];
    self.prevVal = [[sensorTagValues alloc]init];
    self.vals = [[NSMutableArray alloc]init];
    
    // Set timers to print log and to get update values
    MenuActivated = NO;
    self.sensorHistory = [[SensorHistoryData alloc] init:MAX_MEASURES withSamples:MAX_SAMPLES];
    self.peakDetectHistory = [[SensorHistoryData alloc] init:3 withSamples:10];
    self.orientHistory = [[SensorHistoryData alloc] init:3 withSamples:10];
    // Start tablet accelerometer / magnetometer updates
    self.tabletOrientationCountdown = NUM_SAMPLES_PER_TABLET_UPDATE; //Every nth sample, we will update tablet orientation
    //self.devMotionManager = [[CMMotionManager alloc] init];
    //[self.devMotionManager startAccelerometerUpdates];  // How frequently does this need to update?
    //[self.devMotionManager startMagnetometerUpdates];  // Use devMotionManager.accelerometerUpdateIntervral
    //[self.devMotionManager startDeviceMotionUpdates];
    
    // Enable this line to get tablet heading
    //[self.devMotionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical];
        
    // Start detecting gestures
    self.isSwipeDetectionEnabled = YES;
    self.isTapDetectionEnabled = YES;
    
    // Set Hard Iron estimates to 0
    [self readHIEstimatesFromFile];
    //[self setTabletOrientationSimple];
    
    // Set estimate of gravity vector to 0 except Gy, which should be 1.0
    self.sensorGx = self.sensorGz = 0.0; self.sensorGy = -1.0;
    
    // Read sensitivities from file
    [self readSensitivyFromFile];
    
    // Set run-n-read flag
    self.isRunReadEnabled = YES;
    NSLog(@"Enabled Run-n-Read");
    return self;
}

-(void)displayTimeStamp:(CADisplayLink*)l {
    NSLog(@"TimeStamp: %f",[l timestamp]);
}

-(void)writeSensitivityToFile {
    // Write X, Y sensitivities and lag to file
    NSFileManager *filemgr;
    NSString *dataFile;
    NSString *docsDir;
    NSArray *dirPaths;
    filemgr = [NSFileManager defaultManager];
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    docsDir = [dirPaths objectAtIndex:0];
    dataFile = [docsDir stringByAppendingPathComponent: @"RR_XYP_Sensitivities.dat"];
    
    // Check if the file already exists
    if (![filemgr isWritableFileAtPath:dataFile] && [filemgr fileExistsAtPath:dataFile]) {
        NSLog(@"Could not write file at path %@",dataFile);
    } else {
        NSArray *sensParams = [[NSArray alloc] initWithObjects:[NSNumber numberWithFloat:self.xSensitivity],[NSNumber numberWithFloat:self.ySensitivity],[NSNumber numberWithInteger:self.signalLag],nil];
        [sensParams writeToFile:dataFile atomically:YES];
    }
}

-(void)readSensitivyFromFile {
    NSFileManager *filemgr;
    NSString *dataFile;
    NSArray *dirPaths;
    filemgr = [NSFileManager defaultManager];
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    dataFile = [[dirPaths objectAtIndex:0] stringByAppendingPathComponent: @"RR_XYP_Sensitivities.dat"];
    if ([filemgr fileExistsAtPath:dataFile]) {
        NSArray *sensParams = [NSArray arrayWithContentsOfFile:dataFile];
        self.xSensitivity = [[sensParams objectAtIndex:0] floatValue];
        self.ySensitivity = [[sensParams objectAtIndex:1] floatValue];
        if(sensParams.count>2) { self.signalLag = [[sensParams objectAtIndex:2] floatValue]; }
        else { self.signalLag = DEFAULT_SIGNAL_LAG; }
        NSLog(@"Read Sensitivities from file - X:%f Y:%f, Lag: %d",self.xSensitivity,self.ySensitivity,self.signalLag);
    } else {
        self.xSensitivity = MAX_X_SHIFT/2.0;
        self.ySensitivity = MAX_Y_SHIFT/2.0;
        self.signalLag = DEFAULT_SIGNAL_LAG;
    }
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


-(void)setWebView:(bool)v withURL:(NSString*)u
{
    self.isWebView = v;
    self.webURL = u;
}

- (void)viewDidAppear:(BOOL)animated {
    if(self.isRunReadEnabled) {
        self.sensorsEnabled = [[NSMutableArray alloc] init];
        if (!self.d.p.isConnected) {
            self.d.manager.delegate = self;
            [self.d.manager connectPeripheral:self.d.p options:nil];
         } else {
            self.d.p.delegate = self;
            [self configureSensorTag];
        }
    }
}

-(void)setTabletOrientationSimple {
    CMAttitude *currentAttitude = self.devMotionManager.deviceMotion.attitude;
    if(self.devMotionManager.deviceMotion ==nil) {
        //NSLog(@"Device Motion Manager not Active!");
        self.tabletPhi = self.tabletTheta = self.tabletPsi = 0.0;
        return;
    }
    if (currentAttitude == nil) {
        //NSLog(@"Could not get device orientation.");
        self.tabletPhi = self.tabletPsi = self.tabletTheta = 0.0;
        return;
    } else {
        self.tabletPsi = currentAttitude.yaw;
        self.tabletPhi = currentAttitude.pitch;
        self.tabletTheta = currentAttitude.roll;
    }
    //NSLog(@"Tablet oriented at %f, %f, %f radians",self.tabletPhi,self.tabletTheta,self.tabletPsi);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];    // setPaused automatically set to NO in super's implementation
    //[self setPaused:YES];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

-(void)viewWillDisappear:(BOOL)animated {
    [self setPaused:YES];
    if(self.isRunReadEnabled) {
        self.isRunReadEnabled = NO;
        [self tearDownGL];
        [self deconfigureSensorTag];
        //[self.devMotionManager stopDeviceMotionUpdates];
    }
    [self removeButtons];
    [self.menuTimer invalidate];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

-(void)viewDidDisappear:(BOOL)animated {
    if(self.isRunReadEnabled) {
        self.sensorsEnabled = nil;
        self.d.manager.delegate = nil;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    imageGLContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    imageView = (GLKView*)self.view;
    imageView.context = imageGLContext;
    imageView.drawableMultisample = GLKViewDrawableMultisample4X;
    imageView.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    imageView.drawableColorFormat = GLKViewDrawableColorFormatRGB565;
    //imageView.enableSetNeedsDisplay = YES;
    [self setShiftXY:CGPointMake(0.0,-10.0)];
    [self loadPage];
}

// Setup GL
typedef struct {
    float Position[3];
    float Color[4];
    float TexCoord[2];
} Vertex;

const Vertex Vertices[] = {
    // Front
    {{1*IMAGE_SCALE_X, -1*IMAGE_SCALE_Y, 1}, {1, 1, 1, 1}, {1, 0}},
    {{1*IMAGE_SCALE_X, 1*IMAGE_SCALE_Y, 1}, {1, 1, 1, 1}, {1, 1}},
    {{-1*IMAGE_SCALE_X, 1*IMAGE_SCALE_Y, 1}, {1, 1, 1, 1}, {0, 1}},
    {{-1*IMAGE_SCALE_X, -1*IMAGE_SCALE_Y, 1}, {1, 1, 1, 1}, {0, 0}}
};

const GLubyte Indices[] = {
    0, 1, 2,
    2, 3, 0
};

- (void)setupGL {

    [EAGLContext setCurrentContext:imageGLContext];
    imageEffect = [[GLKBaseEffect alloc] init];
    NSError *error;
    NSString *pageFile = [NSString stringWithFormat:@"shortStory%d_pg%02d.PNG",storyNum,pageNum];
    UIImage *originalImage = [UIImage imageNamed:pageFile];
    if(!originalImage) { NSLog(@"Could not find file %@",pageFile); }
    
    glEnable(GL_CULL_FACE);
    NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithBool:YES],
                              GLKTextureLoaderOriginBottomLeft,
                              nil];

    //GLKTextureInfo * info = [GLKTextureLoader textureWithContentsOfFile:path options:options error:&error];
    GLKTextureInfo *info = [GLKTextureLoader textureWithCGImage:originalImage.CGImage options:options error:&error];
    if (info == nil) {
        NSLog(@"Error loading file: %@", [error localizedDescription]);
    }
    imageEffect.texture2d0.name = info.name;
    imageEffect.texture2d0.enabled = true;
    
    // New lines
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    // Old stuff
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
    // New lines (were previously in draw)
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Position));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Color));
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, TexCoord));
    
    // New line
    glBindVertexArrayOES(0);
}

- (void)tearDownGL {
    
    [EAGLContext setCurrentContext:imageGLContext];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    imageEffect = nil;
    
}

#pragma mark - GLKViewDelegate

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    ////////////////////////////
    // Setup display co-ordinates
    ////////////////////////////
    NSMutableArray *recordMeas = [[NSMutableArray alloc] initWithCapacity:MAX_MEASURES];
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970];
    sensorTagValues *newVal = [[sensorTagValues alloc]init];
    if(self.prevVal.timeStamp <= timeInMiliseconds && self.prevVal.timeStamp>timeInMiliseconds-RR_PERIOD) {
        newVal.accX = self.prevVal.accX;
        newVal.accY = self.prevVal.accY;
        newVal.accZ = self.prevVal.accZ;
        newVal.magX = self.prevVal.magX;
        newVal.magY = self.prevVal.magY;
        newVal.magZ = self.prevVal.magZ;
        newVal.timeStamp = self.prevVal.timeStamp;
    } else {
        newVal.accX = self.currentVal.accX;
        newVal.accY = self.currentVal.accY;
        newVal.accZ = self.currentVal.accZ;
        newVal.magX = self.currentVal.magX;
        newVal.magY = self.currentVal.magY;
        newVal.magZ = self.currentVal.magZ;
        newVal.timeStamp = self.currentVal.timeStamp;
    }
    [recordMeas addObject:[NSNumber numberWithDouble:timeInMiliseconds]];
    [recordMeas addObject:[NSNumber numberWithFloat:newVal.accX]];
    [recordMeas addObject:[NSNumber numberWithFloat:newVal.accY]];
    [recordMeas addObject:[NSNumber numberWithFloat:newVal.accZ]];
    [recordMeas addObject:[NSNumber numberWithFloat:(newVal.magX - self.iVx)]];
    [recordMeas addObject:[NSNumber numberWithFloat:(newVal.magY - self.iVy)]];
    [recordMeas addObject:[NSNumber numberWithFloat:(newVal.magZ - self.iVz)]];
    
    // Estimate gravity vector
    float currentAccX = [[recordMeas objectAtIndex:1] floatValue];
    float currentAccY = [[recordMeas objectAtIndex:2] floatValue];
    float currentAccZ = [[recordMeas objectAtIndex:3] floatValue];
    
    /*Enable this block of code for complementary filter based gravity estimation */
    self.sensorGx = K_GRAV_ESTIMATION*currentAccX + (1.0-K_GRAV_ESTIMATION)*self.sensorGx;
    self.sensorGy = K_GRAV_ESTIMATION*currentAccY + (1.0-K_GRAV_ESTIMATION)*self.sensorGy;
    self.sensorGz = K_GRAV_ESTIMATION*currentAccZ + (1.0-K_GRAV_ESTIMATION)*self.sensorGz;
    
    // Add Sample to Sensor History
    [self.sensorHistory enqueueData:recordMeas];
    
    // Implement low-pass filter here
    float xShift = 0.0, yShift = 0.0;
    if(self.sensorHistory.numSamples >= self.signalLag+MOVING_AVG_SAMPLES) {
        
        // Do 3-sample weighted average here
        NSMutableArray *rec2 = [self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples - self.signalLag - 3)];
        NSMutableArray *rec1 =[self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples - self.signalLag - 2)];
        float w1 = SMOOTHING_WEIGHT_K1, w2 = SMOOTHING_WEIGHT_K2; // a_smooth = [a(k) + w1*a(k-1) + w2*a(k-2)]/(1+w1+w2)
        float accXFiltered = (currentAccX + w1*[[rec1 objectAtIndex:1] floatValue] + w2*[[rec2 objectAtIndex:1] floatValue])/(1.0+w1+w2) - self.sensorGx;
        float accYFiltered = (currentAccY + w1*[[rec1 objectAtIndex:2] floatValue] + w2*[[rec2 objectAtIndex:2] floatValue])/(1.0+w1+w2) - self.sensorGy;
        float accZFiltered = (currentAccZ + w1*[[rec1 objectAtIndex:3] floatValue] + w2*[[rec2 objectAtIndex:3] floatValue])/(1.0+w1+w2) - self.sensorGz;
        
        /*
        // Do n-sample moving average here
        NSArray* accFilter = [self nSampleMovingAvg:MOVING_AVG_SAMPLES];
        float accXFiltered = [[accFilter objectAtIndex:0] floatValue]-self.sensorGx;
        float accYFiltered = [[accFilter objectAtIndex:1] floatValue]-self.sensorGy;
        float accZFiltered = [[accFilter objectAtIndex:2] floatValue]-self.sensorGz;
        */
        
        //NSLog(@",%f,%f,%f,%f,%f,%f",currentAccX,currentAccY,currentAccZ,accXFiltered,accYFiltered,accZFiltered);
        //NSMutableArray* sensorAcc = [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:accXFiltered], [NSNumber numberWithFloat:accYFiltered],[NSNumber numberWithFloat:accZFiltered],nil];
        NSMutableArray* sensorValsForOrient = [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:self.sensorGx], [NSNumber numberWithFloat:self.sensorGy], [NSNumber numberWithFloat:self.sensorGz], nil];
        [sensorValsForOrient addObject:[recordMeas objectAtIndex:4]];
        [sensorValsForOrient addObject:[recordMeas objectAtIndex:5]];
        [sensorValsForOrient addObject:[recordMeas objectAtIndex:6]];
        
        // This code block is more sophisticated model for translating sensor orientation to tablet orientation
        // Get sensor orientation from estimated gravity vector
        //NSArray* sensorOrientation = [self getOrientationAngles: sensorValsForOrient];
        //NSMutableArray* orientVals = [[NSMutableArray alloc] initWithArray:sensorOrientation];
        
        //NSArray* sensorAccTrans = [self translateSensorToTabletMotion:sensorAcc sensorAngles:sensorOrientation];
        //NSLog(@"Sensor Phi: %f Theta: %f Psi: %f",[[sensorOrientation objectAtIndex:0] floatValue],[[sensorOrientation objectAtIndex:1] floatValue],[[sensorOrientation objectAtIndex:2] floatValue]);
        //float accXTrans = [[sensorAccTrans objectAtIndex:0] floatValue];
        //float accYTrans = [[sensorAccTrans objectAtIndex:1] floatValue];
        
        // Below lines are the simplest model - ever
        float accXTrans = -accXFiltered;
        
        // Below line sets to current accln. sample value
        float accYTrans = -accYFiltered;  //-ve because negative Y value displaces text up -> corresponds to +ve accln. upwards for head
        //float accYTrans = accYFiltered; //+ve because we are now flipping and delay signal
        // Below lines implement simple sine wave
        //float accYTrans = 1.0*sin(2*M_PI*fmod((double)timeInMiliseconds*1e6,600.0)/600);  //Time period of 400 ms
        
        xShift = accXTrans*self.xSensitivity;
        yShift = accYTrans*self.ySensitivity;
        [self setShiftXY:CGPointMake(xShift, yShift)];
        
        // Build history for tap detection
        NSMutableArray *accFiltered = [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:accXFiltered],[NSNumber numberWithFloat:accYFiltered],[NSNumber numberWithFloat:accZFiltered], nil];
        [self.peakDetectHistory enqueueData:accFiltered];
    }
    
    ///////////////////////////
    // Do Display here
    //////////////////////////

    //glClearColor(1.0, 1.0, 1.0, 1.0);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1, 1, -100, 100);
    imageEffect.transform.projectionMatrix = projectionMatrix;
    
    float trans_y = shift_y / (5*MAX_Y_SHIFT);
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, trans_y, 0.0f);
    imageEffect.transform.modelviewMatrix = modelViewMatrix;

    [imageEffect prepareToDraw];
    
    glBindVertexArrayOES(_vertexArray);
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
    glFlush();

}

-(void)setStoryNumber:(NSInteger)snum withPages:(NSInteger) maxp {
    storyNum = snum;
    maxPages = maxp;
}

-(void)setPageNumber:(NSInteger) pnum
{
    pageNum = pnum;
}

-(void)setShiftXY:(CGPoint) p
{
    shift_x = p.x;
    shift_y = p.y;
}

-(void)redrawPage {
    
    [imageView setNeedsDisplay];   // Not needed if automatically rendering every 16 ms
}

-(void)refreshPage {
    [self tearDownGL];
    if([imageView viewWithTag:5501]) { [[imageView viewWithTag:5501] removeFromSuperview]; }
    if([imageView viewWithTag:5502]) { [[imageView viewWithTag:5502] removeFromSuperview]; }
    if(!self.isWebView){
        [self setupGL];
        [self redrawPage];
    } else {
        UIWebView* webView = [[UIWebView alloc] init];
        webView.tag = 5501;
        webView.frame = imageView.frame;
        webView.backgroundColor = [UIColor clearColor];
        webView.userInteractionEnabled = YES;
        NSURL *url = [[NSURL alloc] initWithString:self.webURL];
        [webView loadRequest:[NSURLRequest requestWithURL:url]];
        [imageView addSubview:webView];
    }
}

- (void)loadPage
{
	// Do any additional setup after loading the view, typically from a nib.
    [self refreshPage];
    
    // Adding the below code to turn page back by swiping right
    UISwipeGestureRecognizer *rightRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(rightSwipeHandle:)];
    rightRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [rightRecognizer setNumberOfTouchesRequired:1];
    [imageView addGestureRecognizer:rightRecognizer];
    
    // Adding left swipe recognizer to turn page forward
    UISwipeGestureRecognizer *leftRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(leftSwipeHandle:)];
    leftRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    [leftRecognizer setNumberOfTouchesRequired:1];
    [imageView addGestureRecognizer:leftRecognizer];
    
    // Adding below code to recognize a double tap
    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapHandle:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    [imageView addGestureRecognizer:doubleTapRecognizer];
    
    // ADding a triple tap recognizer
    UITapGestureRecognizer *tripleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tripleTapHandle:)];
    tripleTapRecognizer.numberOfTapsRequired = 3;
    [imageView addGestureRecognizer:tripleTapRecognizer];
    
    // Add the motion detector and shift function
    if (self.isRunReadEnabled) {
        //self.rrTimer = [NSTimer scheduledTimerWithTimeInterval:RR_PERIOD target:self selector:@selector(rrDisplay:) userInfo:nil repeats:YES];
        //if(![self.timerThread isExecuting] && !self.timerThread) {
        if([self.timerThread isFinished] || self.timerThread==nil) {
            self.timerThread = [[NSThread alloc] initWithTarget:self selector:@selector(rrTimerStart) object:nil]; //Create a new thread
            [self.timerThread start];
        } //else if ([self.timerThread isFinished]) { self.timerThread = nil; }
    }
}

-(void)rrTimerStart
{
    NSLog(@"Entering timer thread");
    BOOL exitNow = NO;
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
    self.rrTimer = [NSTimer scheduledTimerWithTimeInterval:RR_PERIOD target:self selector:@selector(rrDisplay:) userInfo:nil repeats:YES];
    while(!exitNow) {
        [runLoop runUntilDate:[NSDate date]];
        exitNow = !self.isRunReadEnabled;
    } //Keep executing timer function
    [self.rrTimer performSelector:@selector(invalidate) onThread:self.timerThread withObject:nil waitUntilDone:NO];
    NSLog(@"Exiting timer thread");
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
{
    return YES;
}

// Method to remove all buttons
-(void)removeButtons
{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [[self.view viewWithTag:6601] removeFromSuperview];
    [[self.view viewWithTag:6602] removeFromSuperview];
    [[self.view viewWithTag:6603] removeFromSuperview];
    [[self.view viewWithTag:6604] removeFromSuperview];
    [[self.view viewWithTag:6605] removeFromSuperview];
    [[self.view viewWithTag:6606] removeFromSuperview];
}

// Methods to act on left or right swipe
- (void)rightSwipeHandle:(UISwipeGestureRecognizer*)gestureRecognizer
{
    [self removeButtons];
    if(!self.isWebView) {
        [self turnPageBackward];
    } else {
        UIWebView* wV = [imageView viewWithTag:5501];
        if([wV canGoBack]) {
            [wV goBack];
        }
    }
}

- (void)leftSwipeHandle:(UISwipeGestureRecognizer*)gestureRecognizer
{
    [self removeButtons];
    if(!self.isWebView) {
        [self turnPageForward];
    } else {
        UIWebView *wV = [imageView viewWithTag:5501];
        if([wV canGoForward]) {
            [wV goForward];
        }
    }
}

// Method to act on double tap
-(void)doubleTapHandle:(UITapGestureRecognizer*) tapRecognizer
{
    //Nothing currently implemented
}

// Method to act on single tap - draw Bluetooth connection buttons
-(void)tripleTapHandle:(UITapGestureRecognizer*) tapRecognizer
{
    if (!MenuActivated) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
        CGFloat btX = self.view.bounds.origin.x + 0.05*self.view.bounds.size.width;
        CGFloat btY = self.view.bounds.origin.y + 0.17*self.view.bounds.size.height;
        CGFloat btW = 0.44*self.view.bounds.size.width;
        CGFloat btH = 0.08*self.view.bounds.size.height;
        CGFloat btS = 0.04*self.view.bounds.size.width;
        UIButton *btnTwo = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        btnTwo.frame = CGRectMake(btX, btY, btW, btH);
        if(self.isRunReadEnabled) [btnTwo setTitle:@"Stop Run-n-Read" forState:UIControlStateNormal];
        else [btnTwo setTitle:@"Start Run-n-Read" forState:UIControlStateNormal];
        [btnTwo setBackgroundColor:[UIColor blackColor]];
        [btnTwo setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btnTwo setTitleShadowColor:[UIColor grayColor] forState:UIControlStateNormal];
        btnTwo.titleLabel.font = [UIFont fontWithName:@"TrebuchetMS-Bold" size:15];
        [btnTwo addTarget:self action:@selector(startBlueToothConn) forControlEvents:UIControlEventTouchUpInside];
        btnTwo.tag = 6601;
        [self.view addSubview:btnTwo];
        UIButton *btnOne = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        btnOne.frame = CGRectMake((btX+btS+btW),btY,btW,btH);
        [btnOne setTitle:@"Calibration" forState:UIControlStateNormal];
        [btnOne setBackgroundColor:[UIColor blackColor]];
        [btnOne setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btnOne setTitleShadowColor:[UIColor grayColor] forState:UIControlStateNormal];
        btnOne.titleLabel.font = [UIFont fontWithName:@"TrebuchetMS-Bold" size:15];
        [btnOne addTarget:self action:@selector(startCalibration) forControlEvents:UIControlEventTouchUpInside];
        btnOne.tag = 6602;
        [self.view addSubview:btnOne];
        
        // Add a slider to control Y sensitivity
        CGFloat slX = self.view.bounds.origin.x + 0.35*self.view.bounds.size.width;
        CGFloat slY = self.view.bounds.origin.y + 0.70*self.view.bounds.size.height;
        CGFloat slW = 0.65*self.view.bounds.size.width;
        CGFloat slH = 0.075*self.view.bounds.size.height;
        UILabel *sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(slX,slY,slW,slH)];
        sliderLabel.text = [NSString stringWithFormat:@"Set Y Sensitivity (%d)",(NSInteger)self.ySensitivity];
        sliderLabel.backgroundColor = [UIColor blackColor];
        sliderLabel.textColor = [UIColor whiteColor];
        sliderLabel.font = [UIFont fontWithName:@"TrebuchetMS-Bold" size:15];
        sliderLabel.adjustsFontSizeToFitWidth = YES;
        sliderLabel.minimumScaleFactor = 0.5;

        sliderLabel.tag = 6604;
        [self.view addSubview:sliderLabel];
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(slX,(slY+slH),slW,slH)];
        [slider setBackgroundColor:[UIColor blackColor]];
        slider.minimumValue = 0.0;
        slider.maximumValue = MAX_Y_SHIFT;
        slider.minimumValueImage = [UIImage imageNamed:@"minus_sign.png"];
        slider.maximumValueImage = [UIImage imageNamed:@"plus_sign.png"];
        slider.continuous = YES;
        slider.value = self.ySensitivity;
        [slider addTarget:self action:@selector(updateSensitivity:) forControlEvents:UIControlEventValueChanged];
        slider.tag = 6603;
        [self.view addSubview:slider];
        MenuActivated = YES;
        
        // Add a slider to control the delay to peak
        UILabel *dsliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(slX,(slY+2*slH),slW,slH)];
        dsliderLabel.text = [NSString stringWithFormat:@"Set Signal Lag (%d)",self.signalLag];
        dsliderLabel.backgroundColor = [UIColor blackColor];
        dsliderLabel.textColor = [UIColor whiteColor];
        dsliderLabel.font = [UIFont fontWithName:@"TrebuchetMS-Bold" size:15];
        dsliderLabel.adjustsFontSizeToFitWidth = YES;
        dsliderLabel.minimumScaleFactor = 0.5;
        dsliderLabel.tag = 6606;
        [self.view addSubview:dsliderLabel];
        
        UISlider *dslider = [[UISlider alloc] initWithFrame:CGRectMake(slX,(slY+3*slH),slW,slH)];
        [dslider setBackgroundColor:[UIColor blackColor]];
        dslider.minimumValue = 0.0;
        dslider.maximumValue = 25.0;
        dslider.minimumValueImage = [UIImage imageNamed:@"minus_sign.png"];
        dslider.maximumValueImage = [UIImage imageNamed:@"plus_sign.png"];
        dslider.continuous = YES;
        dslider.value = self.signalLag;
        [dslider addTarget:self action:@selector(updateSignalLag:) forControlEvents:UIControlEventValueChanged];
        dslider.tag = 6605;
        [self.view addSubview:dslider];
        self.menuTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(makeMenuDisappear:) userInfo:nil repeats:NO];
    } else {
        [self removeButtons];
        MenuActivated = NO;
    }
}

//Method to update deliberately introduced peak delay
-(IBAction)updateSignalLag:(UISlider*)sender {
    self.signalLag = sender.value;
    UILabel *sliderLabel = (UILabel*)[self.view viewWithTag:6606];
    sliderLabel.text = [NSString stringWithFormat:@"Set Signal Lag (%d)",self.signalLag];
    NSLog(@"Updated Lag to %f",self.signalLag*RR_PERIOD);
}

// Method to change X sensitiyvity
-(IBAction)updateXSensitivity:(UISlider*)sender {
    self.xSensitivity = (NSInteger)sender.value;
    UILabel *sliderLabel = (UILabel*)[self.view viewWithTag:6606];
    sliderLabel.text = [NSString stringWithFormat:@"Set X Sensitivity (%d)",(NSInteger)self.xSensitivity];
    NSLog(@"Updated X Sensitivity to %f",self.xSensitivity);
}

// Method to update sensitivity
-(IBAction)updateSensitivity:(UISlider*)sender {
    self.ySensitivity = sender.value;
    UILabel *sliderLabel = (UILabel*)[self.view viewWithTag:6604];
    sliderLabel.text = [NSString stringWithFormat:@"Set Y Sensitivity (%d)",(NSInteger)self.ySensitivity];
    NSLog(@"Updated Y Sensitivity to %f",self.ySensitivity);
}

// Method to call Bluetooth Activation
-(void)startBlueToothConn
{
    if(self.isRunReadEnabled) {
        self.isRunReadEnabled = NO;
        [self deconfigureSensorTag];
        [self writeSensitivityToFile];
        
        shift_x = 0;
        shift_y = 0;
        
        // Stop accelerometer and magnetometer updates, if running (currently should have stopped it after calibration)
        //[self.devMotionManager stopAccelerometerUpdates];
        //[self.devMotionManager stopMagnetometerUpdates];
        //[self.devMotionManager stopDeviceMotionUpdates];
        
        //Remove all buttons
        [self removeButtons];
        
        //Stop timers
        //[self.rrTimer invalidate];  -> Let this call be handled by thread coming to an end
        
        //Output history of motion
        //[self outputHistory];
        MenuActivated = NO;        
    } else {
        if(self.isWebView) {
            UIWebView* wV = [imageView viewWithTag:5501];
            self.webURL = wV.request.URL.absoluteString;
        }
        deviceSelector *dC = [[deviceSelector alloc] initWithStyle:UITableViewStyleGrouped isDevForCalibration:NO];
        if(self.isWebView) {
            [dC setWebView:YES];
            [dC setWebURL:self.webURL];
        } else {
            [dC setWebView:NO];
            [dC setStoryNumber:storyNum withPages:maxPages];
            [dC setPageNum:pageNum];
        }
        [self.navigationController pushViewController:dC animated:YES];
    }
    return;
}

// Method to call Calibration Screen
-(void)startCalibration
{
    deviceSelector *dC = [[deviceSelector alloc]initWithStyle:UITableViewStyleGrouped isDevForCalibration:YES];
    [self.navigationController pushViewController:dC animated:YES];
    return;
}

//Methods to turn pages forward or backward
-(void)turnPageForward
{
    [self setPaused:YES];
    if(pageNum<maxPages) { pageNum++; }
    [self setShiftXY:CGPointMake(0.0,0.0)];
    [self loadPage];
    [self setPaused:NO];
}

-(void)turnPageBackward
{
    [self setPaused:YES];
    if(pageNum>1) { pageNum--; }
    [self setShiftXY:CGPointMake(0.0,0.0)];
    [self loadPage];
    [self setPaused:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) configureSensorTag {
    // Read all the stored values and keys in Sensor Tag
    for(NSString *key in [self.d.setupData allKeys]) {
        NSLog(@"%@",[self.d.setupData objectForKey:key]);
    }
    
    // Configure sensortag, turning on Sensors and setting update period for sensors etc ...
    
    if ([self sensorEnabled:@"Accelerometer active"]) {
        CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer service UUID"]];
        CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer config UUID"]];
        CBUUID *pUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer period UUID"]];
        //NSInteger period = [[self.d.setupData valueForKey:@"Accelerometer period"] integerValue];
        //uint8_t periodData = (uint8_t)(period / 10);
        uint8_t periodData = (uint8_t)(ACCELEROMETER_PERIOD*1000);
        NSLog(@"Accelerometer Period = %d",periodData);
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:pUUID data:[NSData dataWithBytes:&periodData length:1]];
        uint8_t data = 0x01;
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
        cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer data UUID"]];
        [BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:YES];
        [self.sensorsEnabled addObject:@"Accelerometer"];
    }
    
    if ([self sensorEnabled:@"Magnetometer active"]) {
        CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer service UUID"]];
        CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer config UUID"]];
        CBUUID *pUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer period UUID"]];
        //NSInteger period = [[self.d.setupData valueForKey:@"Magnetometer period"] integerValue];
        //uint8_t periodData = (uint8_t)(period / 10);
        uint8_t periodData = (uint8_t)250;
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
        self.currentVal.accX = x;
        self.currentVal.accY = y;
        self.currentVal.accZ = z;
        self.currentVal.timeStamp = [[NSDate date] timeIntervalSince1970];
    }
    
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


-(void) makeMenuDisappear:(NSTimer *)timer
{
    [self removeButtons];
    MenuActivated = NO;
}

-(void) rrDisplay:(NSTimer *)timer {
    // Modify tablet orientation timer
    self.tabletOrientationCountdown--;
    if(self.tabletOrientationCountdown ==0) {
        self.tabletOrientationCountdown = NUM_SAMPLES_PER_TABLET_UPDATE;
        //[self setTabletOrientationSimple];  --> not currently implementing tablet orientation
    }
    
    // See if gesture detection is enabled, and decrement countdown
    if(!self.isSwipeDetectionEnabled) {
        self.swipeDetectCountdown--;
        if(self.swipeDetectCountdown<=0) self.isSwipeDetectionEnabled = YES;
    }
    if(!self.isTapDetectionEnabled) {
        self.tapDetectCountdown--;
        if(self.tapDetectCountdown<=0) self.isTapDetectionEnabled = YES;
    }
    if(self.tapDetectWindow>0) {
        self.tapDetectWindow--;
        if(self.tapDetectWindow==0) {  // Reset window and number of taps detected, and take appropriate actions
            if(self.numTapsDetected==1) { NSLog(@"Single Tap Detected"); } //[self leftSwipeHandle:nil]; }
                else if(self.numTapsDetected==2) { NSLog(@"Double Tap Detected"); }//[self rightSwipeHandle:nil]; }
            self.numTapsDetected = 0;
        }
    }
    
    // BElow code was crashing -- need to debug
    /*if(self.peakDetectHistory.numSamples == NUM_SAMPLES_FOR_PD_HISTORY && self.isTapDetectionEnabled) {
        if([self isTapDetected]) {
            self.isTapDetectionEnabled = NO;
            self.tapDetectCountdown = TAP_DETECTION_PAUSE;
            if(self.numTapsDetected ==0) self.tapDetectWindow = TAP_DETECTION_WINDOW;
            self.numTapsDetected++;
        }
    }*/
        
        // See if swipe has been detected
        /*[self.orientHistory enqueueData:orientVals];
        if(self.orientHistory.numSamples == NUM_SAMPLES_FOR_OR_HISTORY && self.isSwipeDetectionEnabled) {
            NSInteger swipeVal = [self isSwipeDetected];
            if(swipeVal!=0) {
                if(swipeVal>0) { NSLog(@"Forward Swipe Detected!"); [self leftSwipeHandle:nil]; }
                if(swipeVal<0) { NSLog(@"Backward Swipe Detected!"); [self rightSwipeHandle:nil]; }
                self.isSwipeDetectionEnabled = NO;
                self.swipeDetectCountdown = SWIPE_DETECTION_PAUSE;
            }
        }*/
}

-(NSInteger)isSwipeDetected   //Return -1 for backward swipe, +1 for forward swipe, 0 otherwise
{
    float theta[10];  //Replaced NUM_SAMPLES_FOR_OR_HISTORY with 10 as a hack
    for(int i=0; i<10; i++) {
        NSMutableArray *rec = [self.orientHistory.measData objectAtIndex:i];
        //phi[i] = [[rec objectAtIndex:0] floatValue];
        theta[i] = [[rec objectAtIndex:1] floatValue];
        //psi[i] = [[rec objectAtIndex:2] floatValue];
    }
    if(theta[10-1]-theta[0]>SWIPE_THRESHOLD) { // Swipe backward
        int midpt = (int)10/2;
        if(theta[midpt]<theta[10-1] && theta[midpt]>theta[0])  return 1;
    } else if(theta[0]-theta[10-1]>SWIPE_THRESHOLD) { //Swipe forward
        int midpt = (int)10/2;
        if(theta[midpt]>theta[10-1] && theta[midpt]<theta[0]) return -1;
    }
    return 0;
}

-(bool)isTapDetected
{
    float aX[10],aY[10],aZ[10]; //Replaced NUM_SAMPLES_FOR_PD_HISTORY with 10 as a hack
    for(int i=0; i<10; i++) {
        NSMutableArray *rec = [self.peakDetectHistory.measData objectAtIndex:i];
        aX[i] = [[rec objectAtIndex:0] floatValue];
        aY[i] = [[rec objectAtIndex:1] floatValue];
        aZ[i] = [[rec objectAtIndex:2] floatValue];
    }
    NSInteger xPeakCount = [self numPeaksDetected:aX withSamples:10];
    NSInteger yPeakCount = [self numPeaksDetected:aY withSamples:10];
    //NSInteger yPeakCount = 0;
    NSInteger zPeakCount = [self numPeaksDetected:aZ withSamples:10];
    NSInteger xThreePeaks = (xPeakCount >= 2)?1:0;
    NSInteger yThreePeaks = (yPeakCount >= 2)?1:0;
    NSInteger zThreePeaks = (zPeakCount >= 2)?1:0;
    if(xThreePeaks+yThreePeaks+zThreePeaks>=2) return true;
    else return false;

}

-(NSInteger)numPeaksDetected:(float*)x withSamples:(NSInteger)numSamples
{
    if(numSamples<3) { return 0; } // Need a minimum of 3 samples to detect a peak
    NSInteger peakCount = 0;
    for(int i=1; i<numSamples-1; i++) {
        if([self isAPeak:x[i] prevValue:x[i-1] nextValue:x[i+1]]) peakCount++;
    }
    return peakCount;
}

-(bool)isAPeak:(float)y1 prevValue:(float)y0 nextValue:(float)y2
{
    /* Spike detection algorithm 1
    if(fabs(y1)<TAP_THRESHOLD) continue;
    float avgPred = (y0+y2)/2.0;
    if(y1>=y0 && y1>=y2) {
        return true;
    } else if (y1<=y0 && y1<=y2) {
        return true;
    }*/
    
    //Spike detection algorithm 2
    float t1 = (y1-y0)/RR_PERIOD;
    float t2 = (y2-y1)/RR_PERIOD;
    if(fabs(atanf(t1)-atanf(t2))>=TAP_THRESHOLD) return true;
    return false;
}

-(NSArray*) translateSensorToTabletMotion:(NSArray*)acc sensorAngles:(NSArray*)orient {
    float x = [[acc objectAtIndex:0] floatValue];
    float y = [[acc objectAtIndex:1] floatValue];
    float z = [[acc objectAtIndex:2] floatValue];
    float sensorPhi = [[orient objectAtIndex:0] floatValue];
    float sensorTheta = [[orient objectAtIndex:1] floatValue];
    float sensorPsi = [[orient objectAtIndex:2] floatValue];
    
    float transPhi = self.tabletPhi - sensorPhi;
    float transTheta = self.tabletTheta - sensorTheta;
    float transPsi = self.tabletPsi - sensorPsi;
    float xTrans = x*cosf(transPsi)*cosf(transTheta) + y*sinf(transPsi)*cosf(transTheta) - z*sinf(transTheta);
    float yTrans = cosf(transPhi)*(-x*sinf(transPsi)+y*cosf(transPsi))+sinf(transPhi)*(x*cosf(transPsi)*sinf(transTheta)+y*sinf(transPsi)*sinf(transTheta)+z*cosf(transTheta));
    
    NSArray *xyTrans = [[NSArray alloc] initWithObjects:[NSNumber numberWithFloat:xTrans],[NSNumber numberWithFloat:yTrans], nil];
    return xyTrans;
}

-(void) outputHistory {
    NSLog(@"Outputting sensor history for %d samples, %d measurements",self.sensorHistory.numSamples,self.sensorHistory.numMeasures);
    NSMutableArray* valueToPlot = [[NSMutableArray alloc] initWithCapacity:self.sensorHistory.numSamples];
    while(![self.sensorHistory isEmpty]) {
        NSMutableArray *recordMeas = [self.sensorHistory dequeueData];
        NSLog(@"%f %f %f",[[recordMeas objectAtIndex:1] floatValue],[[recordMeas objectAtIndex:2] floatValue],[[recordMeas objectAtIndex:3] floatValue]);
        [valueToPlot addObject:[recordMeas objectAtIndex:1]];  //X value of accelerometer
    }
}

-(NSArray*)getOrientationAngles:(NSMutableArray*)amval {
    float Gx = [[amval objectAtIndex:0] floatValue];
    float Gy = [[amval objectAtIndex:1] floatValue];
    float Gz = [[amval objectAtIndex:2] floatValue];
    float Bx = [[amval objectAtIndex:3] floatValue];
    float By = [[amval objectAtIndex:4] floatValue];
    float Bz = [[amval objectAtIndex:5] floatValue];
    //NSLog(@"Gx: %f Gy: %f Gz: %f",Gx,Gy,Gz);
    float phi = atan2f(Gy,Gz);  // phi = roll angle, angle of rotation about X-axis. For phone this is axis through phone, through volume button
    if(phi>M_PI) { phi -= 2*M_PI; }
    else if(phi<-M_PI) { phi += 2*M_PI; }
    float theta = atan2f(-Gx,(Gy*sinf(phi)+Gz*cosf(phi))); // theta = tilt angle, angle or rotation about Y-axis, through phone, through earphone
    if(theta>M_PI) { theta -= 2*M_PI; }
    else if(theta<-M_PI) {theta += 2*M_PI; }
    float psi = atan2f(((Bz-self.iVz)*sinf(phi)-(By-self.iVy)*cosf(phi)),((Bx-self.iVx)*cosf(theta)+(By-self.iVy)*sinf(theta)*sinf(phi)+(Bz-self.iVz)*sinf(theta)*cosf(phi))); // psi = yaw angle, angle of rotation about Z-axis. Into plane of phone
    NSArray *rotAngles = @[[NSNumber numberWithFloat:phi],[NSNumber numberWithFloat:theta],[NSNumber numberWithFloat:psi]]; //Preserve order
    return rotAngles;
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

