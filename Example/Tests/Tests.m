//
//  SDWebImageAVIFCoderTests.m
//  SDWebImageAVIFCoderTests
//
//  Created by lizhuoli1126@126.com on 04/14/2019.
//  Copyright (c) 2019 lizhuoli1126@126.com. All rights reserved.
//
@import XCTest;

#import <SDWebImageAVIFCoder/SDImageAVIFCoder.h>
#import <SDWebImageAVIFCoder/Conversion.h>
#import <SDWebImageAVIFCoder/ColorSpace.h>

static UInt8 kBlack8[] = {0,0,0};
static UInt8 kGray8[] = {0x88,0x88,0x88};
static UInt8 kWhite8[] = {255,255,255};
static UInt8 kRed8[] = {255,0,0};
static UInt8 kGreen8[] = {0,255,0};
static UInt8 kBlue8[] = {0,0,255};
static UInt8 kSpecial8[] = {0xe4,0x7a,0x8c};

static UInt16 kBlack16[] = {0,0,0};
static UInt16 kGray16[] = {0x88 << 8,0x88 << 8,0x88 << 8};
static UInt16 kWhite16[] = {65535,65535,65535};
static UInt16 kRed16[] = {65535,0,0};
static UInt16 kGreen16[] = {0,65535,0};
static UInt16 kBlue16[] = {0,0,65535};
static UInt16 kSpecial16[] = {0xe4 << 8,0x7a << 8,0x8c << 8};

static avifNclxColourPrimaries const kNumPrimaries = AVIF_NCLX_COLOUR_PRIMARIES_EBU3213E;
static avifNclxTransferCharacteristics const kNumTransfers = AVIF_NCLX_TRANSFER_CHARACTERISTICS_BT2100_HLG;


// FIXME(ledyba-z): libavif does not respect MatrixCoefficients in AV1 Sequence Header.
// Instead, it uses ColorPrimaries to calculate MatrixCoefficients.
// This threashold can be less if libavif respects MatrixCoefficients...
int const threshold8 = 16;
int const threshold16 = 16 << 8;

@interface Tests : XCTestCase

{
    @private
    SDImageAVIFCoder* coder;
    NSMutableArray<NSDictionary*>* blackList;
    NSMutableArray<NSDictionary*>* whiteList;
    NSMutableArray<NSDictionary*>* grayList;
    NSMutableArray<NSDictionary*>* redList;
    NSMutableArray<NSDictionary*>* greenList;
    NSMutableArray<NSDictionary*>* blueList;
    NSMutableArray<NSDictionary*>* specialList;
}
@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    self->coder = [[SDImageAVIFCoder alloc] init];
    self->blackList = [[NSMutableArray alloc] init];
    self->whiteList = [[NSMutableArray alloc] init];
    self->grayList = [[NSMutableArray alloc] init];
    self->redList = [[NSMutableArray alloc] init];
    self->greenList = [[NSMutableArray alloc] init];
    self->blueList = [[NSMutableArray alloc] init];
    self->specialList = [[NSMutableArray alloc] init];

    NSString* listBundle = [[NSBundle mainBundle] pathForResource: @"image-list" ofType: @"tsv"];
    NSData* listContent = [NSData dataWithContentsOfFile: listBundle];
    NSString* listString = [[NSString alloc] initWithData:listContent encoding:NSUTF8StringEncoding];
    NSScanner *scanner = [NSScanner scannerWithString: listString];

    NSCharacterSet* nlSet = [NSCharacterSet newlineCharacterSet];
    while (![scanner isAtEnd]) {
        NSString* line;
        [scanner scanUpToCharactersFromSet:nlSet intoString:&line];
        NSMutableDictionary* item = [[NSMutableDictionary alloc] init];
        NSArray<NSString*>* items = [line componentsSeparatedByString:@"\t"];
        [item setValue:[items objectAtIndex:0] forKey:@"original"];
        [item setValue:[items objectAtIndex:1] forKey:@"converted"];
        
        NSString* converted = [items objectAtIndex:1];
        if([converted containsString: @"black"]) {
            [self->blackList addObject: item];
        }else if([converted containsString: @"white"]) {
            [self->whiteList addObject: item];
        }else if([converted containsString: @"gray"]) {
            [self->grayList addObject: item];
        }else if([converted containsString: @"red"]){
            [self->redList addObject: item];
        }else if([converted containsString: @"green"]){
            [self->greenList addObject: item];
        }else if([converted containsString: @"blue"]){
            [self->blueList addObject: item];
        }else if([converted containsString: @"e47a8c"]){
            [self->specialList addObject: item];
        }else{
            XCTAssert(false, "Unknown color: %@", converted);
        }
        [scanner scanCharactersFromSet:nlSet intoString:NULL];
    }
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testBlackTest
{
    [self assertImages:self->blackList colorName:@"black"
       expectedColor8: kBlack8 expectedNumComponents8:3
       expectedColor16:kBlack16 expectedNumComponents16:3];
}

- (void)testWhiteTest
{
    [self assertImages:self->whiteList colorName:@"white"
       expectedColor8: kWhite8 expectedNumComponents8:3
       expectedColor16:kWhite16 expectedNumComponents16:3];
}

- (void)testGrayTest
{
    [self assertImages:self->grayList colorName:@"gray"
       expectedColor8: kGray8 expectedNumComponents8:3
       expectedColor16:kGray16 expectedNumComponents16:3];
}

- (void)testRedTest
{
    [self assertImages:self->redList colorName:@"red"
       expectedColor8: kRed8 expectedNumComponents8:3
       expectedColor16:kRed16 expectedNumComponents16:3];
}

- (void)testGreenTest
{
    [self assertImages:self->greenList colorName:@"green"
       expectedColor8: kGreen8 expectedNumComponents8:3
       expectedColor16:kGreen16 expectedNumComponents16:3];
}

- (void)testBlueTest
{
    [self assertImages:self->blueList colorName:@"blue"
       expectedColor8: kBlue8 expectedNumComponents8:3
       expectedColor16:kBlue16 expectedNumComponents16:3];
}

- (void)testSpecialTest
{
    [self assertImages:self->specialList colorName:@"special"
       expectedColor8: kSpecial8 expectedNumComponents8:3
       expectedColor16:kSpecial16 expectedNumComponents16:3];
}

-(void)testAllColorSpaceSupportsOutput
{
    for(avifNclxColourPrimaries primaries = 0; primaries < kNumPrimaries; ++primaries) {
        for(avifNclxTransferCharacteristics transfer = 0; transfer < kNumTransfers; ++transfer) {
            CGColorSpaceRef space = NULL;
            
            space = SDAVIFCreateColorSpaceRGB(primaries, transfer);
            XCTAssertTrue(CGColorSpaceSupportsOutput(space));
            CGColorSpaceRelease(space);

            space = SDAVIFCreateColorSpaceMono(primaries, transfer);
            XCTAssertTrue(CGColorSpaceSupportsOutput(space));
            CGColorSpaceRelease(space);
        }

    }
}

-(void)testCalcNCLXColorSpaceFromAVIFImage
{
    avifImage* img = avifImageCreate(100, 100, 8, AVIF_PIXEL_FORMAT_YUV420);
    for(avifNclxColourPrimaries primaries = 0; primaries < kNumPrimaries; ++primaries) {
        for(avifNclxTransferCharacteristics transfer = 0; transfer < kNumTransfers; ++transfer) {
            avifNclxColorProfile nclx;
            nclx.colourPrimaries = primaries;
            nclx.transferCharacteristics = transfer;
            avifImageSetProfileNCLX(img, &nclx);
            avifImageAllocatePlanes(img, AVIF_PLANES_YUV);

            CGColorSpaceRef space = NULL;
            BOOL shouldRelease = FALSE;
            
            SDAVIFCalcColorSpaceRGB(img, &space, &shouldRelease);
            XCTAssertTrue(CGColorSpaceSupportsOutput(space));
            if(shouldRelease) {
                CGColorSpaceRelease(space);
            }
            
            // monochrome
            free(img->yuvPlanes[AVIF_CHAN_U]);
            img->yuvPlanes[AVIF_CHAN_U] = NULL;
            img->yuvRowBytes[AVIF_CHAN_U] = 0;
            free(img->yuvPlanes[AVIF_CHAN_V]);
            img->yuvPlanes[AVIF_CHAN_V] = NULL;
            img->yuvRowBytes[AVIF_CHAN_V] = 0;

            SDAVIFCalcColorSpaceMono(img, &space, &shouldRelease);
            XCTAssertTrue(CGColorSpaceSupportsOutput(space));
            if(shouldRelease) {
                CGColorSpaceRelease(space);
            }

            avifImageFreePlanes(img, AVIF_PLANES_ALL);
        }
    }
    avifImageDestroy(img);
}

-(void)testCalcICCColorSpaceFromAVIFImage
{
    NSData *iccProfile = (__bridge_transfer NSData *)CGColorSpaceCopyICCProfile([SDImageCoderHelper colorSpaceGetDeviceRGB]);
    avifImage* img = avifImageCreate(100, 100, 8, AVIF_PIXEL_FORMAT_YUV420);
    avifImageSetProfileICC(img, (uint8_t *)iccProfile.bytes, iccProfile.length);

    avifImageAllocatePlanes(img, AVIF_PLANES_YUV);

    CGColorSpaceRef space = NULL;
    BOOL shouldRelease = FALSE;

    SDAVIFCalcColorSpaceRGB(img, &space, &shouldRelease);
    XCTAssertTrue(CGColorSpaceSupportsOutput(space));
    if(shouldRelease) {
        CGColorSpaceRelease(space);
    }

    // monochrome
    free(img->yuvPlanes[AVIF_CHAN_U]);
    img->yuvPlanes[AVIF_CHAN_U] = NULL;
    img->yuvRowBytes[AVIF_CHAN_U] = 0;
    free(img->yuvPlanes[AVIF_CHAN_V]);
    img->yuvPlanes[AVIF_CHAN_V] = NULL;
    img->yuvRowBytes[AVIF_CHAN_V] = 0;

    SDAVIFCalcColorSpaceMono(img, &space, &shouldRelease);
    XCTAssertTrue(CGColorSpaceSupportsOutput(space));
    if(shouldRelease) {
        CGColorSpaceRelease(space);
    }

    avifImageFreePlanes(img, AVIF_PLANES_ALL);

    avifImageDestroy(img);
}

-(void)testEncodingAndDecoding
{
    CGSize size = CGSizeMake(100, 100);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData* encoded = [self->coder encodedDataWithImage:image format:SDImageFormatAVIF options:nil];
    image = nil;
    
    XCTAssertTrue([self->coder canDecodeFromData:encoded]);

    image = [self->coder decodedImageWithData:encoded options:nil];
    [self assertColor8:@"<in-memory>" img:image.CGImage expectedColor: kRed8];
}

-(void)assertColor8: (NSString*)filename img:(CGImageRef)img expectedColor:(UInt8*)expectedColor
{
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(img));
    UInt8* const buf = (UInt8 *) CFDataGetBytePtr(rawData);
    size_t const width = CGImageGetWidth(img);
    size_t const height = CGImageGetHeight(img);
    size_t const stride = CGImageGetBytesPerRow(img);
    size_t const bitsPerPixel = CGImageGetBitsPerPixel(img);
    size_t const bytesPerPixel = bitsPerPixel / 8;
    size_t const numComponents = bitsPerPixel / CGImageGetBitsPerComponent(img);
    XCTAssertEqual(numComponents, 3);
    XCTAssertEqual(bytesPerPixel, 3);
    for(size_t y = 0; y < height; ++y) {
        for(size_t x = 0; x < width; ++x) {
            UInt8* pix = (buf + (stride * y) + (bytesPerPixel * x));
            bool ok = true;
            for(size_t c = 0; c < 3; ++c) {
                int32_t result = pix[c];
                int32_t expected = expectedColor[c];
                XCTAssertTrue(ok = (abs(result - expected) <= threshold8),
                              "(x: %ld, y: %ld, c:%ld): result=%d vs expected=%d (%@)",
                              x, y, c, result, expected, filename);
            }
            if(!ok) {
                goto end;
            }
        }
    }
end:
    CFRelease(rawData);
}

-(void)assertColorAlpha8: (NSString*)filename img:(CGImageRef)img expectedColor:(UInt8*)expectedColor
{
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(img));
    UInt8* const buf = (UInt8 *) CFDataGetBytePtr(rawData);
    size_t const width = CGImageGetWidth(img);
    size_t const height = CGImageGetHeight(img);
    size_t const stride = CGImageGetBytesPerRow(img);
    size_t const bitsPerPixel = CGImageGetBitsPerPixel(img);
    size_t const bytesPerPixel = bitsPerPixel / 8;
    size_t const numComponents = bitsPerPixel / CGImageGetBitsPerComponent(img);
    XCTAssertEqual(numComponents, 4);
    XCTAssertEqual(bytesPerPixel, 4);
    for(size_t y = 0; y < height; ++y) {
        for(size_t x = 64; x < width; x+=128) {
            UInt8* pix = (buf + (stride * y) + (bytesPerPixel * x));
            bool ok = true;
            for(size_t c = 1; c < 4; ++c) {
                int32_t result = pix[c];
                int32_t expected = expectedColor[c-1];
                XCTAssertTrue(ok &= (abs(result - expected) <= threshold8),
                              "(x: %ld, y: %ld, c:%ld): result=%d vs expected=%d (%@)",
                              x, y, c, result, expected, filename);
            }
            XCTAssertTrue(ok &= (pix[0] == (x < 128 ? 0xff : 0x00)),
                          "(x: %ld, y: %ld, c: alpha): result=%d vs expected=%d (%@)",
                          x, y, pix[0], x < 128 ? 0xff : 0x00, filename);
            if(!ok) {
                goto end;
            }
        }
    }
end:
    CFRelease(rawData);
}

-(void)assertColor16: (NSString*)filename img:(CGImageRef)img expectedColor:(UInt16*)expectedColor
{
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(img));
    UInt8* const buf = (UInt8 *) CFDataGetBytePtr(rawData);
    size_t const width = CGImageGetWidth(img);
    size_t const height = CGImageGetHeight(img);
    size_t const stride = CGImageGetBytesPerRow(img);
    size_t const bitsPerPixel = CGImageGetBitsPerPixel(img);
    size_t const bytesPerPixel = bitsPerPixel / 8;
    size_t const numComponents = bitsPerPixel / CGImageGetBitsPerComponent(img);
    XCTAssertEqual(numComponents, 3);
    XCTAssertEqual(bytesPerPixel, 6);
    for(size_t y = 0; y < height; ++y) {
        for(size_t x = 0; x < width; ++x) {
            UInt16* pix = (UInt16*)(buf + (stride * y) + (bytesPerPixel * x));
            bool ok = true;
            for(size_t c = 0; c < 3; ++c) {
                int32_t result = pix[c];
                int32_t expected = expectedColor[c];
                XCTAssertTrue(ok &= (abs(result - expected) <= threshold16),
                              "(x: %ld, y: %ld, c:%ld): result=%d vs expected=%d (%@)",
                              x, y, c, result, expected, filename);
            }
            if(!ok) {
                goto end;
            }
        }
    }
end:
    CFRelease(rawData);
}

-(void)assertColorAlpha16: (NSString*)filename img:(CGImageRef)img expectedColor:(UInt16*)expectedColor
{
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(img));
    UInt8* const buf = (UInt8 *) CFDataGetBytePtr(rawData);
    size_t const width = CGImageGetWidth(img);
    size_t const height = CGImageGetHeight(img);
    size_t const stride = CGImageGetBytesPerRow(img);
    size_t const bitsPerPixel = CGImageGetBitsPerPixel(img);
    size_t const bytesPerPixel = bitsPerPixel / 8;
    size_t const numComponents = bitsPerPixel / CGImageGetBitsPerComponent(img);
    XCTAssertEqual(numComponents, 4);
    XCTAssertEqual(bytesPerPixel, 8);
    for(size_t y = 0; y < height; ++y) {
        for(size_t x = 64; x < width; x+=128) {
            UInt16* pix = (UInt16*)(buf + (stride * y) + (bytesPerPixel * x));
            bool ok = true;
            for(size_t c = 1; c < 4; ++c) {
                int32_t result = pix[c];
                int32_t expected = expectedColor[c-1];
                XCTAssertTrue(ok &= (abs(result - expected) <= threshold16),
                              "(x: %ld, y: %ld, c:%ld): result=%d vs expected=%d (%@)",
                              x, y, c, result, expected, filename);
            }
            XCTAssertTrue(ok &= (pix[0] == (x < 128 ? 0xffff : 0x0000)),
                          "(x: %ld, y: %ld, c: alpha): result=%d vs expected=%d (%@)",
                          x, y, pix[0], x < 128 ? 0xffff : 0x00, filename);
            if(!ok) {
                goto end;
            }
        }
    }
end:
    CFRelease(rawData);
}

-(void)assertMono8: (NSString*)filename img:(CGImageRef)img
{
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(img));
    UInt8* const buf = (UInt8 *) CFDataGetBytePtr(rawData);
    size_t const width = CGImageGetWidth(img);
    size_t const height = CGImageGetHeight(img);
    size_t const stride = CGImageGetBytesPerRow(img);
    size_t const bitsPerPixel = CGImageGetBitsPerPixel(img);
    size_t const bytesPerPixel = bitsPerPixel/8;
    size_t const numComponents = bitsPerPixel / CGImageGetBitsPerComponent(img);
    XCTAssertEqual(numComponents, 1);
    XCTAssertEqual(bytesPerPixel, 1);
    UInt8 const pix0 = *buf;
    for(size_t y = 0; y < height; ++y) {
        for(size_t x = 0; x < width; ++x) {
            bool ok = true;
            UInt8* pix = (buf + (stride * y) + (bytesPerPixel * x));
            XCTAssertTrue(ok &= (abs(pix0 - *pix) <= threshold8),
                          "(x: %ld, y: %ld): result=%d vs expected=%d (%@)",
                          x, y, *pix, pix0, filename);
            if(!ok) {
                goto end;
            }
        }
    }
end:
    CFRelease(rawData);
}

-(void)assertMonoAlpha8: (NSString*)filename img:(CGImageRef)img
{
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(img));
    UInt8* const buf = (UInt8 *) CFDataGetBytePtr(rawData);
    size_t const width = CGImageGetWidth(img);
    size_t const height = CGImageGetHeight(img);
    size_t const stride = CGImageGetBytesPerRow(img);
    size_t const bitsPerPixel = CGImageGetBitsPerPixel(img);
    size_t const bytesPerPixel = bitsPerPixel/8;
    size_t const numComponents = bitsPerPixel / CGImageGetBitsPerComponent(img);
    XCTAssertEqual(numComponents, 2);
    XCTAssertEqual(bytesPerPixel, 2);
    UInt8 const pix0 = buf[1];
    for(size_t y = 0; y < height; ++y) {
        for(size_t x = 64; x < width; x+=128) {
            bool ok = true;
            UInt8* pix = (buf + (stride * y) + (bytesPerPixel * x));
            XCTAssertTrue(ok &= (abs(pix0 - pix[1]) <= threshold8),
                          "(x: %ld, y: %ld, c: mono): result=%d vs expected=%d (%@)",
                          x, y, pix[1], pix0, filename);
            XCTAssertTrue(ok &= (pix[0] == (x < 128 ? 0xff : 0x00)),
                          "(x: %ld, y: %ld, c: alpha): result=%d vs expected=%d (%@)",
                          x, y, pix[0], x < 128 ? 0xff : 0x00, filename);
            if(!ok) {
                goto end;
            }
        }
    }
end:
    CFRelease(rawData);
}


-(void)assertMono16: (NSString*)filename img:(CGImageRef)img
{
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(img));
    UInt8* const buf = (UInt8 *) CFDataGetBytePtr(rawData);
    size_t const width = CGImageGetWidth(img);
    size_t const height = CGImageGetHeight(img);
    size_t const stride = CGImageGetBytesPerRow(img);
    size_t const bitsPerPixel = CGImageGetBitsPerPixel(img);
    size_t const bytesPerPixel = bitsPerPixel/8;
    size_t const numComponents = bitsPerPixel / CGImageGetBitsPerComponent(img);
    XCTAssertEqual(numComponents, 1);
    XCTAssertEqual(bytesPerPixel, 2);
    UInt16 const pix0 = *((UInt16*)buf);
    for(size_t y = 0; y < height; ++y) {
        for(size_t x = 0; x < width; ++x) {
            UInt16* pix = (UInt16*)(buf + (stride * y) + (bytesPerPixel * x));
            bool ok = true;
            XCTAssertTrue(ok &= (abs(pix0 - *pix) <= threshold16),
                          "(x: %ld, y: %ld): result=%d vs expected=%d (%@)",
                          x, y, *pix, pix0, filename);
            if(!ok) {
                goto end;
            }
        }
    }
end:
    CFRelease(rawData);
}

-(void)assertMonoAlpha16: (NSString*)filename img:(CGImageRef)img
{
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(img));
    UInt8* const buf = (UInt8 *) CFDataGetBytePtr(rawData);
    size_t const width = CGImageGetWidth(img);
    size_t const height = CGImageGetHeight(img);
    size_t const stride = CGImageGetBytesPerRow(img);
    size_t const bitsPerPixel = CGImageGetBitsPerPixel(img);
    size_t const bytesPerPixel = bitsPerPixel/8;
    size_t const numComponents = bitsPerPixel / CGImageGetBitsPerComponent(img);
    XCTAssertEqual(numComponents, 2);
    XCTAssertEqual(bytesPerPixel, 4);
    UInt16 const pix0 = ((UInt16*)buf)[1];
    for(size_t y = 0; y < height; ++y) {
        for(size_t x = 64; x < width; x+=128) {
            UInt16* pix = (UInt16*)(buf + (stride * y) + (bytesPerPixel * x));
            bool ok = true;
            XCTAssertTrue(ok &= (abs(pix0 - pix[1]) <= threshold16),
                          "(x: %ld, y: %ld): result=%d vs expected=%d (%@)",
                          x, y, pix[1], pix0, filename);
            XCTAssertTrue(ok &= (pix[0] == (x < 128 ? 0xffff : 0x0000)),
                          "(x: %ld, y: %ld, c: alpha): result=%d vs expected=%d (%@)",
                          x, y, pix[0], x < 128 ? 0xffff : 0x0000, filename);
            if(!ok) {
                goto end;
            }
        }
    }
end:
    CFRelease(rawData);
}

- (void)assertImages: (NSMutableArray*) list colorName:(NSString*)colorName expectedColor8:(UInt8*)expectedColor8 expectedNumComponents8:(size_t)expectedNumComponents8
    expectedColor16:(UInt16*)expectedColor16 expectedNumComponents16:(size_t)expectedNumComponents16
{
    NSLog(@"Testing %lu [%@] images", list.count, colorName);
    [list enumerateObjectsUsingBlock:^(NSDictionary* item, NSUInteger idx, BOOL *stop) {
        NSString* convertedFilename = [item objectForKey:@"converted"];
        NSArray<NSString*>* items = [convertedFilename componentsSeparatedByString:@"."];
        NSString* base = [items objectAtIndex:0];
        NSString* size = [items objectAtIndex:1];
        NSString* bpc = [items objectAtIndex:2];
        NSString* fmt = [items objectAtIndex:3];
        NSString* color = [items objectAtIndex:4];
        NSString* range = [items objectAtIndex:5];
        NSString* alpha = [items objectAtIndex:6];
        NSString* ext = [items objectAtIndex:7];
        assert([ext isEqual: @"avif"]);
        NSLog(@"Testing: %@/%@/%@/%@/%@/%@/%@", base, size, bpc, fmt, color, range, alpha);

        NSString* imgBundle = [[NSBundle mainBundle] pathForResource: convertedFilename ofType: @""];
        NSData* imgData = [[NSData alloc] initWithContentsOfFile: imgBundle];
        

        UIImage* img = [self->coder decodedImageWithData: imgData options:nil];

        bool hdr = CGImageGetBitsPerComponent(img.CGImage) != 8;
        if([color isEqualToString: @"mono"]){
            if(!hdr) {
                if([alpha isEqualToString:@"with-alpha"]) {
                    [self assertMonoAlpha8: convertedFilename img:img.CGImage];
                }else{
                    [self assertMono8: convertedFilename img:img.CGImage];
                }
            }else{
                if([alpha isEqualToString:@"with-alpha"]) {
                    [self assertMonoAlpha16: convertedFilename img:img.CGImage];
                }else{
                    [self assertMono16: convertedFilename img:img.CGImage];
                }
            }
        } else {
            if(!hdr) {
                if([alpha isEqualToString:@"with-alpha"]) {
                    [self assertColorAlpha8: convertedFilename img:img.CGImage expectedColor:expectedColor8];
                } else {
                    [self assertColor8: convertedFilename img:img.CGImage expectedColor:expectedColor8];
                }
            } else {
                if([alpha isEqualToString:@"with-alpha"]) {
                    [self assertColorAlpha16: convertedFilename img:img.CGImage expectedColor:expectedColor16];
                } else {
                    [self assertColor16: convertedFilename img:img.CGImage expectedColor:expectedColor16];
                }
            }
        }
    }];
}

@end

