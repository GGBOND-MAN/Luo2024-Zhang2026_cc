classdef localMusicSpectrumTest < matlab.unittest.TestCase
    %LOCALMUSICSPECTRUMTEST Tests for the public MUSIC grid evaluator.

    methods (TestClassSetup)
        function addSourcePath(testCase)
            sourceFolder = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(sourceFolder));
        end
    end

    methods (Test)
        function testNoiselessPeakAtTruth(testCase)
            cfg = jad.defaultConfig();
            cfg.numAntennas = 32;
            cfg.subarraySize = 16;
            cfg.numSubarrays = cfg.numAntennas - cfg.subarraySize + 1;
            cfg.elementIndex = (0:cfg.numAntennas - 1).' ...
                - (cfg.numAntennas - 1) / 2;
            carrierIndex = [900; 1024; 1150];
            [~, ~, frequencyHz] = jad.trajectory(cfg, carrierIndex);
            truthThetaDeg = 15;
            truthRangeM = 30;
            referenceStart = floor((cfg.numSubarrays + 1) / 2);
            ids = referenceStart:(referenceStart + cfg.subarraySize - 1);
            x = cfg.elementIndex(ids) * cfg.elementSpacing;
            distance = truthRangeM - x * sind(truthThetaDeg) ...
                + x.^2 * cosd(truthThetaDeg)^2 / (2 * truthRangeM);
            signalVectors = exp(-1i * 2 * pi / cfg.c ...
                * distance * frequencyHz.') / sqrt(cfg.subarraySize);
            thetaGridDeg = 14.9:0.01:15.1;
            rangeGridM = 29.9:0.01:30.1;

            spectrum = jad.localMusicSpectrum(cfg, signalVectors, ...
                carrierIndex, thetaGridDeg, rangeGridM);
            diagnostics = jad.localSpectrumDiagnostics( ...
                spectrum, thetaGridDeg, rangeGridM);

            testCase.verifyEqual( ...
                diagnostics.peakThetaDeg, truthThetaDeg, AbsTol=1e-12);
            testCase.verifyEqual( ...
                diagnostics.peakRangeM, truthRangeM, AbsTol=1e-12);
        end

        function testSignalVectorSizeErrors(testCase)
            cfg = jad.defaultConfig();
            operation = @() jad.localMusicSpectrum(cfg, ...
                ones(cfg.subarraySize - 1, 1), 1, 0, 30);

            testCase.verifyError(operation, ...
                "jad:InvalidSignalVectorSize");
        end
    end
end
