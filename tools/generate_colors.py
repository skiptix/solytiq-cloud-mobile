#!/usr/bin/env python3
"""Generate Assets.xcassets color sets from the Luminous List design tokens.

Run whenever a token value changes: `python3 tools/generate_colors.py`.
Colors are hand-derived light/dark pairs (the source design is light-only;
dark values are chosen to keep the same hue/contrast relationships).
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "SolytiqCloudMobile", "Resources", "Assets.xcassets")

# name -> (light hex, dark hex)
COLORS = {
    "scPage":        ("#FDF8FF", "#14111D"),
    "scCard":        ("#FFFFFF", "#1C1926"),
    "scTinted":      ("#F7F2FC", "#211E2D"),
    "scHover":       ("#F1ECF6", "#272334"),
    "scBorder":      ("#E9E4F2", "#322E40"),
    "scSeparator":   ("#E5E1EB", "#3A3548"),
    "scText":        ("#1C1B22", "#F3F1F8"),
    "scText2":       ("#484552", "#C9C5D6"),
    "scText3":       ("#787584", "#9B96AB"),
    "scText4":       ("#B0ACBE", "#6B6678"),
    "scPrimary":     ("#5E4DBB", "#9D8DFF"),
    "scPrimarySoft": ("#9D8DFF", "#7C6CD9"),
    "scPrimaryBg":   ("#F5F3FF", "#241F3D"),
    "scPrimaryBg2":  ("#EDE9FF", "#2C2650"),
    "scSuccess":     ("#10B981", "#34D399"),
    "scWarning":     ("#EA580C", "#FB923C"),
    "scDanger":      ("#BA1A1A", "#F87171"),
    "scInfo":        ("#1D4ED8", "#60A5FA"),
    "scWorkBg":      ("#FFF5D6", "#3A331A"),
    "scWorkFg":      ("#6E5E0D", "#F0DE8E"),
    "scUrgentBg":    ("#FFDAD6", "#3A1E1C"),
    "scUrgentFg":    ("#BA1A1A", "#FF8A80"),
}


def hex_to_components(hex_str):
    h = hex_str.lstrip("#")
    r, g, b = h[0:2], h[2:4], h[4:6]
    return {
        "alpha": "1.000",
        "blue": f"0x{b.upper()}",
        "green": f"0x{g.upper()}",
        "red": f"0x{r.upper()}",
    }


def write_colorset(name, light_hex, dark_hex):
    dir_path = os.path.join(ROOT, f"{name}.colorset")
    os.makedirs(dir_path, exist_ok=True)
    contents = {
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": hex_to_components(light_hex),
                },
                "idiom": "universal",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "color": {
                    "color-space": "srgb",
                    "components": hex_to_components(dark_hex),
                },
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(dir_path, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


def main():
    os.makedirs(ROOT, exist_ok=True)
    root_contents = {"info": {"author": "xcode", "version": 1}}
    with open(os.path.join(ROOT, "Contents.json"), "w") as f:
        json.dump(root_contents, f, indent=2)
        f.write("\n")
    for name, (light, dark) in COLORS.items():
        write_colorset(name, light, dark)
    print(f"Wrote {len(COLORS)} color sets to {ROOT}")


if __name__ == "__main__":
    main()
