# Stage2：完整数值通过，整Frame收益未证，STOP

Stage1先以f0e40e10封存，Stage2没有混入V候选。LLVM23 offline91436=0，ISA严格门确认目标10624B只八main的TH bit52变化，两个down/scope/waits/资源一致；唯一style地址literal解析到相同global4B0000003c后才归一。Hint不是保证绕L2，也没有cachemiss/stall因果数据。

unit18221退出0：old2/new2的八份完整输出全部同after-kernel reference，main每份70,778,880B SHA170b599…985d5b/down17,694,720B SHA0417a910…71973，byte/repeat/NaN/guard全0，显式编码style1/128。

原Frame11901/68401资格失败保留：Style1在生产helper返回-1默认sentinel，错误guard导致NR1 ready0/实际NT0；两个子进程0不等候选生效。这不是NT数学失败或性能轮。仅hostguard接纳已证默认−1或显式1/128，host20047=0；不改module、不重unit。新有效gold79532退出0：NT3/stock0 vs0/3，六HDR0900、finite/repeat0、Auto3/PDL0。

有效整Frame ABBA89008退出0，四freshprocess320弃80、480样本/arm；原未QPC caller，同exe NR0/1，当前43joint原模块不变另加侧车761，只有newprefix被替换。八首尾0900、Auto320/reject0/PDL0、实际candidate320/stock0 vs0/320、current8+8compactkeys与44文件前后身份全通过。

| Slot | Mean ms | p99 ms | Max ms |
|---|---:|---:|---:|
|A1 原|9.643316667|9.87530|9.899|
|B1 NT|9.640095833|9.83383|9.926|
|B2 NT|9.671225000|9.89093|9.903|
|A2 原|9.669725000|9.89503|9.947|
|原 pooled|9.656520833|9.88847|9.947|
|NT pooled|9.655660417|9.86799|9.926|

均值仅−0.8604µs，相比控制漂移+26.4083µs/候选漂移+31.1292µs不可辨；B2比末A2慢1.5µs。Median反+8µs也保留。p99−20.48µs/max−21µs只是本短样本描述，不能挑尾统计宣赢。

资源gold两arm weights297609000/pool290571128/gather5242880/noise0、history0及driverfree15995121664B快照都相同。文件清单同不等加载GPU code/residency同：NR1冷加载额外侧车，NR0不加载。该冷成本在warm窗外，实验比较的是完整variant，不以此证明TH硬件机制。不是资源节省任务。

固定flags误写了unused HIP_NET_TIMING/HIP_NET_SPAN两个alias0；真实NET_TIMING/HIP_SPAN_PROBE在实际same.flags均不存在，child环境先清，bridge缺省false，所以本轮没有这两类probe。按实际状态说明，不改已经跑过的case、不因此重刷。

裁决：**收益未证，STOP，不集成、不换TH、不加第三候选、不再试验**。保留ISA/数值成功及旧资格失败，不宣称NT普遍无效或候选已证变慢。代码/小CSV/manifest/独立JSON均持久；大raw在原artifact目录，不进git。
