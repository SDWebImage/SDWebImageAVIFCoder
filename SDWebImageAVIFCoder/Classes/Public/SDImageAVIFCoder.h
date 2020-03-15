//
//  SDImageAVIFCoder.h
//  SDWebImageHEIFCoder
//
//  Created by lizhuoli on 2018/5/8.
//

#if __has_include(<SDWebImage/SDWebImage.h>)
#import <SDWebImage/SDWebImage.h>
#else
@import SDWebImage;
#endif

static const SDImageFormat SDImageFormatAVIF = 15; // AV1-codec based HEIF

@interface SDImageAVIFCoder : NSObject <SDImageCoder>

@property (nonatomic, class, readonly, nonnull) SDImageAVIFCoder *sharedCoder;

@end
