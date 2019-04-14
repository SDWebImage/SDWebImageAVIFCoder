//
//  ViewController.m
//  SDWebImageAVIFCoder_Example macOS
//
//  Created by lizhuoli on 2019/4/14.
//  Copyright © 2019 lizhuoli1126@126.com. All rights reserved.
//

#import "ViewController.h"
#import <SDWebImage/SDWebImage.h>
#import <SDWebImageAVIFCoder/SDImageAVIFCoder.h>

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    SDImageAVIFCoder *AVIFCoder = [SDImageAVIFCoder sharedCoder];
    [[SDImageCodersManager sharedManager] addCoder:AVIFCoder];
    NSURL *AVIFURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/AOMediaCodec/av1-avif/master/testFiles/Microsoft/kids_720p.avif"];
    NSURL *HDRAVIFURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/AOMediaCodec/av1-avif/master/testFiles/Microsoft/Chimera_10bit_cropped_to_1920x1008.avif"];
    
    CGSize screenSize = self.view.bounds.size;
    
    UIImageView *imageView1 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width / 2, screenSize.height)];
    imageView1.imageScaling = NSImageScaleProportionallyUpOrDown;
    
    UIImageView *imageView2 = [[UIImageView alloc] initWithFrame:CGRectMake(screenSize.width / 2, 0, screenSize.width / 2, screenSize.height)];
    imageView2.imageScaling = NSImageScaleProportionallyUpOrDown;
    
    [self.view addSubview:imageView1];
    [self.view addSubview:imageView2];
    
    [imageView1 sd_setImageWithURL:AVIFURL completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        if (image) {
            NSLog(@"Static AVIF load success");
        }
    }];
    [imageView2 sd_setImageWithURL:HDRAVIFURL completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        // 10-bit HDR
        if (image) {
            NSLog(@"HDR AVIF load success");
        }
    }];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}


@end
