# R36 定向验证中文总结

日期：2026-09-12。本轮按运行前固定的R36协议，使用12个新的Latin-hypercube位置，在-10、0、20 dB各运行一次，共36个条件。原P_A、R34、R35和冻结源代码均未修改。

## 核心结果

1. **最终角度保持很强，但不是绝对相同。** P_A的一维MUSIC与同状态、同载波、同角窗、距离窗±1m的二维MUSIC在35/36个条件中最终角度严格相同；36/36均在一个最终网格步长内。唯一差异发生在case2、0dB，差值为0.0002666667°。
2. **逐级验证是必要的。** 第1、2级的实际角度选择均为36/36相同，第3级为35/36。只检查第一级不能保证最终输出。
3. **单侧有限条件明显比原对称界更有认证能力。** 原gap>2epsilon条件在第1/2/3级分别认证26/23/18个条件；保守单侧条件分别认证36/33/33个条件。两类充分条件均为0次误认证。未通过条件不代表输出一定不同。
4. **profile模式切换存在，但本轮没有被实际角度误差触发。** 6/36个条件在±0.02°、步长0.0005°的固定扫描中出现相邻距离跳变超过0.02m，其中-10dB有4个、0dB有2个、20dB为0。最大跳变0.571676m。
5. **切换边界离实际误差仍较远。** 实际角度误差最大0.001492°；最近测得切换为0.00325°，最近切换与实际角度误差之比最小为3.05。直接在真实角度重新运行冻结profile后，0/36个条件的估计角度端点与真实角度端点相差超过0.02m。

## 研究判断

R36强化了“一维MUSIC在冻结配置下通常保持二维MUSIC角度”的有限证据，但也给出了一个真实的第3级反例，因此不能写成连续域精确解耦或普遍等价。

模式切换是条件profile的真实数值风险，但在本轮12个新位置中，实际角度误差不足以跨越观测到的切换边界。当前没有证据支持为此修改P_A、增加二维profile或引入SNR门控。

单侧条件目前仍通过评估实际二维有限评分面得到，属于解释性证书，不是低成本在线算法。若继续研究，应构造无需完整二维评分的严格竞争角增益上界，并在新的开发数据上形成方法，再使用新的未见位置验证；不能用R36继续选规则又称其为独立验证。

## 证据与限制

- [运行前协议](../research_extensions/r36_certificate_validation/PROTOCOL.md)
- [三级验证明细](77_r36_three_stage_certificate_validation.md)
- [模式切换与主张审查](78_r36_profile_switch_validation_and_claims_audit.md)
- [36条件结果](../research_extensions/r36_certificate_validation/results/conditions.csv)
- [108级证书](../research_extensions/r36_certificate_validation/results/stage_certificates.csv)
- [2916行profile扫描](../research_extensions/r36_certificate_validation/results/profile_switch_sweep.csv)
- [交付审计](../research_extensions/r36_certificate_validation/results/delivery_checks.csv)

本轮只有12个独立位置，三个SNR条件复用同一位置几何。结果是R35之后的新定向验证，不并入R34原预声明统计家族，也不支持多径、未知时延、硬件或任意配置下的普遍结论。
