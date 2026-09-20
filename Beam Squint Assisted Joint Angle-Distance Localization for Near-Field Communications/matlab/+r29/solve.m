function result = solve(score, bounds, feasible, settings)
%SOLVE Shared identical range optimizer policy for M and P.
arguments
    score (1,1) function_handle
    bounds (1,2) double
    feasible (:,1) double
    settings (1,1) struct
end
args = namedargs2cell(settings);
result = fsjad.maximizeRangeScore(score,bounds,feasible,args{:});
end
