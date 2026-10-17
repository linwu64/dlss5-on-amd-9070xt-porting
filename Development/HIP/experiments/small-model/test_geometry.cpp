#include <array>
#include "native_network_geometry.h"
#include <cassert>
#include <cstdio>
int main(){for(auto t:{std::array<unsigned,6>{1920,1080,1920,1152,32,20},{1600,900,1600,1024,28,16},{1280,720,1344,768,24,12},{1001,777,1024,832,16,16},{2560,1440,2560,1472,40,24}}){auto g=NativeNetworkGeometry::Small(t[0],t[1]);assert(g.processing_width==t[2]&&g.processing_height==t[3]&&g.vit_w==t[4]&&g.vit_h==t[5]);}puts("Small geometry native cases PASS");}
