# R52：P_FARC2 Basin-Consistency Certified Recovery协议

日期：2026-09-18  
实现：`R52-PFARC2-basin-consistency-development-v2`  
状态：v2已执行；Development FAIL；停止

## 1. 独立假说

R51保持正式Development FAIL并永久冻结。R52不修补R51，而检验新假说：奇偶载波对L06
top-8的最佳盆地可能彼此一致，却共同不同于完整频带选中的`front.selected`盆地。

## 2. 方法

Base逐行等于冻结P_FA。保留C1、C2、C3a和C4，新增：

`C3b = same(B_odd,B_even) AND NOT same(B_odd,B_F) AND NOT same(B_even,B_F)`。

同盆地阈值冻结为`0.2 deg/2 m`，并列分数取最小候选索引。新trigger为
`C1 OR C2 OR C3a OR C3b OR C4`。未触发时输出必须逐行等于P_FA。

触发后不使用R51 split recovery，直接运行冻结P_FAW06宽角度和`[15,50] m`全局exact-q
profile；数值非法时回退P_FA。

## 3. 对照

- P_FA；
- 冻结R51 P_FARC，仅作审计参考；
- R51旧trigger + 简单wide/global；
- R52新trigger（含C3b）+ 简单wide/global，Primary；
- P_A与C_enhanced仅作性能和复杂度参考。

## 4. 数据隔离

- normal：30个全新位置乘`-10/0/20 dB`，共90行；
- natural stress：固定600个全新单源、`-10 dB`位置候选池；
- 对每行完整生成原始`z/Y`并运行冻结L06，只按真值是否位于L06的`+-0.2 deg/+-2 m`
  支持外标记angle/range/joint；
- 每类按positionId顺序保留前3行；固定池不足时stress构造FAIL，禁止扩大候选池；
- stress筛选不读取C1-C4、C3b或恢复结果；
- R51 position11和R48 position124仅在代码冻结后重放，不进入Gate；
- 不读取R46 final，不运行calibration或final。

## 5. Gate

Primary要求：stress三类均构造成功；aggregate range MSE/P_A不超过1.00；任一SNR不超过
1.05；aggregate angle MSE/P_FA不超过1.01；normal false-trigger rate不超过0.05；触发条件下
有害恢复率不超过0.10；各类stress敏感度至少0.90；C3b至少新增1个stable-interior检测且
range敏感度比R51旧trigger提高至少0.20；旧trigger下简单恢复/R51距离MSE不超过1.01；
未触发行恒等性违规为0；完整运行时间低于C_enhanced。

所有比值同时报告按位置聚类bootstrap。任一Gate失败即停止，不增加候选池、阈值或证书，
也不进入calibration。

`v1`首次运行完成筛选和normal阶段后，在零行自然stress的汇总处发生空string列类型错误，未生成
最终结果。该目录已只读归档；`v2`仅修复通用空stress汇总，不改变种子、方法、证书或Gate，
并从零重新执行以保持源码摘要一致。
