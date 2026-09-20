function setup = round27Setup(project, countPerSnr, mode)
%ROUND27SETUP Load paired calibration data and freeze a diagnostic protocol.
arguments
    project (1,1) string
    countPerSnr (1,1) double {mustBeInteger,mustBePositive}
    mode (1,1) string {mustBeMember(mode,["formal","smoke"])}
end
root=fullfile(project,"results","full_spectrum");
z=load(fullfile(root,"round26_zhang_large_joint_mc", ...
    "zhang_joint_mc_optimization.mat"),"cfg","selectedAlgorithm", ...
    "calibrationDesign","calibration","selected");
f=load(fullfile(root,"round26_fsjad_large_joint_mc", ...
    "fsjad_joint_mc_optimization.mat"),"cfg","selectedAlgorithm", ...
    "calibrationDesign","calibration","selected");
assert(isequal(z.cfg,f.cfg) && isequal(z.calibrationDesign,f.calibrationDesign), ...
    "fsjad:Round27UnpairedInputs");
assert(z.selectedAlgorithm.version=="Zhang-EF-JointMC-R26-locked");
assert(f.selectedAlgorithm.version=="FSJAD-JointMC-R26-locked");
assert(countPerSnr<=1000,"fsjad:Round27CalibrationLimit", ...
    "Round 27 uses only the 1000 saved calibration samples per SNR.");
setup.cfg=z.cfg;
setup.zhang=z.selectedAlgorithm;
setup.ours=f.selectedAlgorithm;
setup.design=z.calibrationDesign;
setup.design.trialIndex=repmat((1:1000).',3,1);
setup.design.legacyZhangThetaDeg=z.calibration.thetaDeg(z.selected.candidateId,:).';
setup.design.legacyZhangRangeM=z.calibration.rangeM(z.selected.candidateId,:).';
setup.design.legacyFsjadThetaDeg=f.calibration.thetaDeg(f.selected.candidateId,:).';
setup.design.legacyFsjadRangeM=f.calibration.rangeM(f.selected.candidateId,:).';
setup.design=setup.design(setup.design.trialIndex<=countPerSnr,:);
setup.protocol.version="Round27-convergence-ablation-v3";
setup.protocol.mode=mode;
setup.protocol.countPerSnr=countPerSnr;
setup.protocol.sourceData="Round26-calibration-only";
setup.protocol.observationModel="R26-exact-coherent-scalar-plus-independent-Fresnel-array";
setup.protocol.frontVersion="FS-Front-Monotone-R27-v2";
setup.protocol.maxIterations=200;
setup.protocol.stabilityMaxIterations=400;
setup.protocol.stepTolerance=1e-6;
setup.protocol.stabilityScoreTolerance=1e-10;
setup.protocol.stabilityThetaToleranceDeg=1e-7;
setup.protocol.stabilityRangeToleranceM=1e-5;
setup.protocol.bootstrapResamples=20000;
setup.protocol.bootstrapSeed=20260906;
setup.protocol.methodNames=["legacy_front","stable_front", ...
    "a_legacy_zhang_music","b_legacy_zhang_profile", ...
    "c_stable_zhang_music","d_stable_zhang_profile", ...
    "zhang_r26_cached","fsjad_r26_cached", ...
    "fsjad_r26_stable","fsjad_music_stable", ...
    "profile_at_front_angle"];
setup.protocol.methodIndex=struct( ...
    LegacyFront=1,StableFront=2,A=3,B=4,C=5,D=6, ...
    ZhangCached=7,FsjadCached=8,FsjadStable=9, ...
    FsjadMusic=10,ProfileAtFront=11);
setup.protocol.comparisonNames=["B-minus-A","C-minus-A", ...
    "D-minus-C-primary","D-minus-B","D-minus-E", ...
    "A-minus-Zhang-cached","FSJAD-stable-minus-cached", ...
    "FSJAD-profile-minus-music","D-minus-FSJAD-stable", ...
    "Profile-front-minus-E"];
setup.protocol.comparisonPairs=[4,3;5,3;6,5;6,4;6,2;3,7; ...
    9,8;9,10;6,9;11,2];
setup.protocol.excludedDiagnostic="zhang_declared_protocol";
setup.protocol.exclusionReason=[ ...
    "Published equations (14)-(15), the stated 15-50 m region, and the " ...
    "reported (14.8 deg, 29.5 m) coarse point are mutually inconsistent. " ...
    "The published-formula audit is isolated from formal comparisons."];
if mode=="smoke"
    assert(countPerSnr==1,"fsjad:Round27SmokeSize");
    setup.cfg.numAntennas=32;
    setup.cfg.numSubcarriers=65;
    setup.cfg.elementIndex=(0:31).'-15.5;
    setup.cfg.subarraySize=16;
    setup.cfg.numSubarrays=17;
    setup.zhang.fusionCarrierCount=9;
    setup.zhang.subarraySize=16;
    setup.zhang.gridSizes=[9,7,5];
    setup.ours.fusionCarrierCount=9;
    setup.ours.subarraySize=16;
    setup.ours.gridSizes=[9,7,5];
    setup.ours.profileHalfWidthM=0.2;
    setup.ours.profileSpacingM=0.1;
end
setup.source=sourceSnapshot(project);
end

function source=sourceSnapshot(project)
folders=["+fsjad","+jad"];
paths=strings(0,1);
for folder=folders
    files=dir(fullfile(project,folder,"*.m"));
    paths=[paths;folder+"/"+string({files.name}).']; %#ok<AGROW>
end
paths=[paths;"experiments/run_round27_convergence_shard.m"; ...
    "experiments/run_round27_front_stability.m"; ...
    "experiments/aggregate_round27_convergence.m"; ...
    "experiments/run_round27_published_formula_audit.m"; ...
    "experiments/preflight_round27.m";"tests/round27ConvergenceTest.m"; ...
    "tests/round27WorkflowTest.m"; ...
    "tests/round27PublishedFormulaAuditTest.m"];
paths=sort(paths);
content=strings(size(paths));
for i=1:numel(paths)
    content(i)=string(fileread(fullfile(project,paths(i))));
end
source=table(paths,content);
end
