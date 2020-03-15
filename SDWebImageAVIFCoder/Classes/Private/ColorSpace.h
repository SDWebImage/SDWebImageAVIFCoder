//
//  ColorSpace.h
//  SDWebImageAVIFCoder
//
//  Created by psi on 2020/03/15.
//

#pragma once
#if __has_include(<libavif/avif.h>)
#import <libavif/avif.h>
#else
#import "avif/avif.h"
#endif

CGColorSpaceRef CreateColorSpaceMono(avifNclxColourPrimaries const colorPrimaries, avifNclxTransferCharacteristics const transferCharacteristics);
CGColorSpaceRef CreateColorSpaceRGB(avifNclxColourPrimaries const colorPrimaries, avifNclxTransferCharacteristics const transferCharacteristics);

void CalcColorSpaceMono(avifImage * avif, CGColorSpaceRef* ref, BOOL* shouldRelease);
void CalcColorSpaceRGB(avifImage * avif, CGColorSpaceRef* ref, BOOL* shouldRelease);
