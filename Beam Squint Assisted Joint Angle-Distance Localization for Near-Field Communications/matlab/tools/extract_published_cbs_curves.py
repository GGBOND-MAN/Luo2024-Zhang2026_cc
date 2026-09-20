"""Recover the target paper's published CBS-Low coordinates from PDF paths.

The logarithmic y-axis transform is calibrated against the already recovered
Proposed Joint MUSIC coordinates on the same axes. The PDF is read-only.
"""

from pathlib import Path

import numpy as np
import pdfplumber


PDF_PATH = Path(
    r"G:\研究生\paper\Beam_Squint_Assisted_Joint_Angle-Distance_Localization_for_Near-Field_Communications.pdf"
)


def path_y(page, curve_index):
    """Return the y coordinates of move/line commands in one vector path."""
    path = page.curves[curve_index]["path"]
    return np.array([command[1][1] for command in path if command[0] in ("m", "l")])


def recover(page, proposed_index, proposed_values, targets):
    """Fit log10(value)=a*y+b and invert target paths on the same axis."""
    y_coordinates = path_y(page, proposed_index)
    design = np.column_stack([y_coordinates, np.ones_like(y_coordinates)])
    log_values = np.log10(np.asarray(proposed_values, dtype=float))
    slope, intercept = np.linalg.lstsq(design, log_values, rcond=None)[0]
    residual = np.max(np.abs(design @ [slope, intercept] - log_values))
    print(f"calibration path {proposed_index}: max log10 residual={residual:.3e}")
    for name, curve_index in targets:
        values = 10 ** (slope * path_y(page, curve_index) + intercept)
        formatted = " ".join(f"{value:.10g}" for value in values)
        print(f"{name} = [{formatted}]")


def main():
    proposed_10_angle = [
        0.10222305, 0.026220697, 0.0077105099, 0.0026459847,
        0.0012447656, 0.00084484464, 0.00075050297,
    ]
    proposed_10_range = [
        0.099998239, 0.039411058, 0.015372596, 0.0059306791,
        0.0022856537, 0.00087991824, 0.00033835853,
    ]
    proposed_11_angle = [
        0.10000054, 0.032145184, 0.010682044, 0.0039654289,
        0.0018706047, 0.0012080282, 0.00098909744,
    ]
    proposed_11_range = [
        0.11999714, 0.030238381, 0.009793350, 0.0041759610,
        0.0023090864, 0.0015829322, 0.0012752394,
    ]
    proposed_12_angle = [
        0.00069995949, 0.0011999365, 0.0016999164,
        0.0019998906, 0.0021998860,
    ]
    proposed_12_range = [
        0.00050005613, 0.00090008715, 0.0016001483,
        0.0021001947, 0.0024001994,
    ]
    proposed_13_angle = [
        0.0062495752, 0.0029771232, 0.0021233954, 0.0016650221,
        0.0012691583, 0.0011092732, 0.0009969757, 0.00094453389,
        0.00089606954, 0.00086816776,
    ]
    proposed_13_range = [
        0.0045460326, 0.0026029401, 0.0021272951, 0.0018499735,
        0.0016216554, 0.0015619626, 0.0015348607, 0.0015165644,
        0.0014982809, 0.0014887748,
    ]

    with pdfplumber.open(PDF_PATH) as document:
        page_11 = document.pages[10]
        page_12 = document.pages[11]

        print("FIGURE 10")
        recover(page_11, 15, proposed_10_angle, [("cbs10_angle", 60)])
        recover(page_11, 103, proposed_10_range, [("cbs10_range", 148)])

        print("FIGURE 11")
        recover(page_11, 176, proposed_11_angle, [
            ("cbs11_angle_10deg", 207),
            ("cbs11_angle_30deg", 222),
            ("cbs11_angle_50deg", 223),
        ])
        recover(page_11, 248, proposed_11_range, [
            ("cbs11_range_10m", 279),
            ("cbs11_range_30m", 294),
            ("cbs11_range_50m", 295),
        ])

        print("FIGURE 12")
        recover(page_11, 331, proposed_12_angle, [("cbs12_angle", 364)])
        recover(page_11, 387, proposed_12_range, [("cbs12_range", 420)])

        print("FIGURE 13")
        recover(page_12, 0, proposed_13_angle, [
            ("cbs13_angle_10deg", 44),
            ("cbs13_angle_50deg", 65),
        ])
        recover(page_12, 96, proposed_13_range, [
            ("cbs13_range_10m", 140),
            ("cbs13_range_50m", 161),
        ])


if __name__ == "__main__":
    main()
