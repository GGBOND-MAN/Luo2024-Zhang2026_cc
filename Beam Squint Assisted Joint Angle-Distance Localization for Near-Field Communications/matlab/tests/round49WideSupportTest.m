classdef round49WideSupportTest < matlab.unittest.TestCase
    %ROUND49WIDESUPPORTTEST Unit tests for the frozen R49 interfaces.

    methods (TestClassSetup)
        function addProjectPath(testCase)
            project = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                project, IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testDesignIsDeterministic(testCase)
            protocol = r49.config();
            first = r49.design(protocol);
            second = r49.design(protocol);

            testCase.verifyEqual(first, second);
            testCase.verifyEqual(height(first), 60);
            testCase.verifyEqual(numel(unique(first.seed)), 60);
        end

        function testVariantWidthsAndGridSpacing(testCase)
            protocol = r49.config();
            variants = r49.variantProtocols(protocol);
            sizes = arrayfun( ...
                @(item) item.angleProtocol.pfa.coarseAngleGridSize, variants);

            testCase.verifyEqual([variants.widthDeg], [0.6, 1.0], ...
                AbsTol=1e-12);
            testCase.verifyEqual(sizes, [121; 201]);
            testCase.verifyEqual(string({variants.name}).', ...
                ["P_FAW06"; "P_FAW10"]);
        end

        function testGlobalRangeConfiguration(testCase)
            protocol = r49.config();

            testCase.verifyEqual(protocol.range.intervalCount, 350);
            testCase.verifyEqual(protocol.range.peakCount, 8);
            testCase.verifyEqual(protocol.range.support, ...
                "full-physical-range");
            testCase.verifyTrue(protocol.legacyStress.excludedFromSelection);
        end

        function testMethodRemainsPaFree(testCase)
            protocol = r49.config();

            testCase.verifyTrue(protocol.method.paFree);
            testCase.verifyTrue(protocol.method.musicFree);
            testCase.verifyTrue(protocol.method.evdFree);
            testCase.verifyFalse(protocol.method.jointObjective);
        end
    end
end
