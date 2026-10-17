#include "linux/src/core/nr_native_plan.hpp"
#include <iostream>
#include <fstream>
int main(int argc,char**argv){unsigned w=std::stoul(argv[1]),h=std::stoul(argv[2]);auto p=nr::make_native_plan(w,h,argc>3&&std::string(argv[3])=="old"?nr::NetworkModel::Original:nr::NetworkModel::Small);std::cout<<"# work "<<p.width<<" "<<p.height<<" reductions "<<p.reductions_x<<" "<<p.reductions_y<<" model "<<p.model<<"\n"<<p.text;}
