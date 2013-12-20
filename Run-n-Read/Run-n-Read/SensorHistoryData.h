//
//  SensorMeasureData.h
//  SensorTagEX
//
//  Created by Shak on 6/27/13.
//  Copyright (c) 2013 Texas Instruments. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SensorHistoryData : NSObject

@property NSMutableArray *measData;
@property NSInteger numMeasures;
@property NSInteger numSamples;
@property NSInteger maxSamples;

-(id)init:(NSInteger)measNum withSamples:(NSInteger) n;
-(bool)isEmpty;
-(void)enqueueData:(NSMutableArray*)t;
-(NSMutableArray*)dequeueData;

@end
