// waifu2x implemented with ncnn library

#ifndef WAIFU2X_H
#define WAIFU2X_H

#include <string>

// ncnn
#include "net.h"
#include "gpu.h"
#include "layer.h"

typedef void (^waifu2xProcessPercentageCallback)(float progress);

class Waifu2x
{
public:
    enum Mode {
        waifu2x = 1,
        realsr
    };
public:
    Waifu2x(int gpuid, bool tta_mode = false, Mode mode = Mode::waifu2x);
    ~Waifu2x();

    int load(const std::string& parampath, const std::string& modelpath);

    int process(const ncnn::Mat& inimage, ncnn::Mat& outimage, waifu2xProcessPercentageCallback cb) const;

public:
    // waifu2x parameters
    int noise;
    int scale;
    int tilesize;
    int prepadding;
    
    Mode mode;

private:
    ncnn::Net net;
    ncnn::Pipeline* waifu2x_preproc;
    ncnn::Pipeline* waifu2x_postproc;
    
    // waifu2x -> bicubic_2x
    // realsr  -> bicubic_4x
    ncnn::Layer* bicubic_op;
    float bicubic_scale;
    bool tta_mode;
};

#endif // WAIFU2X_H
