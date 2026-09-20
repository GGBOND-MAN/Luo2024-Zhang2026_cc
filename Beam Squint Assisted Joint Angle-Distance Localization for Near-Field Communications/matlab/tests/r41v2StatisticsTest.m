classdef r41v2StatisticsTest < matlab.unittest.TestCase
    %R41V2STATISTICSTEST Verify hierarchy-only changes and bootstrap audit.

    methods (Test)
        function nonStatisticalProtocolIsIdentical(testCase)
            v1 = r41.config();
            v2 = r41statsv2.config();
            testCase.verifyEqual(v2.design, v1.design);
            testCase.verifyEqual(v2.algorithm, v1.algorithm);
            testCase.verifyEqual(v2.schemeG, v1.schemeG);
            testCase.verifyEqual(v2.r34, v1.r34);
            testCase.verifyEqual(v2.complexity, v1.complexity);
            testCase.verifyEqual(v2.statistics.bootstrapSeed, ...
                v1.statistics.bootstrapSeed);
            testCase.verifyEqual(v2.statistics.bootstrapCount, ...
                v1.statistics.bootstrapCount);
            testCase.verifyEqual(v2.statistics.familyA, v1.statistics.familyA);
            testCase.verifyEqual(v2.statistics.familyB, v1.statistics.familyB);
            testCase.verifyEqual(v2.statistics.familyMultiplicity, ...
                v1.statistics.familyMultiplicity);
            testCase.verifyNotEqual(r41.structHash(v2.statistics), ...
                r41.structHash(v1.statistics));
        end

        function globalAndPerSnrNumericsMatchV1(testCase)
            [design, results, protocol] = syntheticCase(0.1, 0.2, 0.1, 0.2);
            v1Output = r41.summarizeFinal(design, results, protocol);
            v2Output = r41statsv2.summarizeFinal( ...
                design, results, protocol);
            testCase.verifyEqual(v2Output.coPrimaryGlobal.observedRatio, ...
                v1Output.globalSecondary.observedRatio, AbsTol=1e-15);
            testCase.verifyEqual(v2Output.coPrimaryGlobal.upper95, ...
                v1Output.globalSecondary.upper95, AbsTol=1e-15);
            testCase.verifyEqual( ...
                v2Output.perSnrConfirmatoryFamilies(:, 1:5), ...
                v1Output.primaryFamilies);
            testCase.verifyTrue(v2Output.coreFinalStatisticalSuccess);
            testCase.verifyTrue(v2Output.pointwiseConsistencyPass);
            testCase.verifyTrue(v2Output.strongAllSnrSuccess);
            testCase.verifyEqual(v2Output.interpretation.level, "Level 3");
        end

        function bootstrapAuditFreezesEqualWeighting(testCase)
            [design, results, protocol] = syntheticCase(0.1, 0.2, 0.1, 0.2);
            output = r41statsv2.summarizeFinal(design, results, protocol);
            audit = output.statisticsAudit.global;
            testCase.verifyEqual(audit.equalSnrWeights, ones(1, 7)/7);
            testCase.verifyTrue(audit.sharedClusterIndicesAcrossSnr);
            testCase.verifyTrue(audit.divisionByZeroChecked);
            testCase.verifyFalse(audit.posthocStudentizationAllowed);
            testCase.verifyGreaterThan( ...
                audit.angleMinimumBootstrapDenominator, 0);
            testCase.verifyGreaterThan( ...
                audit.rangeMinimumBootstrapDenominator, 0);
        end

        function pointwiseGateDetectsOneWorseSnr(testCase)
            summary = pointwiseSummary();
            summary.angleMseDeg2(summary.method == "G_schur" ...
                & summary.snrDb == 5) = 3;
            output = r41statsv2.pointwiseConsistency( ...
                summary, r41statsv2.config());
            testCase.verifyFalse(all(output.bothStrictlyLower));
            testCase.verifyFalse(output.angleStrictlyLower(output.snrDb == 5));
            testCase.verifyTrue(output.rangeStrictlyLower(output.snrDb == 5));
        end

        function interpretationLevelsAreFrozen(testCase)
            families = familyFixture(false);
            level1 = r41statsv2.classifyInterpretation( ...
                false, true, false, families);
            testCase.verifyEqual(level1.level, "Level 1");
            level2 = r41statsv2.classifyInterpretation( ...
                true, true, false, families);
            testCase.verifyEqual(level2.level, "Level 2");
            inconsistent = r41statsv2.classifyInterpretation( ...
                true, false, false, families);
            testCase.verifyEqual(inconsistent.level, ...
                "Core-only: pointwise inconsistency");
            level3 = r41statsv2.classifyInterpretation( ...
                true, true, true, familyFixture(true));
            testCase.verifyEqual(level3.level, "Level 3");
            testCase.verifyEqual(level3.allowedClaim, ...
                "G achieved statistically superior angle and range " + ...
                "performance at every tested SNR.");
        end

        function zeroGlobalDenominatorIsRejected(testCase)
            protocol = r41statsv2.config();
            protocol.statistics.bootstrapCount = 50;
            perUser = globalPerUserFixture();
            perUser.angleErrorDeg(perUser.method == "C_enhanced") = 0;
            testCase.verifyError(@() r41statsv2.globalCoPrimary( ...
                perUser, protocol), "r41v2:UndefinedGlobalRatio");
        end

        function failedGlobalCannotBeRescued(testCase)
            output = r41statsv2.classifyInterpretation( ...
                false, true, true, familyFixture(true));
            testCase.verifyEqual(output.level, "Level 1");
            testCase.verifyFalse(output.coreGlobalSuccess);
        end
    end
end

function [design, results, protocol] = syntheticCase( ...
    gAngle, cAngle, gRange, cRange)
protocol = r41statsv2.config();
protocol.design.positionCount = 4;
protocol.design.expectedRows = 28;
protocol.design.expectedRowsPerShard = 14;
protocol.design.expectedPositionsPerShard = 2;
protocol.statistics.bootstrapCount = 200;
design = r41.finalDesign(protocol);
methods = ["G_schur", "C_enhanced", "P_A"];
results = cell(height(design), 1);
for index = 1:height(design)
    angleSign = (-1)^index;
    rangeSign = (-1)^(index+1);
    results{index} = struct(success=true, ...
        positionId=design.positionId(index), seed=design.seed(index), ...
        snrDb=design.snrDb(index), methodNames=methods, ...
        thetaDeg=design.truthThetaDeg(index) ...
        +angleSign*[gAngle, cAngle, 0.15], ...
        rangeM=design.truthRangeM(index) ...
        +rangeSign*[gRange, cRange, 0.15], ...
        runtimeSeconds=[1, 2, 1], ...
        responseEquivalentCount=[10, 20, 8], ...
        musicEvaluationCount=[5, 6, 5], evdCount=[3, 3, 3], ...
        fullArrayEvaluationCount=[2, 0, 0], ...
        profilePassCount=[1, 0, 1], ...
        profileEvaluationCount=[4, 0, 4]);
end
end

function summary = pointwiseSummary()
snrDb = repelem((-10:5:20).', 2, 1);
method = repmat(["G_schur"; "C_enhanced"], 7, 1);
angleMseDeg2 = repmat([1; 2], 7, 1);
rangeMseM2 = repmat([0.5; 1], 7, 1);
summary = table(snrDb, method, angleMseDeg2, rangeMseM2);
end

function families = familyFixture(allPass)
family = [repmat("A-angle", 7, 1); repmat("B-range", 7, 1)];
snrDb = repmat((-10:5:20).', 2, 1);
statisticallySuperior = false(14, 1);
if allPass
    statisticallySuperior(:) = true;
else
    statisticallySuperior([1, 3, 8, 10]) = true;
end
families = table(family, snrDb, statisticallySuperior);
end

function perUser = globalPerUserFixture()
positionId = repelem((1:4).', 14, 1);
snrDb = repmat(repelem((-10:5:20).', 2, 1), 4, 1);
method = repmat(["G_schur"; "C_enhanced"], 28, 1);
angleErrorDeg = repmat([0.1; 0.2], 28, 1);
rangeErrorM = repmat([0.1; 0.2], 28, 1);
perUser = table(positionId, snrDb, method, angleErrorDeg, rangeErrorM);
end
