#include "gif.h"
#include "rlottie.h"

#include<iostream>
#include<vector>
#include<array>
#include<cstdlib>

class GifBuilder {
public:
    GifBuilder(const std::string &fileName , const uint32_t width,
               const uint32_t height, const uint32_t delay = 2)
    {
        GifBegin(&handle, fileName.c_str(), width, height, delay);
    }
    void addFrame(rlottie::Surface &s, uint32_t delay = 2)
    {
        argbTorgba(s);
        GifWriteFrame(&handle,
                      reinterpret_cast<uint8_t *>(s.buffer()),
                      s.width(),
                      s.height(),
                      delay);
    }
    void argbTorgba(rlottie::Surface &s)
    {
        uint8_t *buffer = reinterpret_cast<uint8_t *>(s.buffer());
        uint32_t totalBytes = s.height() * s.bytesPerLine();

        for (uint32_t i = 0; i < totalBytes; i += 4) {
           unsigned char a = buffer[i+3];
           // compute only if alpha is non zero
           if (a) {
               unsigned char r = buffer[i+2];
               unsigned char g = buffer[i+1];
               unsigned char b = buffer[i];

               if (a != 255) { //un premultiply
                  r = (r * 255) / a;
                  g = (g * 255) / a;
                  b = (b * 255) / a;

                  buffer[i] = r;
                  buffer[i+1] = g;
                  buffer[i+2] = b;

               } else {
                 // only swizzle r and b
                 buffer[i] = r;
                 buffer[i+2] = b;
               }
           } else {
               buffer[i+2] = 255;
               buffer[i+1] = 255;
               buffer[i] = 255;
           }
        }
    }
    void commit()
    {
        GifEnd(&handle);
    }
private:
    GifWriter      handle;
};

class App {
public:
    int render(uint32_t w, uint32_t h)
    {
        auto player = rlottie::Animation::loadFromFile(fileName);
        if (!player) return help();

        uint32_t* buffer = (uint32_t *) malloc(w * h * 4);
        size_t frameCount = player->totalFrame();

        GifBuilder builder(baseName.data(), w, h);
        for (size_t i = 0; i < frameCount ; i++) {
            rlottie::Surface surface(buffer, w, h, w * 4);
            player->renderSync(i, surface);
            builder.addFrame(surface);
        }
        builder.commit();

        free(buffer);
        return result();
    }

    int setup(int argc, char **argv)
    {
        if (argc > 1) fileName = argv[1];

        if (!fileName) return help();

        fileName = realpath(fileName, absoloutePath.data());

        if (!fileName || !jsonFile(fileName) ) return help();

        baseName = absoloutePath;
        char *base = basename(baseName.data());
        snprintf(baseName.data(), baseName.size(), "%s.gif",base);
        return 0;
    }

private:

    bool jsonFile(const char *filename) {
      const char *dot = strrchr(filename, '.');
      if(!dot || dot == filename) return false;
      return !strcmp(dot + 1, "json");
    }

    int result() {
        std::cout<<"Generated GIF file : "<<baseName.data()<<std::endl;
        return 0;
    }

    int help() {
        std::cout<<"Usage: \n   lottie2gif [lottieFileName]\n";
        return 1;
    }

private:
    char *fileName{nullptr};
    std::array<char, 5000> absoloutePath;
    std::array<char, 5000> baseName;
};

int
main(int argc, char **argv)
{
    App app;

    if (app.setup(argc, argv)) return 1;

    app.render(200, 200);

    return 0;
}
