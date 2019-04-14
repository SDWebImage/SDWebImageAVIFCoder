# SDWebImageAVIFCoder

[![CI Status](https://img.shields.io/travis/SDWebImage/SDWebImageAVIFCoder.svg?style=flat)](https://travis-ci.org/SDWebImage/SDWebImageAVIFCoder)
[![Version](https://img.shields.io/cocoapods/v/SDWebImageAVIFCoder.svg?style=flat)](https://cocoapods.org/pods/SDWebImageAVIFCoder)
[![License](https://img.shields.io/cocoapods/l/SDWebImageAVIFCoder.svg?style=flat)](https://cocoapods.org/pods/SDWebImageAVIFCoder)
[![Platform](https://img.shields.io/cocoapods/p/SDWebImageAVIFCoder.svg?style=flat)](https://cocoapods.org/pods/SDWebImageAVIFCoder)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/SDWebImage/SDWebImageAVIFCoder)

## What's for

This is a [SDWebImage](https://github.com/rs/SDWebImage) coder plugin to add [AV1 Image File Format (AVIF)](https://aomediacodec.github.io/av1-avif/) support. Which is built based on the open-sourced [libavif](https://github.com/joedrago/avif) codec.

This AVIF coder plugin currently support AVIF still image **decoding**. Including alpha channel, as well as 10bit/12bit HDR images.

The AVIF encoding is not currently support, because the software-based encoding speed is really slow. Need to wait for better enc implementation.

Note: AVIF image spec is still in evolve. And the current AVIF codec is a simple implementation.

Since AVIF is AV1-based inside HEIF image container. In the future, this repo may moved to existing HEIF coder plugin [SDWebImageHEIFCoder](https://github.com/SDWebImage/SDWebImageHEIFCoder) instead. 

## Requirements

+ iOS 8
+ tvOS 9.0
+ macOS 10.10
+ watchOS 2.0

## Installation

#### CocoaPods
SDWebImageAVIFCoder is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SDWebImageAVIFCoder'
```

#### Carthage

SDWebImageAVIFCoder is available through [Carthage](https://github.com/Carthage/Carthage).

```
github "SDWebImage/SDWebImageAVIFCoder"
```

## Usage

To use AVIF coder, you should firstly add the `SDImageAVIFCoder.sharedCoder` to the coders manager. Then you can call the View Category method to start load AVIF images.

+ Objective-C

```objective-c
SDImageAVIFCoder *AVIFCoder = SDImageAVIFCoder.sharedCoder;
[[SDImageCodersManager sharedManager] addCoder:AVIFCoder];
UIImageView *imageView;
[imageView sd_setImageWithURL:url];
```

+ Swift

```swift
let AVIFCoder = SDImageAVIFCoder.shared
SDImageCodersManager.shared.addCoder(AVIFCoder)
let imageView: UIImageView
imageView.sd_setImage(with: url)
```

## Screenshot

<img src="https://raw.githubusercontent.com/SDWebImage/SDWebImageAVIFCoder/master/Example/Screenshot/AVIFDemo.png" width="300" />
<img src="https://raw.githubusercontent.com/SDWebImage/SDWebImageAVIFCoder/master/Example/Screenshot/AVIFDemo-macOS.png" width="600" />

The images are from [AV1 Still Image File Format Specification](https://github.com/AOMediaCodec/av1-avif/tree/master/testFiles)

## Author

DreamPiggy, lizhuoli1126@126.com

## License

SDWebImageAVIFCoder is available under the MIT license. See the LICENSE file for more info.

## Thanks

+ [libavif](https://github.com/joedrago/avif)
+ [aom](https://aomedia.googlesource.com/aom/)


