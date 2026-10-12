# 两候选顺序试验：独立测量约定

基线79599997；隔离树从4a9d7eee文档祖先建立。主控唯一GPU/RTC队列，独立统计不运行设备。Stage1结论与证据封存后，Stage2才可编译/执行。Stage2现有源码生成不属于编译或性能门。

共同固定：当前43模块joint vit-stream da1b、原模型/输入、1152/640tokens/full71/FAST1/MP1/AE0/history0/Style1/seed0、实际生产Auto接受路径及PDL实际计数。完整Frame使用原未插桩caller；不得借用上一轮Auto hostQPC私有头/helper，GAME_PROBE/NET_TIMING/SPAN/INPUT_POLL明确关，HIP_MEMORY只在资源/正确性门开、性能关闭。不得为计时关生产marker、换数学/权重/selector或加入单边D2H。模块/源码/所有相关数据hash必须与具体case绑定。

## Stage1：V末端rendezvous

先真实640token完整QKV输出严格gold、finite、重复和ISA依赖门。小pair保持相同producer/consumer、数据、grid、stream、launchflags和资源；候选只替新QKV函数。外事件包围原pair，读回/首末gold放窗外，两个arm观测对称。这个pair不含全Frame前面已有Auto marker，不得将其命名为完整生产Auto收益。

只一轮有界筛选，逐slot报告GPUouter和CPU提交完成wall，以及mean/median/p99/max、control与candidate漂移。先看候选两槽与基线两槽的方向、量级是否超过漂移；细微差异无可靠信号就STOP，不追加筛选轮/展开/预取组合。pair改善即使可靠，也只能说明该pair有潜力；主控明确有希望后才排相同原Auto完整Frame短A/B。最终以Frame首尾raw/实际Auto计数/尾部结果决定，不能把8层乘微核差当实测整帧收益。

## Stage2：main-only TH_STORE_NT

仅在Stage1 sealed后启动。原f46中八个main store与两个down store已审计：arg4 main偏移0x20、arg5 down0x28。ISA门必须确认只八个main TH位改变、down/其它指令/scope/hazards/VGPR/LDS/private无变化。builtin或源码名字本身不是此证明。

真实prefix main67.5MiB与down16.875MiB两完整输出重复bytegold/finite；再整Frame首末0900/实际Auto/模块身份。只做当前Auto完整Frame单轮短ABBA，各320弃80/480样本每arm。缓存影响跨后继kernel，prefix孤立微核不作收益替代。即使prefix变快，post70延后读skip0可能变慢；必须保留整Framemean/p99/max与slot漂移。无可靠收益即STOP，不扫TH枚举。TH是保留优先级提示，不保证绕L2，未测miss/stall不臆造缓存因果。

## 统一解释

数值/身份通过和性能通过分开。按原运行/失败case保存，不刷新以求正；前置脚本/布局/编译器失败不冒充数学或速度失败。p99在480样本仅约五个尾点，单最大值也要呈现但不当稳定尾界。帧时变化小于控制漂移只写“未证明稳定加速”，不硬判加速或变慢。资源容量、driver-free和实际驻留峰值分别标注；本轮目标是真性能，不以空分配节省替代。
