classdef round33ComplexityLedgerTest < matlab.unittest.TestCase
    %ROUND33COMPLEXITYLEDGERTEST Verify symbolic boundaries and counts.

    methods (Test)
        function originalUnknownsRemainSymbolic(testCase)
            ledger = fixtureLedger();
            row = ledger.methodFormulas.method ...
                == "original_paper_full_structure";
            formula = ledger.methodFormulas.publishedOrReference(row);
            testCase.verifyTrue(contains(formula, "K_Z"));
            testCase.verifyTrue(contains(formula, "G_Z"));
            testCase.verifyTrue(contains( ...
                ledger.methodFormulas.disclosure(row), "not uniquely"));
        end

        function rangeProfileCallsOnlyEnterPA(testCase)
            ledger = fixtureLedger();
            current = ledger.actualPerUser;
            testCase.verifyEqual(current.Er( ...
                current.method == "C_enhanced"), 0);
            testCase.verifyEqual(current.Er(current.method == "C_public"), 0);
            testCase.verifyEqual(current.Er(current.method == "P_A"), 150);
        end

        function currentMusicUsesInnerProductCount(testCase)
            ledger = fixtureLedger();
            current = ledger.actualPerUser;
            row = current.method == "P_A";
            expected = 2047*93*160;
            testCase.verifyEqual(current.musicInnerProductMacs(row), expected);
            reduction = ledger.ratioStatements.percent( ...
                ledger.ratioStatements.quantity ...
                == "frozen_search_point_reduction");
            testCase.verifyEqual(reduction, 100*(1-93/3083), ...
                AbsTol=1e-12);
        end

        function operationClassesStaySeparate(testCase)
            ledger = fixtureLedger();
            names = string(ledger.actualPerUser.Properties.VariableNames);
            testCase.verifyTrue(all(ismember(["musicInnerProductMacs", ...
                "evdCubicUnits", "responseExponentialTerms", ...
                "responseSqrtTerms"], names)));
        end
    end
end

function ledger = fixtureLedger()
cfg = jad.defaultConfig();
counts = table(36200001, -10, 1756, 185, 100, 85, 150, 3083, 93, ...
    3083, 0, 0, 2047, 0, 2047*160*97^2, 2047*97^3, ...
    3*2047*160*97, 5*129*128^2, 5*128^3, 0, ...
    'VariableNames', {'seed', 'snrDb', 'Es', 'Ef', ...
    'frontDerivativeCalls', 'frontQOnlyCalls', 'Er', 'G_C', 'G_A', ...
    'G_public', 'enhancedFallbackCount', 'publicFallbackCount', ...
    'enhancedGramSuccessCount', 'publicGramSuccessCount', ...
    'enhancedMatrixFormationMacs', 'enhancedEvdCubicUnits', ...
    'enhancedRecoveryMacs', 'publicMatrixFormationMacs', ...
    'publicEvdCubicUnits', 'publicRecoveryMacs'});
ledger = r33.complexityLedger(cfg, counts);
end
