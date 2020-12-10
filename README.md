# Waifu2x iOS

Free and easy to use waifu2x application on iOS.

## Screenshot

![screenshot 1](1.png)

![screenshot 2](2.png)

![screenshot 3](3.png)

### Compile

```bash
# clone this repo
git clone https://github.com/BlueCocoa/waifu2x-ios
cd waifu2x-ios && export SRCROOT=`pwd`

# download and unarchive Vuklan SDK for macOS to waifu2x-ios/Vulkan_SDK
# at the time of writing, latest SDK is https://vulkan.lunarg.com/sdk/home#sdk/downloadConfirm/1.2.154.0/mac/vulkansdk-macos-1.2.154.0.dmg
https://vulkan.lunarg.com/sdk/home#mac
```

Also you need to set the code sign in Xcode.

Then you can build `waifu2x-ios` with Xcode in either GUI mode or by invoking `xcodebuild` in terminal.

You might encounter some errors (see example below) at the first couple of compiling tries. (Because CMake needs to generate some files). Just ignore the errors and try to compile 2-4 times, it should be alright.

```
error: Build input file cannot be found: '/Users/cocoa/src/waifu2x-ios/waifu2x-ncnn-vulkan/src/ncnn/build-apple/src/layer/arm/unaryop_arm_arm82.cpp' (in target 'ncnn' from project 'ncnn')
```

The run script is baked in Xcode project, basically, it does these work for you.

```bash
# setup environment variables
export VULKAN_SDK="${SRCROOT}/VulkanSDK"
export VULKAN_LIB="${VULKAN_SDK}/MoltenVK/MoltenVK.xcframework/ios-arm64/libMoltenVK.a"

# init dependencies
git submodule update --init --recursive

# SRCROOT is the root directory of this repo
if [ ! -d "${SRCROOT}/waifu2x-ncnn-vulkan/src/ncnn/build-apple" ]; then
    mkdir -p "${SRCROOT}/waifu2x-ncnn-vulkan/src/ncnn/build-apple"
    cd "${SRCROOT}/waifu2x-ncnn-vulkan/src/ncnn/build-apple"
    cmake -GXcode -DCMAKE_BUILD_TYPE=Release \
        -DNCNN_BUILD_BENCHMARK=OFF \
        -DNCNN_BUILD_TESTS=OFF \
        -DNCNN_BUILD_TOOLS=OFF \
        -DNCNN_BUILD_EXAMPLES=OFF \
        -DCMAKE_TOOLCHAIN_FILE="${SRCROOT}/waifu2x-ncnn-vulkan/src/ncnn/toolchains/ios.toolchain.cmake" \
        -DIOS_PLATFORM=OS64 \
        -DIOS_DEPLOYMENT_TARGET=11.0 \
        -DVulkan_LIBRARY="${VULKAN_LIB}" \
        -DVulkan_INCLUDE_DIR="${VULKAN_SDK}/MoltenVK/include" \
        -DNCNN_VULKAN=ON \
        ..
fi
```

## Acknowledgement

1. SVProgressHUD - https://github.com/SVProgressHUD/SVProgressHUD
2. waifu2x-ncnn-vulkan - https://github.com/nihui/waifu2x-ncnn-vulkan
3. libwebp - https://github.com/webmproject/libwebp.git
4. ncnn - https://github.com/Tencent/ncnn
5. glslang - https://github.com/KhronosGroup/glslang
6. Icon - https://www.flaticon.com/free-icon/zoom-in_3670592



