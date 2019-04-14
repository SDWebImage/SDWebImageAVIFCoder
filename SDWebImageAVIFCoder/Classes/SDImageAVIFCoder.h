//
//  SDImageAVIFCoder.h
//  SDWebImageHEIFCoder
//
//  Created by lizhuoli on 2018/5/8.
//

#import <SDWebImage/SDWebImage.h>

static const SDImageFormat SDImageFormatAVIF = 15; // AV1-codec based HEIF

@interface SDImageAVIFCoder : NSObject <SDImageCoder>

@property (nonatomic, class, readonly, nonnull) SDImageAVIFCoder *sharedCoder;

@end
