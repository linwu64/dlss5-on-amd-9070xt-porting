#include "native_model_mode.h"
#include "small_model_assets.h"
#include <cassert>
int main(int argc,char**argv){using namespace dlss5_mode;
 assert(Parse(nullptr)==0&&Parse("")==0&&Parse("0.5")==0);
 assert(Parse("1")==1&&Parse("2")==2&&Parse("3")==3);
 assert(Parse("0")==0&&Parse("0.50")==0&&Parse("-1")==0);
 unsigned m=0;for(unsigned want:{1u,2u,3u,0u}){m=Next(m);assert(m==want);}assert(Passes(0)==1&&Passes(3)==3);
 assert(argc==4);assert(!hip_reference::SmallAssetsAvailable(argv[3]));assert(hip_reference::SmallAssetsAvailable(argv[1]));assert(!hip_reference::SmallAssetsAvailable(argv[2]));
 puts("mode defaults, four-way cycle, pass count and complete/missing model assets: PASS");
}
