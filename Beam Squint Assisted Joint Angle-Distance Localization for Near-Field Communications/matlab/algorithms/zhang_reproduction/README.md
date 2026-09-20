# Zhang reproduction versions

This folder isolates the executable Zhang-style baselines from both FSJAD
implementations.

`Zhang-EF-513-v1` is the frozen baseline used in Rounds 18--21. It replaces
the paper's non-covering trajectory coarse point with the enhanced complex-
spectrum front end, then runs Zhang-style geometry compensation and fused
two-dimensional MUSIC using 513 power-peak-neighborhood carriers, subarray
size 96, local half-widths 0.02 degrees and 0.02 m, and grids 61/41/31.

`Zhang-EF-R22-tuned` is a separately named candidate selected in Round 22
from 15 carrier/grid configurations. It uses 385 carriers and grids
49/35/25; all other parameters remain equal to the frozen baseline. The
candidate failed independent validation at 0 dB and was rejected. The formal
baseline therefore remains `Zhang-EF-513-v1`. Neither version may be
described as the unpublished configuration used by Zhang et al.

`Zhang-EF-JointMC-R23-locked` is the tuned enhanced-front-end baseline after
jointly retuning five numerical parameter dimensions. Zhang actually specifies
subarray size 128 (Table II) and local half-widths 1 degree and 1 m (p. 8);
the earlier description of those three dimensions as unpublished was wrong. The search
covered a discrete space of 18,144 combinations by evaluating 136 joint
candidates with successive halving and 4,128 sample-configuration MUSIC
evaluations. It uses 1025 carriers, subarray size 224, local half-widths
0.1 degrees and 0.0025 m, and grids 37/27/19. The version is a locally tuned
strong baseline, not evidence of the settings used by the paper authors.

Round 27 separately evaluates a declared-protocol branch: trajectory coarse
point, subarray size 128, and a fixed initial 1 degree / 1 m domain. Its fusion
count is inherited from R26 and its grid is 61/41/31, explicitly numerical
assumptions rather than recovered author settings. It still uses the R26
synthetic observation model and does not certify an end-to-end hardware model.
