function [cost, diagnostics] = jointCost(cfg, context, thetaDeg, rangeM, protocol)
%JOINTCOST Exact concentrated Scheme H objective.

arguments
    cfg (1, 1) struct
    context (1, 1) struct
    thetaDeg (1, 1) double {mustBeFinite}
    rangeM (1, 1) double {mustBeFinite, mustBePositive}
    protocol (1, 1) struct = r42.config()
end

state = r42.blockState(cfg, context, deg2rad(thetaDeg), rangeM, protocol);
cost = state.cost;
if nargout > 1
    diagnostics = rmfield(state, ["gradient", "information", ...
        "gradientZ", "gradientY", "informationZ", "informationY"]);
end
end
