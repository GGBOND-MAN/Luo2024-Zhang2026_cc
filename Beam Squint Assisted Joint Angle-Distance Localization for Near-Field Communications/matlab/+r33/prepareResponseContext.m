function context = prepareResponseContext(cfg, scan, observation)
%PREPARERESPONSECONTEXT Cache invariant exact-response scoring quantities.

arguments
    cfg (1, 1) struct
    scan (1, 1) struct
    observation (:, 1) double {mustBeFinite}
end

carrierCount = numel(scan.wavenumber);
if numel(observation) ~= carrierCount ...
        || size(scan.beamformer, 2) ~= carrierCount
    error("r33:ResponseContextSize", ...
        "Observation and scan must contain the same carriers.");
end
observationEnergy = real(observation'*observation);
if observationEnergy <= 0
    error("r33:ZeroObservationEnergy", ...
        "The observation energy must be positive.");
end

context.version = "R33-exact-response-context-v1";
context.x = scan.x;
context.xSquared = scan.x.^2;
context.wavenumber = scan.wavenumber(:).';
context.conjugateBeamformer = conj(scan.beamformer);
context.arrayNormalization = sqrt(cfg.numAntennas);
context.observation = observation;
context.observationEnergy = observationEnergy;
context.carrierCount = carrierCount;
context.numAntennas = cfg.numAntennas;
end
