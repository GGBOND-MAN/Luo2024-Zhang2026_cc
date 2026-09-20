function setup = setup(project, mode)
%SETUP Reuse the fixed Round29 development design without new users.

arguments
    project (1, 1) string
    mode (1, 1) string {mustBeMember(mode, ["pilot", "calibration600"])}
end

base = r29.setup(project, mode);
setup.version = "R30-existing-calibration-design-v1";
setup.mode = mode;
setup.cfg = base.cfg;
setup.design = base.design;
setup.enhancedAlgorithm = base.algorithm;
if ~isfield(setup.enhancedAlgorithm, "label")
    setup.enhancedAlgorithm.label = ...
        "Zhang-R26-enhanced-fixed-configuration-new-light-front";
end
setup.protocol = r30.config();
setup.source = r30.manifest(project);
setup.dataHash = base.dataHash;
setup.dataRole = setup.protocol.dataRole;
end
