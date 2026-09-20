function data = replayRound27Data(cfg, scan, row)
%REPLAYROUND27DATA Recreate one saved Round 27 observation and array snapshot.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
end

stream = RandStream("mt19937ar", Seed=row.seed);
initialState = stream.State;
response = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(row.truthThetaDeg), row.truthRangeM, scan);
variance = mean(abs(response).^2)/10^(row.snrDb/10);
beta = exp(1i*2*pi*rand(stream));
noise = sqrt(variance/2)*(randn(stream, cfg.numSubcarriers, 1) ...
    + 1i*randn(stream, cfg.numSubcarriers, 1));
observation = beta*response+noise;
[~, peak] = max(abs(observation).^2);
snapshotCarrierIndex = (0:cfg.numSubcarriers-1).';
snapshots = jad.simulateSnapshots(cfg, row.truthThetaDeg, ...
    row.truthRangeM, row.snrDb, snapshotCarrierIndex, stream);

data.version = "Round27-exact-replay-v1";
data.seed = row.seed;
data.rngType = "mt19937ar";
data.initialRngState = initialState;
data.finalRngState = stream.State;
data.response = response;
data.variance = variance;
data.beta = beta;
data.noise = noise;
data.observation = observation;
data.peakCarrierIndex = peak-1;
data.snapshotCarrierIndex = snapshotCarrierIndex;
data.snapshots = snapshots;
end
