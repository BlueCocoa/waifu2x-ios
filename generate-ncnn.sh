#!/bin/sh


export VULKAN_SDK="${SRCROOT}/VulkanSDK"
export VULKAN_LIB="${VULKAN_SDK}/MoltenVK/MoltenVK.xcframework/ios-arm64/libMoltenVK.a"
if [ ! -e "${VULKAN_LIB}" ]; then
    echo "Please download and unarchive VulkanSDK to ${VULKAN_SDK}."
    exit -1
fi

echo "[+] Recursive downloading dependences..."
if [ ! -d "${SRCROOT}/waifu2x-ncnn-vulkan/src/ncnn/build-apple" ]; then
    cd "${SRCROOT}/waifu2x-ncnn-vulkan"
    git submodule update --init src/libwebp
    rm -rf src/ncnn
    git clone --depth=1 https://github.com/Tencent/ncnn src/ncnn
    mkdir -p "${SRCROOT}/waifu2x-ncnn-vulkan/src/ncnn/build-apple"
    cd "${SRCROOT}/waifu2x-ncnn-vulkan/src/ncnn"
    git submodule update --init
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

# waifu2x-ncnn-vulkan
# generate shader spv hex files
if [ ! -d "${SRCROOT}/waifu2x-ncnn-vulkan/src/gen-shader-spv-hex" ]; then
    cp -rf "${SRCROOT}/waifu2x-ncnn-vulkan-shader-spv-hex" "${SRCROOT}/waifu2x-ncnn-vulkan/src/gen-shader-spv-hex"
    cd "${SRCROOT}/waifu2x-ncnn-vulkan/src/gen-shader-spv-hex"
    mkdir -p build-shader && cd build-shader
    VULKAN_SDK="${SRCROOT}/VulkanSDK/macOS" cmake \
        -DVulkan_LIBRARY="${VULKAN_LIB}" \
        -DVulkan_INCLUDE_DIR="${VULKAN_SDK}/MoltenVK/include" \
        -DCMAKE_TOOLCHAIN_FILE="${SRCROOT}/waifu2x-ncnn-vulkan/src/ncnn/toolchains/ios.toolchain.cmake" \
        -DIOS_PLATFORM=OS64 \
        -DIOS_DEPLOYMENT_TARGET=11.0 \
        ..
    cmake --build .
    cp -f *.h "${SRCROOT}/waifu2x-ios"
fi

cd "${SRCROOT}"
git submodule update realsr-ncnn-vulkan
# realsr-ncnn-vulkan
# generate shader spv hex files
if [ ! -d "${SRCROOT}/realsr-ncnn-vulkan/src/gen-shader-spv-hex" ]; then
    cp -rf "${SRCROOT}/realsr-ncnn-vulkan-shader-spv-hex" "${SRCROOT}/realsr-ncnn-vulkan/src/gen-shader-spv-hex"
    cd "${SRCROOT}/realsr-ncnn-vulkan/src/gen-shader-spv-hex"
    mkdir -p build-shader && cd build-shader
    VULKAN_SDK="${SRCROOT}/VulkanSDK/macOS" cmake \
        -DVulkan_LIBRARY="${VULKAN_LIB}" \
        -DVulkan_INCLUDE_DIR="${VULKAN_SDK}/MoltenVK/include" \
        -DCMAKE_TOOLCHAIN_FILE="${SRCROOT}/waifu2x-ncnn-vulkan/src/ncnn/toolchains/ios.toolchain.cmake" \
        -DIOS_PLATFORM=OS64 \
        -DIOS_DEPLOYMENT_TARGET=11.0 \
        ..
    cmake --build .
    cp -f *.h "${SRCROOT}/waifu2x-ios"
fi

mkdir -p "${SRCROOT}/waifu2x-ios/models"
copy_models() {
    if [ ! -d "${SRCROOT}/waifu2x-ios/models/$1" ]; then
        cp -rf "$2/$1" "${SRCROOT}/waifu2x-ios/models/$1"
    fi
}
copy_models "models-cunet" "${SRCROOT}/waifu2x-ncnn-vulkan/models"
copy_models "models-upconv_7_photo" "${SRCROOT}/waifu2x-ncnn-vulkan/models"
copy_models "models-upconv_7_anime_style_art_rgb" "${SRCROOT}/waifu2x-ncnn-vulkan/models"
copy_models "models-DF2K" "${SRCROOT}/realsr-ncnn-vulkan/models"
copy_models "models-DF2K_JPEG" "${SRCROOT}/realsr-ncnn-vulkan/models"
