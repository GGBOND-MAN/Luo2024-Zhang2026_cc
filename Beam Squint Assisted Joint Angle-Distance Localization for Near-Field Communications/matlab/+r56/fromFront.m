function result = fromFront(cfg, observation, snapshots, scan, front, protocol)
%FROMFRONT Run frozen P_FALF and q-anchored split-consensus variants.

arguments
    cfg (1, 1) struct
    observation (:, 1) double {mustBeFinite}
    snapshots (:, :) double
    scan (1, 1) struct
    front (1, 1) struct
    protocol (1, 1) struct = r56.config()
end

timer = tic;
base = r53.fromFront(cfg, observation, snapshots, scan, front, protocol.base);
thetaDeg = base.P_FA.thetaDeg;
qProfile = r33.profileAtAngle(cfg, observation, scan, thetaDeg, ...
    front.selected.rangeM, protocol.base.base.r34.r33);
if abs(qProfile.value-base.P_FA.rangeM) > 1e-7
    error("r56:FrozenPfaMismatch", ...
        "The q anchor does not reproduce frozen P_FA range.");
end
candidates = r56.qCandidates(qProfile);
qSelected = find(candidates.isQSelected, 1);
carrierIndex = base.pfa.carrierIndex(:);
oddMask = mod((1:numel(carrierIndex)).', 2) == 1;
evenMask = ~oddMask;
oddContext = r42.prepareContext(cfg, scan, observation, ...
    snapshots(:, carrierIndex(oddMask)+1), carrierIndex(oddMask));
evenContext = r42.prepareContext(cfg, scan, observation, ...
    snapshots(:, carrierIndex(evenMask)+1), carrierIndex(evenMask));

oddScore = zeros(height(candidates), 1);
evenScore = zeros(height(candidates), 1);
jointScore = zeros(height(candidates), 1);
for index = 1:height(candidates)
    rangeM = candidates.rangeM(index);
    oddScore(index) = r56.yScore( ...
        oddContext, thetaDeg, rangeM, protocol);
    evenScore(index) = r56.yScore( ...
        evenContext, thetaDeg, rangeM, protocol);
    state = r53.likelihoodState( ...
        cfg, base.context, thetaDeg, rangeM, protocol.base);
    jointScore(index) = state.scoreJoint;
end
oddBest = firstMaximum(oddScore);
evenBest = firstMaximum(evenScore);
jointBest = firstMaximum(jointScore);
consensus = oddBest == evenBest && oddBest == jointBest;
selected = qSelected;
if consensus
    selected = oddBest;
end

qb = r56.refineBasin( ...
    cfg, base.context, thetaDeg, candidates(qSelected, :), protocol);
sc = r56.refineBasin( ...
    cfg, base.context, thetaDeg, candidates(selected, :), protocol);
candidates.oddYScore = oddScore;
candidates.evenYScore = evenScore;
candidates.fullJointScore = jointScore;
candidates.oddBest = candidates.candidateIndex == oddBest;
candidates.evenBest = candidates.candidateIndex == evenBest;
candidates.jointBest = candidates.candidateIndex == jointBest;

result = struct(version=protocol.version, ...
    P_FA=base.P_FA, P_FALF=base.P_FALF, ...
    P_FALF_QB=location(thetaDeg, qb.rangeM), ...
    P_FALF_SC=location(thetaDeg, sc.rangeM), ...
    base=base, qProfile=qProfile, candidates=candidates, ...
    qSelectedCandidateIndex=qSelected, oddBestCandidateIndex=oddBest, ...
    evenBestCandidateIndex=evenBest, jointBestCandidateIndex=jointBest, ...
    consensus=consensus, consensusSwitch=consensus && selected ~= qSelected, ...
    selectedCandidateIndex=selected, qbRefinement=qb, scRefinement=sc, ...
    backendSeconds=toc(timer));
end

function index = firstMaximum(score)
maximum = max(score);
index = find(score == maximum, 1, "first");
end

function output = location(thetaDeg, rangeM)
output = struct(thetaDeg=thetaDeg, rangeM=rangeM);
end
