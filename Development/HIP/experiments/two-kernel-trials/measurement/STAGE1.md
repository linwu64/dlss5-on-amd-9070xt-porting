# Stage1：数值通过，收益未证，STOP

真实unit94277退出0：原/候选四份完整1,966,080B QKV输出均同845725…7348d7，finite/guard通过。屏662786/PID24248退出0，120行完整、八edge全部byte/NaN/guard0。原current joint da1b、实际640token输入72f2/FWaf438、候选module及caller身份绑定各manifest。

这是**单QKV kernel**的同进程ABBA筛选，普通launch，768×160，10warm20measure每slot；两个role事件/完成同步、slotsetup及窗外edgeD2H对称。没有生产Auto marker，不是两核producer/consumer pair，也不代表全Frame。

| Slot | Role | GPUouter mean µs | Host wall mean µs |
|---|---|---:|---:|
|0|原|113.300|159.600|
|1|新|36.850|90.400|
|2|新|32.250|88.350|
|3|原|34.295|86.450|

40样本/arm pooled GPU73.7975→34.5500µs，表面−39.2475µs；但控制slot漂移−79.005µs更大，B1慢于末原slot。Host wall pooled123.025→89.375µs，表面−33.650µs，控制漂移−73.150µs；**两个候选slot都慢于末原slot**。首原高值保留，不删样本、不补warm重跑。

GPU pooled p99 152.267→83.865µs/max177.500→102.000µs；wall p99 258.190→137.890µs/max289.000→157.000µs。n40的p99只在约一个尾样本附近插值，不能称稳定尾改善。详细逐slot均值/尾/标准差见independent-statistics.json。

裁决：**收益未证，STOP，不整Frame、不刷新筛选，不把候选判为已证明更慢**。ISA/数值成功保留，但不进生产。不得将pooled差乘八层或换算FPS。Stage1 sealed后主控才可启动Stage2；Stage2基线保持原79599997/currentjoint，不混入本V候选。
