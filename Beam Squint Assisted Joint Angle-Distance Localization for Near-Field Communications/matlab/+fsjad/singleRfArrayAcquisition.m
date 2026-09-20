function [reconstructed, combined, diagnostics] = ...
    singleRfArrayAcquisition(signal, noiseStd, energyScale, stream)
%SINGLERFARRAYACQUISITION Acquire an array vector using DFT RF combining.

arguments
    signal (:, :) double
    noiseStd (1, 1) double {mustBeNonnegative}
    energyScale (1, 1) double {mustBePositive} = 1
    stream = RandStream.getGlobalStream
end

numAntennas = size(signal, 1);
numCarriers = size(signal, 2);
combinedSignal = energyScale * fft(signal, [], 1) / sqrt(numAntennas);
noise = noiseStd / sqrt(2) * ( ...
    randn(stream, numAntennas, numCarriers) ...
    + 1i * randn(stream, numAntennas, numCarriers));
combined = combinedSignal + noise;
reconstructed = sqrt(numAntennas) * ifft(combined, [], 1);

diagnostics.numRfChains = 1;
diagnostics.numTrainingSymbols = numAntennas;
diagnostics.numCombinedSamples = numAntennas * numCarriers;
diagnostics.energyScale = energyScale;
diagnostics.signalEnergyBeforeCombining = sum(abs(signal).^2, 1);
diagnostics.signalEnergyAfterCombining = sum(abs(combinedSignal).^2, 1);
diagnostics.effectiveSnrPenaltyDb = 20 * log10(energyScale);
end
