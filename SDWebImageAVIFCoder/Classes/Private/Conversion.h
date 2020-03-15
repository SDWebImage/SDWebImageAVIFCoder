//
//  Conversion.h
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

CGImageRef CreateCGImageFromAVIF(avifImage * avif);
