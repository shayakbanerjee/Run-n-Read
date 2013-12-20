//
//  RealTimePlot.h
//  CorePlotGallery
//

#import "PlotItem.h"

@interface RealTimePlot : PlotItem<CPTPlotDataSource>
{
    @private
    NSMutableArray *plotX;
    NSUInteger currentIndex;
}

@property (strong,nonatomic) NSString* plotTitle;
@property (strong,nonatomic) CPTColor* plotLineColor;

-(void) newData:(NSMutableArray*)inData;
-(void) setGraphTitle:(NSString*)pT withColor:(CPTColor*)pC;

@end
