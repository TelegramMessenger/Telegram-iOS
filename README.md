
# rlottie [![Build Status](https://travis-ci.org/Samsung/rlottie.svg?branch=master)](https://travis-ci.org/Samsung/rlottie)

rlottie is a platform independent standalone c++ library for rendering vector based animations and art in realtime.

Lottie loads and renders animations and vectors exported in the bodymovin JSON format. Bodymovin JSON can be created and exported from After Effects with [bodymovin](https://github.com/bodymovin/bodymovin), Sketch with [Lottie Sketch Export](https://github.com/buba447/Lottie-Sketch-Export), and from [Haiku](https://www.haiku.ai).

For the first time, designers can create and ship beautiful animations without an engineer painstakingly recreating it by hand. Since the animation is backed by JSON they are extremely small in size but can be large in complexity! 

Here is just a small sampling of the power of Lottie

For resource test, please visit rlottie online viewer:
http://www.rlottie.com

Query about rlottie or request troubleshooting online, please visit Gitter:
https://gitter.im/rLottie-dev/community#

## Contents
- [Building Lottie](#building-lottie)
	- [Meson Build](#meson-build)
	- [Cmake Build](#cmake-build)
	- [Test](#test)
- [Demo](#demo)
- [Dynamic Property](#dynamic-property)
- [Quick Start](#quick-start)
- [Supported After Effects Features](#supported-after-effects-features)
- [Issues or Feature Requests?](#issues-or-feature-requests)

## Building Lottie
rottie supports [meson](https://mesonbuild.com/) and [cmake](https://cmake.org/) build system. rottie is written in ***C++14***. and has a public dependancy of ***C++11***

### Meson Build
install [meson](http://mesonbuild.com/Getting-meson.html) and [ninja](https://ninja-build.org/) if not already installed.

Run meson to configure rlottie
```
meson build
```
Run ninja to build rlottie
```
ninja -C build
```

### Cmake Build

Install [cmake](https://cmake.org/download/) if not already installed

Create a build directory for out of source build
```
mkdir build
```
Run cmake command inside build directory to configure rlottie.
```
cd build
cmake -DLIB_INSTALL_DIR=/usr/lib ..

# install to a different prefix. eg ~/test/lib

cmake -DCMAKE_INSTALL_PREFIX=~/test -DLIB_INSTALL_DIR=lib ..

```
Run make to build rlottie

```
make -j 2
```
To install rlottie library

```
make install
```

### Test

Configure to build test
```
meson configure -Dtest=true
```
Build test suit

```
ninja
```
Run test suit
```
ninja test
```
[Back to contents](#contents)

#
## Demo

Update me

#
## Dynamic Property

Update me.

#
## Quick Start

Update me.

[Back to contents](#contents)

#
## Supported After Effects Features

| **Shapes** | **Supported** |
|:--|:-:|
| Shape | 👍 |
| Ellipse | 👍 |
| Rectangle | 👍 |
| Rounded Rectangle | 👍 |
| Polystar | 👍 |
| Group | 👍 |
| Trim Path (individually) | 👍 |
| Trim Path (simultaneously) | 👍 |
| **Renderable** | **Supported** |
| Fill  | 👍 |
| Stroke | 👍 |
| Radial Gradient | 👍 |
| Linear Gradient | 👍 | 
| Gradient Stroke | 👍 | 
| **Transforms** | **Supported** |
| Position | 👍 |
| Position (separated X/Y) | 👍 |
| Scale | 👍 |
| Skew | ⛔️ |
| Rotation | 👍 | 
| Anchor Point | 👍 |
| Opacity | 👍 |
| Parenting | 👍 |
| Auto Orient | 👍 |
| **Interpolation** | **Supported** |
| Linear Interpolation | 👍 |
| Bezier Interpolation | 👍 |
| Hold Interpolation | 👍 |
| Spatial Bezier Interpolation | 👍 |
| Rove Across Time | 👍 |
| **Masks** | **Supported** |
| Mask Path | 👍 |
| Mask Opacity | 👍 |
| Add | 👍 |
| Subtract | 👍 |
| Intersect | 👍 |
| Lighten | ⛔️ |
| Darken | ⛔️ |
| Difference | ⛔️ |
| Expansion | ⛔️ |
| Feather | ⛔️ |
| **Mattes** | **Supported** |
| Alpha Matte | 👍 |
| Alpha Inverted Matte | 👍 |
| Luma Matte | 👍 |
| Luma Inverted Matte | 👍 |
| **Merge Paths** | **Supported** |
| Merge | ⛔️ |
| Add | ⛔️ |
| Subtract | ⛔️ |
| Intersect | ⛔️ |
| Exclude Intersection | ⛔️ |
| **Layer Effects** | **Supported** |
| Fill | ⛔️ |
| Stroke | ⛔️ |
| Tint | ⛔️ |
| Tritone | ⛔️ |
| Levels Individual Controls | ⛔️ |
| **Text** | **Supported** |
| Glyphs |  ⛔️ | 
| Fonts | ⛔️ |
| Transform | ⛔️ |
| Fill | ⛔️ | 
| Stroke | ⛔️ | 
| Tracking | ⛔️ | 
| Anchor point grouping | ⛔️ | 
| Text Path | ⛔️ |
| Per-character 3D | ⛔️ |
| Range selector (Units) | ⛔️ |
| Range selector (Based on) | ⛔️ |
| Range selector (Amount) | ⛔️ |
| Range selector (Shape) | ⛔️ |
| Range selector (Ease High) | ⛔️ |
| Range selector (Ease Low)  | ⛔️ |
| Range selector (Randomize order) | ⛔️ |
| expression selector | ⛔️ |
| **Other** | **Supported** |
| Expressions | ⛔️ |
| Images | 👍 |
| Precomps | 👍 |
| Time Stretch |  👍 |
| Time remap |  👍 |
| Markers | ⛔️ |

#
[Back to contents](#contents)

## Issues or Feature Requests?
File github issues for anything that is broken. Be sure to check the [list of supported features](#supported-after-effects-features) before submitting.  If an animation is not working, please attach the After Effects file to your issue. Debugging without the original can be very difficult. For immidiate assistant or support please reach us in [Gitter](https://gitter.im/rLottie-dev/community#)
