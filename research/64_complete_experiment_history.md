# 完整实验史：research/01–63

整理日期：2026-09-11。逐文件完整读取63份文档；日期未写明时登记未载明，绝不把文件修改时间当实验日期。Round是研究轮次，document是记录编号，二者不同。本文追加回顾，不改历史记录。

## 阅读与使用规则

最终性能唯一来源为R34的200位置×7SNR。历史独立验证仅表示在当轮选参时隔离，后续复用后属于历史开发材料；不同轮次不得相加成独立用户总数。候选评估、bootstrap重采样、软件smoke、定向重放与新位置分别记账。协议文件只列计划量，不能计为完成。

主线演变：完整复谱信息保留 → MUSIC角度有效而距离更新不稳 → 门控/收缩有限收益与失败 → 条件复谱profile → 粗中心/边界/竞争模态与数值收敛消融 → R30少载波角度失败 → R31全载波降维控制 → R32冻结P_A → R33仅接受q-only复用 → R34独立确认。

## 必须撤回或限定的历史假设

- **REJECTED HYPOTHESIS**：local Hessian angle-range cross curvature是主要失败原因（R14：预测相关接近0，固定真角度无显著改善）。
- **REJECTED HYPOTHESIS**：当前范围的大误差主要来自Fresnel近似（R2/R4无噪声控制）。
- **REJECTED HYPOTHESIS**：协方差收缩失败主要因为中心化删除共同偏差（R11修正为重复机制不匹配）。
- 当前IEEE接收稿已公开L=128和±1°/±1m，并描述顺序单RF获取。旧“全部未知/未说明RF”的事实性断言撤回。
- 旧移动窗可达半宽0.00278333m，R31之后硬窗为0.0025m；不得混用。
- 区间跨零表示未建立差异，不能称统计等价。
- R21、R26、旧lambda0.9、alpha、gating、Gram以及R30失败候选均为historical / rejected / superseded。

## 逐文件台账

### Document 01 — Round theory

[01_full_spectrum_identifiability_theory.md](../research/01_full_spectrum_identifiability_theory.md)

- 日期：未载明（不推定）
- 问题/假设：单峰索引是否足以反演二维位置；完整复谱是否局部可辨识？
- 算法与变更：公共复增益集中似然与投影EFIM；exact球面模型
- 数据角色：mechanism audit; calibration
- 样本/工作量：理论文档，无新增用户
- 数值：实参数投影导数秩2是正则局部条件；任意逐载波复增益可吸收位置变化
- 统计与失败边界：局部可辨识不推出全局唯一；一维轨迹面积零不等于波束不能照射二维区域
- 假设判断：PARTIAL / qualified
- 保留：复增益消元、实秩、单位缩放
- 放弃/纠正：**historical / rejected / superseded** — 自动95%窗口和全局保证尚未建立；旧条件数=耦合说法纠正
- 后续替代关系：核心集中似然/投影EFIM保留；强窗口与耦合解读由R2/R14/R26审计限定
- 当前用途：Yes: definitions/complexity/scope, no new performance claim；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/01_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 02 — Round 1

[02_sequential_experiment_results.md](../research/02_sequential_experiment_results.md)

- 日期：未载明（不推定）
- 问题/假设：峰值、功率谱与完整复谱的初始验证
- 算法与变更：N256/M2048/60GHz/3GHz；375位置网格、连续GN及K5 MUSIC
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：无噪声375点；6位置每SNR100次；端到端3位置每SNR20次
- 数值：峰值固定窗捕获1.6%；网格复谱100%；20dB连续SD/CRLB约0.879-1.040；端到端range 0.136m
- 统计与失败边界：网格零误差非连续唯一性；低SNR连续收敛19%-29%；历史轨迹数字仅公式诊断
- 假设判断：PARTIAL / qualified
- 保留：全复谱信息保留、收敛和捕获分开
- 放弃/纠正：**historical / rejected / superseded** — 粗整数二维字典漏窄主瓣；纸面曲线不能当最终对手
- 后续替代关系：早期前后端配置由R15条件profile及后续R26/R32配置取代；原实验保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/02_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 03 — Round 2

[03_round2_robustness_results.md](../research/03_round2_robustness_results.md)

- 日期：未载明（不推定）
- 问题/假设：离网格、相位、Fresnel和频变增益是否破坏结论？
- 算法与变更：200连续位置；相位0-90deg；N64-512与r3-50；公共/线性/任意复增益
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：离网格200位置/SNR；相位每位置/SNR/相位100次；确定性失配扫描
- 数值：EFIM覆盖31.5/78/91/95%；N256声明域最大距偏1.82e-5m；90deg相位RMSE12.86m(20dB)
- 统计与失败边界：REJECTED HYPOTHESIS：当前域Fresnel失配是巨大误差主因；低SNR欠覆盖主要受优化影响
- 假设判断：REJECTED or mixed; see numerical result
- 保留：相位同步、低维nuisance与模型边界
- 放弃/纠正：**historical / rejected / superseded** — 8次迭代失败版；把20deg网格捕获外推硬件相位鲁棒性
- 后续替代关系：早期前后端配置由R15条件profile及后续R26/R32配置取代；原实验保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/03_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 04 — Round 3

[04_round3_extended_experiments.md](../research/04_round3_extended_experiments.md)

- 日期：未载明（不推定）
- 问题/假设：波形相位、校准、多径和资源成本的扩展
- 算法与变更：Wiener CPE/ICI；经验椭圆和bootstrap；两径；RF预算情景
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：椭圆200校准+100测试/SNR；40测试点×30bootstrap/低SNR；两径4位置×5分离×4功率×2SNR×100相位
- 数值：低SNR经验膨胀305.2/140倍，覆盖95/96%；3600重拟合约24分钟；强ICI捕获降至62.3/65%
- 统计与失败边界：较弱可分辨双径未击穿复谱，不证明一般多径；早期单RF缺失指控被接收稿纠正
- 假设判断：PARTIAL / qualified
- 保留：报告额外观测成本、ICI与适用边界
- 放弃/纠正：**historical / rejected / superseded** — 小相位误差必然失败、弱双径必然击穿、单RF原文未交代的强断言
- 后续替代关系：早期前后端配置由R15条件profile及后续R26/R32配置取代；原实验保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/04_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 05 — Round 4

[05_round4_failure_attribution.md](../research/05_round4_failure_attribution.md)

- 日期：未载明（不推定）
- 问题/假设：EFIM、优化器、MUSIC边界和RF的失败归因
- 算法与变更：真值线性/初始化、DFT合并、无噪声模型、K1-17控制
- 数据角色：mechanism audit; calibration
- 样本/工作量：EFIM每SNR100位置；RF3位置×30/SNR；边界150/SNR
- 数值：低SNR线性覆盖95%、全局34%、truth-start87%；wrong mode12%；边界70.7%
- 统计与失败边界：REJECTED HYPOTHESIS：EFIM缩放错误或Fresnel大偏差解释主要失败；真值对照非部署
- 假设判断：REJECTED or mixed; see numerical result
- 保留：数值收敛与模式选择分开；边界诊断
- 放弃/纠正：**historical / rejected / superseded** — 旧RF指控作为事实结论；早期移动窗误当硬窗
- 后续替代关系：早期前后端配置由R15条件profile及后续R26/R32配置取代；原实验保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/05_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 06 — Round 5

[06_round5_parameter_optimization.md](../research/06_round5_parameter_optimization.md)

- 日期：未载明（不推定）
- 问题/假设：未公开/可调参数与前端多起点能否改善端到端？
- 算法与变更：K33/L96、1.5deg/0.25m、41/31/21；5角度起点
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：MUSIC20校准+40验证/SNR；角度10+20/SNR；端到端15新位置/SNR=45
- 数值：调优前端range 0.110/0.0105/0.00245m变为MUSIC 0.288/0.249/0.198m
- 统计与失败边界：100%捕获不等于精度；二维字典验证63.3/56.7/66.7%，劣于连续初始化
- 假设判断：PARTIAL / qualified
- 保留：邻域多起点与角度精化
- 放弃/纠正：**historical / rejected / superseded** — 普通二维字典多起点；较宽距离MUSIC更新
- 后续替代关系：早期前后端配置由R15条件profile及后续R26/R32配置取代；原实验保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/06_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 07 — Round 6

[07_round6_carrier_window_boundary.md](../research/07_round6_carrier_window_boundary.md)

- 日期：未载明（不推定）
- 问题/假设：载波与窗口最优是否仅为搜索边界？
- 算法与变更：K5-2048、center/peak；range半窗0-1m；窄窗0.02deg/0.02m
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：每SNR10校准；每SNR10独立验证
- 数值：peak513窄窗range 0.12302/0.01665/0.02113m；front 0.13228/0.00537/0.00234m
- 统计与失败边界：低SNR校准增益不稳定，高SNR约2cm地板；513不是作者参数
- 假设判断：PARTIAL / qualified
- 保留：窄窗正则化解释、角度/距离分工动机
- 放弃/纠正：**historical / rejected / superseded** — 把小窗当Zhang原默认；33载波已饱和假设
- 后续替代关系：早期前后端配置由R15条件profile及后续R26/R32配置取代；原实验保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/07_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 08 — Round 7

[08_round7_adaptive_gate_paper_comparison.md](../research/08_round7_adaptive_gate_paper_comparison.md)

- 日期：未载明（不推定）
- 问题/假设：SNR门控能否稳定保留有益MUSIC距离？
- 算法与变更：K513/L96、0.02窗；SNR阈值-15至20
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：84校准+210独立验证；固定15deg/30m
- 数值：校准最优从不更新；验证front 0.047920m、MUSIC 0.050047m pooled
- 统计与失败边界：REJECTED HYPOTHESIS：低SNR更新稳定有益；历史原图比较不是同预算结论
- 假设判断：REJECTED or mixed; see numerical result
- 保留：MUSIC角度+front距离消融
- 放弃/纠正：**historical / rejected / superseded** — SNR硬门控；原图RMSE作为性能基线
- 后续替代关系：门控/alpha/shrinkage/no-harm均退出最终路径；R15起转向conditional profile
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/08_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 09 — Round 8

[09_round8_learned_confidence_gate.md](../research/09_round8_learned_confidence_gate.md)

- 日期：未载明（不推定）
- 问题/假设：24个可观测特征能否学习更新正负收益？
- 算法与变更：袋装树、最小MSE与one-SE；K513/L96
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：复用294行；新增210校准+420验证=630
- 数值：学习最小规则仅0.69%数值收益；95%CI[-2.92e-4,1.76e-4]m²；one-SE恶化0.30%
- 统计与失败边界：REJECTED HYPOTHESIS：当前谱特征可可靠门控；跨位置训练到固定位置测试有分布差异
- 假设判断：REJECTED or mixed; see numerical result
- 保留：oracle与可实现规则严格区分
- 放弃/纠正：**historical / rejected / superseded** — 学习门控与置信门控均非最终P_A
- 后续替代关系：门控/alpha/shrinkage/no-harm均退出最终路径；R15起转向conditional profile
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/09_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 10 — Round 9

[10_round9_continuous_range_shrinkage.md](../research/10_round9_continuous_range_shrinkage.md)

- 日期：未载明（不推定）
- 问题/假设：连续alpha是否优于二元门控？
- 算法与变更：全局/SNR/学习收缩；alpha=0.636及oracle
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：复用R8 630行；新低SNR200/SNR=600
- 数值：保守学习pooled改善1.00%；-10/-5区间小于0，0dB跨0
- 统计与失败边界：0dB跨0不等于等价；相对MUSIC汇总未显著更好
- 假设判断：PARTIAL / qualified
- 保留：风险分解和负结果
- 放弃/纠正：**historical / rejected / superseded** — 所有alpha分支被最终lambda=1 profile取代
- 后续替代关系：门控/alpha/shrinkage/no-harm均退出最终路径；R15起转向conditional profile
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/10_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 11 — Round 10

[11_round10_truth_free_covariance_alpha.md](../research/11_round10_truth_free_covariance_alpha.md)

- 日期：未载明（不推定）
- 问题/假设：载波分组协方差可否无真值估计alpha？
- 算法与变更：4/8/16组；raw/conservative/independent variance
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：60校准+300独立验证
- 数值：选4组independent；pooled front改善0.67%未显著；0dB较MUSIC降低17.4%
- 统计与失败边界：分组重复不代表MC风险重复；独立误差假设未证实
- 假设判断：REJECTED or mixed; see numerical result
- 保留：控制相关性与重复机制的审计
- 放弃/纠正：**historical / rejected / superseded** — 协方差收缩；共同偏差主因假设后被R11否定
- 后续替代关系：门控/alpha/shrinkage/no-harm均退出最终路径；R15起转向conditional profile
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/11_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 12 — Round 11

[12_round11_parametric_bootstrap_alpha.md](../research/12_round11_parametric_bootstrap_alpha.md)

- 日期：未载明（不推定）
- 问题/假设：参数化bootstrap能否恢复正确风险？
- 算法与变更：Kb65；B8 scaled raw；三SNR pooled校准
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：24pilot+90校准+300验证
- 数值：主规则相对MUSIC pooled差0.56%；0dB相对front显著恶化；raw为未选中候选
- 统计与失败边界：REJECTED HYPOTHESIS：中心化丢失偏差是主因；1/K创新外推失败
- 假设判断：REJECTED or mixed; see numerical result
- 保留：SNR平衡校准教训；主规则失败保留
- 放弃/纠正：**historical / rejected / superseded** — bootstrap shrinkage及事后替换校准胜者
- 后续替代关系：门控/alpha/shrinkage/no-harm均退出最终路径；R15起转向conditional profile
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/12_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 13 — Round 12

[13_round12_large_mc_snr_release.md](../research/13_round12_large_mc_snr_release.md)

- 日期：未载明（不推定）
- 问题/假设：SNR释放微小收益能否大样本重复？
- 算法与变更：tau=-4dB,s=1；残差SNR、alpha释放
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：900校准+10002验证(3334/SNR)
- 数值：相对MUSIC -10退化0.0034%、-5改善0.443%、0改善13.284%；pooled改善0.441%
- 统计与失败边界：历史独立验证随后被反复使用，不能继续叫最终独立；0dB对front未显著
- 假设判断：PARTIAL / qualified
- 保留：极小退化和历史重复使用披露
- 放弃/纠正：**historical / rejected / superseded** — SNR释放alpha最终废弃
- 后续替代关系：门控/alpha/shrinkage/no-harm均退出最终路径；R15起转向conditional profile
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/13_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 14 — Round 13

[14_round13_reproduced_method_comparison.md](../research/14_round13_reproduced_method_comparison.md)

- 日期：未载明（不推定）
- 问题/假设：同条件可执行对比与no-harm规则
- 算法与变更：Luo mid1=mid2=50m/62deg；no-harm tau=-7,s=2,sat=-5
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：Luo11520+7200候选评估及10002验证；345无噪声点；no-harm复用10002
- 数值：Luo range7.8641/7.0674/5.9137m；no-harm在0dB相对MUSIC区间小于0
- 统计与失败边界：no-harm数据已看过，属开发；公开公式疑点不作为作者性能失败证据
- 假设判断：PARTIAL / qualified
- 保留：R13起取消原图数值对比
- 放弃/纠正：**historical / rejected / superseded** — no-harm、作者exact reproduction措辞
- 后续替代关系：门控/alpha/shrinkage/no-harm均退出最终路径；R15起转向conditional profile
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/14_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 15 — Round 14

[15_round14_joint_music_error_injection.md](../research/15_round14_joint_music_error_injection.md)

- 日期：未载明（不推定）
- 问题/假设：粗中心、边界还是Hessian耦合主导？
- 算法与变更：oracle中心、truth-angle、5x5 Hessian、窗口控制
- 数据角色：mechanism audit; calibration
- 样本/工作量：10002历史预审计+180新机制(60/SNR)
- 数值：饱和97.69/95.29/90.61%；Hessian预测相关0.033/0.036/-0.103；固定truth-angle无显著改善
- 统计与失败边界：REJECTED HYPOTHESIS：local Hessian cross curvature为主要失败通道
- 假设判断：REJECTED or mixed; see numerical result
- 保留：粗中心依赖、边界正则化双重作用
- 放弃/纠正：**historical / rejected / superseded** — Hessian主导解释；oracle结果作可部署上界
- 后续替代关系：中心/边界机制保留并由R28/R29深化；Hessian主导假设在本轮即拒绝
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/15_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 16 — Round 15

[16_round15_profile_range_transfer.md](../research/16_round15_profile_range_transfer.md)

- 日期：未载明（不推定）
- 问题/假设：MUSIC角度配合复谱条件range是否有益？
- 算法与变更：K513/L96；profile半窗0.2m、lambda1
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：180校准+540新验证
- 数值：较MUSIC RMSE降9.95/22.20/35.68%；-10与0显著、-5跨0
- 统计与失败边界：改进含条件重优化贡献；不能全部归因角度；半窗尚在搜索上界
- 假设判断：PARTIAL / qualified
- 保留：conditional complex-spectrum range
- 放弃/纠正：**historical / rejected / superseded** — 旧alpha融合；普遍角度增益等比例转距增益
- 后续替代关系：历史K513、1m及lambda0.9配置由R26和R32冻结profile取代；失捕发现保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/16_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 17 — Round 16

[17_round16_expanded_profile_large_mc.md](../research/17_round16_expanded_profile_large_mc.md)

- 日期：未载明（不推定）
- 问题/假设：扩大profile窗口并检验大样本
- 算法与变更：半窗1m、lambda0.9；重放已有z
- 数据角色：development; reused historical data; independent subset only as stated
- 样本/工作量：540转开发；R12锁定10002回溯验证，非全新
- 数值：较MUSIC降32.81/48.51/57.45%；9个配对区间小于0
- 统计与失败边界：历史种子非最终确认；-10最大误差1.4509m略高于MUSIC1.4352m
- 假设判断：PARTIAL / qualified
- 保留：宽profile可压缩尾部
- 放弃/纠正：**historical / rejected / superseded** — lambda0.9与旧窗口均superseded
- 后续替代关系：历史K513、1m及lambda0.9配置由R26和R32冻结profile取代；失捕发现保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/17_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 18 — Round 17

[18_round17_extended_snr_and_parameter_stability.md](../research/18_round17_extended_snr_and_parameter_stability.md)

- 日期：未载明（不推定）
- 问题/假设：高SNR、lambda稳定性与seed审计
- 算法与变更：固定0.9/1m vs 自适应lambda；参数平台
- 数据角色：development; reused historical data; independent subset only as stated
- 样本/工作量：10002历史低SNR+1200新高SNR=11202
- 数值：较旧MUSIC高SNR降61.72/77.08/84.44/89.52%；799候选在1%平台内
- 统计与失败边界：自适应lambda在-5/0显著更差；高SNR按显著性停止仅历史描述
- 假设判断：PARTIAL / qualified
- 保留：参数平台而非唯一最优；单seed非总体证据
- 放弃/纠正：**historical / rejected / superseded** — 自适应lambda、最好seed作为性能证明
- 后续替代关系：历史K513、1m及lambda0.9配置由R26和R32冻结profile取代；失捕发现保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/18_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 19 — Round 18

[19_round18_cross_location_and_zhang_version.md](../research/19_round18_cross_location_and_zhang_version.md)

- 日期：未载明（不推定）
- 问题/假设：跨位置能否泛化，1m/2m是否充分？
- 算法与变更：9位置×3SNR；固定lambda0.9；窗口对比
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：5350总trial；主聚合各cell前100=2700
- 数值：平衡range0.43893/0.014836/0.001567m；-10仅3/9 cell显著；近距最坏7.022m
- 统计与失败边界：曾修正可选停止和位置权重；粗前端仍可失捕
- 假设判断：PARTIAL / qualified
- 保留：粗中心支持集与尾部问题
- 放弃/纠正：**historical / rejected / superseded** — 全区域逐点支配；历史1m版本
- 后续替代关系：历史K513、1m及lambda0.9配置由R26和R32冻结profile取代；失捕发现保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/19_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 20 — Round 19

[20_round19_random_miss_fallback_complexity.md](../research/20_round19_random_miss_fallback_complexity.md)

- 日期：未载明（不推定）
- 问题/假设：前端失捕检测和全距回退能否有效？
- 算法与变更：1m/2m分歧、0.95m位移门限；全域回退
- 数据角色：development; reused historical data; independent subset only as stated
- 样本/工作量：100校准+300随机验证
- 数值：粗miss 0/400；回退0次；-10提升3.01%未显著；profile慢5.8%
- 统计与失败边界：无正例无法识别阈值，identified=false
- 假设判断：REJECTED or mixed; see numerical result
- 保留：成本与少见事件可识别性披露
- 放弃/纠正：**historical / rejected / superseded** — 失捕检测已成功的假设、该回退分支
- 后续替代关系：历史K513、1m及lambda0.9配置由R26和R32冻结profile取代；失捕发现保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/20_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 21 — Round 20

[21_round20_complexity_reduction.md](../research/21_round20_complexity_reduction.md)

- 日期：未载明（不推定）
- 问题/假设：保持精度下压缩网格/载波/profile步长？
- 算法与变更：K17-513；61/41/31到41/31/21；0.25/0.1m
- 数据角色：development; reused historical data; independent subset only as stated
- 样本/工作量：R19 150校准+150锁定重用
- 数值：0.25m在验证低SNR失败；0.1m后验总耗时降33.99%
- 统计与失败边界：后验恢复0.1m已看验证，非独立；少载波角度退化
- 假设判断：PARTIAL / qualified
- 保留：网格压缩与载波压缩分开
- 放弃/纠正：**historical / rejected / superseded** — 0.25m粗种子；该历史压缩非最终P_A
- 后续替代关系：R21压缩/旧Zhang候选由R26增强基线及R31/R32的全载波1-D架构取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/21_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 22 — Round 21

[22_round21_large_parameter_lock.md](../research/22_round21_large_parameter_lock.md)

- 日期：未载明（不推定）
- 问题/假设：历史压缩参数联合锁定
- 算法与变更：R21 compressed K513,37/27/19,0.15m,1m,lambda0.9
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：150校准×75=11250评估；600新验证
- 数值：较旧MUSIC降25.85/52.79/91.84%；耗时15.261到9.626s
- 统计与失败边界：三CI跨0不能证明与full等价；未独立计时Zhang
- 假设判断：PARTIAL / qualified
- 保留：独立版本隔离与离线成本
- 放弃/纠正：**historical / rejected / superseded** — R21性能/36.9%时间不可混入最终1400
- 后续替代关系：R21压缩/旧Zhang候选由R26增强基线及R31/R32的全载波1-D架构取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/22_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 23 — Round 22

[23_round22_zhang_parameter_audit.md](../research/23_round22_zhang_parameter_audit.md)

- 日期：未载明（不推定）
- 问题/假设：针对Zhang本身重排载波/网格是否改善？
- 算法与变更：385+49/35/25候选；L96与0.02窗固定
- 数据角色：development; reused historical data; independent subset only as stated
- 样本/工作量：150×15=2250校准评估；复用600验证
- 数值：0dB候选0.028132m显著劣于冻结0.026202m
- 统计与失败边界：参数泛化失败，未穷尽组合
- 假设判断：REJECTED or mixed; see numerical result
- 保留：不能只用弱对手；拒绝候选记录
- 放弃/纠正：**historical / rejected / superseded** — Zhang-R22-tuned
- 后续替代关系：R21压缩/旧Zhang候选由R26增强基线及R31/R32的全载波1-D架构取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/23_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 24 — Round 23

[24_round23_zhang_full_joint_mc_optimization.md](../research/24_round23_zhang_full_joint_mc_optimization.md)

- 日期：未载明（不推定）
- 问题/假设：五维联合重调能否加强Zhang-style？
- 算法与变更：K1025/L224/0.1deg/0.0025m/37,27,19
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：136候选；4128评估；600新验证
- 数值：C0.18615/0.022010/0.0027301m；旧我方对C仅20dB显著
- 统计与失败边界：其中L与窗口已公开；136不是18144穷举；边界93.89%
- 假设判断：PARTIAL / qualified
- 保留：更强基线与窄窗正则化解释
- 放弃/纠正：**historical / rejected / superseded** — 全部五维未知、全SNR显著领先
- 后续替代关系：R21压缩/旧Zhang候选由R26增强基线及R31/R32的全载波1-D架构取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/24_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 25 — Round 24

[25_round24_two_server_10000_mc_protocol.md](../research/25_round24_two_server_10000_mc_protocol.md)

- 日期：未载明（不推定）
- 问题/假设：是否进行双服务器万次/SNR确认？
- 算法与变更：R24 protocol先R25后R26前置锁定
- 数据角色：software-only
- 样本/工作量：计划30000；该文未证明执行
- 数值：仅准备分片、恢复、完整性流程
- 统计与失败边界：PROTOCOL ONLY；后由R34 1400最终确认取代，不能计入实测样本
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：seed/分片完整性理念
- 放弃/纠正：**historical / rejected / superseded** — R24未来命令不再执行
- 后续替代关系：R24万次计划未作为最终测试执行；最终确认采用R34的1400trial协议
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/25_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 26 — Round 25

[26_round25_equal_budget_full_joint_optimization_protocol.md](../research/26_round25_equal_budget_full_joint_optimization_protocol.md)

- 日期：未载明（不推定）
- 问题/假设：双方能否同候选预算联合调参？
- 算法与变更：R25八维136候选，successive halving
- 数据角色：software-only
- 样本/工作量：计划4128评估/方法+600验证；本文为协议
- 数值：升级R26前的历史预实验协议
- 统计与失败边界：不据协议推算已执行量
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：同校准、同候选预算原则
- 放弃/纠正：**historical / rejected / superseded** — R25小协议被R26 superseded
- 后续替代关系：明确由R26的1000校准/SNR同预算协议取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/26_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 27 — Round 26

[27_round26_large_equal_budget_joint_optimization.md](../research/27_round26_large_equal_budget_joint_optimization.md)

- 日期：未载明（不推定）
- 问题/假设：大规模同预算联合调参方案
- 算法与变更：R26 136→32→8、67→333→1000/SNR
- 数据角色：software-only
- 样本/工作量：计划68880评估/方法；3000校准+600验证
- 数值：结果在文档28核验，本文仅协议
- 统计与失败边界：全参数维度覆盖不是笛卡尔穷举
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：预定义预算与冻结数据隔离
- 放弃/纠正：**historical / rejected / superseded** — 未来R24计划被R34取代
- 后续替代关系：协议执行结果由文档28审计；旧FSJAD部署配置后由R32取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/27_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 28 — Round 26

[28_round26_results_and_theory_audit.md](../research/28_round26_results_and_theory_audit.md)

- 日期：2026-09-05
- 问题/假设：R26结果、理论及源码配对是否可靠？
- 算法与变更：两MAT重配对Zhang-R26，前端/时延/候选审计
- 数据角色：mechanism audit; calibration
- 样本/工作量：已完成68880评估/方法；600验证；20000已有用户bootstrap
- 数值：range降7.9543/20.124/63.062%；-10未显著；已知seed继续求解-0.104711到+0.001001m
- 统计与失败边界：原表错用R23；12次截断；未统一RF能源；窗口实际可达0.00278333m
- 假设判断：PARTIAL / qualified
- 保留：纠正公开参数、复增益、实秩、实际可达域
- 放弃/纠正：**historical / rejected / superseded** — 旧FSJAD-R26非P_A；未知时延鲁棒、global最优
- 后续替代关系：R26旧FSJAD不再是最终方法；增强C的K/L/窗口数值继承，front和硬窗规则须看R31/R32
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/28_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 29 — Round 27

[29_round27_convergence_and_ablation_protocol.md](../research/29_round27_convergence_and_ablation_protocol.md)

- 日期：未载明（不推定）
- 问题/假设：共享前端200次收敛是否消除差异？
- 算法与变更：R27 v1单调GN，包含后废弃declared支路
- 数据角色：software-only
- 样本/工作量：计划3000已有校准；此文尚无完成性能
- 数值：初版测试受环境阻断，未验证
- 统计与失败边界：PROTOCOL/SOFTWARE；v1不能当已运行结果
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：内层收敛不同外层选参
- 放弃/纠正：**historical / rejected / superseded** — v1、把准备代码当通过
- 后续替代关系：R27 v1/v2明确由v3（文档31）取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/29_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 30 — Round 27

[30_round27_v2_server_protocol.md](../research/30_round27_v2_server_protocol.md)

- 日期：2026-09-06
- 问题/假设：QR前端和同角度消融v2
- 算法与变更：实增广QR/200-400；12输出
- 数据角色：software-only
- 样本/工作量：44预检；30软件smoke；200/SNR为后续计划
- 数值：已知seed200/400稳定；v2后来废弃
- 统计与失败边界：declared公式审计误混入性能集
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：数值驻点与truth误差分开
- 放弃/纠正：**historical / rejected / superseded** — R27-v2整个协议superseded
- 后续替代关系：R27 v1/v2明确由v3（文档31）取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/30_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 31 — Round 27

[31_round27_v3_server_protocol.md](../research/31_round27_v3_server_protocol.md)

- 日期：2026-09-06
- 问题/假设：v3隔离公式审计后正式消融
- 算法与变更：11输出；D-C主比较，同角度
- 数据角色：mechanism audit; calibration
- 样本/工作量：30本地smoke；600后续完成由32确认
- 数值：v2/v3共同11方法差0；smoke选中解100%收敛
- 统计与失败边界：600为R26派生校准，非独立；200次并未排除候选遗漏
- 假设判断：PARTIAL / qualified
- 保留：v3机制数据身份
- 放弃/纠正：**historical / rejected / superseded** — declared_protocol不进入性能表
- 后续替代关系：v3作为历史校准来源保留；前端候选闭合后由R28/R29参考前端深化
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/31_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 32 — Round 28

[32_round28_fixed_angle_distance_ablation_protocol.md](../research/32_round28_fixed_angle_distance_ablation_protocol.md)

- 日期：2026-09-07
- 问题/假设：固定角度、冻结子空间的2×2距离消融？
- 算法与变更：Mn/Pn/Mw/Pw，同求解器；窄0.00278333m/宽2m
- 数据角色：mechanism audit; calibration
- 样本/工作量：600已有用户设计；9定向seed/45起点；非执行完成证明
- 数值：主比较Pw-Mw预定义；30smoke见34，600实际升级R29
- 统计与失败边界：不同Y空间统计与z相干统计；同窗非同信息
- 假设判断：PARTIAL / qualified
- 保留：2×2机制设计与批次无关原始log-MUSIC
- 放弃/纠正：**historical / rejected / superseded** — 旧单点归一化评分作为连续目标
- 后续替代关系：R28原/改进前端及增量计划由R29有限验收与一般化接线取代；失败原样保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/32_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 33 — Round 28

[33_round28_server_run_guide.md](../research/33_round28_server_run_guide.md)

- 日期：2026-09-07
- 问题/假设：如何增量执行R28？
- 算法与变更：分片、checkpoint、定向闭合入口
- 数据角色：software-only
- 样本/工作量：600与45起点为计划
- 数值：无新增科学结果，服务器指南
- 统计与失败边界：SOFTWARE/PROTOCOL；不能按命令认定已执行
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：完整覆盖/失败保留
- 放弃/纠正：**historical / rejected / superseded** — 旧运行命令，仅内部归档
- 后续替代关系：R28原/改进前端及增量计划由R29有限验收与一般化接线取代；失败原样保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/33_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 34 — Round 28

[34_round28_implementation_and_local_validation.md](../research/34_round28_implementation_and_local_validation.md)

- 日期：2026-09-07
- 问题/假设：R28实现与小样本数值闭合是否可靠？
- 算法与变更：冻结子空间评分与共享一维多峰求解器
- 数据角色：mechanism audit; calibration
- 样本/工作量：30smoke(10/SNR)；先完成1seed×5起点
- 数值：Mw0.3844/0.09623/0.01476m；Pw0.1423/0.01029/0.001636m
- 统计与失败边界：每SNR10仅smoke；不作主性能；剩余8seed当时未完成
- 假设判断：PARTIAL / qualified
- 保留：宽窗暴露竞争模态线索
- 放弃/纠正：**historical / rejected / superseded** — 把30例当600；选中稳定等同全部候选收敛
- 后续替代关系：R28原/改进前端及增量计划由R29有限验收与一般化接线取代；失败原样保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/34_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 35 — Round 28

[35_round28_front_candidate_closure_v2.md](../research/35_round28_front_candidate_closure_v2.md)

- 日期：2026-09-07
- 问题/假设：旧起点驻定是否仍漏候选？
- 算法与变更：R28-v2 full range0.05m,16峰；200/400/800
- 数据角色：mechanism audit; calibration
- 样本/工作量：9预定seed；有限定向诊断
- 数值：至少2样本有更高候选；36200073至800仍未驻定
- 统计与失败边界：不是总体；更高评分不保证更小truth误差
- 假设判断：PARTIAL / qualified
- 保留：candidate miss/wrong mode区分
- 放弃/纠正：**historical / rejected / superseded** — 只延长同一批起点已完全闭合假设
- 后续替代关系：R28原/改进前端及增量计划由R29有限验收与一般化接线取代；失败原样保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/35_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 36 — Round 29

[36_round29_finite_acceptance_and_integration.md](../research/36_round29_finite_acceptance_and_integration.md)

- 日期：2026-09-07
- 问题/假设：有限敏感性后无历史锚点一般化接线
- 算法与变更：R29 reference0.025m/32峰；新F*重算C*，固定state
- 数据角色：mechanism audit; calibration
- 样本/工作量：4seed×4配置(4复用+12新增)；60pilot计划
- 数值：触发预定最密参考而停止加密；旧复现容差失败保留
- 统计与失败边界：新工程容差不能把旧失败改成通过
- 假设判断：PARTIAL / qualified
- 保留：无seed输入前端、固定态消融
- 放弃/纠正：**historical / rejected / superseded** — R28旧容差通过、R29低成本主张
- 后续替代关系：R29机制证据保留；高成本参考前端的部署身份由R32 L06/P_A取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/36_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 37 — Round 29

[37_round29_model_and_cost_scope.md](../research/37_round29_model_and_cost_scope.md)

- 日期：未载明（不推定）
- 问题/假设：z/Y、nuisance与成本有何严格边界？
- 算法与变更：模型与成本口径文档，无算法变更
- 数据角色：mechanism audit; calibration
- 样本/工作量：无新增用户
- 数值：公共初相可消元；公共时延不能由单复常数消除
- 统计与失败边界：z/Y条件独立理想化、非同接收的等价表示；EFIM非混合算法界
- 假设判断：PARTIAL / qualified
- 保留：明确同步LoS、能源/时隙缺口
- 放弃/纠正：**historical / rejected / superseded** — 同信息纯目标优越、硬件等能量主张
- 后续替代关系：R29机制证据保留；高成本参考前端的部署身份由R32 L06/P_A取代
- 当前用途：Yes: definitions/complexity/scope, no new performance claim；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/37_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 38 — Round 29

[38_round29_execution_record.md](../research/38_round29_execution_record.md)

- 日期：未载明（不推定）
- 问题/假设：R29有限敏感性和pilot实际通过多少？
- 算法与变更：同36冻结规则；严格记录失败/更新
- 数据角色：mechanism audit; calibration
- 样本/工作量：16敏感性结果；60pilot；首用户串行复现
- 数值：60/60驻定；4,750,808响应；9.03h；Holm p约0.051747
- 统计与失败边界：Pw对H并非必需；600当时仅60缓存+540待计算
- 假设判断：PARTIAL / qualified
- 保留：数值验收不以获胜为条件
- 放弃/纠正：**historical / rejected / superseded** — 旧withinTolerance=0改写为通过；低成本身份
- 后续替代关系：R29机制证据保留；高成本参考前端的部署身份由R32 L06/P_A取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/38_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 39 — Round 29

[39_round29_source_change_index.md](../research/39_round29_source_change_index.md)

- 日期：未载明（不推定）
- 问题/假设：哪些源文件改变，历史是否保留？
- 算法与变更：+r29与独立入口；旧164文件哈希无变化
- 数据角色：software-only
- 样本/工作量：软件索引，0新用户
- 数值：176等运行依赖身份；历史保护
- 统计与失败边界：不是性能实验
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：可追溯源码与状态
- 放弃/纠正：**historical / rejected / superseded** — 旧seed短路完成标志用于新结果
- 后续替代关系：R29机制证据保留；高成本参考前端的部署身份由R32 L06/P_A取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/39_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 40 — Round 29

[40_round29_server_handoff.md](../research/40_round29_server_handoff.md)

- 日期：未载明（不推定）
- 问题/假设：有效交付包及600机制执行方式
- 算法与变更：084238包；两片各30缓存/270待算
- 数据角色：software-only
- 样本/工作量：60完成；540计划；非600已完成
- 数值：116/116预检；232包文件哈希匹配
- 统计与失败边界：开发pilot Holm未达0.05；内部指南
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：包身份与复用provenance
- 放弃/纠正：**historical / rejected / superseded** — 083718缺依赖草稿
- 后续替代关系：R29机制证据保留；高成本参考前端的部署身份由R32 L06/P_A取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/40_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 41 — Round 29

[41_round29_600_mechanism_audit.md](../research/41_round29_600_mechanism_audit.md)

- 日期：2026-09-10
- 问题/假设：600冻结态机制结果是否支持距离统计差异？
- 算法与变更：R29 F*，K2047/L160；Mn/Pn/Mw/Pw
- 数据角色：mechanism audit; calibration
- 样本/工作量：600 R26派生校准(200/SNR)
- 数值：Pw/Mw RMSE降低74.38/90.97/91.67%；边界549/78/1/0；Holm p1.4999e-4
- 统计与失败边界：Pw对H在20dB退化2.02%；校准证据，非最终；44,875,126前端调用
- 假设判断：PARTIAL / qualified
- 保留：竞争模态、窄窗正则化、profile非普遍必要
- 放弃/纠正：**historical / rejected / superseded** — R29参考前端作为低成本最终部署
- 后续替代关系：R29机制证据保留；高成本参考前端的部署身份由R32 L06/P_A取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/41_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 42 — Round 30

[42_round30_lightweight_protocol.md](../research/42_round30_lightweight_protocol.md)

- 日期：2026-09-10
- 问题/假设：有限六个少载波候选能否兼顾精度成本？
- 算法与变更：R30 L01-L06；65-513前端、5-65 MUSIC
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：6候选协议；真实单seed smoke
- 数值：L01烟雾出现混叠36.55m；L02-06约26.336m
- 统计与失败边界：单seed不能选型；通过工程门槛待60pilot
- 假设判断：PARTIAL / qualified
- 保留：有上限开发预算
- 放弃/纠正：**historical / rejected / superseded** — 添加第7候选或放宽门槛
- 后续替代关系：R30候选拒绝且600扩展停止；R31另立控制协议，不追溯改成R30成功
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/42_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 43 — Round 30

[43_round30_method_and_complexity_draft.md](../research/43_round30_method_and_complexity_draft.md)

- 日期：未载明（不推定）
- 问题/假设：轻量前端与角度专用MUSIC的复杂度结构
- 算法与变更：R30方法草稿，统一单向量O(KGL)
- 数据角色：software-only
- 样本/工作量：无新增用户
- 数值：F/H/P分别计成本；不能只给我方低阶投影
- 统计与失败边界：预期贡献尚未证实
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：前端成本不能免费扣除
- 放弃/纠正：**historical / rejected / superseded** — 以少载波公式直接宣布精度保持
- 后续替代关系：R30候选拒绝且600扩展停止；R31另立控制协议，不追溯改成R30成功
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/43_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 44 — Round 30

[44_round30_execution_and_handoff.md](../research/44_round30_execution_and_handoff.md)

- 日期：2026-09-10
- 问题/假设：R29收尾和R30六候选实际执行
- 算法与变更：R30 L01-L06开发筛选
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：60×6=360配置评估；少量N缩放
- 数值：0候选通过；L06角度差7.09/4.76/2.78倍
- 统计与失败边界：失败由角度主导；600扩展明确未执行
- 假设判断：REJECTED or mixed; see numerical result
- 保留：真实失败和Pareto诊断
- 放弃/纠正：**historical / rejected / superseded** — R30扩展及以P_L距离好掩盖角度失败
- 后续替代关系：R30候选拒绝且600扩展停止；R31另立控制协议，不追溯改成R30成功
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/44_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 45 — Round 30

[45_round30_pilot_and_complexity_results.md](../research/45_round30_pilot_and_complexity_results.md)

- 日期：2026-09-10
- 问题/假设：R30低成本性能是否达标？
- 算法与变更：L05/L06 diagnostic；N128/256/512计时
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：60开发；3位置×3重复/阵列规模
- 数值：L06 P_L range0.12730/0.010048/0.001326m；角度0.007496/0.002286/0.000254deg
- 统计与失败边界：全部联合门槛失败；旧增强计时L被裁128，R31纠正
- 假设判断：REJECTED or mixed; see numerical result
- 保留：少载波损角度线索
- 放弃/纠正：**historical / rejected / superseded** — R30成功压缩、旧L128计时作L160
- 后续替代关系：R30候选拒绝且600扩展停止；R31另立控制协议，不追溯改成R30成功
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/45_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 46 — Round 31

[46_round31_correctness_repair_and_angle_controls.md](../research/46_round31_correctness_repair_and_angle_controls.md)

- 日期：2026-09-10
- 问题/假设：删除距离维还是少载波造成角度损失？
- 算法与变更：R31 C/A/B：2047二维、2047一维、65一维；L160固定
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：60既有开发；L06修复重放；3位置×3计时
- 数值：A=C角度60/60；B/A angleRMSE7.62/5.72/2.56倍；P_A工程门槛通过
- 统计与失败边界：候选保留缺口在旧L06未影响输出；不能追溯R30成功
- 假设判断：PARTIAL / qualified
- 保留：全载波一维角度、P_A候选
- 放弃/纠正：**historical / rejected / superseded** — 65载波B；旧错误计时联结、线程Java哈希
- 后续替代关系：R31全载波P_A后在R32冻结；R31软件/负结果记录保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/46_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 47 — Round 31

[47_round31_source_change_index.md](../research/47_round31_source_change_index.md)

- 日期：2026-09-10
- 问题/假设：R31源码改动与身份
- 算法与变更：+r31单独命名空间，132依赖文件
- 数据角色：software-only
- 样本/工作量：软件索引，无新用户
- 数值：13新增测试；最终137全项目通过
- 统计与失败边界：非新性能
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：不回写历史命名空间
- 放弃/纠正：**historical / rejected / superseded** — 诊断候选自动扩展
- 后续替代关系：R31全载波P_A后在R32冻结；R31软件/负结果记录保留
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/47_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 48 — Round 32

[48_round32_pa_method_theory_and_scope.md](../research/48_round32_pa_method_theory_and_scope.md)

- 日期：2026-09-10
- 问题/假设：冻结P_A与有限离散角度条件
- 算法与变更：L06 Q513/8候选/10次；K2047/L160/G93；profile2m,0.05m,lambda1
- 数据角色：mechanism audit; calibration
- 样本/工作量：方法定义，沿用60开发；20位置时延计划
- 数值：Delta_l>2epsilon_l是逐级充分条件，非全局定理
- 统计与失败边界：接收稿已公开顺序RF重构；P_A仍依赖coarse角窗和2m域
- 假设判断：PARTIAL / qualified
- 保留：P_A架构、truth-free独立入口
- 放弃/纠正：**historical / rejected / superseded** — 旧alpha、普遍解耦、原文RF未说明指控
- 后续替代关系：R32统计方法保留；实现由R33A等价加速，final编排/索引由R34修正；未执行状态已过时
- 当前用途：Yes: definitions/complexity/scope, no new performance claim；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/48_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 49 — Round 32

[49_round32_single_final_test_protocol.md](../research/49_round32_single_final_test_protocol.md)

- 日期：2026-09-10
- 问题/假设：最终独立试验如何冻结？
- 算法与变更：200位置×7SNR；position-cluster20000 bootstrap；1.21角MSE界
- 数据角色：software-only
- 样本/工作量：1400设计，本文未执行
- 数值：两个七SNR家族；P_A/C primary，H描述性
- 统计与失败边界：旧bootstrap实现后来R34修正，目标不变
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：固定样本、家族、数据角色
- 放弃/纠正：**historical / rejected / superseded** — 追加样本/按最终切换H/P
- 后续替代关系：R32统计方法保留；实现由R33A等价加速，final编排/索引由R34修正；未执行状态已过时
- 当前用途：Yes: definitions/complexity/scope, no new performance claim；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/49_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 50 — Round 32

[50_round32_pa_finite_closeout_results.md](../research/50_round32_pa_finite_closeout_results.md)

- 日期：2026-09-10
- 问题/假设：冻结方法有限验收与模型边界
- 算法与变更：R32独立入口、计时、±0.1ns检查
- 数据角色：development; calibration; historical independent validation where explicitly stated
- 样本/工作量：3入口回归；60 raw复用；4方法×9计时；20零时延复用+40扰动
- 数值：P_A15.250s/C23.475s降35.04%；时延引距±0.02998m
- 统计与失败边界：开发-10/0区间跨0；高SNR profile略差；计时后由R33替代
- 假设判断：PARTIAL / qualified
- 保留：已校准公共时延前提、完整online计时
- 放弃/纠正：**historical / rejected / superseded** — 35.04%当最终计时；未知时延鲁棒
- 后续替代关系：R32统计方法保留；实现由R33A等价加速，final编排/索引由R34修正；未执行状态已过时
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/50_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 51 — Round 32

[51_round32_source_change_index_and_run_guide.md](../research/51_round32_source_change_index_and_run_guide.md)

- 日期：2026-09-10
- 问题/假设：R32源码和交付目录索引
- 算法与变更：+r32单独保留；147测试
- 数据角色：software-only
- 样本/工作量：软件-only；最终设计1400未执行
- 数值：入口最大range差3.61e-9m，见50
- 统计与失败边界：不是60新回归；不重复计用户
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：依赖/门禁与历史保护
- 放弃/纠正：**historical / rejected / superseded** — 增量小包当独立完整工程
- 后续替代关系：R32统计方法保留；实现由R33A等价加速，final编排/索引由R34修正；未执行状态已过时
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/51_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 52 — Round 33

[52_round33_finite_complexity_and_equivalent_acceleration.md](../research/52_round33_finite_complexity_and_equivalent_acceleration.md)

- 日期：2026-09-10
- 问题/假设：等价加速可否通过预冻结精度门禁？
- 算法与变更：R33 A q-only/invariant direct EVD；B/AB Gram
- 数据角色：software-only; frozen timing
- 样本/工作量：9旧用户×4方法=36输出/变体；4×9计时
- 数值：A score/angle/range差0；B/AB score1.480e-12>1e-12失败；P_A9.133054/C18.336638s
- 统计与失败边界：最终输出相同仍不能宣告Gram通过；60组合回归未执行
- 假设判断：PARTIAL / qualified
- 保留：A-only；评分点降96.98%、总时间降50.1923%分开
- 放弃/纠正：**historical / rejected / superseded** — Gram B/AB、eigs或幂迭代
- 后续替代关系：R33A被R34正式继承；B/AB拒绝不变；最终未授权状态由R34实际执行取代
- 当前用途：Yes: definitions/complexity/scope, no new performance claim；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/52_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 53 — Round 33

[53_round33_source_index_and_reproduction.md](../research/53_round33_source_index_and_reproduction.md)

- 日期：2026-09-10
- 问题/假设：R33结果与源码复核入口
- 算法与变更：接受A-only身份；参考v1失败、v2修正
- 数据角色：software-only
- 样本/工作量：软件索引；9旧用户，不是60
- 数值：160全项目测试；source摘要ab98e12f…
- 统计与失败边界：历史默认UseGram=true必须由R34显式封闭
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：accepted A-only身份
- 放弃/纠正：**historical / rejected / superseded** — B/AB和60等价回归成功主张
- 后续替代关系：R33A被R34正式继承；B/AB拒绝不变；最终未授权状态由R34实际执行取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/53_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 54 — Round 33

[54_round33_delivery_manifest.md](../research/54_round33_delivery_manifest.md)

- 日期：2026-09-10
- 问题/假设：R33增量交付包含什么？
- 算法与变更：增量包、依赖R32等
- 数据角色：software-only
- 样本/工作量：0新用户；不包含60组合回归
- 数值：9用户验收和计时已保存；最终未执行
- 统计与失败边界：交付清单非实验
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：包范围披露
- 放弃/纠正：**historical / rejected / superseded** — 增量包冒充全项目
- 后续替代关系：R33A被R34正式继承；B/AB拒绝不变；最终未授权状态由R34实际执行取代
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/54_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 55 — Round 34

[55_round34_final_engineering_integration.md](../research/55_round34_final_engineering_integration.md)

- 日期：2026-09-10
- 问题/假设：A-only接入及bootstrap索引是否正确？
- 算法与变更：R34 wrapper UseGram=false；reshape列保持bootstrap
- 数据角色：software-only
- 样本/工作量：3旧输入smoke；14专项+174全项目
- 数值：旧3×4索引错误给1×1，新4×1与循环相同；Gram0
- 统计与失败边界：软件修正于final前；不改变预声明估计量/家族/置信水平
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：R34正式入口和整位置分片
- 放弃/纠正：**historical / rejected / superseded** — 错误bootstrap、worker Java哈希、Gram默认风险
- 后续替代关系：工程定义仍保留；准备/授权状态由文档62完成记录更新；增量包以完整授权包为准
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/55_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 56 — Round 34

[56_round34_paper_ready_method_complexity_and_limits.md](../research/56_round34_paper_ready_method_complexity_and_limits.md)

- 日期：2026-09-10
- 问题/假设：哪些方法/复杂度/机制文字可写论文？
- 算法与变更：R32统计方法+R33A+R34编排
- 数据角色：software-only
- 样本/工作量：论文材料；最终结果当时留空
- 数值：R29机制与R33计时分别引用；final不填假值
- 统计与失败边界：本文预留表已被62/63真实结果取代
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：边界限定与公式
- 放弃/纠正：**historical / rejected / superseded** — 把留空时期状态当当前未执行
- 后续替代关系：工程定义仍保留；准备/授权状态由文档62完成记录更新；增量包以完整授权包为准
- 当前用途：Yes: definitions/complexity/scope, no new performance claim；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/56_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 57 — Round 34

[57_round34_source_index_and_future_run_guide.md](../research/57_round34_source_index_and_future_run_guide.md)

- 日期：2026-09-10
- 问题/假设：R34源码/依赖/运行指南
- 算法与变更：165执行文件、源码摘要2d40cca4…
- 数据角色：software-only
- 样本/工作量：软件索引；3smoke非最终
- 数值：174测试；1400设计未运行的历史状态
- 统计与失败边界：当时未授权状态后由60/61取代
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：身份绑定分片与聚合
- 放弃/纠正：**historical / rejected / superseded** — 重跑历史未来命令
- 后续替代关系：工程定义仍保留；准备/授权状态由文档62完成记录更新；增量包以完整授权包为准
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/57_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 58 — Round 34

[58_round34_full_dependency_package_correction.md](../research/58_round34_full_dependency_package_correction.md)

- 日期：2026-09-11
- 问题/假设：增量包缺依赖如何修正？
- 算法与变更：24/165源已含、141缺失；完整包
- 数据角色：software-only
- 样本/工作量：软件打包，无新用户
- 数值：165哈希复制；MATLAB+Parallel Computing Toolbox
- 统计与失败边界：包修复不是算法修改；历史授权处理后纠正
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：依赖清单
- 放弃/纠正：**historical / rejected / superseded** — 旧增量包用于空目录独立运行
- 后续替代关系：工程定义仍保留；准备/授权状态由文档62完成记录更新；增量包以完整授权包为准
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/58_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 59 — Round 34

[59_round34_full_dependency_server_run_guide.md](../research/59_round34_full_dependency_server_run_guide.md)

- 日期：2026-09-11
- 问题/假设：完整依赖包如何预检？
- 算法与变更：R34 source/design不变
- 数据角色：software-only
- 样本/工作量：软件指南，无新用户
- 数值：明确排除授权的历史包
- 统计与失败边界：本文件是当时未授权说明，后由60/61更新
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：包前置检查
- 放弃/纠正：**historical / rejected / superseded** — 当前要求重新授权/运行最终测试
- 后续替代关系：工程定义仍保留；准备/授权状态由文档62完成记录更新；增量包以完整授权包为准
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/59_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 60 — Round 34

[60_round34_authorized_execution_correction.md](../research/60_round34_authorized_execution_correction.md)

- 日期：2026-09-11
- 问题/假设：合法授权后旧预检为何失败？
- 算法与变更：包外authorized_preflight；不改165源
- 数据角色：software-only
- 样本/工作量：软件流程修正，无新用户
- 数值：旧门禁要求无授权，授权后必然不满足
- 统计与失败边界：不能改旧预检以掩盖历史；实际server2偏差见62
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：授权后只读审计
- 放弃/纠正：**historical / rejected / superseded** — 把授权前门禁误当授权后缺陷
- 后续替代关系：工程定义仍保留；准备/授权状态由文档62完成记录更新；增量包以完整授权包为准
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/60_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 61 — Round 34

[61_round34_authorized_server_execution_guide.md](../research/61_round34_authorized_server_execution_guide.md)

- 日期：2026-09-11
- 问题/假设：一次冻结最终1400试验的授权与执行
- 算法与变更：R34A-only；两个100位置/700行分片
- 数据角色：software-only
- 样本/工作量：授权1400；实际完成见62
- 数值：source/design精确绑定；不允许参数变更
- 统计与失败边界：指南不替代结果；server2实际未获预检PASS
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：一次确认与停止规则
- 放弃/纠正：**historical / rejected / superseded** — 追加用户、切换方法
- 后续替代关系：工程定义仍保留；准备/授权状态由文档62完成记录更新；增量包以完整授权包为准
- 当前用途：No as final performance; selected mechanisms may be cited with historical role；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/61_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 62 — Round 34

[62_round34_final_independent_test_audit.md](../research/62_round34_final_independent_test_audit.md)

- 日期：2026-09-11
- 问题/假设：最终独立证据与身份是否可信？
- 算法与变更：冻结P_A/H_A/C_enhanced/C_public；R34A-only
- 数据角色：final confirmation; independent validation
- 样本/工作量：200独立位置×7SNR=1400；每SNR200
- 数值：1398角度完全同；全部角度NI；距离仅0/15/20优效；低SNR max1.9111到0.6656m
- 统计与失败边界：server2空目录预检失败、aggregate旧metadata需披露；P_A对H高SNR轻微退化
- 假设判断：SUPPORTED: all angle NI; range superiority only 0/15/20; profile universal benefit rejected
- 保留：最终独立主证据及完整负面结果
- 放弃/纠正：**historical / rejected / superseded** — 全SNR优效、普遍profile必要、作者实现速度比较
- 后续替代关系：No: frozen final independent confirmation; no post-hoc method replacement
- 当前用途：Yes: frozen independent results；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/62_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。

### Document 63 — Round 34

[63_round34_paper_results_and_abstract_draft.md](../research/63_round34_paper_results_and_abstract_draft.md)

- 日期：2026-09-11
- 问题/假设：论文结果和摘要如何表述？
- 算法与变更：引用62原始结果与R33冻结计时
- 数据角色：software-only; secondary reporting of final confirmation
- 样本/工作量：无新用户，复用1400最终
- 数值：距离数值降低3.05%-49.63%；时间降低50.19%
- 统计与失败边界：统计优效限定0/15/20；同步LoS条件z+Y
- 假设判断：N/A software/protocol; execution status explicitly separated
- 保留：四贡献、数据角色和limitations
- 放弃/纠正：**historical / rejected / superseded** — 摘要中普遍消误差、同信息理论优越
- 后续替代关系：数值沿用62不变；论文组织在本次66/67细化，不产生新性能结果
- 当前用途：Yes: definitions/complexity/scope, no new performance claim；补充材料需标角色；内部协议不作实测。
- 完整配置、所有子实验表格和原始路径：[逐文证据](../paper_support/history_evidence/63_source_evidence.md)；结构化全部23字段见[CSV](../paper_support/experiment_ledger.csv)。
