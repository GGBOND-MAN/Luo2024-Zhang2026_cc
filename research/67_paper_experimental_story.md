# 论文实验故事线

日期：2026-09-11。正文按问题和证据组织；下列Round号只作为内部出处，投稿正文不照抄开发日志顺序。

## 1. What Zhang2026 solves

传统先角后距方法把估计角度显式代入距离阶段，可能放大误差。Zhang2026用beam-squint-assisted power-spectrum coarse JAD初始化，在局部二维域内做geometry-compensated MUSIC与多载波几何平均，以缓解显式代入式误差传播，并减少相对global 2-D MUSIC的搜索负担。应首先公平承认这是joint refinement。

## 2. What limitation remains

局部优化仍需要coarse center决定支持集与几何补偿。联合优化的形式本身不能保证truth属于支持集，也不能保证有限噪声下距离维的谱极大改善truth误差。原文已明确larger/smaller window的复杂度与失捕权衡，我们进一步用结构分析和控制实验识别其实际后果。图1讲机制，图2给预定final案例；±0.0025m只能标本项目C_enhanced。

## 3. How our experiments discovered it

起点是保留完整复频谱，避免把全部观测压缩成单个峰值索引。初始理论通过公共复增益消元得到集中似然与投影EFIM；离网格、相位、模型失配实验逐步划清同步和数值收敛条件。随后发现MUSIC角度能改善，range却常移向局部边界；小窗口改善捕获率可能只是截断有害移动。跨位置后，前端严重失捕又暴露有限支持无法恢复truth。这些是历史发现过程，不是最终P_A的性能数字。

## 4. Which early hypotheses failed

SNR门控校准选择完全不更新；学习置信门控收益未稳定显著；连续alpha、分组协方差和bootstrap存在小收益、跨SNR折衷及泛化失败。R11否定“共同偏差丢失是主因”的解释。R14的**REJECTED HYPOTHESIS**是local Hessian angle-range coupling主导失败：归一化交叉项约1%、预测相关近0，固定真角度未显著改善range。Fresnel近似在当前域造成大误差也不受支持。旧分支与旧强措辞全部留在内部演进和补充证据，不嵌入最终算法。

## 5. Why angle and range were assigned different roles

MUSIC空间子空间可提供高分辨angle；z中的跨频相干信息可供条件range估计。两者不是同一统计的等价变换。固定相同angle和subspace后，R29宽窗MUSIC暴露竞争模式，而profile在同宽支持下更稳定；同时它不普遍优于保留准确front range的H*。因此提出的是按信息来源分工的条件架构，不是理论证明一个objective在完全相同信息下胜过另一个。

## 6. Why full 2-D MUSIC was reduced to 1-D angle MUSIC

既然最终range由full-spectrum profile给出，需要检验为取得angle是否仍须付出完整二维MUSIC搜索。冻结窄range窗下，删去range维把网格3083降至93。R31通过同配置控制验证这一步与少载波压缩不同；R34用独立位置确认角度非劣。有限逐层score-gap条件提供解释，但不保证任意模型下相同解。

## 7. Why P_A was finally selected

P_A在已有60开发用户上通过未修改的精度工程门槛，以全载波angle search保留增强基线的角度，并以conditional profile修复部分有限前端range误差。随后R32在最终数据之前固定P_A，而H_A保留为消融。选择不来自R34的七条RMSE曲线，也不能因高SNR H_A略好而切换输出。L06有限前端不等于R29高成本数值参考，不声称全局求解。

## 8. What R30 failure taught us

六个低成本候选都未通过联合工程门槛。L06的profile range有用，但角度在三SNR明显退化。软件候选保留缺口后来修复，对这批L06输出没有影响，因此不能把失败归咎于该bug或事后宣布R30成功。它说明计算压缩必须同时核验角度信息，不能只展示距离和速度。

## 9. What R31 isolation proved

同L06、K2047、L160、相同补偿/子空间、相同41/31/21规则下，二维C和一维A角度60/60相同；把载波改为65的B角度RMSE为A的7.62/5.72/2.56倍。它支持当前角度损失主要随载波信息删除出现，删range维本身在这批数据没有损失。这个结论有限于开发数据和冻结配置；独立统计确认由图4提供。

## 10. What R33 acceleration changed and did not change

q-only计算避免不必要导数数组，调用内复用不变量。候选、carrier、subarray、window、grid、profile、λ和direct EVD保持冻结；所有对手同样获得这类实现优化。A在9个旧用户36条输出通过；Gram B/AB score超过预注册1e−12容差，维持拒绝，60组合回归未执行。计时收益为实现常数收益，不是普遍阶数降低；图7分别画评分点和完整online时间，S4补充模块成本。

## 11. What the frozen R34 independent test established

200独立位置跨七SNR复用，共1400配对trial，0失败。推断按positionId整簇20000次重采样，七角度和七距离分别为家族。角度七点同时上界均低于1.21；1398相同、另两例一个grid step。距离七点RMSE数值下降，但只有0/15/20dB建立预声明优效，position结果是次要终点。−10dB的40.54% RMSE下降伴随严格胜率47.5%，由严重尾部压缩驱动，图5必须保留分布而非只有均值。P_A对H_A在10/15/20dB分别微增0.72/0.56/0.14%，图6主动显示。图8将该独立精度与另行冻结计时联系，明确不同用户/协议。server2授权后预检未获PASS和旧aggregate元数据滞后在复现材料披露，原日志和MAT不修改。

## 12. What remains outside the scope

结论仅限同步LoS单径条件z+Y，公共时延已校准。z精确球面，Y/MUSIC用Fresnel，两路噪声条件独立且分别归一化；尚无统一物理RF、total-energy、时隙及路径损耗采集证明。旧相位噪声和两径试验不是最终P_A的异步或多径验证。z-only EFIM不是混合算法CRLB。P_A仍有有限前端、coarse-dependent angle域、profile有限支持与wrong-mode风险。对比对象为本地strengthened/transparent两类基线，不是作者真实完整代码，也不把论文估算3.90ms与本地秒数直接比较。

## 正文压缩主线

**Problem**：显式顺序代入已被joint JAD缓解，但局部coarse-to-fine仍受粗中心与支持约束。  
**Mechanism**：truth exclusion、边界正则化、宽域竞争模式；不采用Hessian主导假设。  
**Proposed solution**：有限复谱front → 全载波1-D MUSIC angle → conditional coherent range。  
**Complexity benefit**：MUSIC评分点−96.98%，完整online时间−50.19%，两者分别报告。  
**Independent evidence**：200×7冻结验证，angle全点非劣，range仅0/15/20统计优效。  
**Limitations**：高SNR profile增量近零并略负；低SNR尾部驱动；同步单径条件模型；无作者代码/硬件等能量普遍结论。

到此停止研究开发。论文材料整理不触发新模拟、调参或追加独立用户。
