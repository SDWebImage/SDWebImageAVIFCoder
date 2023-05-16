//
//  SDViewController.m
//  SDWebImageAVIFCoder
//
//  Created by lizhuoli1126@126.com on 04/14/2019.
//  Copyright (c) 2019 lizhuoli1126@126.com. All rights reserved.
//

#import "SDViewController.h"
#import <SDWebImage/SDWebImage.h>
#import <SDWebImageAVIFCoder/SDImageAVIFCoder.h>

@interface SDViewController ()

@end

@implementation SDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    SDImageAVIFCoder *AVIFCoder = [SDImageAVIFCoder sharedCoder];
    [[SDImageCodersManager sharedManager] addCoder:AVIFCoder];
    NSURL *AVIFURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/link-u/avif-sample-images/master/fox.profile0.8bpc.yuv420.avif"];
//    NSURL *HDRAVIFURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/link-u/avif-sample-images/master/hato.profile2.12bpc.yuv422.avif"];
    NSURL *animatedAVIFSURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/link-u/avif-sample-images/master/star-12bpc-with-alpha.avifs"];
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    UIImageView *imageView1 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, screenSize.height / 2)];
    SDAnimatedImageView *imageView2 = [[SDAnimatedImageView alloc] initWithFrame:CGRectMake(0, screenSize.height / 2, screenSize.width, screenSize.height / 2)];
    
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
    CGSize animatedThumbnailSize = CGSizeMake(100, 100);
    [imageView2 sd_setImageWithURL:animatedAVIFSURL placeholderImage:nil options:0 context:@{SDWebImageContextImageThumbnailPixelSize : @(animatedThumbnailSize)} progress:nil completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        NSCAssert(image.size.width == 100, @"Thumbnail width should be 100");
        NSCAssert(image.size.height == 100, @"Thumbnail height should be 100");
        if (image) {
            NSLog(@"Animated AVIFS load success");
        }
    }];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
