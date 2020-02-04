//
//  main.m
//  SDWebImageAVIFCoder_CITestRunner
//
//  Created by psi on 2020/02/04.
//  Copyright © 2020 lizhuoli1126@126.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SDWebImage/SDWebImage.h>
#import <SDWebImageAVIFCoder/SDImageAVIFCoder.h>

int main(int argc, const char * argv[]) {
    if(argc != 3) {
        fprintf(stderr, "usage: %s <inputPath> <outputPath>\n", argv[0]);
        return -1;
    }
    @autoreleasepool {
        NSString* inputPath = [NSString stringWithUTF8String: argv[1]];
        NSString* outputPath = [NSString stringWithUTF8String: argv[2]];
        NSData* data = [[NSData alloc] initWithContentsOfFile: inputPath];
        SDImageAVIFCoder* const coder = [SDImageAVIFCoder sharedCoder];
        UIImage* img = [coder decodedImageWithData: data options:nil];
        
        CGImageRef cgRef = [img CGImageForProposedRect:nil context:nil hints:nil];
        NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
        [newRep setSize:[img size]];   // if you want the same resolution
        NSDictionary *prop = [[NSDictionary alloc] init];
        NSData* pngData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties: prop];
        [pngData writeToFile:outputPath atomically:YES];
    }
    return 0;
}
