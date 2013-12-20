//
//  LibraryViewController.m
//  SensorTagEX
//
//  Created by Shak on 7/3/13.
//  Copyright (c) 2013 Texas Instruments. All rights reserved.
//

#import "LibraryViewController.h"
#import "RunReadPNGViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface LibraryViewController ()

@end

@implementation LibraryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    UIColor *bground = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"Ancient_wallpapers_110.jpg"]];
    self.view.backgroundColor = bground;
    //UIImageView *bground = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Old_Paper_Texture.png"]];
    //bground.frame = [self.view bounds];
    //bground.contentMode = UIViewContentModeScaleAspectFit;
    //[self.view addSubview:bground];
    
    self.navigationController.navigationBar.topItem.title = @"Run-n-Read Library";
    // Set button parameters
    CGFloat btX = self.view.bounds.origin.x + 0.15*self.view.bounds.size.width;
    CGFloat btY = self.view.bounds.origin.y + 0.25*self.view.bounds.size.height;
    CGFloat btW = 0.7*self.view.bounds.size.width;
    CGFloat btH = 0.08*self.view.bounds.size.height;
    CGFloat btS = 0.08*self.view.bounds.size.height;
    CGFloat btP = btS + btH;
    NSInteger btFontSize = 18;
    if ( [(NSString*)[UIDevice currentDevice].model isEqualToString:@"iPad"] ) btFontSize = 22;
    
    // Lay out the buttons
    UIButton *bt1 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    bt1.tag = 1;
    [bt1 addTarget:self action:@selector(loadShortStory:) forControlEvents:UIControlEventTouchUpInside];
    [bt1 setTitle:@"I. Short Story 1" forState:UIControlStateNormal];
    bt1.titleLabel.font = [UIFont fontWithName:@"Copperplate-Bold" size:btFontSize];
    [bt1 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bt1.frame = CGRectMake(btX, btY, btW, btH);
    [self.view addSubview:bt1];
    UIButton *bt2 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    bt2.tag = 2;
    [bt2 addTarget:self action:@selector(loadShortStory:) forControlEvents:UIControlEventTouchUpInside];
    [bt2 setTitle:@"II. Short Story 2" forState:UIControlStateNormal];
    bt2.titleLabel.font = [UIFont fontWithName:@"Copperplate-Bold" size:btFontSize];
    [bt2 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bt2.frame = CGRectMake(btX, (btY+btP), btW, btH);
    [self.view addSubview:bt2];
    UIButton *bt3 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    bt3.tag = 3;
    [bt3 addTarget:self action:@selector(loadWebView:) forControlEvents:UIControlEventTouchUpInside];
    [bt3 setTitle:@"III. Wall St. Journal" forState:UIControlStateNormal];
    bt3.titleLabel.font = [UIFont fontWithName:@"Copperplate-Bold" size:btFontSize];
    [bt3 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bt3.frame = CGRectMake(btX, (btY+2*btP), btW, btH);
    [self.view addSubview:bt3];
    UIButton *bt4 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    bt4.tag = 4;
    [bt4 addTarget:self action:@selector(loadWebView:) forControlEvents:UIControlEventTouchUpInside];
    [bt4 setTitle:@"IV. BBC News" forState:UIControlStateNormal];
    bt4.titleLabel.font = [UIFont fontWithName:@"Copperplate-Bold" size:btFontSize];
    [bt4 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    bt4.frame = CGRectMake(btX, (btY+3*btP), btW, btH);
    [self.view addSubview:bt4];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadShortStory:(id)sender
{
    UIButton *clicked = (UIButton *) sender;
    if(clicked.tag<=2) {
        RunReadPNGViewController *dRR = [[RunReadPNGViewController alloc] init];
        if(clicked.tag==1) [dRR setStoryNumber:1 withPages:10];
        else if(clicked.tag==2) [dRR setStoryNumber:4 withPages:4];
        [self.navigationController pushViewController:dRR animated:YES];
    }
}

-(void)loadWebView:(id)sender
{
    UIButton *clicked = (UIButton *) sender;
    NSString* webURL;
    if(clicked.tag==3) { webURL = @"http://m.us.wsj.com"; }
    if(clicked.tag==4) { webURL = @"http://m.bbc.co.uk"; }
    RunReadPNGViewController *dWR = [[RunReadPNGViewController alloc] init];
    [dWR setWebView:true withURL:webURL];
    [self.navigationController pushViewController:dWR animated:YES];
}

@end
