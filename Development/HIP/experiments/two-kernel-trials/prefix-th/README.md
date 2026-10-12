# Stage2 offline source only

`prepare_source.py --out PATH`只读取当前canonical c32-wave1-fast recipe并生成私有源码/manifest，不调用编译器，不上传/运行设备。Stage1必须由主控先封存。

在cw_body末增加默认false的PrefixMainNT参数，旧exports仍走原8B memcpy。唯一newexport c32_wave1_prefix_b8d_main_nt选择true；仅完整tile prefix main的单一8B向量写表达式使用nontemporal builtin。down表达式和所有值/舍入/加载/fence/scope保持原样。

后续ISA必须确认：新Fn只有八个main store的TH位与原f46不同，down两个store及其它指令/资源不变。Compiler lowering未验证，生成成功不等于TH生效/ABI通过/数学通过。若不符合，止于编译门，不扫一套缓存策略。

main未来由post70读取，不是可以丢弃的数据。TH_STORE_NT不是BYPASS，不保证绕L2。实际miss/stall/收益均未知。该副本不修改生产源、不改变旧module/host路径。


Stage1已f0e40e10封存后，本候选由本地LLVM23 offline compile91436退出0。模块SHA761984e781c58f9587a9e6b3432f2b9c6c8713516e441ed21bc0aabdcb67f094。严格verify_isa门已通过：10624B函数仅八main的TH bit52变化，down两条/scope/其它指令字节一致；唯一style PC-relative literal解析至同名dlss5_style_feature，旧0x7e00/新0x8e00均raw0000003c，才允许地址归一。ABI76B/WG32/LDS4096/VGPR128/SGPR48/private0/spill0与f46一致。完整ISA/编译/数据身份JSON见results/isa。

全模块不能直接当生产替换：23/26旧函数rawbytes同，三个prefix含已解释style地址迁移，另有当前源码已有的PR12post-logit额外导出。试验仅调用侧车newFn，所有其他函数仍来自原current43模块。实际GPU数值/全Frame/performance门由主控后续执行；这个CPU门不宣布收益。单位STYLE1字段须已编码1/128，不能把裸1写进API.style_feature。


原私有host11901/Framecase68401保留：两个子进程输出正常但NR1 ready0/candidate_calls0，因为资格误把api.style_feature必须显式1/128。生产StyleFeatureFromEnvironment对Style1实际返回-1，表示保留模块默认1/128。此为host资格错误，不是NT数值/性能失败。仅资格修为-1或1/128（f46/761默认global已锁定0000003c），没有改实际style、module或unit；host重链20047退出0，新fresh-case由主控执行。旧exe/source身份保留在本地-build/prefix-th/frame-11901*及原远端case。0/2仍走原路径。
