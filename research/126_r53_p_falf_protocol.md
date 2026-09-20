# R53：P_FALF 距离后端独立开发协议

日期：2026-09-18  
状态：**方法与Gate预声明；尚未读取R53性能结果**

## 1. 冻结边界

- 冻结 P_FA 的 L06 前端、2047载波选择、完整N=256 Fresnel角度目标、正负0.2 deg搜索窗和连续细化；
- theta_P_FALF 必须逐行严格等于冻结 theta_P_FA；
- 不修改 matlab/+r45、R46结果或既有审计文档；
- R53新代码只放在 matlab/+r53，独立入口为 matlab/experiments/run_round53_p_falf_development.m；
- 不读取R46 final、R45/R48 calibration、R51/R52 development结果进行选参或Gate决策。

## 2. 唯一候选

固定 theta=theta_FA，对同一个局部距离区间计算两个残差块。

标量块：

\[
E_z(r)=\|z\|^2-\frac{|q(\theta_{FA},r)^Hz|^2}
{\|q(\theta_{FA},r)\|^2},
\qquad
\ell_z(r)=-M\log\frac{E_z(r)}{M}.
\]

阵列块每载波独立消去复增益：

\[
E_Y(r)=\sum_m\left(\|y_m\|^2-
\frac{|a_m(\theta_{FA},r)^Hy_m|^2}{\|a_m(\theta_{FA},r)\|^2}\right),
\]

\[
\ell_Y(r)=-NK\log\frac{E_Y(r)}{NK}.
\]

唯一新方法：

\[
\ell_{FALF}(r)=\ell_z(r)+\ell_Y(r),
\qquad
\hat r_{FALF}=\arg\max_r\ell_{FALF}(r).
\]

普通集中最大似然使用原始复观测数 M 与 NK，不是残差自由度 M-1 与 K(N-1)。后者若作为
限制或积分似然使用，还需要设计矩阵行列式项，本轮不采用。

禁止引入 lambda、temperature、SNR权重、学习权重、selector、扩大支持、全局恢复或truth信息。

## 3. 搜索与诊断

- 距离支持、粗网格、保留峰数、fminbnd容差完全继承P_A；
- A：P_A；B：P_FA硬角度q-only；C：固定P_FA角度的Y-only诊断；D：P_FALF，唯一Primary；
- 曲率统一在 r_FA 计算，并补充P_FALF选中点联合曲率；
- basin定义为同一冻结q粗网格上的最近保留峰编号；
- 报告 |H_Y|/|H_z|、距离位移、q峰身份变化和Y-only/q basin一致率。

## 4. 独立development设计

- 30个全新位置；
- SNR为 -10/0/20 dB；
- 共90行逐位置配对数据；
- position seed：68000000；trial seed root：68100000；
- 不追加样本，不根据结果改权重、阈值或模型。

## 5. 预声明Gate

1. 数据谱系统计Gate必须通过；
2. P_FALF角度逐行等于P_FA，最大差不超过 1e-12 deg；
3. equal-SNR聚合距离 MSE(P_FALF)/MSE(P_A) <= 0.98；
4. 每个SNR距离MSE比不超过 1.05；
5. 大于1 m失捕率不高于P_A；
6. 完整独立运行时间低于C_enhanced。

bootstrap、配对差、W/T/L和尾部指标只用于报告，不反向修改Gate。

## 6. 停止规则

若任一Gate失败，R53正式判为Development FAIL，不进入600行calibration，不增加融合权重、
候选、selector、窗口或样本。该结果将关闭当前观测模型下的PA-free距离增强路线。

