# SDWebImageAVIFCoder

[![CI Status](https://img.shields.io/travis/SDWebImage/SDWebImageAVIFCoder.svg?style=flat)](https://travis-ci.org/SDWebImage/SDWebImageAVIFCoder)
[![Version](https://img.shields.io/cocoapods/v/SDWebImageAVIFCoder.svg?style=flat)](https://cocoapods.org/pods/SDWebImageAVIFCoder)
[![License](https://img.shields.io/cocoapods/l/SDWebImageAVIFCoder.svg?style=flat)](https://cocoapods.org/pods/SDWebImageAVIFCoder)
[![Platform](https://img.shields.io/cocoapods/p/SDWebImageAVIFCoder.svg?style=flat)](https://cocoapods.org/pods/SDWebImageAVIFCoder)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/SDWebImage/SDWebImageAVIFCoder)

## What's for

This is a [SDWebImage](https://github.com/rs/SDWebImage) coder plugin to add [AV1 Image File Format (AVIF)](https://aomediacodec.github.io/av1-avif/) support. Which is built based on the open-sourced [libavif](https://github.com/AOMediaCodec/libavif) codec.

This AVIF coder plugin currently support AVIF still image **decoding**. Including alpha channel, as well as 10bit/12bit HDR images.

The AVIF encoding is also supported now. Which always encode as 8-bit depth images.

## Note

AVIF image spec is still in evolve. And the current upstream AVIF codec is a simple implementation. The encoding time may be long for large images.

Since we rely on the external codec libavif. We may periodically update the dependency and bump version. Make sure you're using the latest version as possible as you can :)

## aom && dav1d

libavif is a still image codec. But AVIF is based on the AV1 Video standard. So it need a AV1 codec for support. This relationship is just like HEIF(image) and HEVC(video) codec.

By default, libavif is built with [aom](https://aomedia.googlesource.com/aom/) codec support. aom is the first AV1 codec during the standard draft implementation.

[dav1d](https://github.com/videolan/dav1d) is the new and next generation AV1 codec, focused on speed and correctness.

From v0.3.0, libavif can built with dav1d. For CocoaPods user, you can simply use the subspec for this. Carthage for optional dav1d codec is not supported currently.

## Requirements

+ iOS 8
+ macOS 10.10
+ tvOS 9.0
+ watchOS 2.0

## Installation

#### CocoaPods
SDWebImageAVIFCoder is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SDWebImageAVIFCoder'
```

Note: From version 0.4.0, if you want to use dav1d instead aom for libavif which we dependent on, control the subspec of libavif instead:

```ruby
pod 'SDWebImageAVIFCoder'
pod 'libavif/libdav1d'
```

Note: From version 0.2.0, the dependency libavif and libaom use the portable C implementation to works on Apple platforms. If you need the pre-built library with SIMD/AVX and assembly optimization, try the 0.1.0 version. 

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

<img src="https://raw.githubusercontent.com/SDWebImage/SDWebImageAVIFCoder/master/Example/Screenshot/AVIFDemo-iOS.png" width="300" />
<img src="https://raw.githubusercontent.com/SDWebImage/SDWebImageAVIFCoder/master/Example/Screenshot/AVIFDemo-macOS.png" width="600" />

The images are from [AV1 Still Image File Format Specification Test Files](https://github.com/AOMediaCodec/av1-avif/tree/master/testFiles).

## AVIF Image Viewer

AVIF is a new image format, which lack of related toolchains like Browser or Desktop Viewer support.

You can try [AVIFQuickLook](https://github.com/dreampiggy/AVIFQuickLook) QuickLook plugin on macOS to view it in Finder.

You can also try using [avif.js](https://kagami.github.io/avif.js/) to view it online by using Chrome's AV1 codec.

## Author

DreamPiggy, lizhuoli1126@126.com

## License

SDWebImageAVIFCoder is available under the MIT license. See the LICENSE file for more info.

## Thanks

+ [libavif](https://github.com/AOMediaCodec/libavif)
+ [aom](https://aomedia.googlesource.com/aom/)
+ [AVIFQuickLook](https://github.com/dreampiggy/AVIFQuickLook)
+ [avif.js](https://github.com/Kagami/avif.js)


