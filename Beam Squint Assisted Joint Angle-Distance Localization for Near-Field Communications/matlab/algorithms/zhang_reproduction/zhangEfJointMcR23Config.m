function algorithm = zhangEfJointMcR23Config
%ZHANGEFJOINTMCR23CONFIG Locked result of the Round 23 joint MC search.

algorithm.version = "Zhang-EF-JointMC-R23-locked";
algorithm.fusionCarrierCount = 1025;
algorithm.subarraySize = 224;
algorithm.localHalfWidthDeg = 0.1;
algorithm.localHalfWidthM = 0.0025;
algorithm.gridSizes = [37, 27, 19];
algorithm.frontOffsetsDeg = [-0.2; -0.1; 0; 0.1; 0.2];
end
