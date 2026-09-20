# R50：P_FA 距离条件机制诊断协议

日期：2026-09-18  
版本：`R50-PFA-range-conditioning-diagnostics600-v1`  
状态：冻结诊断；不实现新估计器；完成后暂停

## 1. 数据边界

- 主诊断只使用既有R48 calibration-600的200个位置、`-10/0/20 dB`、600行；
- 不生成新位置，不访问R46观测以选择方法；
- R46 final-1400只做独立的只读配对/重尾结论审计，其结果不得决定后续候选；
- `+r32/+r45/+r47`保持只读，所有新增代码位于`+r50`。

## 2. 主诊断

每行重放冻结观测，并复用R48保存的同一L06前端中心和P_A/P_FA/P_FAM5输出。

1. `oracleLocal`：真值角度加原`r_F+-2 m` q-only profile；
2. `oracleGlobal`：真值角度加`[15,50] m`全物理距离profile；
3. `grid`：P_FA 41点网格最佳角度加原局部profile；
4. `continuous`：冻结P_FA连续角度及原距离输出；
5. 在P_A和P_FA各自`(theta,r)`处用`1e-4 deg/1e-3 m`中心差分计算q-score Hessian，
   `kappa=-J_rtheta/J_rr`；
6. 以选中粗峰中心差超过`0.05/0.10/0.20 m`分别定义三档mode-switch敏感性；主描述阈值
   固定为`0.10 m`；
7. 按逐行`kappa_i`计算距离MSE的angle、oracle残差和交叉项，不使用单一平均kappa替代。

## 3. Oracle统计判据

使用位置簇bootstrap 10,000次，seed `65000000`，报告oracle/local/global相对P_A和P_FA的
逐SNR与equal-SNR MSE比及双侧95%区间。

- 整个区间位于`[0.98,1.02]`才称实用等价；
- 上界低于`0.80`才称强oracle收益；
- 区间覆盖1但未落入等价带，只称结论不确定，不把未显著当作等价。

## 4. R46只读审计

对已有final-1400逐行结果报告：配对平方误差差和MSE比的共同位置簇bootstrap、top-1%/5%
贡献、按绝对配对差5% trimming、去除top-3/top-5的敏感性、中位平方误差和大于1 m失捕率。
这些结果不能覆盖或修改R46预声明的距离非劣失败结论。

## 5. 明确排除

- 本轮不执行B1/B2/B3，不实现R51；
- 不修改P_FAM5，不增加GH节点；
- 不执行Claude T5-T8；
- exact-spherical Y不在本轮运行，因为当前冻结Y数据由Fresnel模型生成，只替换估计器会把
  “统一模型”与“人为失配”混为一谈；若未来评估，必须作为独立数据生成模型消融。
