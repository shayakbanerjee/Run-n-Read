//
//  deSimpleChartViewController.m
//  deSimpleChart
//
//  Created by Benjamin M. Duivesteyn on 20.02.10.
//  Copyright TBA 2010. All rights reserved.
//

#import "deSimpleChartViewController.h"

@implementation deSimpleChartViewController


/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

-(id)init:(NSArray*)xyData {
    // Sample data
    self = [super init];
	sparkLine = [[CKSparkline alloc] initWithFrame:CGRectMake(17.0, 32.0, 300, 400)];
    sparkLine.data = [[NSArray alloc] initWithArray:xyData];
    return self;
}

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	[self sparkleChart];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
	
}

-(void)viewWillDisappear:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations.
	return (interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}



-(void)sparkleChart{
    [self.view addSubview:sparkLine];
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
}

@end
