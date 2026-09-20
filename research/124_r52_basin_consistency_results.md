# R52：P_FARC2 Basin-Consistency开发结果

日期：2026-09-18  
协议：`R52-PFARC2-basin-consistency-development-v2`  
状态：**完整执行；Development FAIL；停止，不进入calibration**

## 1. 执行身份

- 固定自然stress候选池：600/600行成功；
- normal：30个全新位置乘`-10/0/20 dB`，90/90行成功；
- 自然stress：固定池未产生angle/range/joint支持失败，最终0行；
- source digest：`bf5597fc45353b15112e93cacc07c5d556e5295e314b2413a595acf837f5c8e5`；
- normal design hash：`1a56e116ed0cfef9de28019a49952a47d90afe45cbe412da0f9224fb60a908de`；
- pool design hash：`f9d5e5bac1110875a9cb3f56005eb9e6abbe7f13da2e24b8593efc9a6d84ecfd`；
- 未读取R46 final，未用R51既有结果作Gate；历史重放排除于Gate；
- R51源码和结果未修改。

v1完成筛选和normal后，在0行stress汇总处遇到空string列类型错误，未生成最终结果并已只读归档。
v2只修复空stress汇总，从零重跑全部600+90行，方法、种子、证书和Gate均未改变。

## 2. 正式Gate

| Gate | 结果 | 门槛 | 判定 |
|:--|--:|--:|:--|
| stress construction | 0 | 必须成功 | **FAIL** |
| aggregate range MSE/P_A | 1.000894 | <=1.00 | **FAIL** |
| max per-SNR range MSE/P_A | 1.004745 | <=1.05 | PASS |
| aggregate angle MSE/P_FA | 1.000000 | <=1.01 | PASS |
| normal false-trigger rate | 0 | <=0.05 | PASS |
| normal harmful-recovery rate | 0 | <=0.10 | PASS |
| minimum stress sensitivity | NaN | >=0.90 | **FAIL** |
| range stress sensitivity | NaN | >=0.90 | **FAIL** |
| additional stable-interior detections | 0 | >=1 | **FAIL** |
| range sensitivity gain over R51 trigger | NaN | >=0.20 | **FAIL** |
| simple recovery/R51 range MSE | 1.000000 | <=1.01 | PASS |
| no-trigger identity violations | 0 | =0 | PASS |
| complete runtime/C_enhanced | 0.277085 | <=1.00 | PASS |

R52存在多项预声明FAIL，正式结论不能由正常数据的低误触发率挽救。

## 3. 自然stress构造结果

| 类别 | 固定池出现数 | 目标数 | 构造判定 |
|:--|--:|--:|:--|
| angle support miss | 0 | 3 | FAIL |
| range support miss | 0 | 3 | FAIL |
| joint support miss | 0 | 3 | FAIL |

600个候选均为单源、`-10 dB`、完整原始`z/Y`重放，并由冻结L06自然生成`selected front`和
top-8。没有使用证书或恢复结果筛选。零事件对应的单侧95%发生率上界约为`0.498%`，但该结论
仅适用于预声明的`theta in [-55,55] deg, r in [18,47] m`内部位置分布。

两个已知自然失败的真值距离分别约为`15.77 m`和`15.42 m`，均不属于本轮固定pool的
`[18,47] m`范围。因此R52不能据此宣称整个物理区域不存在自然支持失败，也不能用这600行
验证C3b敏感度。

## 4. Normal-90结果

所有证书计数均为0：`C1=C2=C3a=C3b=C4=0`，旧R51 trigger和新R52 trigger均为0。
因此P_FARC2、冻结R51、旧trigger+simple recovery和P_FA在90行上逐值相同。

P_FARC2相对P_A：

| SNR | angle MSE ratio | range MSE ratio | range RMSE差 |
|---:|---:|---:|---:|
| -10 | 0.939594 | 1.000848 | +0.05757 mm |
| 0 | 0.416121 | 1.003255 | +0.03070 mm |
| 20 | 0.105181 | 1.004745 | +0.00286 mm |
| equal-SNR | 0.826807 | 1.000894 | +0.03538 mm |

aggregate range ratio的位置簇bootstrap 95%区间为`[1.000034,1.001499]`，单侧U95为
`1.001405`。这批normal数据中P_FA/P_FARC2距离相对P_A存在一致但极小的劣化；其绝对量级
只有约`0.035 mm`，且R52没有触发，不能归因于C3b或恢复器。

## 5. 历史重放

- R51 position11：`C1=1,C2=1,C3a=0,C3b=0,C4=0`；P_FARC2把距离误差从
  `+1.5172 m`恢复为约`-0.00775 m`；
- R48 position124：`C1=1,C2=0,C3a=1,C3b=0,C4=1`；P_FARC2把距离误差从
  `+19.4919 m`恢复为约`-0.19418 m`。

C3b对两个已知自然失败均没有贡献；恢复完全由原C1/C2/C3a/C4触发。

## 6. 复杂度

独立完整运行平均时间：P_FARC2为`5.6548 s`，C_enhanced为`20.4083 s`，比值
`0.2771`，即P_FARC2约快`72.3%`。复杂度通过不能替代机制与准确率Gate失败。

## 7. 正式结论

R52证明C3b在正常90行上没有引入误触发，但没有获得任何自然stress事件来验证其敏感度；
C3b也没有检测两个已知历史自然异常。normal aggregate距离又以`1.000894`略高于P_A。

按停止规则：**Basin-consistency certificate研究分支停止，不扩池、不修改区域、不增加新证书，
不进入calibration或final。**
