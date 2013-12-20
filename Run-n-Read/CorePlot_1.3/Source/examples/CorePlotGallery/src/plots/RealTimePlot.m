//
//  RealTimePlot.m
//  CorePlotGallery
//

#import "RealTimePlot.h"

const double kFrameRate         = 25.0;  // frames per second
const double kAlpha             = 0.25; // smoothing constant
const NSUInteger kMaxDataPoints = 51;
NSString *kXPlotId       = @"Acc X Plot";

@implementation RealTimePlot

+(void)load
{
    [super registerPlotItem:self];
}

-(id)init
{
    if ( (self = [super init]) ) {
        plotX  = [[NSMutableArray alloc] initWithCapacity:kMaxDataPoints];
        self.title   = @"Accelerometer Values";
        self.section = kLinePlots;
    }

    return self;
}

-(void)killGraph
{
    [super killGraph];
}

-(void)setGraphTitle:(NSString*)pT withColor:(CPTColor*)pC
{
    self.title = pT;
    self.plotLineColor = pC;
}

/*-(void)generateData
{
    [plotX removeAllObjects];
    currentIndex = 0;
    dataTimer = [NSTimer timerWithTimeInterval:1.0 / kFrameRate
                                         target:self
                                       selector:@selector(newData:)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:dataTimer forMode:NSDefaultRunLoopMode];
}
*/

-(void)renderInLayer:(CPTGraphHostingView *)layerHostingView withTheme:(CPTTheme *)theme animated:(BOOL)animated
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    CGRect bounds = layerHostingView.bounds;
#else
    CGRect bounds = NSRectToCGRect(layerHostingView.bounds);
#endif

    CPTGraph *graph = [[CPTXYGraph alloc] initWithFrame:bounds];
    [self addGraph:graph toHostingView:layerHostingView];
    [self applyTheme:theme toGraph:graph withDefault:[CPTTheme themeNamed:kCPTDarkGradientTheme]];

    [self setTitleDefaultsForGraph:graph withBounds:bounds];
    [self setPaddingDefaultsForGraph:graph withBounds:bounds];

    graph.plotAreaFrame.paddingTop    = 15.0;
    graph.plotAreaFrame.paddingRight  = 15.0;
    graph.plotAreaFrame.paddingBottom = 15.0;
    graph.plotAreaFrame.paddingLeft   = 15.0;
    graph.plotAreaFrame.masksToBorder = NO;

    // Grid line styles
    CPTMutableLineStyle *majorGridLineStyle = [CPTMutableLineStyle lineStyle];
    majorGridLineStyle.lineWidth = 0.75;
    majorGridLineStyle.lineColor = [[CPTColor colorWithGenericGray:0.2] colorWithAlphaComponent:0.75];

    CPTMutableLineStyle *minorGridLineStyle = [CPTMutableLineStyle lineStyle];
    minorGridLineStyle.lineWidth = 0.25;
    minorGridLineStyle.lineColor = [[CPTColor whiteColor] colorWithAlphaComponent:0.1];

    // Axes
    // X axis
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x          = axisSet.xAxis;
    x.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
    x.orthogonalCoordinateDecimal = CPTDecimalFromUnsignedInteger(0);
    x.majorGridLineStyle          = majorGridLineStyle;
    x.minorGridLineStyle          = minorGridLineStyle;
    x.minorTicksPerInterval       = 9;
    x.title                       = @"Time";
    x.titleOffset                 = 5.0;
    NSNumberFormatter *labelFormatter = [[NSNumberFormatter alloc] init];
    labelFormatter.numberStyle = NSNumberFormatterNoStyle;
    x.labelFormatter           = labelFormatter;

    // Y axis
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
    y.orthogonalCoordinateDecimal = CPTDecimalFromUnsignedInteger(0);
    y.majorGridLineStyle          = majorGridLineStyle;
    y.minorGridLineStyle          = minorGridLineStyle;
    y.minorTicksPerInterval       = 3;
    y.labelOffset                 = 5.0;
    y.title                       = @"Acc";
    y.titleOffset                 = 5.0;
    y.axisConstraints             = [CPTConstraints constraintWithLowerOffset:0.0];

    // Rotate the labels by 45 degrees, just to show it can be done.
    //x.labelRotation = M_PI * 0.25;

    // Create the X plot
    CPTScatterPlot *dataXLinePlot = [[CPTScatterPlot alloc] init];
    dataXLinePlot.identifier     = kXPlotId;
    dataXLinePlot.cachePrecision = CPTPlotCachePrecisionDouble;

    CPTMutableLineStyle *lineStyle = [dataXLinePlot.dataLineStyle mutableCopy];
    lineStyle.lineWidth              = 2.0;
    lineStyle.lineColor              = self.plotLineColor;
    dataXLinePlot.dataLineStyle = lineStyle;

    dataXLinePlot.dataSource = self;
    [graph addPlot:dataXLinePlot];

    // Plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(0) length:CPTDecimalFromUnsignedInteger(kMaxDataPoints - 1)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInteger(-10) length:CPTDecimalFromUnsignedInteger(20)];
}

-(void)dealloc
{
}

#pragma mark -
#pragma mark Timer callback
-(void)newData:(NSMutableArray*)inData
{
    CPTGraph *theGraph = [self.graphs objectAtIndex:0];
    CPTPlot *xPlot = [theGraph plotWithIdentifier:kXPlotId];
    
    if ( xPlot ) {
        if ( plotX.count >= kMaxDataPoints ) {
            [plotX removeObjectAtIndex:0];
            [xPlot deleteDataInIndexRange:NSMakeRange(0, 1)];
        }
        
        CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
        NSUInteger location       = (currentIndex >= kMaxDataPoints ? currentIndex - kMaxDataPoints + 1 : 0);
        plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(location)
                                                        length:CPTDecimalFromUnsignedInteger(kMaxDataPoints - 1)];
        
        currentIndex++;
        NSNumber* accX = [inData objectAtIndex:0];
        [plotX addObject:accX];
        if(plotX.count>=kMaxDataPoints) {
            [xPlot insertDataAtIndex:plotX.count-1 numberOfRecords:1];
        } else {
            [xPlot reloadData];
        }
    }
}

#pragma mark -
#pragma mark Plot Data Source Methods

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return [plotX count];
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    NSNumber *num = nil;

    switch ( fieldEnum ) {
        case CPTScatterPlotFieldX:
            num = [NSNumber numberWithUnsignedInteger:index + currentIndex - plotX.count];
            break;

        case CPTScatterPlotFieldY:
            num = [plotX objectAtIndex:index];
            break;

        default:
            break;
    }

    return num;
}

@end
