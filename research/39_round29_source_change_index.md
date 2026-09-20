# Round29 源码差异索引

## 历史版本

没有修改旧的 +fsjad、+jad、algorithms、Round23–28实验或旧tests中的文件。
与round28_front_v2_upload_20260907_110547清单对比，164个历史MATLAB源码文件哈希无变化。
run_round28_front_candidate_closure_v2的历史完成标志仍是旧逻辑，保留作为封存版本；
新的Round29入口不以该标志授权跳过计算。

## 新增运行源码

| 文件 | 与历史流程的差异 |
|---|---|
| +r29/candidateFront.m | v2候选前端的独立副本，增加候选、stage1、角度剖面和最终分支的次数与时间计量；只供新入口与诊断使用 |
| +r29/front.m | 仅接收cfg、z、scan和冻结协议；禁用历史定位锚点；最终未驻定解最多有限续算400/800，成本另记 |
| +r29/config.m | 固定工程及模态容差、后端求解规则、主/必要性/角度/窗口比较、扩窗和bootstrap预算 |
| +r29/trial.m | 重放z/Y，算F*，重新运行一次Zhang-R26固定后端MUSIC，复用返回signalVectors；所有一维距离在固定新角度和冻结子空间下计算 |
| +r29/solve.m | M与P共用同一maximizeRangeScore设置，返回原始评分结果 |
| +r29/setup.m | 从已有600行按固定顺序选60行pilot；读取敏感性决定；不按真值误差筛选；区分pilot与calibration600 |
| +r29/paths.m | 解析现有R27 v3与R28 v2原始MAT路径，不读取定位解进入一般化前端 |
| +r29/manifest.m | 对全部运行源码、实验和tests生成SHA-256清单，路径归一化以支持服务器 |
| +r29/assertIdentity.m | 精确比较配置、版本、design、数据哈希、源码哈希和分片身份 |
| +r29/statistics.m | 配对MSE/RMSE及区间、分位数、1m失捕、胜率、尾部贡献、位置误差；主比较三SNR的Holm族 |

## 新增实验入口

- preflight_round29：全量MATLAB回归与静态检查，绑定当前source。
- run_round29_sensitivity：4seed × 2间距 × 2峰预算；4基准复用，12新增，有限续算。
- run_round29_shard：一次60行pilot或手动600行双服务器分片，不生成新独立验证seed。
- check_round29_pilot_replay：预选第一个pilot用户，比较串行/线程的同一观测、前端与全部后端。
- aggregate_round29：精确校验分片和整个预定design，执行失败不删除；输出统计、成本与验收文件。
- tests/round29IntegrationTest：新接线与身份校验的五项回归。

## 支持脚本与文档

tools/audit_round29_outputs.m在全部计算结束后进行独立分析，
额外保存该分析脚本自己的SHA-256，不改写原始结果。
tools/measure_round29_resources.ps1记录进程级部分资源采样，不与每用户模块时间混用。
tools/build_round29_package.ps1打包当前源码、已有输入、验收文件、统计及日志，输出独立清单。

research/36–39是对32–35的追加说明，不覆盖历史报告。
原serial_thread_check.csv及withinTolerance=0保留。
源码准备、软件测试、敏感性、pilot与600用户机制结果分别记录，不互相替代。
