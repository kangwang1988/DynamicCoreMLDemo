//
//  ViewController.m
//  DynamicCoreMLDemo
//
//  Created by Kyle on 30/06/2017.
//  Copyright © 2017 KyleWong. All rights reserved.
//

#import "ViewController.h"
#import "JSCCoreMLWrapper.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *resultTV;
@property (weak, nonatomic) IBOutlet UIButton *recognizeBtn;
@property (weak, nonatomic) IBOutlet UIImageView *imgView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.imgView setImage:[UIImage imageNamed:@"person"]];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)onRecognizeAction:(id)sender {
    NSString *modelName = [@[@"gender_net",@"age_net"] objectAtIndex:arc4random()%2];
    [self.resultTV setText:@""];
    [self.loadingView startAnimating];
    [self.recognizeBtn setHidden:YES];
    NSString *imgPath = [[NSBundle mainBundle] pathForResource:@"person" ofType:@"png"];
    JSCCoreMLWrapper *wrapper = [JSCCoreMLWrapper wrapperWithModel:modelName type:JSCCoreMLTypeImg inputs:@[imgPath]];
    NSString *result = [wrapper recognize];
    [self.resultTV setText:result];
    [self.loadingView stopAnimating];
    [self.recognizeBtn setHidden:NO];
}
@end
