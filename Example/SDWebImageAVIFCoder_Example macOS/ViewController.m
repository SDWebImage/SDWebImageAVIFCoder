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
    NSURL *AVIFURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/link-u/avif-sample-images/master/fox.profile0.8bpc.yuv420.avif"];
//    NSURL *HDRAVIFURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/link-u/avif-sample-images/master/hato.profile2.12bpc.yuv422.avif"];
    NSURL *animatedAVIFSURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/link-u/avif-sample-images/master/star-12bpc-with-alpha.avifs"];
    
    CGSize screenSize = self.view.bounds.size;
    
    UIImageView *imageView1 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width / 2, screenSize.height)];
    imageView1.imageScaling = NSImageScaleProportionallyUpOrDown;
    
    SDAnimatedImageView *imageView2 = [[SDAnimatedImageView alloc] initWithFrame:CGRectMake(screenSize.width / 2, 0, screenSize.width / 2, screenSize.height)];
    imageView2.imageScaling = NSImageScaleProportionallyUpOrDown;
    
    [self.view addSubview:imageView1];
    [self.view addSubview:imageView2];
    
    [imageView1 sd_setImageWithURL:AVIFURL completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        if (image) {
            NSLog(@"Static AVIF load success");
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSData *avifData = [SDImageAVIFCoder.sharedCoder encodedDataWithImage:image format:SDImageFormatAVIF options:nil];
                if (avifData) {
                    NSLog(@"Static AVIF encode success");
                }
            });
        }
    }];
    [imageView2 sd_setImageWithURL:animatedAVIFSURL completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        if (image) {
            NSLog(@"Animated AVIFS load success");
        }
    }];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}


@end
