function algorithm = zhangEf513Config
%ZHANGEF513CONFIG Frozen strengthened Zhang-style baseline configuration.

algorithm.version = "Zhang-EF-513-v1";
algorithm.fusionCarrierCount = 513;
algorithm.subarraySize = 96;
algorithm.localHalfWidthDeg = 0.02;
algorithm.localHalfWidthM = 0.02;
algorithm.gridSizes = [61, 41, 31];
algorithm.frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
end
