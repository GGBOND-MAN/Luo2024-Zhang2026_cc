# Round29收尾与Round30轻量化执行记录

日期：2026-09-10。

## Round29审计结论

下载包`round29_reference_upload_20260908_084238`中的两个分片各含300行，600个seed唯一，
-10/0/20 dB各200行，失败为0，聚合与分片源码哈希一致，冻结数值验收通过。该数据仍是
`R26-derived-calibration-not-independent-validation`，不能写成独立测试集。

同角度、同固定2m窗口下，`P_w`相对`M_w`的距离RMSE在-10/0/20 dB分别降低
74.38%/90.97%/91.67%，三个配对MSE区间均小于0。另一方面，`P_w`相对`H*`只在
-10 dB有14.06%的RMSE数值改善且区间跨0；0和20 dB分别退化0.36%和2.02%。因此，
复谱后端相对宽窗MUSIC的机制优势成立，但没有证据要求最终部署版必须保留`P_w`，也没有
证据支持FSJAD在全部SNR优于更简单的`H*`。

窄窗`M_n`有549/600个边界解，其中548个目标向外；`P_n`为78/600；`M_w`为1/600；
`P_w`为0。-10 dB下`M_w`的1m失捕率为6%，其他核心链路为0。这说明局部搜索域既是
复杂度机制，也是会改变统计输出的隐式约束；联合MUSIC避免固定角度点的机械级联，但不能
自动消除窗口、边界、冻结补偿/子空间和谱峰结构造成的距离误差。

600行前端共进行44,875,126次全频响应调用，平均74,791.9次/用户。并行任务归属时间之和
为前端1777.31小时、MUSIC 10.93小时、全链路1859.11小时；这些不是单用户墙钟时延，
也不能与论文Fig.9的3.90 ms估算值直接比较。R29前端只保留为数值参考。

## Round30实现

独立版本`R30-lightweight-development-v1`已经实现，不修改R29：

1. 稀疏全带宽子载波进行有限多峰筛选，只对4或8个候选做有上限的全频细化；
2. 在轻量前端输出处只构造一次几何补偿和子空间；
3. 固定前端距离的一维MUSIC角度得到`theta_1D`；
4. 输出`H_L=(theta_1D,r_FL)`和`P_L=(theta_1D,r_profile)`；
5. 不使用旧alpha，不按真值、真实SNR或单用户误差门控；
6. 公共论文配置假设基线与R26增强Zhang-style基线分开命名；
7. 计数器覆盖前端稀疏/全频响应、协方差/EVD、角度投影、profile响应与各模块时间。

候选固定为L01--L06，不允许增加第7个。若没有候选通过预声明工程阈值，只从真实非支配
Pareto集合中保留最多2个并标为诊断性失败，不继续寻优。

## 已完成验证

- MATLAB全量回归：124 passed，0 failed，0 incomplete；
- 动态Code Analyzer：0项；
- 单点/批次MUSIC评分、有限前端预算、身份拒绝、端到端计时、有限候选和Pareto回退均有测试；
- 最终真实全尺寸smoke：seed 36200001，-10 dB，L02成功；`P_L=26.336487298 m`，
  全响应等效调用317.607，轻量在线模块计时3.359 s；
- 同一smoke中的公开假设MUSIC和R26增强MUSIC接口均成功。

单个smoke不用于候选选择。L01在该样本上出现明显稀疏载波混叠，这正是60用户筛选必须
保留失捕率和尾部指标的原因。

## 执行顺序

先完成唯一一次60用户开发筛选并聚合：

```matlab
addpath('matlab/experiments');
run_round30_pilot_shard(1,1,NumWorkers=8,BatchSize=8,PoolType='Threads');
aggregate_round30_pilot;
run_round30_selected_baselines(NumWorkers=8,BatchSize=8);
aggregate_round30_selected_baselines;
run_round30_complexity_scaling(PositionCount=3,Repetitions=3);
```

只有60用户结果通过软件验收并冻结最多2个候选后，才准备现有600行缓存；不自动执行：

```matlab
addpath('matlab/experiments');
prepare_round30_600_cache;
```

两台32线程服务器的入口分别是：

```matlab
run_round30_selected_shard(1,2,NumWorkers=32,BatchSize=32);
run_round30_selected_shard(2,2,NumWorkers=32,BatchSize=32);
```

`BatchSize=32`只改变每次并行提交和检查点保存粒度，不改变seed、候选、算法或统计结果；
内存不足时降为16。两个分片下载到同一结果树后运行`aggregate_round30_selected`。

## 60用户实际结果与停止决定

60用户、6候选已于2026-09-10在本地8线程完成，失败0。没有候选通过预声明联合阈值；
按冻结规则仅将L06、L05标记为Pareto诊断对象。L06在-10/0/20 dB的`P_L`距离RMSE为
0.12730/0.01005/0.001326 m，但角度RMSE为0.007496/0.002286/0.000254 deg，
相对R29 pilot角度基线仍退化约7.09/4.76/2.78倍。因此不执行Round30的600用户扩展。

N=128/256/512的少量复杂度缩放已经完成；详细结果见
`research/45_round30_pilot_and_complexity_results.md`。

## 尚未执行

- 现有600行的Round30最多2候选扩展（因开发门槛失败而停止，不应运行）；
- 轻量版本冻结后的精确/Fresnel小型一致性与残余相位/时延敏感性；
- 任何新位置最终测试。

不自动启动1000或10000用户/SNR。若轻量候选达不到精度或端到端预算，结论应保留真实
Pareto差距，不削弱MUSIC基线，也不恢复旧alpha主线。
