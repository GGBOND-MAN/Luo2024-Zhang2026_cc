# Round34 正式授权与授权后审计修正

日期：2026-09-11

## 流程冲突

原 `preflight_round34` 是授权前门禁。其预声明的第5项检查明确要求
`FINAL_TEST_AUTHORIZATION.mat` 不存在。因此正式授权后再次调用原函数，必然以
`no_final_authorization_any_version=false` 结束。这是旧门禁按设计工作，不是算法、源码或授权
身份漂移。

不能为使原预检在授权后“通过”而修改该文件，因为它属于165项冻结源码，修改会改变
R34 source digest，并使刚生成的授权失效。

## 授权后只读审计

新增 `server_tools/round34_authorized_preflight.m`。它位于冻结 `matlab` 目录之外，不进入
`r34.manifest`，不会改变冻结源码摘要。它只读检查：

- 165项源码及 source digest；
- 1400行、200个位置、每档200行和两个700行完整位置分片；
- estimator/statistics身份与 `UseFastResponse=true, UseGram=false`；
- 正式授权与源码、设计的绑定；
- 165项源码 Code Analyzer 为0；
- 14项R34专项测试和当前主工程174项完整测试；
- 正式分片执行前尚无最终结果目录。

原 `preflight_round34` 及其历史6/6授权前检查结果保持不变。正式执行顺序为：授权前原预检、
用户明确授权、生成授权文件、授权后只读审计、两服务器分片、聚合。

服务器若使用精简交付包而没有完整26个测试文件及其小型测试数据，则不能声称执行了174项
完整项目测试。正式同步包应包含这些测试依赖；大型历史观测数据不属于最终估计运行依赖。
