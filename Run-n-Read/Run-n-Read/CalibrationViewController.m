//
//  CalibrationViewController.m
//  SensorTagEX
//
//  Created by Shak on 8/21/13.
//  Copyright (c) 2013 Texas Instruments. All rights reserved.
//

#import "CalibrationViewController.h"

@interface CalibrationViewController ()

@end

@implementation CalibrationViewController

@synthesize d;
@synthesize sensorsEnabled;
@synthesize accXGraph, accYGraph, accZGraph;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}


-(id) initWithStyle:(UITableViewStyle)style andSensorTag:(BLEDevice *)andSensorTag {
    self = [super initWithStyle:style];
    if (self) {
        if (!self.acc) {
            self.acc = [[accelerometerCellTemplate alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Accelerometer"];
            self.acc.accLabel.text = @"Accelerometer";
            self.acc.accValueX.text = @"-";
            self.acc.accValueY.text = @"-";
            self.acc.accValueZ.text = @"-";
            self.acc.accCalibrateButton.hidden = YES;
        }
        if (!self.mag) {
            self.mag = [[accelerometerCellTemplate alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Magnetometer"];
            self.mag.accLabel.text = @"Magnetometer";
            self.mag.accIcon.image = [UIImage imageNamed:@"magnetometer.png"];
            self.mag.accValueX.text = @"-";
            self.mag.accValueY.text = @"-";
            self.mag.accValueZ.text = @"-";
            [self.mag.accCalibrateButton addTarget:self action:@selector(handleCalibrateMag) forControlEvents:UIControlEventTouchUpInside];
            self.magSensor = [[sensorMAG3110 alloc] init];
        }
        self.headingCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Headings"];
        self.graphCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AccGraph"];
    }
    if (self)
        self.d = andSensorTag;
    if(!self.d) NSLog(@"Could not connect to Run-n-Read Device!");
    self.magSensor = [[sensorMAG3110 alloc] init];
    self.sensorHistory = [[SensorHistoryData alloc] init:3 withSamples:MAX_HIST_SAMPLES];
    self.alphaTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(alphaFader:) userInfo:nil repeats:YES];

    self.currentVal = [[sensorTagValues alloc]init];
    self.vals = [[NSMutableArray alloc]init];
    
    // Set gravity estimates to 0
    self.sensorGx = self.sensorGy = self.sensorGz = 0.0;
    
    //Read Hard Iron EStimates from file
    [self readHIEstimatesFromFile];
    self.oldSensorHeading = 0.0;
    self.oldTabletHeading = 0.0;
    
    self.logTimer = [NSTimer scheduledTimerWithTimeInterval:CAL_TIME_INTERVAL target:self selector:@selector(logValues:) userInfo:nil repeats:YES];
    self.accXGraph = self.accYGraph = self.accZGraph = nil;
    
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
    self.sensorsEnabled = [[NSMutableArray alloc] init];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    if (!self.d.p.isConnected) {
        self.d.manager.delegate = self;
        [self.d.manager connectPeripheral:self.d.p options:nil];
    }
    else {
        self.d.p.delegate = self;
        [self configureSensorTag];
        self.title = @"Run-n-Read Application";
    }
}


-(void)viewWillDisappear:(BOOL)animated {
    [self deconfigureSensorTag];
    [self.logTimer invalidate];
    self.logTimer = nil;
    [self.alphaTimer invalidate];
    self.alphaTimer = nil;
    [self.accXGraph killGraph];
    [self.accYGraph killGraph];
    [self.accZGraph killGraph];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

-(void)viewDidDisappear:(BOOL)animated {
    self.sensorsEnabled = nil;
    self.d.manager.delegate = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    // Start getting headings from tablet
    self.devMotionManager=[[CMMotionManager alloc] init];
	[self.devMotionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical];
    
    // Initialize red arrow (tablet heading) and green arrow (sensor heading)
    NSString *redFile = [NSString stringWithFormat:@"red_arrow.png"];
    NSString *greenFile = [NSString stringWithFormat:@"green_arrow.png"];
    self.tabletHeadingImage = [[UIImageView alloc] initWithFrame:CGRectMake(40,100,100,100)];
    self.sensorHeadingImage = [[UIImageView alloc] initWithFrame:CGRectMake(180,100,100,100)];
    self.tabletHeadingImage.image = [UIImage imageNamed:redFile];
    self.sensorHeadingImage.image = [UIImage imageNamed:greenFile];
    UILabel *compassTitle = [[UILabel alloc] initWithFrame:CGRectMake(40,50,120,20)];
    UILabel *sensorTitle = [[UILabel alloc] initWithFrame:CGRectMake(160,50,150,20)];
    compassTitle.text = @"Tablet Heading";
    sensorTitle.text = @"Sensor Heading";
    [self.headingCell addSubview:compassTitle];
    [self.headingCell addSubview:self.tabletHeadingImage];
    [self.headingCell addSubview:sensorTitle];
    [self.headingCell addSubview:self.sensorHeadingImage];
    
    //Add Calibration button
    UIButton *btnTwo = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnTwo.frame = CGRectMake(80, 200, 160, 30);
    [btnTwo setTitle:@"Calibrate Sensor" forState:UIControlStateNormal];
    [btnTwo setBackgroundColor:[UIColor lightGrayColor]];
    [btnTwo addTarget:self action:@selector(startCalibration) forControlEvents:UIControlEventTouchUpInside];
    btnTwo.tag = 6701;
    [self.headingCell addSubview:btnTwo];
    
    // Add graph view
    CGFloat gCellX = self.graphCell.bounds.origin.x;
    CGFloat gCellY = self.graphCell.bounds.origin.y;
    CGFloat gCellW = 640.0;
    CGFloat gCellH = 450.0;
    self.hostXView = [[CPTGraphHostingView alloc] initWithFrame:CGRectMake(gCellX, gCellY, gCellW, gCellH)];
    self.hostYView = [[CPTGraphHostingView alloc] initWithFrame:CGRectMake(gCellX, (gCellY+gCellH), gCellW, gCellH)];
    self.hostZView = [[CPTGraphHostingView alloc] initWithFrame:CGRectMake(gCellX, (gCellY+2*gCellH), gCellW, gCellH)];
    //NSLog(@"Graph bounds: %f %f %f %f",self.hostView.bounds.origin.x, self.hostView.bounds.origin.y, self.hostView.bounds.size.width, self.hostView.bounds.size.height);
    CPTTheme *theme = [CPTTheme themeNamed:kCPTPlainWhiteTheme];
    self.accXGraph = [[RealTimePlot alloc] init];
    [self.accXGraph setGraphTitle:@"AccX Values" withColor:[CPTColor greenColor]];
    //[self.accXGraph renderInLayer:self.hostXView withTheme:theme animated:YES];
    //[self.graphCell addSubview:self.hostXView];
    self.accYGraph = [[RealTimePlot alloc] init];
    [self.accYGraph setGraphTitle:@"AccY Values" withColor:[CPTColor redColor]];
    [self.accYGraph renderInLayer:self.hostYView withTheme:theme animated:YES];
    [self.graphCell addSubview:self.hostYView];
    self.accZGraph = [[RealTimePlot alloc] init];
    [self.accZGraph setGraphTitle:@"AccZ Values" withColor:[CPTColor blueColor]];
    //[self.accZGraph renderInLayer:self.hostZView withTheme:theme animated:YES];
    //[self.graphCell addSubview:self.hostZView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellType;
    if(indexPath.row<2) {
        cellType = [self.sensorsEnabled objectAtIndex:indexPath.row];
    } else if (indexPath.row==2) {
        cellType = @"AccGraph";
    } else {
        cellType = @"Headings";
    }
    
    if ([cellType isEqualToString:@"Accelerometer"]) return self.acc.height;
    if ([cellType isEqualToString:@"Magnetometer"]) return self.mag.height;
    if ([cellType isEqualToString:@"Headings"]) return 300;
    if ([cellType isEqualToString:@"AccGraph"]) return 450*3;
    return 50;
}

-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Sensors";
    }
    return @"";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return self.sensorsEnabled.count+2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellType;
    if(indexPath.row<2) {
        cellType = [self.sensorsEnabled objectAtIndex:indexPath.row];
    } else if(indexPath.row==2) {
        cellType = @"AccGraph";
    } else {
        cellType = @"Headings";
    }
    
    if ([cellType isEqualToString:@"Accelerometer"]) {
        return self.acc;
    }
    else if ([cellType isEqualToString:@"Magnetometer"]) {
        return self.mag;
    }
    else if ([cellType isEqualToString:@"Headings"]) {
        return self.headingCell;
    } else if([cellType isEqualToString:@"AccGraph"]) {
        return self.graphCell;
    }
    
    // Something has gone wrong, because we should never get here, return empty cell
    return [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@""];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

-(void) configureSensorTag {
    // Configure sensortag, turning on Sensors and setting update period for sensors etc ...
    if ([self sensorEnabled:@"Accelerometer active"]) {
        CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer service UUID"]];
        CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer config UUID"]];
        CBUUID *pUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer period UUID"]];
        NSInteger period = [[self.d.setupData valueForKey:@"Accelerometer period"] integerValue];
        //uint8_t periodData = (uint8_t)(period / 10);
        //uint8_t periodData = (uint8_t)(CAL_TIME_INTERVAL*1000);
        uint8_t periodData = (uint8_t)period;
        NSLog(@"Accelerometer Period Set to %d",periodData);
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:pUUID data:[NSData dataWithBytes:&periodData length:1]];
        uint8_t data = 0x01;
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
        cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer data UUID"]];
        //[BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:YES];
        [BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:NO];
        [self.sensorsEnabled addObject:@"Accelerometer"];
    }
    
    if ([self sensorEnabled:@"Magnetometer active"]) {
        CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer service UUID"]];
        CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer config UUID"]];
        CBUUID *pUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer period UUID"]];
        NSInteger period = [[self.d.setupData valueForKey:@"Magnetometer period"] integerValue];
        uint8_t periodData = (uint8_t)(period / 10);
        NSLog(@"Magnetometer Period Set To %d",periodData);
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:pUUID data:[NSData dataWithBytes:&periodData length:1]];
        uint8_t data = 0x01;
        [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
        cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer data UUID"]];
        //[BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:YES];
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
    //NSLog(@"didUpdateValueForCharacteristic = %@",characteristic.UUID);
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Accelerometer data UUID"]]]) {
        float x = [sensorKXTJ9 calcXValue:characteristic.value];
        float y = [sensorKXTJ9 calcYValue:characteristic.value];
        float z = [sensorKXTJ9 calcZValue:characteristic.value];
        
        self.acc.accValueX.text = [NSString stringWithFormat:@"X: % 0.1fG",x];
        self.acc.accValueY.text = [NSString stringWithFormat:@"Y: % 0.1fG",y];
        self.acc.accValueZ.text = [NSString stringWithFormat:@"Z: % 0.1fG",z];
        
        //NSLog(@"%@ %@ %@",self.acc.accValueX.text,self.acc.accValueY,self.acc.accValueZ);
        
        self.acc.accValueX.textColor = [UIColor blackColor];
        self.acc.accValueY.textColor = [UIColor blackColor];
        self.acc.accValueZ.textColor = [UIColor blackColor];
        
        self.acc.accGraphX.progress = (x / [sensorKXTJ9 getRange]) + 0.5;
        self.acc.accGraphY.progress = (y / [sensorKXTJ9 getRange]) + 0.5;
        self.acc.accGraphZ.progress = (z / [sensorKXTJ9 getRange]) + 0.5;
        
        self.currentVal.accX = x;
        self.currentVal.accY = y;
        self.currentVal.accZ = z;
        
    }
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:[self.d.setupData valueForKey:@"Magnetometer data UUID"]]]) {
        
        float x = [self.magSensor calcXValue:characteristic.value];
        float y = [self.magSensor calcYValue:characteristic.value];
        float z = [self.magSensor calcZValue:characteristic.value];
        
        self.mag.accValueX.text = [NSString stringWithFormat:@"X: % 0.1fuT",x];
        self.mag.accValueY.text = [NSString stringWithFormat:@"Y: % 0.1fuT",y];
        self.mag.accValueZ.text = [NSString stringWithFormat:@"Z: % 0.1fuT",z];
        
        self.mag.accValueX.textColor = [UIColor blackColor];
        self.mag.accValueY.textColor = [UIColor blackColor];
        self.mag.accValueZ.textColor = [UIColor blackColor];
        
        self.mag.accGraphX.progress = (x / [sensorMAG3110 getRange]) + 0.5;
        self.mag.accGraphY.progress = (y / [sensorMAG3110 getRange]) + 0.5;
        self.mag.accGraphZ.progress = (z / [sensorMAG3110 getRange]) + 0.5;
        
        self.currentVal.magX = x;
        self.currentVal.magY = y;
        self.currentVal.magZ = z;
        
    }

    [self.tableView reloadData];
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"didWriteValueForCharacteristic %@ error = %@",characteristic.UUID,error);
}



- (IBAction) handleCalibrateMag {
    NSLog(@"Calibrate magnetometer pressed !");
    [self.magSensor calibrate];
}

-(void) alphaFader:(NSTimer *)timer {
    CGFloat w,a;
    if (self.acc) {
        [self.acc.accValueX.textColor getWhite:&w alpha:&a];
        if (a > MIN_ALPHA_FADE) a -= ALPHA_FADE_STEP;
        self.acc.accValueX.textColor = [self.acc.accValueX.textColor colorWithAlphaComponent:a];
        
        [self.acc.accValueY.textColor getWhite:&w alpha:&a];
        if (a > MIN_ALPHA_FADE) a -= ALPHA_FADE_STEP;
        self.acc.accValueY.textColor = [self.acc.accValueY.textColor colorWithAlphaComponent:a];
        
        [self.acc.accValueZ.textColor getWhite:&w alpha:&a];
        if (a > MIN_ALPHA_FADE) a -= ALPHA_FADE_STEP;
        self.acc.accValueZ.textColor = [self.acc.accValueZ.textColor colorWithAlphaComponent:a];
    }
    if (self.mag) {
        [self.mag.accValueX.textColor getWhite:&w alpha:&a];
        if (a > MIN_ALPHA_FADE) a -= ALPHA_FADE_STEP;
        self.mag.accValueX.textColor = [self.mag.accValueX.textColor colorWithAlphaComponent:a];
        
        [self.mag.accValueY.textColor getWhite:&w alpha:&a];
        if (a > MIN_ALPHA_FADE) a -= ALPHA_FADE_STEP;
        self.mag.accValueY.textColor = [self.mag.accValueY.textColor colorWithAlphaComponent:a];
        
        [self.mag.accValueZ.textColor getWhite:&w alpha:&a];
        if (a > MIN_ALPHA_FADE) a -= ALPHA_FADE_STEP;
        self.mag.accValueZ.textColor = [self.mag.accValueZ.textColor colorWithAlphaComponent:a];
    }
}


-(void) logValues:(NSTimer *)timer {
    //NSString *date = [NSDateFormatter localizedStringFromDate:[NSDate date]
    //                                                dateStyle:NSDateFormatterShortStyle
    //                                                timeStyle:NSDateFormatterMediumStyle];
    //self.currentVal.timeStamp = date;
    self.currentVal.timeStamp = [[NSDate date] timeIntervalSince1970];
    sensorTagValues *newVal = [[sensorTagValues alloc]init];
    newVal.accX = self.currentVal.accX;
    newVal.accY = self.currentVal.accY;
    newVal.accZ = self.currentVal.accZ;
    newVal.magX = self.currentVal.magX;
    newVal.magY = self.currentVal.magY;
    newVal.magZ = self.currentVal.magZ;
    
    // Find new sensor accln. and add to history
    NSMutableArray *sensorVals = [[NSMutableArray alloc] init];
    [sensorVals addObject:[NSNumber numberWithFloat:newVal.accX]];
    [sensorVals addObject:[NSNumber numberWithFloat:newVal.accY]];
    [sensorVals addObject:[NSNumber numberWithFloat:newVal.accZ]];
    float currentAccX = newVal.accX;
    float currentAccY = newVal.accY;
    float currentAccZ = newVal.accZ;
    //NSLog(@",%f,%f,%f",currentAccX,currentAccY,currentAccZ);
    /*
    if(self.sensorHistory.numSamples < MAX_HIST_SAMPLES) {
        self.sensorGx = (self.sensorGx*self.sensorHistory.numSamples + currentAccX)/(self.sensorHistory.numSamples+1);
        self.sensorGy = (self.sensorGy*self.sensorHistory.numSamples + currentAccY)/(self.sensorHistory.numSamples+1);
        self.sensorGz = (self.sensorGz*self.sensorHistory.numSamples + currentAccZ)/(self.sensorHistory.numSamples+1);
    } else {
        NSMutableArray *lastrec =[self.sensorHistory.measData objectAtIndex:0];
        float oldAccX = [[lastrec objectAtIndex:0] floatValue];
        float oldAccY = [[lastrec objectAtIndex:1] floatValue];
        float oldAccZ = [[lastrec objectAtIndex:2] floatValue];
        self.sensorGx = (self.sensorGx*MAX_HIST_SAMPLES + currentAccX - oldAccX)/MAX_HIST_SAMPLES;
        self.sensorGy = (self.sensorGy*MAX_HIST_SAMPLES + currentAccY - oldAccY)/MAX_HIST_SAMPLES;
        self.sensorGz = (self.sensorGz*MAX_HIST_SAMPLES + currentAccZ - oldAccZ)/MAX_HIST_SAMPLES;
    }*/
    /*Enable this block of code for complementary filter based gravity estimation */
    self.sensorGx = GRAV_ESTIMATION*currentAccX + (1.0-GRAV_ESTIMATION)*self.sensorGx;
    self.sensorGy = GRAV_ESTIMATION*currentAccY + (1.0-GRAV_ESTIMATION)*self.sensorGy;
    self.sensorGz = GRAV_ESTIMATION*currentAccZ + (1.0-GRAV_ESTIMATION)*self.sensorGz;

    [self.sensorHistory enqueueData:sensorVals];
    
    // Create history for graphing by subtracting gravity
    NSMutableArray *graphVals = [[NSMutableArray alloc] init];
    //[graphVals addObject:self.currentVal.timeStamp];
    [graphVals addObject:[NSNumber numberWithFloat:(currentAccX-self.sensorGx)]];
    
    // Find sensor magnetometer readings
    [sensorVals addObject:[NSNumber numberWithFloat:(newVal.magX-self.iVx)]];
    [sensorVals addObject:[NSNumber numberWithFloat:(newVal.magY-self.iVy)]];
    [sensorVals addObject:[NSNumber numberWithFloat:(newVal.magZ-self.iVz)]];
    
    // Get sensor heading
    float newSensorHeading = 0.0;
    if(self.sensorHistory.numSamples >2) {
        NSMutableArray *rec2 = [self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples-3)];
        NSMutableArray *rec1 =[self.sensorHistory.measData objectAtIndex:(self.sensorHistory.numSamples-2)];
        float w1 = K1_SMOOTHING, w2 = K2_SMOOTHING; // a_smooth = [a(k) + w1*a(k-1) + w2*a(k-2)]/(1+w1+w2)
        float accXFiltered = (currentAccX + w1*[[rec1 objectAtIndex:0] floatValue] + w2*[[rec2 objectAtIndex:0] floatValue])/(1.0+w1+w2) - self.sensorGx;
        float accYFiltered = (currentAccY + w1*[[rec1 objectAtIndex:1] floatValue] + w2*[[rec2 objectAtIndex:1] floatValue])/(1.0+w1+w2) - self.sensorGy;
        float accZFiltered = (currentAccZ + w1*[[rec1 objectAtIndex:2] floatValue] + w2*[[rec2 objectAtIndex:2] floatValue])/(1.0+w1+w2) - self.sensorGz;
        //NSLog(@",%f,%f,%f,%f,%f,%f",currentAccX, currentAccY, currentAccZ, accXFiltered,accYFiltered,accZFiltered);
        //NSLog(@",%f,%f,%f,%f,%f,%f",currentAccX, currentAccY, currentAccZ,self.sensorGx,self.sensorGy,self.sensorGz);
        //NSMutableArray* sensorAcc = [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:accXFiltered],[NSNumber numberWithFloat:accYFiltered],[NSNumber numberWithFloat:accZFiltered],nil];
        //[self.accXGraph newData:[[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:accXFiltered], nil]];
        [self.accYGraph newData:[[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:10*accYFiltered], nil]];
        //[self.accZGraph newData:[[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:accZFiltered], nil]];
        
        /* Enable lines below to see raw Acceleration values */
        //[self.accXGraph newData:[[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:currentAccX], nil]];
        //[self.accYGraph newData:[[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:currentAccY], nil]];
        //[self.accZGraph newData:[[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:currentAccZ], nil]];
        
        NSMutableArray* sensorValsForOrient = [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:self.sensorGx], [NSNumber numberWithFloat:self.sensorGy], [NSNumber numberWithFloat:self.sensorGz], nil];
        [sensorValsForOrient addObject:[sensorVals objectAtIndex:3]];
        [sensorValsForOrient addObject:[sensorVals objectAtIndex:4]];
        [sensorValsForOrient addObject:[sensorVals objectAtIndex:5]];
        NSArray *sensorOrientation = [self getOrientationAngles:sensorValsForOrient];
        newSensorHeading = [[sensorOrientation objectAtIndex:2] floatValue];
    }
    
    // Add animation to the tablet heading pointer
    CMAttitude* currentAttitude = self.devMotionManager.deviceMotion.attitude;
    //if(currentAttitude ==nil) { NSLog(@"Could not get attitude"); }
	float newRad =  currentAttitude.yaw;
	CABasicAnimation *tabletAnimation;
	tabletAnimation=[CABasicAnimation animationWithKeyPath:@"transform.rotation"];
	tabletAnimation.fromValue = [NSNumber numberWithFloat:self.oldTabletHeading];
	tabletAnimation.toValue=[NSNumber numberWithFloat:newRad];
	tabletAnimation.duration = 0.5f;
	[self.tabletHeadingImage.layer addAnimation:tabletAnimation forKey:@"animateMyRotation"];
	self.tabletHeadingImage.transform = CGAffineTransformMakeRotation(newRad);
    self.oldTabletHeading = newRad;

    // Add animation to the sensor heading pointer
    CABasicAnimation *sensorAnimation;
	sensorAnimation=[CABasicAnimation animationWithKeyPath:@"transform.rotation"];
	sensorAnimation.fromValue = [NSNumber numberWithFloat:self.oldSensorHeading];
	sensorAnimation.toValue=[NSNumber numberWithFloat:newSensorHeading];
	sensorAnimation.duration = 0.5f;
	[self.sensorHeadingImage.layer addAnimation:sensorAnimation forKey:@"animateMyRotation"];
	self.sensorHeadingImage.transform = CGAffineTransformMakeRotation(M_PI);
    self.oldSensorHeading = newSensorHeading;
    [self.vals addObject:newVal];
    
    //IF calibration is ongoing, then store values
    if(self.isCalibrationOngoing) {
        NSMutableArray *recordMeas = [[NSMutableArray alloc] initWithCapacity:MAX_CAL_MEASURES];
        NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]/1000;
        [recordMeas addObject:[NSNumber numberWithDouble:timeInMiliseconds]];
        [recordMeas addObject:[NSNumber numberWithFloat:self.currentVal.accX]];
        [recordMeas addObject:[NSNumber numberWithFloat:self.currentVal.accY]];
        [recordMeas addObject:[NSNumber numberWithFloat:self.currentVal.accZ]];
        [recordMeas addObject:[NSNumber numberWithFloat:self.currentVal.magX]];
        [recordMeas addObject:[NSNumber numberWithFloat:self.currentVal.magY]];
        [recordMeas addObject:[NSNumber numberWithFloat:self.currentVal.magZ]];
        //NSLog(@"%f,%f,%f,%f,%f,%f",self.currentVal.accX,self.currentVal.accY,self.currentVal.accZ,self.currentVal.magX,self.currentVal.magY,self.currentVal.magZ);
        [self.calibrationHistory enqueueData:recordMeas];
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
    float phi = atan2f(Gy,Gz)-M_PI/2.0;  // phi = roll angle, angle of rotation about X-axis. For phone this is axis through phone, through volume button. Subtracting 90 degrees because general use case will be with sensor vertical
    float theta = atan2f(Gx,Gz);
    // We cannot correct for tilt over 40 degrees with this algorithm, if the board is tilted as such, return 0.
    if(phi > 0.78 || phi < -0.78 || theta > 0.78 || theta < -0.78) {
        return @[[NSNumber numberWithFloat:0.0],[NSNumber numberWithFloat:0.0],[NSNumber numberWithFloat:0.0]];
    }
    float cosRoll = cosf(phi);
    float sinRoll = sinf(phi);
    float cosPitch = cosf(theta);
    float sinPitch = sinf(theta);
    float Xh = (Bx * cosPitch) + (Bz * sinPitch);
    float Yh = (Bx * sinRoll * sinPitch) + (By * cosRoll) - (Bz * sinRoll * cosPitch);
    float psi = atan2f(Yh, Xh);
    //if(phi>M_PI) { phi -= 2*M_PI; }
    //else if(phi<-M_PI) { phi += 2*M_PI; }
    //float theta = atan2f(-Gx,(Gy*sinf(phi)+Gz*cosf(phi))); // theta = tilt angle, angle or rotation about Y-axis, through phone, through earphone
    //if(theta>M_PI/2.0) { theta -= M_PI; }
    //else if(theta<-M_PI/2.0) {theta += M_PI; }
    //float psi = atan2f(((Bz-self.iVz)*sinf(phi)-(By-self.iVy)*cosf(phi)),((Bx-self.iVx)*cosf(theta)+(By-self.iVy)*sinf(theta)*sinf(phi)+(Bz-self.iVz)*sinf(theta)*cosf(phi))); // psi = yaw angle, angle of rotation about Z-axis. Into plane of phone
    NSArray *rotAngles = @[[NSNumber numberWithFloat:phi],[NSNumber numberWithFloat:theta],[NSNumber numberWithFloat:psi]]; //Preserve order
    //NSLog(@"Sensor Phi: %f Theta: %f, Psi: %f",phi,theta,psi);
    return rotAngles;
}

// Calibration functions
-(void) startCalibration {
    self.isCalibrationOngoing = true;
    self.calibrationCountdown = CALIBRATION_TIME;
    self.calibrationHistory = [[SensorHistoryData alloc] init:MAX_CAL_MEASURES withSamples:800]; //800 Samples should be enough for 32s @ 40ms rate
    self.calibrationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateCalibrationCountdown:) userInfo:nil repeats:YES];
    self.calibrationOngoing = [[UILabel alloc]initWithFrame:CGRectMake(10, 50, 300, 200)];
    [self.calibrationOngoing setBackgroundColor:[UIColor blackColor]];
    self.calibrationOngoing.textColor = [UIColor whiteColor];
    self.calibrationOngoing.tag = 6703;
    self.calibrationOngoing.lineBreakMode = NSLineBreakByWordWrapping;
    self.calibrationOngoing.numberOfLines = 0;
    [self.headingCell addSubview:self.calibrationOngoing];
}

-(void) updateCalibrationCountdown:(NSTimer *) theTimer{
    self.calibrationCountdown--;
    if (self.calibrationCountdown>0) {
        self.calibrationOngoing.text = [NSString stringWithFormat:@"Calibration Ongoing .... %02d seconds left. Rotate sensor about all 3 axes",self.calibrationCountdown];
    } else if (self.calibrationCountdown ==0) {
        self.calibrationOngoing.text = [NSString stringWithFormat:@"Calibration Complete"];
    } else {
    	[theTimer invalidate];
    	self.isCalibrationOngoing = NO;
        [[self.headingCell viewWithTag:6703] removeFromSuperview];
        [self setHardIronVectors:self.calibrationHistory];
    }
}

-(void)setHardIronVectors:(SensorHistoryData*)t {
    float minVx=1000.0, minVy=1000.0, minVz=1000.0;
    float maxVx=-1000.0, maxVy = -1000.0, maxVz = -1000.0;
    for(NSMutableArray* B in t.measData) {
        float Bx = [[B objectAtIndex:4] floatValue];
        float By = [[B objectAtIndex:5] floatValue];
        float Bz = [[B objectAtIndex:6] floatValue];
        if(Bx < minVx) minVx = Bx;
        if(By < minVy) minVy = By;
        if(Bz < minVz) minVz = Bz;
        if(Bx > maxVx) maxVx = Bx;
        if(By > maxVy) maxVy = By;
        if(Bz > maxVz) maxVz = Bz;
    }
    self.iVx = (minVx + maxVx)/2.0;
    self.iVy = (minVy + maxVy)/2.0;
    self.iVz = (minVz + maxVz)/2.0;
    NSLog(@"Hard Iron Estimates = %f %f %f",self.iVx,self.iVy,self.iVz);
    
    // Write Hard Iron Estimates to file
    NSFileManager *filemgr;
    NSString *dataFile;
    NSString *docsDir;
    NSArray *dirPaths;
    filemgr = [NSFileManager defaultManager];
    
    // Identify the documents directory
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    docsDir = [dirPaths objectAtIndex:0];
    
    // Build the path to the data file
    dataFile = [docsDir stringByAppendingPathComponent: @"RR_Hard_Iron_Estimates.dat"];
    
    // Check if the file already exists
    if (![filemgr isWritableFileAtPath:dataFile] && [filemgr fileExistsAtPath:dataFile]) {
        NSLog(@"Could not write file at path %@",dataFile);
    } else {
        NSArray *hIronEst = [[NSArray alloc] initWithObjects:[NSNumber numberWithFloat:self.iVx],[NSNumber numberWithFloat:self.iVy],[NSNumber numberWithFloat:self.iVz],nil];
        [hIronEst writeToFile:dataFile atomically:YES];
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

@end
