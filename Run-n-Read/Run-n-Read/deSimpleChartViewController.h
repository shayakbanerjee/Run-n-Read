//
//  deSimpleChartViewController.h
//  deSimpleChart
//
//  Created by Benjamin M. Duivesteyn on 20.02.10.
//  Copyright TBA 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CKSparkline.h"

@interface deSimpleChartViewController : UIViewController {
    CKSparkline *sparkLine;
}

-(id)init:(NSArray*)xyData;
-(void)sparkleChart;


@end

