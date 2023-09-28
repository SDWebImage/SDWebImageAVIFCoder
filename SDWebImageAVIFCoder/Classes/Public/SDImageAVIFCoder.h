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

/// A `avifCodecChoice` enum which specify the custom codec for AVIF decoding, defaults to 0 (`AVIF_CODEC_CHOICE_AUTO`)
FOUNDATION_EXPORT SDImageCoderOption _Nonnull const SDImageCoderAVIFDecodeCodecChoice;

/// A `avifCodecChoice` enum which specify the custom codec for AVIF encoding, defaults to 0 (`AVIF_CODEC_CHOICE_AUTO`)
FOUNDATION_EXPORT SDImageCoderOption _Nonnull const SDImageCoderAVIFEncodeCodecChoice;

/// Supports AVIF static image and AVIFS animated image
@interface SDImageAVIFCoder : NSObject <SDAnimatedImageCoder>

@property (nonatomic, class, readonly, nonnull) SDImageAVIFCoder *sharedCoder;

@end
