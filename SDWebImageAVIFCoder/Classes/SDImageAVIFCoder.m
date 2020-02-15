//
//  SDImageAVIFCoder.m
//  SDWebImageHEIFCoder
//
//  Created by lizhuoli on 2018/5/8.
//

#import "SDImageAVIFCoder.h"
#import <Accelerate/Accelerate.h>
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif

static CGImageRef CreateImageRef(avifImage * avif, vImage_Buffer* result) {
    BOOL monochrome = avif->yuvPlanes[1] == NULL || avif->yuvPlanes[2] == NULL;
    BOOL hasAlpha = avif->alphaPlane != NULL;
    BOOL usesU16 = avifImageUsesU16(avif);
    size_t components = (monochrome ? 1 : 3) + (hasAlpha ? 1 : 0);

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, result->data, result->rowBytes * result->height, NULL);
    CGBitmapInfo bitmapInfo = usesU16 ? kCGBitmapByteOrder16Host : kCGBitmapByteOrderDefault;
    bitmapInfo |= hasAlpha ? kCGImageAlphaFirst : kCGImageAlphaNone;
    // FIXME: (ledyba-z): Set appropriate color space.
    // Currently, there is no way to get MatrixCoefficients, TransferCharacteristics and ColourPrimaries values
    //  in Sequence Header OBU.
    // https://github.com/AOMediaCodec/libavif/blob/7d36984b2994210b/include/avif/avif.h#L149-L236
    CGColorSpaceRef colorSpace = [SDImageCoderHelper colorSpaceGetDeviceRGB];
    if(monochrome){
        //colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
        colorSpace = CGColorSpaceCreateDeviceGray();
    }
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    size_t bitsPerComponent = usesU16 ? 16 : 8;
    size_t bitsPerPixel = components * bitsPerComponent;
    size_t rowBytes = result->width * components * (usesU16 ? sizeof(uint16_t) : sizeof(uint8_t));

    CGImageRef imageRef = CGImageCreate(result->width, result->height, bitsPerComponent, bitsPerPixel, rowBytes, colorSpace, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    // clean up
    CGDataProviderRelease(provider);
    
    return imageRef;
}

static void SetupConversionInfo(avifImage * avif,
                                avifReformatState* state,
                                vImage_YpCbCrToARGBMatrix* matrix,
                                vImage_YpCbCrPixelRange* pixelRange) {
    avifPrepareReformatState(avif, state);

    // Setup Matrix
    matrix->Yp = 1.0f;

    matrix->Cb_B =  2.0f * (1.0f - state->kb);
    matrix->Cb_G = -2.0f * (1.0f - state->kb) * state->kb / state->kg;

    matrix->Cr_R =  2.0f * (1.0f - state->kr);
    matrix->Cr_G = -2.0f * (1.0f - state->kr) * state->kr / state->kg;

    // Setup Pixel Range
    switch (avif->depth) {
        case 8:
            if (avif->yuvRange == AVIF_RANGE_LIMITED) {
                pixelRange->Yp_bias = 16;
                pixelRange->YpRangeMax = 235;
                pixelRange->YpMax = 255;
                pixelRange->YpMin = 0;
                pixelRange->CbCr_bias = 128;
                pixelRange->CbCrRangeMax = 240;
                pixelRange->CbCrMax = 255;
                pixelRange->CbCrMin = 0;
            }else{
                pixelRange->Yp_bias = 0;
                pixelRange->YpRangeMax = 255;
                pixelRange->YpMax = 255;
                pixelRange->YpMin = 0;
                pixelRange->CbCr_bias = 128;
                pixelRange->CbCrRangeMax = 255;
                pixelRange->CbCrMax = 255;
                pixelRange->CbCrMin = 0;
            }
            break;
        case 10:
            if (avif->yuvRange == AVIF_RANGE_LIMITED) {
                pixelRange->Yp_bias = 64;
                pixelRange->YpRangeMax = 940;
                pixelRange->YpMax = 1023;
                pixelRange->YpMin = 0;
                pixelRange->CbCr_bias = 512;
                pixelRange->CbCrRangeMax = 960;
                pixelRange->CbCrMax = 1023;
                pixelRange->CbCrMin = 0;
            }else{
                pixelRange->Yp_bias = 0;
                pixelRange->YpRangeMax = 1023;
                pixelRange->YpMax = 1023;
                pixelRange->YpMin = 0;
                pixelRange->CbCr_bias = 512;
                pixelRange->CbCrRangeMax = 1023;
                pixelRange->CbCrMax = 1023;
                pixelRange->CbCrMin = 0;
            }
            break;
        case 12:
            if (avif->yuvRange == AVIF_RANGE_LIMITED) {
                pixelRange->Yp_bias = 256;
                pixelRange->YpRangeMax = 3760;
                pixelRange->YpMax = 4095;
                pixelRange->YpMin = 0;
                pixelRange->CbCr_bias = 2048;
                pixelRange->CbCrRangeMax = 3840;
                pixelRange->CbCrMax = 4095;
                pixelRange->CbCrMin = 0;
            }else{
                pixelRange->Yp_bias = 0;
                pixelRange->YpRangeMax = 4095;
                pixelRange->YpMax = 4095;
                pixelRange->YpMin = 0;
                pixelRange->CbCr_bias = 2048;
                pixelRange->CbCrRangeMax = 4095;
                pixelRange->CbCrMax = 4095;
                pixelRange->CbCrMin = 0;
            }
            break;
        default:
            NSLog(@"Unknown bit depth: %d", avif->depth);
            return;
    }
    
}


// Convert 8bit AVIF image into RGB888/ARGB8888/Mono/MonoA using vImage Acceralation Framework.
static CGImageRef ConvertAvifImage8(avifImage * avif) {
    vImage_Error err = kvImageNoError;
    BOOL const monochrome = avif->yuvPlanes[1] == NULL || avif->yuvPlanes[2] == NULL;
    BOOL const hasAlpha = avif->alphaPlane != NULL;
    size_t const components = (monochrome ? 1 : 3) + (hasAlpha ? 1 : 0);
    size_t const rowBytes = components * sizeof(uint8_t) * avif->width;

    // setup conversion info
    avifReformatState state = {0};
    vImage_YpCbCrToARGBMatrix matrix = {0};
    vImage_YpCbCrPixelRange pixelRange = {0};
    SetupConversionInfo(avif, &state, &matrix, &pixelRange);

    vImage_YpCbCrToARGB convInfo = {0};

    uint8_t* outPixels = calloc(components * rowBytes * avif->height, sizeof(uint8_t));
    if(outPixels == NULL) {
        return NULL;
    }
    uint8_t* argbPixels = NULL;
    uint8_t* dummyCb = NULL;
    uint8_t* dummyCr = NULL;
    
    BOOL const useTempBuffer = monochrome || !hasAlpha;

    if(useTempBuffer) {
        argbPixels = calloc(avif->width * avif->height * 4, sizeof(uint8_t));
        if(!argbPixels) {
            free(outPixels);
            return NULL;
        }
    }

    vImage_Buffer argbBuffer = {
        .data = useTempBuffer ? argbPixels : outPixels,
        .width = avif->width,
        .height = avif->height,
        .rowBytes = avif->width * 4,
    };

    vImage_Buffer origY = {
        .data = avif->yuvPlanes[AVIF_CHAN_Y],
        .rowBytes = avif->yuvRowBytes[AVIF_CHAN_Y],
        .width = avif->width,
        .height = avif->height,
    };

    vImage_Buffer origCb = {
        .data = avif->yuvPlanes[AVIF_CHAN_U],
        .rowBytes = avif->yuvRowBytes[AVIF_CHAN_U],
        .width = (avif->width+state.formatInfo.chromaShiftX) >> state.formatInfo.chromaShiftX,
        .height = (avif->height+state.formatInfo.chromaShiftY) >> state.formatInfo.chromaShiftY,
    };

    if(!origCb.data) { // allocate dummy data to convert monochrome images.
        dummyCb = calloc(origCb.width, sizeof(uint8_t));
        if(!dummyCb) {
            free(outPixels);
            free(argbPixels);
            return NULL;
        }
        origCb.data = dummyCb;
        origCb.rowBytes = 0;
        memset(origCb.data, pixelRange.CbCr_bias, origCb.width);
    }

    vImage_Buffer origCr = {
        .data = avif->yuvPlanes[AVIF_CHAN_V],
        .rowBytes = avif->yuvRowBytes[AVIF_CHAN_V],
        .width = (avif->width+state.formatInfo.chromaShiftX) >> state.formatInfo.chromaShiftX,
        .height = (avif->height+state.formatInfo.chromaShiftY) >> state.formatInfo.chromaShiftY,
    };
    if(!origCr.data) { // allocate dummy data to convert monochrome images.
        dummyCr = calloc(origCr.width, sizeof(uint8_t));
        if(!dummyCr) {
            free(outPixels);
            free(argbPixels);
            free(dummyCb);
            return NULL;
        }
        origCr.data = dummyCr;
        origCr.rowBytes = 0;
        memset(origCr.data, pixelRange.CbCr_bias, origCr.width);
    }
        
    uint8_t const permuteMap[4] = {0, 1, 2, 3};
    switch(avif->yuvFormat) {
        case AVIF_PIXEL_FORMAT_NONE:
            free(outPixels);
            free(argbPixels);
            free(dummyCb);
            free(dummyCr);
            NSLog(@"Invalid pixel format.");
            return NULL;
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
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                NSLog(@"Failed to setup conversion: %ld", err);
                return NULL;
            }
                    
            err = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&origY,
                                                         &origCb,
                                                         &origCr,
                                                         &argbBuffer,
                                                         &convInfo,
                                                         permuteMap,
                                                         255,
                                                         kvImageNoFlags);
            if(err != kvImageNoError) {
                free(outPixels);
                free(argbPixels);
                NSLog(@"Failed to convert to ARGB8888: %ld", err);
                return NULL;
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
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                NSLog(@"Failed to setup conversion: %ld", err);
                return NULL;
            }

            vImage_Buffer tmpBuffer = {
                .data = calloc(avif->width * avif->height * 3, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * 3,
            };
            if(!tmpBuffer.data) {
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                return NULL;
            }
            err = vImageConvert_Planar8toRGB888(&origCr, &origY, &origCb, &tmpBuffer, kvImageNoFlags);
            if(err != kvImageNoError) {
                NSLog(@"Failed to composite kvImage444CrYpCb8: %ld", err);
                free(outPixels);
                free(argbPixels);
                free(tmpBuffer.data);
                return NULL;
            }
            vImageConvert_444CrYpCb8ToARGB8888(&tmpBuffer,
                                               &argbBuffer,
                                               &convInfo,
                                               permuteMap,
                                               255,
                                               kvImageNoFlags);
            free(tmpBuffer.data);
            if(err != kvImageNoError) {
                free(outPixels);
                free(argbPixels);
                NSLog(@"Failed to convert to ARGB8888: %ld", err);
                return NULL;
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
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                NSLog(@"Failed to setup conversion: %ld", err);
                return NULL;
            }

            const vImagePixelCount alignedWidth = (origY.width+1) & (~1);
            vImage_Buffer tmpY1 = {
                .data = calloc(alignedWidth/2 * origY.height, sizeof(uint8_t)),
                .width = alignedWidth/2,
                .height = origY.height,
                .rowBytes = alignedWidth/2 * sizeof(uint8_t),
            };
            if(!tmpY1.data) {
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                return NULL;
            }
            err = vImageConvert_ChunkyToPlanar8((const void*[]){origY.data},
                                               (const vImage_Buffer*[]){&tmpY1},
                                               1 /* channelCount */, 2 /* src srcStrideBytes */,
                                               alignedWidth/2, origY.height,
                                               origY.rowBytes, kvImageNoFlags);
            if(err != kvImageNoError) {
                NSLog(@"Failed to separate first Y channel: %ld", err);
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(tmpY1.data);
                return NULL;
            }
            vImage_Buffer tmpY2 = {
                .data = calloc(alignedWidth/2 * origY.height, sizeof(uint8_t)),
                .width = alignedWidth/2,
                .height = origY.height,
                .rowBytes = alignedWidth/2 * sizeof(uint8_t),
            };
            if(!tmpY2.data) {
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(tmpY1.data);
                return NULL;
            }
            tmpY2.width = origY.width/2;
            err = vImageConvert_ChunkyToPlanar8((const void*[]){origY.data + 1},
                                               (const vImage_Buffer*[]){&tmpY2},
                                               1 /* channelCount */, 2 /* src srcStrideBytes */,
                                               origY.width/2, origY.height,
                                               origY.rowBytes, kvImageNoFlags);
            tmpY2.width = alignedWidth/2;
            if(err != kvImageNoError) {
                NSLog(@"Failed to separate second Y channel: %ld", err);
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(tmpY1.data);
                free(tmpY2.data);
                return NULL;
            }
            vImage_Buffer tmpBuffer = {
                .data = calloc(alignedWidth * avif->height * 2, sizeof(uint8_t)),
                .width = alignedWidth/2,
                .height = avif->height,
                .rowBytes = alignedWidth / 2 * 4 * sizeof(uint8_t),
            };
            if(!tmpBuffer.data) {
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(tmpY1.data);
                free(tmpY2.data);
                return NULL;
            }

            err = vImageConvert_Planar8toARGB8888(&tmpY1, &origCb, &tmpY2, &origCr,
                                                  &tmpBuffer, kvImageNoFlags);
            free(tmpY1.data);
            free(tmpY2.data);
            if(err != kvImageNoError) {
                NSLog(@"Failed to composite kvImage422YpCbYpCr8: %ld", err);
                free(outPixels);
                free(argbPixels);
                free(tmpBuffer.data);
                return NULL;
            }
            tmpBuffer.width *= 2;

            err = vImageConvert_422YpCbYpCr8ToARGB8888(&tmpBuffer,
                                                       &argbBuffer,
                                                       &convInfo,
                                                       permuteMap,
                                                       255,
                                                       kvImageNoFlags);
            free(tmpBuffer.data);
            if(err != kvImageNoError) {
                free(outPixels);
                free(argbPixels);
                NSLog(@"Failed to convert to ARGB8888: %ld", err);
                return NULL;
            }
            break;
        }
    }
    free(dummyCb);
    free(dummyCr);

    if(hasAlpha) {
        vImage_Buffer alphaBuffer = {
            .data = avif->alphaPlane,
            .width = avif->width,
            .height = avif->height,
            .rowBytes = avif->alphaRowBytes,
        };
        if(monochrome) {
            vImage_Buffer outBuffer = {
                .data = outPixels,
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * components,
            };
            vImage_Buffer tmpBuffer = {
                .data = calloc(avif->width, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = 0,
            };
            if(!tmpBuffer.data) {
                free(outPixels);
                free(argbPixels);
                return NULL;
            }
            vImage_Buffer monoBuffer = {
                .data = calloc(avif->width * avif->height, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width,
            };
            if(!monoBuffer.data) {
                free(outPixels);
                free(argbPixels);
                free(tmpBuffer.data);
                return NULL;
            }
            err = vImageConvert_ARGB8888toPlanar8(&argbBuffer, &tmpBuffer, &tmpBuffer, &monoBuffer, &tmpBuffer, kvImageNoFlags);
            free(argbPixels);
            free(tmpBuffer.data);
            if(err != kvImageNoError) {
                free(outPixels);
                free(monoBuffer.data);
                NSLog(@"Failed to convert ARGB to RGB: %ld", err);
                return NULL;
            }
            err = vImageConvert_PlanarToChunky8((const vImage_Buffer*[]){&monoBuffer, &alphaBuffer},
                                                (void*[]){outBuffer.data, outBuffer.data + 1},
                                                2 /* channelCount */, 2 /* destStrideBytes */,
                                                outBuffer.width, outBuffer.height,
                                                outBuffer.rowBytes, kvImageNoFlags);
            CGImageRef img = CreateImageRef(avif, &outBuffer);
            free(outPixels);
            return img;
        } else {
            err = vImageOverwriteChannels_ARGB8888(&alphaBuffer, &argbBuffer, &argbBuffer, 0x8, kvImageNoFlags);
            if(err != kvImageNoError) {
                free(outPixels);
                NSLog(@"Failed to overwrite alpha: %ld", err);
                return NULL;
            }
            CGImageRef img = CreateImageRef(avif, &argbBuffer);
            free(outPixels);
            return img;
        }
    } else {
        if(monochrome) {
            vImage_Buffer outBuffer = {
                .data = outPixels,
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * components,
            };
            vImage_Buffer tmpBuffer = {
                .data = calloc(avif->width, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = 0,
            };
            if(!tmpBuffer.data) {
                free(outPixels);
                free(argbPixels);
                return NULL;
            }
            err = vImageConvert_ARGB8888toPlanar8(&argbBuffer, &tmpBuffer, &tmpBuffer, &outBuffer, &tmpBuffer, kvImageNoFlags);
            free(argbPixels);
            free(tmpBuffer.data);
            if(err != kvImageNoError) {
                free(outPixels);
                NSLog(@"Failed to convert ARGB to RGB: %ld", err);
                return NULL;
            }
            CGImageRef img = CreateImageRef(avif, &outBuffer);
            free(outPixels);
            return img;
        } else {
            vImage_Buffer outBuffer = {
                .data = outPixels,
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * components,
            };
            err = vImageConvert_ARGB8888toRGB888(&argbBuffer, &outBuffer, kvImageNoFlags);
            free(argbPixels);
            if(err != kvImageNoError) {
                free(outPixels);
                NSLog(@"Failed to convert ARGB to RGB: %ld", err);
                return NULL;
            }
            CGImageRef img = CreateImageRef(avif, &outBuffer);
            free(outPixels);
            return img;
        }
    }
}

// Convert 10/12bit AVIF image into RGB16U/ARGB16U/Mono16U/MonoA16U
static CGImageRef ConvertAvifImage16U(avifImage * avif) {
    vImage_Error err = kvImageNoError;
    BOOL const monochrome = avif->yuvPlanes[1] == NULL || avif->yuvPlanes[2] == NULL;
    BOOL const hasAlpha = avif->alphaPlane != NULL;
    size_t const components = (monochrome ? 1 : 3) + (hasAlpha ? 1 : 0);
    size_t const rowBytes = components * sizeof(uint8_t) * avif->width;

    // setup conversion info
    avifReformatState state = {0};
    vImage_YpCbCrToARGBMatrix matrix = {0};
    vImage_YpCbCrPixelRange pixelRange = {0};
    SetupConversionInfo(avif, &state, &matrix, &pixelRange);

    vImage_YpCbCrToARGB convInfo = {0};

    uint16_t* outPixels = calloc(components * rowBytes * avif->height, sizeof(uint16_t));
    if(outPixels == NULL) {
        return NULL;
    }
    uint16_t* argbPixels = NULL;
    uint16_t* dummyCb = NULL;
    uint16_t* dummyCr = NULL;
    uint16_t* dummyAlpha = NULL;

    BOOL const useTempBuffer = monochrome || !hasAlpha;

    if(useTempBuffer) {
        argbPixels = calloc(avif->width * avif->height * 4, sizeof(uint16_t));
        if(!argbPixels) {
            free(outPixels);
            return NULL;
        }
    }

    vImage_Buffer argbBuffer = {
        .data = useTempBuffer ? argbPixels : outPixels,
        .width = avif->width,
        .height = avif->height,
        .rowBytes = avif->width * 4 * sizeof(uint16_t),
    };

    vImage_Buffer origY = {
        .data = avif->yuvPlanes[AVIF_CHAN_Y],
        .rowBytes = avif->yuvRowBytes[AVIF_CHAN_Y],
        .width = avif->width,
        .height = avif->height,
    };
    
    vImage_Buffer origCb = {
        .data = avif->yuvPlanes[AVIF_CHAN_U],
        .rowBytes = avif->yuvRowBytes[AVIF_CHAN_U],
        .width = (avif->width+state.formatInfo.chromaShiftX) >> state.formatInfo.chromaShiftX,
        .height = (avif->height+state.formatInfo.chromaShiftY) >> state.formatInfo.chromaShiftY,
    };

    if(!origCb.data) { // allocate dummy data to convert monochrome images.
        vImagePixelCount origHeight = origCb.height;
        origCb.rowBytes = origCb.width * sizeof(uint16_t);
        dummyCb = calloc(origCb.width, sizeof(uint16_t));
        if(!dummyCb) {
            free(outPixels);
            free(argbPixels);
            return NULL;
        }
        origCb.data = dummyCb;
        origCb.height = 1;
        // fill zero values.
        err = vImageOverwriteChannelsWithScalar_Planar16U(pixelRange.CbCr_bias, &origCb, kvImageNoFlags);
        if (err != kvImageNoError) {
            free(outPixels);
            free(argbPixels);
            NSLog(@"Failed to fill dummy Cr buffer: %ld", err);
            return NULL;
        }
        origCb.rowBytes = 0;
        origCb.height = origHeight;
    }

    vImage_Buffer origCr = {
        .data = avif->yuvPlanes[AVIF_CHAN_V],
        .rowBytes = avif->yuvRowBytes[AVIF_CHAN_V],
        .width = (avif->width+state.formatInfo.chromaShiftX) >> state.formatInfo.chromaShiftX,
        .height = (avif->height+state.formatInfo.chromaShiftY) >> state.formatInfo.chromaShiftY,
    };

    if(!origCr.data) { // allocate dummy data to convert monochrome images.
        vImagePixelCount origHeight = origCr.height;
        origCr.rowBytes = origCr.width * sizeof(uint16_t);
        dummyCr = calloc(origCr.width, sizeof(uint16_t));
        if(!dummyCr) {
            free(outPixels);
            free(argbPixels);
            free(dummyCb);
            return NULL;
        }
        origCr.data = dummyCr;
        origCr.height = 1;
        // fill zero values.
        err = vImageOverwriteChannelsWithScalar_Planar16U(pixelRange.CbCr_bias, &origCr, kvImageNoFlags);
        if (err != kvImageNoError) {
            free(outPixels);
            free(argbPixels);
            free(dummyCb);
            NSLog(@"Failed to fill dummy Cr buffer: %ld", err);
            return NULL;
        }
        origCr.rowBytes = 0;
        origCr.height = origHeight;
    }

    vImage_Buffer origAlpha = {0};
    if(hasAlpha) {
        origAlpha.data = avif->alphaPlane;
        origAlpha.width = avif->width;
        origAlpha.height = avif->height;
        origAlpha.rowBytes = avif->alphaRowBytes;
    } else {
        // allocate dummy data to convert monochrome images.
        origAlpha.rowBytes = avif->width * sizeof(uint16_t);
        dummyAlpha = calloc(avif->width, sizeof(uint16_t));
        if(!dummyAlpha) {
            free(outPixels);
            free(argbPixels);
            free(dummyCb);
            free(dummyCr);
            return NULL;
        }
        origAlpha.data = dummyAlpha;
        origAlpha.width = avif->width;
        origAlpha.height = 1;
        err = vImageOverwriteChannelsWithScalar_Planar16U(0xffff, &origAlpha, kvImageNoFlags);
        if (err != kvImageNoError) {
            free(outPixels);
            free(argbPixels);
            free(dummyCb);
            free(dummyCr);
            NSLog(@"Failed to fill dummy alpha buffer: %ld", err);
            return NULL;
        }
        origAlpha.rowBytes = 0;
        origAlpha.height = avif->height;
    };
    
    vImage_Buffer aYpCbCrBuffer = {
        .data = calloc(avif->width * avif->height * 4, sizeof(uint16_t)),
        .width = avif->width,
        .height = avif->height,
        .rowBytes = avif->width * 4 * sizeof(uint16_t),
    };
    if (!aYpCbCrBuffer.data) {
        free(outPixels);
        free(argbPixels);
        free(dummyCb);
        free(dummyCr);
        free(dummyAlpha);
        return NULL;
    }

    uint8_t const permuteMap[4] = {0, 1, 2, 3};
    switch(avif->yuvFormat) {
        case AVIF_PIXEL_FORMAT_NONE:
            free(outPixels);
            free(argbPixels);
            free(dummyCb);
            free(dummyCr);
            free(dummyAlpha);
            free(aYpCbCrBuffer.data);
            NSLog(@"Invalid pixel format.");
            return NULL;
        case AVIF_PIXEL_FORMAT_YUV420:
        case AVIF_PIXEL_FORMAT_YUV422:
        case AVIF_PIXEL_FORMAT_YV12:
        {
            vImage_Buffer scaledCb = {
                .data = calloc(avif->width * avif->height * 4, sizeof(uint16_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * 4 * sizeof(uint16_t),
            };
            if(!scaledCb.data) {
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(dummyAlpha);
                free(aYpCbCrBuffer.data);
                return NULL;
            }
            vImage_Buffer scaledCr = {
                .data = calloc(avif->width * avif->height * 4, sizeof(uint16_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * 4 * sizeof(uint16_t),
            };
            if(!scaledCr.data) {
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(dummyAlpha);
                free(aYpCbCrBuffer.data);
                free(scaledCb.data);
                return NULL;
            }
            vImage_Error scaleTempBuffSize = vImageScale_Planar16U(&origCb, &scaledCb, NULL, kvImageGetTempBufferSize);
            if(scaleTempBuffSize < 0) {
                NSLog(@"Failed to get temp buffer size: %ld", scaleTempBuffSize);
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(dummyAlpha);
                free(aYpCbCrBuffer.data);
                free(scaledCb.data);
                free(scaledCr.data);
                return NULL;
            }
            void* scaleTempBuff = malloc(scaleTempBuffSize);
            if(!scaleTempBuff) {
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(dummyAlpha);
                free(aYpCbCrBuffer.data);
                free(scaledCb.data);
                free(scaledCr.data);
                return NULL;
            }
            // upscale Cb
            err = vImageScale_Planar16U(&origCb, &scaledCb, scaleTempBuff, kvImageNoFlags);
            if(err != kvImageNoError) {
                NSLog(@"Failed to scale Cb: %ld", err);
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(dummyAlpha);
                free(aYpCbCrBuffer.data);
                free(scaledCb.data);
                free(scaledCr.data);
                free(scaleTempBuff);
                return NULL;
            }
            // upscale Cr
            err = vImageScale_Planar16U(&origCr, &scaledCr, scaleTempBuff, kvImageNoFlags);
            if(err != kvImageNoError) {
                NSLog(@"Failed to scale Cb: %ld", err);
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(dummyAlpha);
                free(aYpCbCrBuffer.data);
                free(scaledCb.data);
                free(scaledCr.data);
                free(scaleTempBuff);
                return NULL;
            }
            free(scaleTempBuff);

            err = vImageConvert_Planar16UtoARGB16U(&origAlpha, &origY, &scaledCb, &scaledCr, &aYpCbCrBuffer, kvImageNoFlags);
            free(scaledCb.data);
            free(scaledCr.data);
            if(err != kvImageNoError) {
                NSLog(@"Failed to composite kvImage444AYpCbCr16: %ld", err);
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(dummyAlpha);
                free(aYpCbCrBuffer.data);
                return NULL;
            }
            break;
        }
        case AVIF_PIXEL_FORMAT_YUV444:
        {
            err = vImageConvert_Planar16UtoARGB16U(&origAlpha, &origY, &origCb, &origCr, &aYpCbCrBuffer, kvImageNoFlags);
            if(err != kvImageNoError) {
                NSLog(@"Failed to composite kvImage444AYpCbCr16: %ld", err);
                free(outPixels);
                free(argbPixels);
                free(dummyCb);
                free(dummyCr);
                free(dummyAlpha);
                free(aYpCbCrBuffer.data);
                return NULL;
            }
            break;
        }
    }
    free(dummyCb);
    free(dummyCr);
    free(dummyAlpha);

    err = vImageConvert_YpCbCrToARGB_GenerateConversion(&matrix,
                                                        &pixelRange,
                                                        &convInfo,
                                                        kvImage444AYpCbCr16,
                                                        kvImageARGB16U,
                                                        kvImageNoFlags);
    if(err != kvImageNoError) {
        free(outPixels);
        free(argbPixels);
        free(aYpCbCrBuffer.data);
        NSLog(@"Failed to setup conversion: %ld", err);
        return NULL;
    }
    err = vImageConvert_444AYpCbCr16ToARGB16U(&aYpCbCrBuffer,
                                              &argbBuffer,
                                              &convInfo,
                                              permuteMap,
                                              kvImageNoFlags);
    free(aYpCbCrBuffer.data);
    if(err != kvImageNoError) {
        free(outPixels);
        free(argbPixels);
        NSLog(@"Failed to convert to ARGB16U: %ld", err);
        return NULL;
    }

    if(hasAlpha) {
        if(monochrome){
            vImage_Buffer tmpBuffer = {
                .data = calloc(avif->width, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = 0,
            };
            if(!tmpBuffer.data) {
                free(outPixels);
                free(argbPixels);
                return NULL;
            }
            vImage_Buffer alphaBuffer = {
                .data = calloc(avif->width * avif->height, sizeof(uint16_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * sizeof(uint16_t),
            };
            if(!alphaBuffer.data) {
                free(outPixels);
                free(argbPixels);
                free(tmpBuffer.data);
                return NULL;
            }
            vImage_Buffer monoBuffer = {
                .data = calloc(avif->width * avif->height, sizeof(uint16_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * sizeof(uint16_t),
            };
            if(!monoBuffer.data) {
                free(outPixels);
                free(argbPixels);
                free(tmpBuffer.data);
                free(alphaBuffer.data);
                return NULL;
            }
            err = vImageConvert_ARGB16UtoPlanar16U(&argbBuffer, &alphaBuffer, &tmpBuffer, &monoBuffer, &tmpBuffer, kvImageNoFlags);
            free(argbPixels);
            free(tmpBuffer.data);
            if(err != kvImageNoError) {
                free(outPixels);
                free(monoBuffer.data);
                NSLog(@"Failed to convert ARGB to Mono: %ld", err);
                return NULL;
            }
            vImage_Buffer monoBuffer1 = {
                .data = calloc(avif->width * avif->height, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * sizeof(uint8_t),
            };
            if(!monoBuffer1.data) {
                free(outPixels);
                free(alphaBuffer.data);
                free(monoBuffer.data);
                return NULL;
            }
            vImage_Buffer monoBuffer2 = {
                .data = calloc(avif->width * avif->height, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * sizeof(uint8_t),
            };
            if(!monoBuffer2.data) {
                free(outPixels);
                free(alphaBuffer.data);
                free(monoBuffer.data);
                free(monoBuffer1.data);
                return NULL;
            }
            err = vImageConvert_ChunkyToPlanar8((const void*[]){monoBuffer.data, monoBuffer.data + 1},
                                               (const vImage_Buffer*[]){&monoBuffer1, &monoBuffer2},
                                               2 /* channelCount */, 2 /* src srcStrideBytes */,
                                               monoBuffer.width, monoBuffer.height,
                                               monoBuffer.rowBytes, kvImageNoFlags);
            free(monoBuffer.data);
            if(err != kvImageNoError) {
                free(outPixels);
                free(alphaBuffer.data);
                free(monoBuffer.data);
                free(monoBuffer1.data);
                free(monoBuffer2.data);
                NSLog(@"Failed to split Mono16: %ld", err);
                return NULL;
            }

            vImage_Buffer alphaBuffer1 = {
                .data = calloc(avif->width * avif->height, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * sizeof(uint8_t),
            };
            if(!alphaBuffer1.data) {
                free(outPixels);
                free(alphaBuffer.data);
                free(monoBuffer1.data);
                free(monoBuffer2.data);
                return NULL;
            }
            vImage_Buffer alphaBuffer2 = {
                .data = calloc(avif->width * avif->height, sizeof(uint8_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * sizeof(uint8_t),
            };
            if(!alphaBuffer2.data) {
                free(outPixels);
                free(alphaBuffer.data);
                free(monoBuffer1.data);
                free(monoBuffer2.data);
                free(alphaBuffer1.data);
                return NULL;
            }
            err = vImageConvert_ChunkyToPlanar8((const void*[]){alphaBuffer.data, alphaBuffer.data + 1},
                                               (const vImage_Buffer*[]){&alphaBuffer1, &alphaBuffer2},
                                               2 /* channelCount */, 2 /* src srcStrideBytes */,
                                               alphaBuffer.width, alphaBuffer.height,
                                               alphaBuffer.rowBytes, kvImageNoFlags);
            free(alphaBuffer.data);
            if(err != kvImageNoError) {
                free(outPixels);
                free(monoBuffer1.data);
                free(monoBuffer2.data);
                free(alphaBuffer1.data);
                free(alphaBuffer2.data);
                NSLog(@"Failed to split Mono16: %ld", err);
                return NULL;
            }

            vImage_Buffer outBuffer = {
                .data = outPixels,
                .width = avif->width,
                .height = avif->height,
                .rowBytes = avif->width * components * sizeof(uint16_t),
            };
            err = vImageConvert_Planar16UtoARGB16U(&monoBuffer1, &monoBuffer2, &alphaBuffer1, &alphaBuffer2, &outBuffer, kvImageNoFlags);
            free(monoBuffer1.data);
            free(monoBuffer2.data);
            free(alphaBuffer1.data);
            free(alphaBuffer2.data);
            if(err != kvImageNoError) {
                free(outPixels);
                NSLog(@"Failed to convert ARGB to MonoA: %ld", err);
                return NULL;
            }
            CGImageRef img = CreateImageRef(avif, &outBuffer);
            free(outPixels);
            return img;
            return NULL;
        }else{
            CGImageRef img = CreateImageRef(avif, &argbBuffer);
            free(outPixels);
            return img;
        }
    } else {
        vImage_Buffer outBuffer = {
            .data = outPixels,
            .width = avif->width,
            .height = avif->height,
            .rowBytes = avif->width * components * sizeof(uint16_t),
        };
        if(monochrome) {
            vImage_Buffer tmpBuffer = {
                .data = calloc(avif->width, sizeof(uint16_t)),
                .width = avif->width,
                .height = avif->height,
                .rowBytes = 0,
            };
            if(!tmpBuffer.data) {
                free(outPixels);
                free(argbPixels);
                return NULL;
            }
            err = vImageConvert_ARGB16UtoPlanar16U(&argbBuffer, &tmpBuffer, &tmpBuffer, &outBuffer, &tmpBuffer, kvImageNoFlags);
            free(argbPixels);
            free(tmpBuffer.data);
            if(err != kvImageNoError) {
                free(outPixels);
                NSLog(@"Failed to convert ARGB to Mono: %ld", err);
                return NULL;
            }
            CGImageRef img = CreateImageRef(avif, &outBuffer);
            free(outPixels);
            return img;
        } else {
            err = vImageConvert_ARGB16UtoRGB16U(&argbBuffer, &outBuffer, kvImageNoFlags);
            free(argbPixels);
            if(err != kvImageNoError) {
                free(outPixels);
                NSLog(@"Failed to convert ARGB to RGB: %ld", err);
                return NULL;
            }
            CGImageRef img = CreateImageRef(avif, &outBuffer);
            free(outPixels);
            return img;
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
    avifDecoder * decoder = avifDecoderCreate();
    avifResult decodeResult = avifDecoderParse(decoder, &rawData);
    if (decodeResult != AVIF_RESULT_OK) {
        NSLog(@"Failed to decode image: %s", avifResultToString(decodeResult));
        avifDecoderDestroy(decoder);
        return nil;
    }
    avifResult nextImageResult = avifDecoderNextImage(decoder);
    if (nextImageResult != AVIF_RESULT_OK || nextImageResult == AVIF_RESULT_NO_IMAGES_REMAINING) {
        NSLog(@"Failed to decode image: %s", avifResultToString(nextImageResult));
        avifDecoderDestroy(decoder);
        return nil;
    }
    avifImage * avif = decoder->image;

    CGImageRef image = NULL;
    // convert planar to ARGB/RGB
    if(avifImageUsesU16(avif)) { // 10bit or 12bit
        image = ConvertAvifImage16U(avif);
    } else { //8bit
        image = ConvertAvifImage8(avif);
    }
    avifDecoderDestroy(decoder);
    return image;
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
        .bitmapInfo = bitmapInfo
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
