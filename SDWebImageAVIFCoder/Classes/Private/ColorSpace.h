//
//  ColorSpace.h
//  SDWebImageAVIFCoder
//
//  Created by Ryo Hirafuji on 2020/03/15.
//

#pragma once
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif

extern CGColorSpaceRef _Nullable SDCreateAVIFCreateColorSpaceMono(avifNclxColourPrimaries const colorPrimaries, avifNclxTransferCharacteristics const transferCharacteristics) __attribute__((visibility("hidden")));
extern CGColorSpaceRef _Nullable SDCreateAVIFCreateColorSpaceRGB(avifNclxColourPrimaries const colorPrimaries, avifNclxTransferCharacteristics const transferCharacteristics) __attribute__((visibility("hidden")));

void SDCalcColorSpaceMonoAVIF(avifImage * _Nonnull avif, CGColorSpaceRef _Nullable * _Nonnull ref, BOOL* _Nonnull shouldRelease);
void SDCalcColorSpaceRGBAVIF(avifImage * _Nonnull avif, CGColorSpaceRef _Nullable * _Nonnull ref, BOOL* _Nonnull shouldRelease);
