/*
 *  deviceSelector.h
 *
 * Created by Ole Andreas Torvmark on 10/2/12.
 * Copyright (c) 2012 Texas Instruments Incorporated - http://www.ti.com/
 * ALL RIGHTS RESERVED
 */

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BLEDevice.h"
//#import "SensorTagApplicationViewController.h"
//#import "CalibrationViewController.h"

@interface deviceSelector : UITableViewController <CBCentralManagerDelegate,CBPeripheralDelegate> {
    NSInteger storyNum;
    NSInteger maxPages;
    NSInteger pageNum;
    NSString* webURL;
}

@property (strong,nonatomic) CBCentralManager *m;
@property (strong,nonatomic) NSMutableArray *nDevices;
@property (strong,nonatomic) NSMutableArray *sensorTags;
@property bool isForCalibration;
@property bool isWebView;

- (id)initWithStyle:(UITableViewStyle)style isDevForCalibration:(bool) b;
-(void) setWebView:(bool)t;
-(void) setWebURL:(NSString*)w;
-(void) setPageNum:(NSInteger)p;
-(void) setStoryNumber:(NSInteger)s withPages:(NSInteger) maxP;

-(NSMutableDictionary *) makeSensorTagConfiguration;

@end

