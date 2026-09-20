function candidate = candidate(protocol)
%CANDIDATE Return the frozen L06 sparse-front configuration.

arguments
    protocol (1, 1) struct = r32.config()
end

candidateId = string(protocol.front.candidateId);
frontCarrierCount = protocol.front.carrierCount;
frontRangeSpacingM = protocol.front.rangeSpacingM;
frontCandidateCount = protocol.front.retainedCandidates;
frontMaxIterations = protocol.front.maxIterations;
musicCarrierCount = protocol.music.carrierCount;
musicSubarraySize = protocol.music.subarraySize;
candidate = table(candidateId, frontCarrierCount, frontRangeSpacingM, ...
    frontCandidateCount, frontMaxIterations, musicCarrierCount, ...
    musicSubarraySize);
end
