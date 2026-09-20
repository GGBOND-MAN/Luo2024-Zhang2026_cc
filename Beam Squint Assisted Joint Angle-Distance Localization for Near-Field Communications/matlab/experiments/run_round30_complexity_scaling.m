function run_round30_complexity_scaling(options)
%RUN_ROUND30_COMPLEXITY_SCALING Time frozen methods for N=128/256/512.

arguments
    options.NumAntennas (1, :) double ...
        {mustBeInteger, mustBePositive} = [128, 256, 512]
    options.PositionCount (1, 1) double {mustBeInteger, mustBePositive} = 3
    options.Repetitions (1, 1) double {mustBeInteger, mustBePositive} = 3
    options.IncludeEnhancedBaseline (1, 1) logical = true
end

project = string(fileparts(fileparts(mfilename("fullpath"))));
addpath(project);
setup = r30.setup(project, "pilot");
selection = load(fullfile(project, "results", "full_spectrum", ...
    "round30_pilot_v1", "aggregate", "selection.mat"), "selected");
selectedRow = find(setup.protocol.candidates.candidateId ...
    == selection.selected.candidateId(1));
candidateBase = setup.protocol.candidates(selectedRow, :);
positions = setup.design(setup.design.snrDb == 0, :);
positions = positions(1:min(options.PositionCount, height(positions)), :);
output = table();

for numAntennas = options.NumAntennas
    cfg = setup.cfg;
    cfg.numAntennas = numAntennas;
    cfg.elementIndex = (0:numAntennas-1).'-(numAntennas-1)/2;
    candidate = candidateBase;
    candidate.musicSubarraySize = min(128, floor(numAntennas/2));
    scan = fsjad.prepareScan(cfg);
    public = setup.protocol.publicZhang;
    public.subarraySize = min(128, floor(numAntennas/2));
    localProtocol = setup.protocol;
    localProtocol.publicZhang = public;
    enhanced = setup.enhancedAlgorithm;
    enhanced.subarraySize = min(enhanced.subarraySize, floor(numAntennas/2));
    for position = 1:height(positions)
        replay = makeReplay(cfg, scan, positions(position, :));
        r30.trialFromReplay(cfg, replay, scan, localProtocol, candidate, ...
            IncludePublicBaseline=true, ...
            IncludeEnhancedBaseline=options.IncludeEnhancedBaseline, ...
            EnhancedAlgorithm=enhanced);
        for repetition = 1:options.Repetitions
            item = r30.trialFromReplay(cfg, replay, scan, localProtocol, ...
                candidate, IncludePublicBaseline=true, ...
                IncludeEnhancedBaseline=options.IncludeEnhancedBaseline, ...
                EnhancedAlgorithm=enhanced);
            entry = table(numAntennas, positions.seed(position), repetition, ...
                item.totalSeconds, item.front.runtimeSeconds, ...
                item.musicStateCost.seconds, item.angleSeconds, ...
                item.profileSeconds, item.complexity.onlineSeconds, ...
                item.complexity.totalEquivalentFullResponses, ...
                item.publicBaseline.seconds, ...
                baselineSeconds(item.enhancedBaseline), ...
                candidate.musicSubarraySize, candidate.musicCarrierCount, ...
                'VariableNames', {'numAntennas', 'seed', 'repetition', ...
                'lightTotalSeconds', 'frontSeconds', 'angleStateSeconds', ...
                'angleSearchSeconds', 'profileSeconds', 'onlineSeconds', ...
                'equivalentResponses', 'publicMusicSeconds', ...
                'enhancedMusicSeconds', 'lightSubarraySize', ...
                'lightMusicCarrierCount'});
            output = [output; entry]; %#ok<AGROW>
        end
    end
end
folder = fullfile(project, "results", "full_spectrum", ...
    "round30_complexity_scaling_v1");
if ~isfolder(folder)
    mkdir(folder);
end
writetable(output, fullfile(folder, "timing.csv"));
save(fullfile(folder, "result.mat"), ...
    "setup", "candidateBase", "positions", "output");
fprintf("ROUND30_COMPLEXITY_SCALING_COMPLETE rows=%d\n", height(output));
end

function replay = makeReplay(cfg, scan, row)
stream = RandStream("mt19937ar", Seed=row.seed+30000000);
response = fsjad.exactSpectralResponse( ...
    cfg, deg2rad(row.truthThetaDeg), row.truthRangeM, scan);
variance = mean(abs(response).^2)/10^(row.snrDb/10);
beta = exp(1i*2*pi*rand(stream));
noise = sqrt(variance/2)*(randn(stream, cfg.numSubcarriers, 1) ...
    + 1i*randn(stream, cfg.numSubcarriers, 1));
observation = beta*response+noise;
[~, peak] = max(abs(observation).^2);
carrierIndex = (0:cfg.numSubcarriers-1).';
snapshots = jad.simulateSnapshots(cfg, row.truthThetaDeg, ...
    row.truthRangeM, row.snrDb, carrierIndex, stream);
replay = struct(observation=observation, snapshots=snapshots, ...
    peakCarrierIndex=peak-1);
end

function seconds = baselineSeconds(baseline)
seconds = nan;
if ~isempty(fieldnames(baseline))
    seconds = baseline.seconds;
end
end
