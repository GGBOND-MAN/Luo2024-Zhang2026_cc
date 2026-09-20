# R51：P_FARC 可靠性证书条件恢复开发结果

日期：2026-09-18  
协议：`R51-PFARC-reliability-certified-recovery-development-v1`  
状态：**normal-60与stress-54完成；正式development FAIL；停止，不进入calibration**

## 1. 执行身份

- normal：20个全新位置、`-10/0/20 dB`，60/60行成功；
- controlled stress：6个全新位置、三种SNR、angle/range/joint三类，54/54行成功；
- source digest：`6a20159314243a7774de35520b7b826762f71cf2ddff6cf4a12e2451736f88ac`；
- normal/stress design hash分别为
  `c8038b5fbe115cdf8f29fba9caadd0272a85912bfcc7bbf57a599e0cd7f1abce`和
  `60025cf5a990ec8abdc412d91cd1aaa08c6230a6465accc4f1f9c46408283624`；
- 未读取R46 final，未用calibration行选规则；历史position124只在冻结后重放；
- `+r32/+r45/+r47/+r49/+r50`均未修改，新实现全部位于`+r51`。

## 2. 正式Gate

| Gate | 结果 | 门槛 | 判定 |
|:--|--:|--:|:--|
| aggregate angle MSE/P_FA | 0.002492 | <=1.01 | PASS |
| max per-SNR angle MSE/P_FA | 1.000000 | <=1.02 | PASS |
| aggregate range MSE/P_A | 0.226898 | <=1.00 | PASS |
| max per-SNR range MSE/P_A | **1.040064** | <=1.02 | **FAIL** |
| minimum stress trigger sensitivity | 0.833333 | >=0.80 | PASS |
| maximum accepted stress worsening rate | 0 | <=0.10 | PASS |
| complete runtime/C_enhanced | 0.259397 | <=1.00 | PASS |

因此预声明总判定为FAIL。唯一失败项来自20 dB：P_A距离MSE为`1.19991e-6 m^2`，
P_FA/P_FARC为`1.24798e-6 m^2`。绝对RMSE差约`0.0217 mm`，且P_FARC在该SNR没有触发、
逐行完全等于P_FA。这不是恢复器新引入的退化，但预声明相对门槛不能事后修改。

## 3. Normal-60结果

| SNR | P_FARC/P_A angle MSE | P_FARC/P_FA angle MSE | P_FARC/P_A range MSE | P_FARC/P_FA range MSE |
|---:|---:|---:|---:|---:|
| -10 | 0.002169 | 0.002187 | 0.225690 | 0.225648 |
| 0 | 0.438221 | 1.000000 | 0.997921 | 1.000000 |
| 20 | 0.183030 | 1.000000 | 1.040064 | 1.000000 |
| equal-SNR | 0.002470 | 0.002492 | 0.226898 | 0.226856 |

P_FARC只触发1/60行，触发率与接受率均为`1.667%`；其余59行逐值回退P_FA。L06 top-8
真值盆地覆盖率为59/60，唯一不覆盖行正是唯一触发行。

该自然失败位于`positionId=11,-10 dB`：

| 项目 | 真值 | P_A/P_FA | P_FARC |
|:--|--:|--:|--:|
| angle | 19.569094 deg | 19.473991 deg | 19.570203 deg |
| angle error | - | -0.095103 deg | +0.001108 deg |
| range | 15.766054 m | 17.283222 m | 15.758308 m |
| range error | - | +1.517168 m | -0.007746 m |

该行`C1=1,C2=1,C3=0,C4=0`，接受`remote`恢复。它是与历史position124独立的新自然
证据，证明边界证书可以在低SNR发现部分真实支持失败，也证明top-8不是充分候选集。

位置簇bootstrap仍反映20个位置的低功效：P_FARC/P_A距离比95%区间
`[0.02864,1.00434]`，单侧U95为`1.00300`；P_FARC/P_FA角度和距离区间上界均为1。
所以当前只能写成强正向开发点估计，不能写成已建立总体统计优效。

## 4. Controlled stress

| stress | trigger/accept | P_FA mean abs angle -> P_FARC | P_FA mean abs range -> P_FARC | P_FA >1m恢复到<1m |
|:--|:--|--:|--:|:--|
| angle | 18/18，18/18 | 0.250000 -> 0.000501 deg | 1.592812 -> 0.023484 m | 14/14 |
| range | 15/18，15/18 | 0.000502 -> 0.000502 deg | 1.019537 -> 0.191829 m | **2/5** |
| joint | 18/18，18/18 | 0.250000 -> 0.000326 deg | 1.006005 -> 0.065069 m | 1/1 |

所有被接受的恢复均未使角度或距离真值误差变差。但纯range stress漏检3行，全部在-10 dB，
未恢复距离误差分别约`-1.0537,-1.0598,+1.1900 m`。这些行的C1-C4全部为false：错误
q峰稳定落在局部窗内部，既不靠近边界，也没有奇偶候选分歧或非法曲率。因此现有证书不是完备
的range-support检测器。

## 5. 消融与运行时间

- `trigger_only`逐行等于P_FA，说明收益确实来自恢复；
- normal唯一触发行中，P_FARC与`trigger + unconditional P_FAW06/global`实质相同；
- stress中split-validated P_FARC没有优于较简单的条件wide/global消融：angle stress距离RMSE
  为`0.05081`对`0.04470 m`，joint stress为`0.23656`对`0.12146 m`；
- split验证没有接受任何相对P_FA真值误差更差的行，体现安全性，但未证明额外精度收益；
- 独立完整计时：P_FARC平均`5.3582 s`，C_enhanced平均`20.6562 s`，比值`0.2594`，
  即P_FARC约快`74.1%`。

## 6. 正式结论

R51证明了“稀有失败可观测后条件恢复”方向具备实际价值：它在全新数据中发现并恢复一个自然
灾难行，59/60正常行完全保持P_FA，同时重现历史异常恢复。但R51没有满足全部预声明Gate，
纯距离支持失败证书仍有漏检，复杂split验证也未建立相对简单条件wide/global恢复的增量收益。

按停止规则：**P_FARC只能保留为正向机制候选，不得进入600行calibration或final。**
