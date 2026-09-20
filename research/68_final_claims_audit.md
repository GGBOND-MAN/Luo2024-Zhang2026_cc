# 最终 claims audit 与交付核验

日期：2026-09-11。审查对象为本次research/64_complete–67、原论文全文回顾、13份图注、论文入口、claim CSV及research/01–63历史原文。历史全文副本明确标记为原始引文，不能直接当作已批准论文主张。新旧编号64文件并存，原文件未覆盖。

## SAFE

1. **原论文身份和贡献。** Zhang2026的Stage II确实是localized joint 2-D MUSIC，使用coarse-dependent geometry compensation及多载波几何平均；它缓解传统固定angle代入range阶段的显式传播。当前15页IEEE稿第8页给约±1°/±1m，Table II给L=128/P=129，第3页说明顺序单RF重构。新材料未把本项目±0.0025m归给原论文。
2. **可行域事实。** 在固定硬窗下truth不属于支持集时，域内argmax不能返回truth；这不否定MUSIC正交性。历史移动窗的累计可达域另行说明。P_A也保留coarse center、有限angle域与有限profile域的限制。
3. **最终独立身份。** 200独立位置跨7SNR，共1400配对trial。直接读取两个shard的MAT双精度结果核验1400成功、1398严格相同角度、2个非零差异。Gram=0、fallback=0、direct EVD合计2,872,800。冻结165文件source digest核验一致：`2d40cca46c84cccd580ba8bfc48d1b2bc74dfc4390920f17c80f00428f0a9684`。
4. **统计边界。** 七angle MSE ratio同时上界均小于1.21；range优效只在0/15/20dB建立。其余四点仅为RMSE数值改善。位置误差是次要终点，不借用range星号。读取既有冻结20000次位置簇bootstrap结果，未更改统计或重新选择家族。
5. **完整raw与posthoc一致。** 从7000条method-long原始估计行（1400trial×5输出）重算35组angle/range/position RMSE，105项与posthoc差小于1e−12。没有删异常值、改seed、平滑数据或只保留收敛样本。
6. **高SNR限制保留。** P_A对H_A的描述性增量为+40.71/+15.98/+41.22/+1.83/−0.72/−0.56/−0.14%。三个高SNR小负值保留，未据此切换H/P。
7. **低SNR尾部。** −10dB对C严格胜率47.5%，40.54% RMSE下降主要由严重尾部缩减驱动；C与P_A大于1m计数分别2/200、0/200。未将0/200解释成总体零风险，未宣称该点统计优效。
8. **复杂度口径。** MUSIC评分点3083→93对应96.98%；完整online均值18.336638→9.133054s对应50.1923%。共同前端/补偿/协方差/EVD和profile成本均保留。runtime来自R33独立冻结计时，不是R34服务器吞吐或同一批accuracy用户。
9. **版本保留。** R30六个少载波候选仍失败；R31全载波1-D angle是新候选；R33仅接受q-only/invariant reuse，Gram B/AB虽输出相同仍因1.480e−12>1e−12而拒绝，未运行60用户组合回归。旧alpha/gating/shrinkage/0.9版本不在最终P_A内。
10. **图形与材料。** 已生成8主图、4补充图、1内部时间轴，统一由`matlab/paper_figures/generate_all_paper_figures.m`读取独立source CSV/MAT生成。13份PDF均无嵌入位图、可见文字最小字号≥8pt、页外文字0；SVG存在，PNG的DPI元数据及像素尺寸按600dpi核对。多panel图需按约7.16英寸通栏使用，单panel图约3.5英寸；不可任意缩放到更小字号。已逐图查看渲染，修正数学字符、下标字号、边缘裁切和负值标签拥挤。
11. **原始输入保护。** `input_preservation_audit.csv`确认纳入清单的历史文档、文献与冻结源码/CSV哈希未变；`final_raw_archive_hashes.csv`保存最终原始MAT、日志/CSV等交付时哈希。没有改写冻结估计器、原始统计或历史失败日志。绘图脚本的Code Analyzer有7条非阻断提示（1条索引建议、3条未用图形句柄、3条绘图接口未来兼容提示），不涉及估计器或数据；完整图形生成和格式核验成功。未运行会生成新性能样本的全工程回归。

## NEEDS QUALIFICATION

| 容易误解的句子 | 必须同时保留的限定 | 已放置位置 |
|---|---|---|
| Joint搜索仍有coarse依赖 | 承认其避免传统显式代入；原文也承认窗宽权衡；不宣称首次发现窗口风险 | 65 Attack A；66 Contribution1；Fig01 |
| P_A保持angle | 仅冻结窄range域、全载波与离散搜索规则；非exact equivalence | 65 Attack D；Fig04/S2 |
| Pw明显优于Mw | R29开发/校准机制，不是R34最终；Y与z使用不同信息/statistics | 65 Attack C；FigS3 |
| profile改善距离 | 对H_A高SNR近零且略负；对C并非全SNR统计优效 | Fig03/06；66/67 |
| 更高score说明更好的前端 | 只表示该目标的候选改进，不保证truth误差下降；驻点不等于global最优 | 64 R27–29；67 |
| 复杂度降低 | 区分精确评分点计数、平台特定完整online秒数、渐近阶、物理采集时间 | Fig07/08/S4；65 Attack E |
| 本项目优于Zhang | 比较strengthened Zhang-style executable baseline，不是作者真实完整代码；C_public为transparent-assumption baseline且也共享L06 | 原论文回顾；所有图注共同限制 |
| 同条件观测比较 | 同步LoS单径、common delay calibrated、条件z+Y；尚无统一RF/总能量/时隙采集证明 | 65/66/67；图注 |
| 最终执行已审计 | server2授权后空目录预检没有PASS；aggregate仍有准备期metadata字段；按research/62披露而非覆盖 | 64文档62；67第11节 |
| 案例谱曲线来自final | profile网格与候选来自保存raw；C MUSIC曲线未可靠获得 | Fig02图注及下述重放记录 |

**案例重放处理。** 仅对预先指定seed52100034尝试一次visualization replay，没有新增位置、搜索seed或重跑估计器/优化器。它在重建z/Y后未通过与服务器输入的SHA256一致性，因此没有计算或采用MUSIC曲线，也没有放宽门槛。图2使用已保存raw中的真实估计、支持区间与profile网格/候选分数。原始log score保存不变，展示时仅对该statistic按其已保存最大候选值归一化。`Fig02_replay_disposition.json`、拒绝哈希MAT、完整冻结protocol MAT及system configuration MAT共同保存；入口已防止重复尝试。此失败不影响已保存最终估计，但不能用本机重建曲线替代未经确认的服务器原曲线。

## REMOVE

以下肯定式主张不得进入投稿正文；新材料中若出现相应词语，只处于明确禁止/否定上下文，不要求删除审计本身的反例列表。

- “eliminate error propagation”：改为缓解传统显式代入，同时保留coarse依赖。
- “exact decoupling”或“universally”支配：移除；只给冻结离散协议下的非劣。
- “globally optimal”：移除；有限候选/驻点条件不构成全局证书。
- “exact Zhang reproduction”：移除；两类本地基线都不是作者完整代码。
- “all SNR statistically superior”：移除；仅0/15/20dB建立range优效。
- “lower complexity than Zhang2026 author implementation”：移除；无作者实测代码对照。
- “robust to timing offset”“multipath robust”“hardware validated”：移除；最终实验均没有这些证据。
- “Hessian angle-range cross curvature is the dominant failure mechanism”：**REJECTED HYPOTHESIS**；不得恢复为确认结论。
- “Zhang2026默认±0.0025m”“L和两个窗口均未公开”“论文未说明单RF空间观测获取”：当前接收稿下的事实错误，撤回旧断言。
- “Gram已成功”“R30少载波压缩保持性能”“R21/R26旧曲线代表最终P_A”：与冻结历史记录不符，移除。
- “无显著差异=统计等价”“0/200失捕=总体失捕概率零”“96.98%=总复杂度下降”：均不允许。

## 危险词逐项检索

检索采用大小写不敏感的逐行/句上下文，并检查CSV的allowed/forbidden字段。`claims_occurrences.csv`保存路径、行号、原句、所在章节与判断，`claims_search_coverage.csv`记录零命中词，避免漏查。以下计数不包含本审查报告对词表的自我复述：

| 危险词 | 当前MD命中 | 含结构化矩阵总命中 | 审查结论 |
|---|---:|---:|---|
| eliminate error propagation | 0 | 0 | 无肯定式主张 |
| exact decoupling | 0 | 1 | forbidden字段 |
| universally | 3 | 4 | 均为禁止表述 |
| globally optimal | 0 | 1 | forbidden字段 |
| exact Zhang reproduction | 0 | 0 | 无肯定式主张 |
| all SNR statistically superior | 0 | 1 | forbidden字段 |
| lower complexity than Zhang2026 author implementation | 1 | 2 | 禁止表述/forbidden字段 |
| robust to timing offset | 1 | 2 | 禁止表述/forbidden字段 |
| multipath robust | 1 | 2 | 禁止表述/forbidden字段 |
| hardware validated | 1 | 2 | 禁止表述/forbidden字段 |

15处上下文均已人工核对。中文及非逐字相同的高风险说法另按上面NEEDS QUALIFICATION/REMOVE表检查，尤其是原文公开设置、Hessian主导、历史独立数据复用与高SNR profile限制。

## 核验材料和停止状态

- `paper_support/research_read_log.csv`：63份文档及SHA256。
- `paper_support/experiment_ledger.csv`：每文23字段及完整证据路径；原文子实验表格归档于history_evidence。
- `paper_support/saved_raw_identity_audit.csv`与`saved_mat_nonzero_angle_differences.csv`：原MAT计数和两个差异seed。
- `paper_support/figure_data_validation.csv`：105项raw/posthoc RMSE复核。
- `paper_support/figure_quality_audit.csv`：13图矢量、字号、页面边界、PNG/SVG核验。
- `paper_support/claims_occurrences.csv`与`claims_search_coverage.csv`：逐句危险词审查。
- `paper/figure_manifest.csv`：8 main、4 supplement、1 internal完整来源和图注。

任务到此停止。未新增Monte Carlo用户，未优化或修改P_A/H_A/C_enhanced/C_public，未追加性能验证，未安排后续模拟或自动化。
