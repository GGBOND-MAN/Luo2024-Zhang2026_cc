function setup = setup(project, mode)
%SETUP Select calibration users without looking at localization errors.
arguments
    project (1,1) string
    mode (1,1) string {mustBeMember(mode,["pilot","calibration600"])}
end
paths = r29.paths(project);
saved = load(paths.r27,"setup","design");
assert(saved.setup.protocol.version=="Round27-convergence-ablation-v3","r29:ObsoleteR27");
setup.cfg = saved.setup.cfg;
setup.algorithm = saved.setup.zhang;
setup.protocol = r29.config();
decisionFile = fullfile(project,"results","full_spectrum","round29_sensitivity_v1","result.mat");
if isfile(decisionFile)
    decision = load(decisionFile,"decision");
    setup.protocol.initialSpacingM = decision.decision.initialSpacingM;
    setup.protocol.peakCount = decision.decision.peakCount;
    setup.frontDecision = decision.decision;
else
    setup.frontDecision = struct(reason="sensitivity-not-run");
end
setup.mode = mode;
setup.design = sortrows(saved.design,["snrDb","trialIndex"]);
targets = [36200034;36300058;36200114;36400431;36200073; ...
    36200111;36200127;36200175;36300167];
if mode=="pilot"
    selected = false(height(setup.design),1);
    for snr = [-10,0,20]
        rows = find(setup.design.snrDb==snr & ~ismember(setup.design.seed,targets));
        selected(rows(1:20)) = true;
    end
    setup.design = setup.design(selected,:);
else
    assert(height(setup.design)==600,"r29:Require600SavedRows");
end
setup.source = r29.manifest(project);
% Hash the data content, not the host-specific absolute pathname.
setup.dataHash = fsjad.sourceHashManifest(string(fileparts(paths.r27)), ...
    "round27_aggregate.mat");
setup.protocol.dataRole = "R26-derived-calibration-not-independent-validation";
end
