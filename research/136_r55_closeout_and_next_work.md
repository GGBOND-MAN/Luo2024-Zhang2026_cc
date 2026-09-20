# R55之后的工作方案

日期：2026-09-19

## 1. 立即冻结

1. 永久冻结R55 result、COMPLETE、design、statistics和源码摘要；
2. 不重跑R55，不增加用户，不删除尾部，不更换seed；
3. 不通过修改primary endpoint把R55重新解释为PASS；
4. 不再追加新的P_FALF selector、权重或峰安全规则并使用R55验证；
5. 将R55正式标记为“Primary FAIL / Aggregate superiority PASS”。

## 2. 论文方法层级

建议最终论文按以下层级组织：

| 方法 | 论文角色 | 可支持的主要结论 |
|---|---|---|
| P_A | 主方法、主攻击依据 | 顺序角距估计和稳定距离性能，二维MUSIC非必要 |
| P_FA | 完整孔径角度机制 | 去除L160孔径损失及MUSIC/EVD后角度更优 |
| P_FALF | 聚合距离增强分支 | 保持P_FA角度并建立聚合距离优效，但七档同时非劣未建立 |
| G | P_A兼容增强参照 | 温和角度改善并保持P_A距离 |
| P_FAM5/R49/R51/R52 | 机制消融与负结果 | 排除局部边缘化、无条件扩窗和证书恢复路线 |

若论文必须只保留一个“所有主要终点均通过”的主方法，仍应选择P_A，而不是P_FALF。

## 3. 不新增数据的必要工作

下一阶段不应继续做方法选择实验，而应使用冻结结果完成以下只读工作：

1. 制作P_A/P_FA/P_FALF/G/C七SNR角度与距离MSE、RMSE总表；
2. 绘制逐SNR ratio及simultaneous上界森林图；
3. 绘制P_FALF-P_A配对平方误差ECDF和尾部累计贡献图；
4. 绘制range shift与平方误差改善散点图，标出大于0.1 m行；
5. 对R53、R54、R55做development-calibration-final外推一致性表；
6. 完成Y/z条件独立、集中似然和插件角度的理论限制说明；
7. 统一正文、摘要、表格和图注中的PASS/FAIL措辞。

所有R55追加分析必须明确标记为post-hoc，不能替代冻结主终点。

## 4. 推荐论文表述

推荐：

> P_FALF preserved the full-aperture P_FA angle estimates exactly and achieved
> a pre-specified aggregate range-MSE ratio of 0.719 relative to P_A, with a
> cluster-bootstrap upper 95% bound of 0.849. However, the pre-specified
> seven-SNR simultaneous 2% noninferiority family did not pass; therefore the
> overall final primary endpoint was not met.

不推荐：

- “P_FALF final实验通过”；
- “P_FALF在所有SNR统计优于P_A”；
- “P_FALF已经完全解决P_FA距离问题”。

更准确的中文表述是：

> P_FALF已经建立聚合距离优效，并在七档SNR均得到正向点估计，但尚未建立七档同时的距离
> 非劣，因此不能按预声明规则整体替代P_A。

## 5. 是否继续新的确认实验

不建议在当前论文中再设计一个以“聚合优效”为新Primary的final实验。这样会在看到R55结果后
更换主要终点，容易形成endpoint shopping，也违背一次性final规则。

若未来在独立论文或新硬件数据上继续，应作为全新的研究问题：预先把聚合重尾风险或失捕率设为
主要终点，并在真实同源Y/z观测模型下重新推导联合协方差。R55数据只能用于提出假说，不能再作
确认数据。

## 6. 下一交付物

当前最合理的下一项工作是“论文收束包”，包括：

- 最终方法对比表；
- 主结果与消融结果图；
- Zhang2026攻击点证据矩阵；
- 理论假设与局限性章节；
- R55 Primary FAIL与Aggregate PASS的一致性审计。

