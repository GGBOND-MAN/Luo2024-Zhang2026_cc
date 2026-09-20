function data = r37ReplayCalibrationObservation(cfg, scan, row)
%R37REPLAYCALIBRATIONOBSERVATION Replay only the saved spectral observation.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    row (1, :) table
end

stream = RandStream("mt19937ar", Seed=row.seed);
response = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(row.truthThetaDeg), row.truthRangeM, scan);
variance = mean(abs(response).^2)/10^(row.snrDb/10);
beta = exp(1i*2*pi*rand(stream));
noise = sqrt(variance/2)*(randn(stream, cfg.numSubcarriers, 1) ...
    +1i*randn(stream, cfg.numSubcarriers, 1));
data = struct(version="R37-observation-only-exact-R27-replay-v1", ...
    seed=row.seed, response=response, variance=variance, beta=beta, ...
    noise=noise, observation=beta*response+noise);
end
