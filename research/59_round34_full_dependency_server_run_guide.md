# Round34 完整依赖包服务器运行说明

日期：2026-09-11

## 1. 包的身份

本修正版是 Round34 的完整源码依赖包，不是新的估计器，也不改变 R32 冻结统计方法、
R33 A-only 实现或 R34 的最终设计。它只修复旧增量 ZIP 缺少 141 个继承源码的问题。

冻结身份：

- 估计器：`R33-A-q-only-invariants-direct-EVD-v1`；
- 工程协议：`R34-final-engineering-integration-v1`；
- 统计器：`R34-R32-frozen-statistics-bootstrap-index-fix-v1`；
- 设计哈希：`e1f6cc945644e88806432a52d2b6e18d0df026024c279790c9bf26edb9792cd6`；
- R34 源码摘要：`2d40cca46c84cccd580ba8bfc48d1b2bc74dfc4390920f17c80f00428f0a9684`。

## 2. 环境

已验证环境为 MATLAB R2024b，并需要 Parallel Computing Toolbox。服务器可使用更多 worker，
但 worker 数只影响吞吐，不改变 seed、设计行、估计器或统计结果。建议 worker 数不超过服务器
可用逻辑线程和内存能够支持的并发 trial 数。

## 3. 解压后的工程检查

在 ZIP 解压根目录运行：

```powershell
matlab -logfile round34_targeted_tests_server.log -batch "addpath('matlab'); r=runtests('matlab/tests/round34FinalEngineeringTest.m'); assert(all([r.Passed])); disp(r)"
```

然后运行预检：

```powershell
matlab -logfile round34_preflight_server.log -batch "addpath('matlab/experiments'); preflight_round34"
```

完整包故意不包含 `FINAL_TEST_AUTHORIZATION.mat`。因此直接调用正式分片入口必须在生成观测前
被拒绝；这属于正确行为，不是新的缺依赖错误。

## 4. 未授权状态下不要运行的命令

在用户没有再次明确授权最终 1400-trial 测试前，不运行：

- `authorize_round34_final_test`；
- `run_round34_final_shard`；
- `aggregate_round34_final_test`。

依赖包修复不等于最终试验授权。
