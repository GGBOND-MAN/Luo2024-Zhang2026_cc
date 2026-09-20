# Algorithm versions

The implementations are intentionally isolated so that compression studies
cannot silently change the established full-complexity reference.

| Folder | Public entry point | Role | Result folder |
|---|---|---|---|
| `full/` | `fsjadFullEstimate` | Frozen accuracy reference | `results/full_spectrum/round21/full/` |
| `compressed/` | `fsjadCompressedEstimate` | Independently versioned compressed method | `results/full_spectrum/round21/compressed/` |
| `zhang_reproduction/` | `zhangEfEstimate` | Versioned executable Zhang-style baselines | `results/full_spectrum/round22/` |

The Round 24 distributed confirmation uses the explicitly frozen
`fsjadRound23ComparisonEstimate` and `Zhang-EF-JointMC-R23-locked` settings.
Its disjoint server shards and aggregate outputs are stored under
`results/full_spectrum/round24_confirmatory/`.

Each folder owns its configuration function and README. Comparative tables
are stored at `results/full_spectrum/round21/`, while version-specific trial
details and summaries remain in their respective subfolders.
