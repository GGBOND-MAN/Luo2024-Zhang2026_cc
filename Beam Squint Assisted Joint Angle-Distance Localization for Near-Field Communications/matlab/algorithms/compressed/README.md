# Compressed algorithm

`fsjadCompressedEstimate` is isolated from the frozen full algorithm.
`fsjadCompressedConfig` records the currently locked compressed parameters.

Version `FSJAD-Compressed-R21-locked` keeps 513 fused carriers, uses 0.15 m
range-profile seeds, and reduces MUSIC grids to `37/27/19`. These parameters
were selected from the Round 21 calibration set and locked before the 600-trial
independent validation.

`FSJAD-Compressed-R23-comparison-locked` makes the effective Round 23
comparison pipeline explicit. Round 23 used the compressed carrier, grid, and
profile settings together with a 96-element MUSIC subarray and local
half-widths of 0.02 degrees and 0.02 m. This separately named version prevents
the Round 24 confirmation from silently falling back to the global defaults of
128 elements and 1 degree/1 m.

`fsjadJointSearchSpace` defines the eight-dimensional Round 25 search used to
give FSJAD the same 136-candidate, 4,128-evaluation tuning budget as the Round
23 Zhang baseline. The selected configuration is written as
`FSJAD-JointMC-R25-locked` only after calibration has finished and before its
independent validation begins.
