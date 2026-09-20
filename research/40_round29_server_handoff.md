# Round29 最终交付和服务器命令

有效包：server_packages/round29_reference_upload_20260908_084238.zip。
不要使用083718草稿；该草稿缺少旧绘图回归依赖，已明确标为不可上传运行。

## 已实际完成

- 有限候选敏感性：4个基准复用、12个新增任务，全部完成；
- 无历史锚点参考前端接入后端：60用户pilot完成，执行失败0，60个选中解驻定；
- 预定首用户串行/线程复现通过运行前冻结的工程容差；
- 全量回归和包内预检116/116，静态检查0项；
- 两个600行分片各含30行已验收缓存、270行待计算；
- 232个包内文件清单哈希匹配，旧164个MATLAB源文件未改变。

数值参考前端采用0.025m/32峰。更多候选不保证真实定位更准。
pilot总耗时9.03小时，前端响应调用总计4,750,808次，不具有R21低复杂度身份。
Pw比同窗Mw的pilot RMSE低，但Pw对H*的必要性优势未成立：
-10/20dB的RMSE反而更大，0dB略小。Holm校正后的三个主比较p均约0.0517。
开发校准数据不作独立验证证据，不以赢输或显著性作为数值验收标准。

## 两台服务器分别预检

进入解压后包含matlab目录的根目录：

```bash
matlab -logfile round29_preflight_server.log -batch "addpath('matlab/experiments'); preflight_round29"
```

应看到R29 TESTS passed=116 failed=0 incomplete=0 static=0。
服务器自己的MATLAB版本与运行环境需要保留。
Windows与Linux无需相同线程数；以固定规则和数值复现检查作为判据。

## 服务器1

```bash
matlab -logfile round29_600_shard1.log -batch "addpath('matlab/experiments'); run_round29_shard(1,2,Mode='calibration600',NumWorkers=32,BatchSize=16)"
```

## 服务器2

```bash
matlab -logfile round29_600_shard2.log -batch "addpath('matlab/experiments'); run_round29_shard(2,2,Mode='calibration600',NumWorkers=32,BatchSize=16)"
```

每台只执行其270个缺失用户，原30例保持原值。32是线程池大小，BatchSize=16意味着
每批最多16个并行用户，避免把池容量误当实际同时运行用户数。
相同命令可以续跑；版本、配置、完整设计、数据或源码哈希变化会拒绝旧checkpoint。
不要编辑MAT文件来绕过检查，不清除失败用户，不以显著性提前停止。

## 汇总

将两台服务器实际完成的分片目录放在同一个：
matlab/results/full_spectrum/round29_calibration600_v1/

目录应包含shard_01_of_02和shard_02_of_02，各自有result.mat及COMPLETE.mat。
只有初始checkpoint的目录不算已完成分片。

```bash
matlab -logfile round29_600_aggregate.log -batch "addpath('matlab/experiments'); aggregate_round29('calibration600')"
```

回传完整round29_calibration600_v1目录、两个服务器的预检日志、两个分片日志和汇总日志。
源hash、seed表、失败表、复用provenance必须保留，不只回传图片。

## 结果位置

本地完整pilot：
主MATLAB工程/matlab/results/full_spectrum/round29_pilot_v1/

机制统计在aggregate，逐样本旧前端差异、后端模块成本和明确列名的复现结果在
supplementary_audit。原观测、子空间与候选轨迹位于shard_01_of_01/result.mat。
原serial_thread_check的withinTolerance=0没有改变；事后工程容差分析独立保存。

## 后续顺序

先完成600用户机制审计，再冻结版本，另行设计全新独立1000用户/SNR，
最后才到万次/SNR确认。不能用R26剩余校准行或Round24保留seed冒充新验证。
当前未启动600/1000/10000用户任务，未扩展多径。
硬件能量、RF链、时隙和未知时延等物理假设见research/37，仍保留不确定性。
