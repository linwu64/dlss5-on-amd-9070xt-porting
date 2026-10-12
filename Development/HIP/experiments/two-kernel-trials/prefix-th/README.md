# Stage2 offline source only

`prepare_source.py --out PATH`只读取当前canonical c32-wave1-fast recipe并生成私有源码/manifest，不调用编译器，不上传/运行设备。Stage1必须由主控先封存。

在cw_body末增加默认false的PrefixMainNT参数，旧exports仍走原8B memcpy。唯一newexport c32_wave1_prefix_b8d_main_nt选择true；仅完整tile prefix main的单一8B向量写表达式使用nontemporal builtin。down表达式和所有值/舍入/加载/fence/scope保持原样。

后续ISA必须确认：新Fn只有八个main store的TH位与原f46不同，down两个store及其它指令/资源不变。Compiler lowering未验证，生成成功不等于TH生效/ABI通过/数学通过。若不符合，止于编译门，不扫一套缓存策略。

main未来由post70读取，不是可以丢弃的数据。TH_STORE_NT不是BYPASS，不保证绕L2。实际miss/stall/收益均未知。该副本不修改生产源、不改变旧module/host路径。
