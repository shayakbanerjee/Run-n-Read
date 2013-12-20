//
//  SensorMeasureData.m
//  SensorTagEX
//
//  Created by Shak on 6/27/13.
//  Copyright (c) 2013 Texas Instruments. All rights reserved.
//

#import "SensorHistoryData.h"

@implementation SensorHistoryData

@synthesize measData;
@synthesize numSamples, numMeasures, maxSamples;

-(id)init:(NSInteger)measNum withSamples:(NSInteger) n {
    self.measData = [[NSMutableArray alloc] initWithCapacity:n];
    //for (int i=0; i<n; i++) {
    //    [self.measData addObject:[[NSMutableArray alloc] initWithCapacity:measNum]];
    //}
    self.maxSamples = n;
    self.numMeasures = measNum;
    self.numSamples = 0;
    return(self);
}

-(void)enqueueData:(NSMutableArray*)sdata {
    if (self.numSamples < self.maxSamples) {
        if ([sdata count]==self.numMeasures) {
            [self.measData addObject:sdata];
            self.numSamples++;
        } else {
            NSLog(@"Number of elements in input does not match defined class");
        }
    } else {
        if ([sdata count]==self.numMeasures) {
            [self.measData removeObjectAtIndex:0];
            [self.measData addObject:sdata];
        }
    }
}

-(NSMutableArray*)dequeueData {
    if(self.numSamples <= 0) { return nil; }
    NSMutableArray *headObject = [self.measData objectAtIndex:0];
    if (headObject != nil) {
        [self.measData removeObjectAtIndex:0];
        self.numSamples--;
    }
    return headObject;
}

-(bool)isEmpty {
    if(self.numSamples==0) { return YES; }
    else { return NO; }
}


@end
