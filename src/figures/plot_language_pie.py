import argparse
import json
import matplotlib.pyplot as plt
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent


def main(input_path: str, output_path: str) -> None:
    with open(input_path, encoding="utf-8") as f:
        data = json.load(f)

    languages = [f"{item['language'].capitalize()} ({item['instances']})" for item in data]
    instances = [item["instances"] for item in data]

    colors = ["#FFB3BA", "#BAFFC9", "#BAE1FF", "#FFFFBA", "#FFD9BA", "#E0BBE4", "#C9E4DE"]
    explode = [0.02] * len(instances)

    fig, ax = plt.subplots(figsize=(10, 10), facecolor="white")
    _wedges, texts, autotexts = ax.pie(
        instances,
        labels=languages,
        autopct="%1.1f%%",
        startangle=140,
        colors=colors,
        explode=explode,
        pctdistance=0.75,
        labeldistance=1.15,
    )

    for text in texts:
        text.set_fontsize(28)
    for autotext in autotexts:
        autotext.set_color("black")
        autotext.set_fontsize(26)

    plt.tight_layout()
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(str(out), dpi=300, bbox_inches="tight", facecolor="white")
    print(f"Pie chart saved as {out}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--input",
        default=str(_SCRIPT_DIR / "data" / "language.json"),
    )
    ap.add_argument("--output", default="language_distribution.pdf")
    args = ap.parse_args()
    main(args.input, args.output)
