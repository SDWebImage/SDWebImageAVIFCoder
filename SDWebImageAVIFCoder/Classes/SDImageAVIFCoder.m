//
//  SDImageAVIFCoder.m
//  SDWebImageHEIFCoder
//
//  Created by lizhuoli on 2018/5/8.
//

#include <alloca.h>
#import "SDImageAVIFCoder.h"
#import <Accelerate/Accelerate.h>
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif.h"
#endif

// Convert 8bit AVIF image into RGB888/ARGB8888 using vImage Acceralation Framework.
static void ConvertAvifImagePlanar8ToRGB8(avifImage * avif, uint8_t * outPixels) {
    vImage_Error err = kvImageNoError;
    BOOL hasAlpha = avif->alphaPlane != NULL;
    size_t components = hasAlpha ? 4 : 3;
    
    uint8_t* intermediateBuffer = NULL;

    if(!hasAlpha) {
        intermediateBuffer = calloc(avif->width * avif->height * 4, sizeof(uint8_t));
        if(!intermediateBuffer) {
            return;
        }
    }

    vImage_Buffer dstBuffer = {
        .data = hasAlpha ? outPixels : intermediateBuffer,
        .width = avif->width,
        .height = avif->height,
        .rowBytes = avif->width * 4,
    };

    avifReformatState state;
    avifPrepareReformatState(avif, &state);

    vImage_Buffer origY = {
        .data = avif->yuvPlanes[AVIF_CHAN_Y],
        .rowBytes = avif->yuvRowBytes[AVIF_CHAN_Y],
        .width = avif->width,
        .height = avif->height,
    };

    vImage_Buffer origCb = {
        .data = avif->yuvPlanes[AVIF_CHAN_U],
        .rowBytes = avif->yuvRowBytes[AVIF_CHAN_U],
        .width = avif->width >> state.formatInfo.chromaShiftX,
        .height = avif->height >> state.formatInfo.chromaShiftY,
    };

    if(!origCb.data) { // allocate dummy data to convert monochrome images.
        origCb.data = alloca(origCb.width * sizeof(uint8_t));
        origCb.rowBytes = 0;
        memset(origCb.data, 128, origCb.width);
    }
    vImage_Buffer origCr = {
        .data = avif->yuvPlanes[AVIF_CHAN_V],
        .rowBytes = avif->yuvRowBytes[AVIF_CHAN_V],
        .width = avif->width >> state.formatInfo.chromaShiftX,
        .height = avif->height >> state.formatInfo.chromaShiftY,
    };
    if(!origCr.data) { // allocate dummy data to convert monochrome images.
        origCr.data = alloca(origCr.width * sizeof(uint8_t));
        origCr.rowBytes = 0;
        memset(origCr.data, 128, origCr.width);
    }
        
    vImage_YpCbCrToARGBMatrix matrix = {0};
    matrix.Yp = 1.0f;
    matrix.Cr_R = 2.0f * (1.0f - state.kr);
    matrix.Cb_B = 2.0f * (1.0f - state.kb);
    matrix.Cb_G = -2.0f * (1.0f - state.kr) * state.kr / state.kg;
    matrix.Cr_G = -2.0f * (1.0f - state.kb) * state.kb / state.kg;
    
    vImage_YpCbCrPixelRange pixelRange = {0};
    switch (avif->depth) {
        case 8:
            if (avif->yuvRange == AVIF_RANGE_LIMITED) {
                pixelRange.Yp_bias = 16;
                pixelRange.YpRangeMax = 235;
                pixelRange.YpMax = 255;
                pixelRange.YpMin = 0;
                pixelRange.CbCr_bias = 128;
                pixelRange.CbCrRangeMax = 240;
                pixelRange.CbCrMax = 255;
                pixelRange.CbCrMin = 0;
            }else{
                pixelRange.Yp_bias = 0;
                pixelRange.YpRangeMax = 255;
                pixelRange.YpMax = 255;
                pixelRange.YpMin = 0;
                pixelRange.CbCr_bias = 128;
                pixelRange.CbCrRangeMax = 255;
                pixelRange.CbCrMax = 255;
                pixelRange.CbCrMin = 0;
            }
            break;
        /*
        case 10: // FIXME(ledyba-z): Support acceleration also on 10bit images.
            if (avif->yuvRange == AVIF_RANGE_LIMITED) {
                pixelRange.Yp_bias = 64;
                pixelRange.YpRangeMax = 940;
                pixelRange.YpMax = 1023;
                pixelRange.YpMin = 0;
                pixelRange.CbCr_bias = 512;
                pixelRange.CbCrRangeMax = 960;
                pixelRange.CbCrMax = 1023;
                pixelRange.CbCrMin = 0;
            }else{
                pixelRange.Yp_bias = 0;
                pixelRange.YpRangeMax = 1023;
                pixelRange.YpMax = 1023;
                pixelRange.YpMin = 0;
                pixelRange.CbCr_bias = 512;
                pixelRange.CbCrRangeMax = 1023;
                pixelRange.CbCrMax = 1023;
                pixelRange.CbCrMin = 0;
            }
            break;
        case 12: // FIXME(ledyba-z): Support acceleration also on 12bit images.
            if (avif->yuvRange == AVIF_RANGE_LIMITED) {
                pixelRange.Yp_bias = 256;
                pixelRange.YpRangeMax = 3760;
                pixelRange.YpMax = 4095;
                pixelRange.YpMin = 0;
                pixelRange.CbCr_bias = 2048;
                pixelRange.CbCrRangeMax = 3840;
                pixelRange.CbCrMax = 4095;
                pixelRange.CbCrMin = 0;
            }else{
                pixelRange.Yp_bias = 0;
                pixelRange.YpRangeMax = 4095;
                pixelRange.YpMax = 4095;
                pixelRange.YpMin = 0;
                pixelRange.CbCr_bias = 2048;
                pixelRange.CbCrRangeMax = 4095;
                pixelRange.CbCrMax = 4095;
                pixelRange.CbCrMin = 0;
            }
            break;
        */
        default:
            free(intermediateBuffer);
            NSLog(@"Unknown bit depth: %d", avif->depth);
            return;
    }
    
    vImage_YpCbCrToARGB convInfo = {0};
    
    uint8_t const permuteMap[4] = {0, 1, 2, 3};
    switch(avif->yuvFormat) {
        case AVIF_PIXEL_FORMAT_NONE:
            free(intermediateBuffer);
            NSLog(@"Invalid pixel format.");
            return;
        case AVIF_PIXEL_FORMAT_YUV420:
        case AVIF_PIXEL_FORMAT_YV12:
        {
            err =
            vImageConvert_YpCbCrToARGB_GenerateConversion(&matrix,
                                                          &pixelRange,
                                                          &convInfo,
                                                          kvImage420Yp8_Cb8_Cr8,
                                                          kvImageARGB8888,
                                                          kvImageNoFlags);
            if(err != kvImageNoError) {
                free(intermediateBuffer);
                NSLog(@"Failed to setup conversion: %ld", err);
                return;
            }
                    
            err = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&origY,
                                                         &origCb,
                                                         &origCr,
                                                         &dstBuffer,
                                                         &convInfo,
                                                         permuteMap,
                                                         255,
                                                         kvImageNoFlags);
            if(err != kvImageNoError) {
                free(intermediateBuffer);
                NSLog(@"Failed to convert to ARGB8888: %ld", err);
                return;
            }
            break;
        }
        case AVIF_PIXEL_FORMAT_YUV444:
        {
            err =
            vImageConvert_YpCbCrToARGB_GenerateConversion(&matrix,
                                                          &pixelRange,
                                                          &convInfo,
                                                          kvImage444CrYpCb8,
                                                          kvImageARGB8888,
                                                          kvImageNoFlags);
            if(err != kvImageNoError) {
                free(intermediateBuffer);
                NSLog(@"Failed to setup conversion: %ld", err);
                return;
            }

            vImage_Buffer tmpBuffer = {
                .data = calloc(avif->width * avif->height * 3, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * 3,
            };
            if(!tmpBuffer.data) {
                free(intermediateBuffer);
                return;
            }
            err = vImageConvert_Planar8toRGB888(&origCr, &origY, &origCb, &tmpBuffer, kvImageNoFlags);
            if(err != kvImageNoError) {
                NSLog(@"Failed to composite kvImage444CrYpCb8: %ld", err);
                free(intermediateBuffer);
                free(tmpBuffer.data);
                return;
            }
            vImageConvert_444CrYpCb8ToARGB8888(&tmpBuffer,
                                               &dstBuffer,
                                               &convInfo,
                                               permuteMap,
                                               255,
                                               kvImageNoFlags);
            free(intermediateBuffer);
            free(tmpBuffer.data);
            if(err != kvImageNoError) {
                NSLog(@"Failed to convert to ARGB8888: %ld", err);
                return;
            }
            break;
        }
        case AVIF_PIXEL_FORMAT_YUV422:
        {
            err =
            vImageConvert_YpCbCrToARGB_GenerateConversion(&matrix,
                                                          &pixelRange,
                                                          &convInfo,
                                                          kvImage422YpCbYpCr8,
                                                          kvImageARGB8888,
                                                          kvImageNoFlags);
            if(err != kvImageNoError) {
                NSLog(@"Failed to setup conversion: %ld", err);
                return;
            }

            vImage_Buffer tmpY1 = {
                .data = calloc(avif->width/2 * avif->height, sizeof(uint8_t)),
                .width = avif->width/2,
                .height = avif->height,
                .rowBytes = avif->width/2,
            };
            if(!tmpY1.data) {
                free(intermediateBuffer);
                return;
            }
            vImage_Buffer tmpY2 = {
                .data = calloc(avif->width/2 * avif->height, sizeof(uint8_t)),
                .width = avif->width/2,
                .height = avif->height,
                .rowBytes = avif->width/2,
            };
            if(!tmpY2.data) {
                free(intermediateBuffer);
                free(tmpY1.data);
                return;
            }
            err= vImageConvert_ChunkyToPlanar8((const void*[]){origY.data, origY.data+1},
                                               (const vImage_Buffer*[]){&tmpY1, &tmpY2},
                                               2 /* channelCount */,2 /* src srcStrideBytes */,
                                               avif->width/2, avif->height,
                                               avif->width, kvImageNoFlags);
            if(err != kvImageNoError) {
                NSLog(@"Failed to separate Y channel: %ld", err);
                free(intermediateBuffer);
                free(tmpY1.data);
                free(tmpY2.data);
                return;
            }
            vImage_Buffer tmpBuffer = {
                .data = calloc(avif->width * avif->height * 2, sizeof(uint8_t)),
                .width = avif->width/2,
                .height = avif->height,
                .rowBytes = avif->width * 2,
            };
            if(!tmpBuffer.data) {
                free(intermediateBuffer);
                free(tmpY1.data);
                free(tmpY2.data);
                return;
            }
            err = vImageConvert_Planar8toARGB8888(&tmpY1, &origCb, &tmpY2, &origCr,
                                                  &tmpBuffer, kvImageNoFlags);
            if(err != kvImageNoError) {
                NSLog(@"Failed to composite kvImage422YpCbYpCr8: %ld", err);
                free(intermediateBuffer);
                free(tmpY1.data);
                free(tmpY2.data);
                free(tmpBuffer.data);
                return;
            }
            tmpBuffer.width *= 2;

            err = vImageConvert_422YpCbYpCr8ToARGB8888(&tmpBuffer,
                                                       &dstBuffer,
                                                       &convInfo,
                                                       permuteMap,
                                                       255,
                                                       kvImageNoFlags);
            free(intermediateBuffer);
            free(tmpY1.data);
            free(tmpY2.data);
            free(tmpBuffer.data);
            if(err != kvImageNoError) {
                NSLog(@"Failed to convert to ARGB8888: %ld", err);
                return;
            }
            break;
        }
    }

    if(hasAlpha) {
        vImage_Buffer alpha = {
            .data = avif->alphaPlane,
            .width = avif->width,
            .height = avif->height,
            .rowBytes = avif->alphaRowBytes,
        };
        err = vImageOverwriteChannels_ARGB8888(&alpha, &dstBuffer, &dstBuffer, 0x8, kvImageNoFlags);
        if(err != kvImageNoError) {
            NSLog(@"Failed to overwrite alpha: %ld", err);
            return;
        }
    } else {
        vImage_Buffer outBuffer = {
            .data = outPixels,
            .width = avif->width,
            .height = avif->height,
            .rowBytes = avif->width * components,
        };
        err = vImageConvert_ARGB8888toRGB888(&dstBuffer, &outBuffer, kvImageNoFlags);
        free(intermediateBuffer);
        if(err != kvImageNoError) {
            NSLog(@"Failed to convert ARGB to RGB: %ld", err);
            return;
        }
    }

    
}

// Convert 10/12bit AVIF image into RGB888/ARGB8888
static void ConvertAvifImagePlanar16ToRGB8(avifImage * avif, uint8_t * outPixels) {
    BOOL hasAlpha = avif->alphaPlane != NULL;
    size_t components = hasAlpha ? 4 : 3;
    float maxChannel = (float)((1 << avif->depth) - 1);
    for (int j = 0; j < avif->height; ++j) {
        for (int i = 0; i < avif->width; ++i) {
            uint8_t * pixel = &outPixels[components * (i + (j * avif->width))];
            uint16_t r = *((uint16_t *)&avif->rgbPlanes[AVIF_CHAN_R][(i * 2) + (j * avif->rgbRowBytes[AVIF_CHAN_R])]);
            uint16_t g = *((uint16_t *)&avif->rgbPlanes[AVIF_CHAN_G][(i * 2) + (j * avif->rgbRowBytes[AVIF_CHAN_G])]);
            uint16_t b = *((uint16_t *)&avif->rgbPlanes[AVIF_CHAN_B][(i * 2) + (j * avif->rgbRowBytes[AVIF_CHAN_B])]);
            pixel[0] = (uint8_t)roundf((r / maxChannel) * 255.0f);
            pixel[1] = (uint8_t)roundf((g / maxChannel) * 255.0f);
            pixel[2] = (uint8_t)roundf((b / maxChannel) * 255.0f);
            if (hasAlpha) {
                uint16_t a = *((uint16_t *)&avif->alphaPlane[(i * 2) + (j * avif->alphaRowBytes)]);
                pixel[3] = (uint8_t)roundf((a / maxChannel) * 255.0f);
            }
        }
    }
}

static void FillRGBABufferWithAVIFImage(vImage_Buffer *red, vImage_Buffer *green, vImage_Buffer *blue, vImage_Buffer *alpha, avifImage *img) {
    red->width = img->width;
    red->height = img->height;
    red->data = img->rgbPlanes[AVIF_CHAN_R];
    red->rowBytes = img->rgbRowBytes[AVIF_CHAN_R];
    
    green->width = img->width;
    green->height = img->height;
    green->data = img->rgbPlanes[AVIF_CHAN_G];
    green->rowBytes = img->rgbRowBytes[AVIF_CHAN_G];
    
    blue->width = img->width;
    blue->height = img->height;
    blue->data = img->rgbPlanes[AVIF_CHAN_B];
    blue->rowBytes = img->rgbRowBytes[AVIF_CHAN_B];
    
    if (img->alphaPlane != NULL) {
        alpha->width = img->width;
        alpha->height = img->height;
        alpha->data = img->alphaPlane;
        alpha->rowBytes = img->alphaRowBytes;
    }
}

static void FreeImageData(void *info, const void *data, size_t size) {
    free((void *)data);
}

@implementation SDImageAVIFCoder

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
    
    // Currently only support primary image :)
    CGImageRef imageRef = [self sd_createAVIFImageWithData:data];
    if (!imageRef) {
        return nil;
    }
    
#if SD_MAC
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:kCGImagePropertyOrientationUp];
#else
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
#endif
    CGImageRelease(imageRef);
    
    return image;
}

- (nullable CGImageRef)sd_createAVIFImageWithData:(nonnull NSData *)data CF_RETURNS_RETAINED {
    // Decode it
    avifROData rawData = {
        .data = (uint8_t *)data.bytes,
        .size = data.length
    };
    avifImage * avif = avifImageCreateEmpty();
    avifDecoder *decoder = avifDecoderCreate();
    avifResult result = avifDecoderRead(decoder, avif, &rawData);
    if (result != AVIF_RESULT_OK) {
        avifDecoderDestroy(decoder);
        avifImageDestroy(avif);
        return nil;
    }
    
    int width = avif->width;
    int height = avif->height;
    BOOL hasAlpha = avif->alphaPlane != NULL;
    size_t components = hasAlpha ? 4 : 3;
    size_t bitsPerComponent = 8;
    size_t bitsPerPixel = components * bitsPerComponent;
    size_t rowBytes = width * bitsPerPixel / 8;
    
    uint8_t * dest = calloc(width * components * height, sizeof(uint8_t));
    if (!dest) {
        avifDecoderDestroy(decoder);
        avifImageDestroy(avif);
        return nil;
    }
    // convert planar to ARGB8888/RGB888
    if(avifImageUsesU16(avif)) { // 10bit or 12bit (using normal CPU convert functions)
        avifImageYUVToRGB(avif);
        ConvertAvifImagePlanar16ToRGB8(avif, dest);
    } else { //8bit (using vImage Acceralation Framework)
        ConvertAvifImagePlanar8ToRGB8(avif, dest);
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, dest, rowBytes * height, FreeImageData);
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNone;
    CGColorSpaceRef colorSpaceRef = [SDImageCoderHelper colorSpaceGetDeviceRGB];
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef imageRef = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, rowBytes, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    // clean up
    CGDataProviderRelease(provider);
    avifDecoderDestroy(decoder);
    avifImageDestroy(avif);
    
    return imageRef;
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
    CGBitmapInfo byteOrderInfo = bitmapInfo & kCGBitmapByteOrderMask;
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                      alphaInfo == kCGImageAlphaNoneSkipFirst ||
                      alphaInfo == kCGImageAlphaNoneSkipLast);
    BOOL byteOrderNormal = NO;
    switch (byteOrderInfo) {
        case kCGBitmapByteOrderDefault: {
            byteOrderNormal = YES;
        } break;
        case kCGBitmapByteOrder32Little: {
        } break;
        case kCGBitmapByteOrder32Big: {
            byteOrderNormal = YES;
        } break;
        default: break;
    }
    
    vImageConverterRef convertor = NULL;
    vImage_Error v_error = kvImageNoError;
    
    vImage_CGImageFormat srcFormat = {
        .bitsPerComponent = (uint32_t)bitsPerComponent,
        .bitsPerPixel = (uint32_t)bitsPerPixel,
        .colorSpace = CGImageGetColorSpace(imageRef),
        .bitmapInfo = bitmapInfo
    };
    vImage_CGImageFormat destFormat = {
        .bitsPerComponent = 8,
        .bitsPerPixel = hasAlpha ? 32 : 24,
        .colorSpace = [SDImageCoderHelper colorSpaceGetDeviceRGB],
        .bitmapInfo = hasAlpha ? kCGImageAlphaFirst | kCGBitmapByteOrderDefault : kCGImageAlphaNone | kCGBitmapByteOrderDefault // RGB888/ARGB8888 (Non-premultiplied to works for libbpg)
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
    enum avifPlanesFlags planesFlags = hasAlpha ? AVIF_PLANES_RGB | AVIF_PLANES_A : AVIF_PLANES_RGB;
    
    avifImage *avif = avifImageCreate((int)width, (int)height, 8, avifFormat);
    if (!avif) {
        free(dest.data);
        return nil;
    }
    avifImageAllocatePlanes(avif, planesFlags);
    
    NSData *iccProfile = (__bridge_transfer NSData *)CGColorSpaceCopyICCProfile([SDImageCoderHelper colorSpaceGetDeviceRGB]);
    
    avifImageSetProfileICC(avif, (uint8_t *)iccProfile.bytes, iccProfile.length);
    
    vImage_Buffer red, green, blue, alpha;
    FillRGBABufferWithAVIFImage(&red, &green, &blue, &alpha, avif);
    
    if (hasAlpha) {
        v_error = vImageConvert_ARGB8888toPlanar8(&dest, &alpha, &red, &green, &blue, kvImageNoFlags);
    } else {
        v_error = vImageConvert_RGB888toPlanar8(&dest, &red, &green, &blue, kvImageNoFlags);
    }
    free(dest.data);
    if (v_error != kvImageNoError) {
        return nil;
    }
    
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
