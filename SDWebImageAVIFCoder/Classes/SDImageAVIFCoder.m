//
//  SDImageAVIFCoder.m
//  SDWebImageAVIFCoder
//
//  Created by lizhuoli on 2018/5/8.
//

#import "SDImageAVIFCoder.h"
#import <Accelerate/Accelerate.h>
#import <os/lock.h>
#import <libkern/OSAtomic.h>
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#import <libavif/internal.h>
#else
#import "avif/avif.h"
#import "avif/internal.h"
#endif

#import "Private/Conversion.h"

#define SD_USE_OS_UNFAIR_LOCK TARGET_OS_MACCATALYST ||\
    (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_10_0) ||\
    (__MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_12) ||\
    (__TV_OS_VERSION_MIN_REQUIRED >= __TVOS_10_0) ||\
    (__WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_3_0)

#ifndef SD_LOCK_DECLARE
#if SD_USE_OS_UNFAIR_LOCK
#define SD_LOCK_DECLARE(lock) os_unfair_lock lock
#else
#define SD_LOCK_DECLARE(lock) os_unfair_lock lock API_AVAILABLE(ios(10.0), tvos(10), watchos(3), macos(10.12)); \
OSSpinLock lock##_deprecated;
#endif
#endif

#ifndef SD_LOCK_INIT
#if SD_USE_OS_UNFAIR_LOCK
#define SD_LOCK_INIT(lock) lock = OS_UNFAIR_LOCK_INIT
#else
#define SD_LOCK_INIT(lock) if (@available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *)) lock = OS_UNFAIR_LOCK_INIT; \
else lock##_deprecated = OS_SPINLOCK_INIT;
#endif
#endif

#ifndef SD_LOCK
#if SD_USE_OS_UNFAIR_LOCK
#define SD_LOCK(lock) os_unfair_lock_lock(&lock)
#else
#define SD_LOCK(lock) if (@available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *)) os_unfair_lock_lock(&lock); \
else OSSpinLockLock(&lock##_deprecated);
#endif
#endif

#ifndef SD_UNLOCK
#if SD_USE_OS_UNFAIR_LOCK
#define SD_UNLOCK(lock) os_unfair_lock_unlock(&lock)
#else
#define SD_UNLOCK(lock) if (@available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *)) os_unfair_lock_unlock(&lock); \
else OSSpinLockUnlock(&lock##_deprecated);
#endif
#endif

@implementation SDImageAVIFCoder {
    avifDecoder *_decoder;
    NSData *_imageData;
    CGFloat _scale;
    NSUInteger _loopCount;
    NSUInteger _frameCount;
    SD_LOCK_DECLARE(_lock);
}

- (void)dealloc {
    if (_decoder) {
        avifDecoderDestroy(_decoder);
    }
}

+ (instancetype)sharedCoder {
    static SDImageAVIFCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[SDImageAVIFCoder alloc] init];
    });
    return coder;
}

- (BOOL)canDecodeFromData:(NSData *)data {
    return [[self class] isAVIFFormatForData:data];
}

- (UIImage *)decodedImageWithData:(NSData *)data options:(SDImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    CGFloat scale = 1;
    if ([options valueForKey:SDImageCoderDecodeScaleFactor]) {
        scale = [[options valueForKey:SDImageCoderDecodeScaleFactor] doubleValue];
        if (scale < 1) {
            scale = 1;
        }
    }
    
    // Decode it
    avifDecoder * decoder = avifDecoderCreate();
    avifDecoderSetIOMemory(decoder, data.bytes, data.length);
    // Disable strict mode to keep some AVIF image compatible
    decoder->strictFlags = AVIF_STRICT_DISABLED;
    avifResult decodeResult = avifDecoderParse(decoder);
    if (decodeResult != AVIF_RESULT_OK) {
        NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
        avifDecoderDestroy(decoder);
        return nil;
    }
    
    // Static image
    if (decoder->imageCount <= 1) {
        avifResult nextImageResult = avifDecoderNextImage(decoder);
        if (nextImageResult != AVIF_RESULT_OK) {
            NSLog(@"Failed to decode image: %s", avifResultToString(nextImageResult));
            avifDecoderDestroy(decoder);
            return nil;
        }
        CGImageRef imageRef = SDCreateCGImageFromAVIF(decoder->image);
        if (!imageRef) {
            avifDecoderDestroy(decoder);
            return nil;
        }
    #if SD_MAC
        UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:kCGImagePropertyOrientationUp];
    #else
        UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
    #endif
        CGImageRelease(imageRef);
        avifDecoderDestroy(decoder);
        return image;
    }
    
    // Animated image
    NSMutableArray<SDImageFrame *> *frames = [NSMutableArray array];
    while (avifDecoderNextImage(decoder) == AVIF_RESULT_OK) {
        @autoreleasepool {
            CGImageRef imageRef = SDCreateCGImageFromAVIF(decoder->image);
            if (!imageRef) {
                continue;
            }
#if SD_MAC
            UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:kCGImagePropertyOrientationUp];
#else
            UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
#endif
            NSTimeInterval duration = decoder->imageTiming.duration; // Should use `decoder->imageTiming`, not the `decoder->duration`, see libavif source code
            SDImageFrame *frame = [SDImageFrame frameWithImage:image duration:duration];
            [frames addObject:frame];
        }
    }
    
    avifDecoderDestroy(decoder);
    
    UIImage *animatedImage = [SDImageCoderHelper animatedImageWithFrames:frames];
    animatedImage.sd_imageLoopCount = 0;
    animatedImage.sd_imageFormat = SDImageFormatAVIF;
    
    return animatedImage;
}

// The AVIF encoding seems slow at the current time, but at least works
- (BOOL)canEncodeToFormat:(SDImageFormat)format {
    return format == SDImageFormatAVIF;
}

- (nullable NSData *)encodedDataWithImage:(nullable UIImage *)image format:(SDImageFormat)format options:(nullable SDImageCoderOptions *)options {
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        return nil;
    }
    
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    size_t bitsPerPixel = CGImageGetBitsPerPixel(imageRef);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                      alphaInfo == kCGImageAlphaNoneSkipFirst ||
                      alphaInfo == kCGImageAlphaNoneSkipLast);
    
    vImageConverterRef convertor = NULL;
    vImage_Error v_error = kvImageNoError;
    
    vImage_CGImageFormat srcFormat = {
        .bitsPerComponent = (uint32_t)bitsPerComponent,
        .bitsPerPixel = (uint32_t)bitsPerPixel,
        .colorSpace = CGImageGetColorSpace(imageRef),
        .bitmapInfo = bitmapInfo,
        .renderingIntent = CGImageGetRenderingIntent(imageRef)
    };
    vImage_CGImageFormat destFormat = {
        .bitsPerComponent = 8,
        .bitsPerPixel = hasAlpha ? 32 : 24,
        .colorSpace = [SDImageCoderHelper colorSpaceGetDeviceRGB],
        .bitmapInfo = hasAlpha ? kCGImageAlphaFirst | kCGBitmapByteOrderDefault : kCGImageAlphaNone | kCGBitmapByteOrderDefault // RGB888/ARGB8888 (Non-premultiplied to works for libavif)
    };
    
    convertor = vImageConverter_CreateWithCGImageFormat(&srcFormat, &destFormat, NULL, kvImageNoFlags, &v_error);
    if (v_error != kvImageNoError) {
        return nil;
    }
    
    vImage_Buffer src;
    v_error = vImageBuffer_InitWithCGImage(&src, &srcFormat, NULL, imageRef, kvImageNoFlags);
    if (v_error != kvImageNoError) {
        return nil;
    }
    vImage_Buffer dest;
    vImageBuffer_Init(&dest, height, width, hasAlpha ? 32 : 24, kvImageNoFlags);
    if (!dest.data) {
        free(src.data);
        return nil;
    }
    
    // Convert input color mode to RGB888/ARGB8888
    v_error = vImageConvert_AnyToAny(convertor, &src, &dest, NULL, kvImageNoFlags);
    free(src.data);
    vImageConverter_Release(convertor);
    if (v_error != kvImageNoError) {
        free(dest.data);
        return nil;
    }
    
    avifPixelFormat avifFormat = AVIF_PIXEL_FORMAT_YUV444;

    avifImage *avif = avifImageCreate((int)width, (int)height, 8, avifFormat);
    if (!avif) {
        free(dest.data);
        return nil;
    }
    avifRGBImage rgb = {
        .width = (uint32_t)width,
        .height = (uint32_t)height,
        .depth = 8,
        .format = hasAlpha ? AVIF_RGB_FORMAT_ARGB : AVIF_RGB_FORMAT_RGB,
        .pixels = dest.data,
        .rowBytes = (uint32_t)dest.rowBytes,
    };
    avifImageRGBToYUV(avif, &rgb);
    free(dest.data);
    dest.data = NULL;

    NSData *iccProfile = (__bridge_transfer NSData *)CGColorSpaceCopyICCProfile([SDImageCoderHelper colorSpaceGetDeviceRGB]);
    
    avifImageSetProfileICC(avif, (uint8_t *)iccProfile.bytes, iccProfile.length);
    
    double compressionQuality = 1;
    if (options[SDImageCoderEncodeCompressionQuality]) {
        compressionQuality = [options[SDImageCoderEncodeCompressionQuality] doubleValue];
    }
    int rescaledQuality = AVIF_QUANTIZER_WORST_QUALITY - (int)((compressionQuality) * AVIF_QUANTIZER_WORST_QUALITY);
    
    avifRWData raw = AVIF_DATA_EMPTY;
    avifEncoder *encoder = avifEncoderCreate();
    encoder->minQuantizer = rescaledQuality;
    encoder->maxQuantizer = rescaledQuality;
    encoder->maxThreads = 2;
    avifResult result = avifEncoderWrite(encoder, avif, &raw);
    
    if (result != AVIF_RESULT_OK) {
        avifEncoderDestroy(encoder);
        return nil;
    }
    
    NSData *imageData = [NSData dataWithBytes:raw.data length:raw.size];
    free(raw.data);
    avifEncoderDestroy(encoder);
    
    return imageData;
}

#pragma mark - Animation
- (instancetype)initWithAnimatedImageData:(NSData *)data options:(SDImageCoderOptions *)options {
    self = [super init];
    if (self) {
        avifDecoder *decoder = avifDecoderCreate();
        avifDecoderSetIOMemory(decoder, data.bytes, data.length);
        // Disable strict mode to keep some AVIF image compatible
        decoder->strictFlags = AVIF_STRICT_DISABLED;
        avifResult decodeResult = avifDecoderParse(decoder);
        if (decodeResult != AVIF_RESULT_OK) {
            avifDecoderDestroy(decoder);
            NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
            return nil;
        }
        // TODO: Optimize the performance like WebPCoder (frame meta cache, etc)
        _frameCount = decoder->imageCount;
        _loopCount = 0;
        CGFloat scale = 1;
        NSNumber *scaleFactor = options[SDImageCoderDecodeScaleFactor];
        if (scaleFactor != nil) {
            scale = [scaleFactor doubleValue];
            if (scale < 1) {
                scale = 1;
            }
        }
        _scale = scale;
        _decoder = decoder;
        _imageData = data;
        SD_LOCK_INIT(_lock);
    }
    return self;
}

- (NSData *)animatedImageData {
    return _imageData;
}

- (NSUInteger)animatedImageLoopCount {
    return _loopCount;
}

- (NSUInteger)animatedImageFrameCount {
    return _frameCount;
}

- (NSTimeInterval)animatedImageDurationAtIndex:(NSUInteger)index {
    if (index >= _frameCount) {
        return 0;
    }
    if (_frameCount <= 1) {
        return 0;
    }
    SD_LOCK(_lock);
    avifImageTiming timing;
    avifResult decodeResult = avifDecoderNthImageTiming(_decoder, (uint32_t)index, &timing);
    SD_UNLOCK(_lock);
    if (decodeResult != AVIF_RESULT_OK) {
        return 0;
    }
    return timing.duration;
}

- (UIImage *)animatedImageFrameAtIndex:(NSUInteger)index {
    if (index >= _frameCount) {
        return nil;
    }
    SD_LOCK(_lock);
    avifResult decodeResult = avifDecoderNthImage(_decoder, (uint32_t)index);
    if (decodeResult != AVIF_RESULT_OK) {
        return nil;
    }
    CGImageRef imageRef = SDCreateCGImageFromAVIF(_decoder->image);
    SD_UNLOCK(_lock);
    if (!imageRef) {
        return nil;
    }
#if SD_MAC
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:_scale orientation:kCGImagePropertyOrientationUp];
#else
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:_scale orientation:UIImageOrientationUp];
#endif
    CGImageRelease(imageRef);
    return image;
}


#pragma mark - Helper
+ (BOOL)isAVIFFormatForData:(NSData *)data
{
    if (!data) {
        return NO;
    }
    if (data.length >= 12) {
        //....ftypavif ....ftypavis
        NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(4, 8)] encoding:NSASCIIStringEncoding];
        if ([testString isEqualToString:@"ftypavif"]
            || [testString isEqualToString:@"ftypavis"]) {
            return YES;
        }
    }
    
    return NO;
}

@end
