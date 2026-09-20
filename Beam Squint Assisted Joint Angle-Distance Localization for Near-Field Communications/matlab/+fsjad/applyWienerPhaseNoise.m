function [distortedSpectrum, diagnostics] = applyWienerPhaseNoise( ...
    spectrum, innovationStdRad, stream, initialPhaseRad)
%APPLYWIENERPHASENOISE Apply time-domain Wiener phase noise to OFDM blocks.

arguments
    spectrum (:, :) double
    innovationStdRad (1, 1) double {mustBeNonnegative}
    stream = RandStream.getGlobalStream
    initialPhaseRad = 0
end

numSamples = size(spectrum, 1);
numBlocks = size(spectrum, 2);
if ~(isscalar(initialPhaseRad) || ...
        isequal(size(initialPhaseRad), [1, numBlocks]))
    error("fsjad:applyWienerPhaseNoise:InitialPhaseSize", ...
        "Initial phase must be scalar or one value per OFDM block.");
end
initialPhaseRad = initialPhaseRad + zeros(1, numBlocks);

if innovationStdRad == 0
    phaseRad = repmat(initialPhaseRad, numSamples, 1);
else
    increments = innovationStdRad * randn( ...
        stream, numSamples - 1, numBlocks);
    phaseRad = [initialPhaseRad; initialPhaseRad + cumsum(increments, 1)];
end

phaseRotation = exp(1i * phaseRad);
timeSignal = ifft(spectrum, [], 1);
distortedSpectrum = fft(timeSignal .* phaseRotation, [], 1);

cpe = mean(phaseRotation, 1);
cpeComponent = spectrum .* cpe;
iciComponent = distortedSpectrum - cpeComponent;
usefulEnergy = sum(abs(cpeComponent).^2, 1);
iciEnergy = sum(abs(iciComponent).^2, 1);
centeredPhaseRad = phaseRad - mean(phaseRad, 1);

diagnostics.phaseRad = phaseRad;
diagnostics.centeredPhaseRmsRad = sqrt(mean(centeredPhaseRad.^2, 1));
diagnostics.cpe = cpe;
diagnostics.cpeMagnitude = abs(cpe);
diagnostics.iciToUsefulRatio = iciEnergy ./ max(usefulEnergy, realmin);
diagnostics.inputEnergy = sum(abs(spectrum).^2, 1);
diagnostics.outputEnergy = sum(abs(distortedSpectrum).^2, 1);
end
