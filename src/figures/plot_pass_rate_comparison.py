#!/usr/bin/env python3
"""
Pass Rate Comparison Bar Chart

Usage:
    python plot_pass_rate_comparison.py --input data.json --output pass_rate.pdf

Input format (JSON):
    {
        "models": ["Model A", "Model B", "Model C"],
        "pass_rates": [0.45, 0.62, 0.38]
    }
"""

import argparse
import json
import matplotlib.pyplot as plt
import numpy as np

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True, help='Input JSON file')
    parser.add_argument('--output', required=True, help='Output image file')
    args = parser.parse_args()

    with open(args.input) as f:
        data = json.load(f)

    models = data['models']
    pass_rates = [r * 100 for r in data['pass_rates']]

    fig, ax = plt.subplots(figsize=(10, 6))
    x = np.arange(len(models))
    bars = ax.bar(x, pass_rates, width=0.6)

    ax.set_xlabel('Models', fontsize=12)
    ax.set_ylabel('Pass Rate (%)', fontsize=12)
    ax.set_xticks(x)
    ax.set_xticklabels(models, rotation=45, ha='right')
    ax.set_ylim(0, 100)
    ax.grid(axis='y', alpha=0.3)

    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}%', ha='center', va='bottom')

    plt.tight_layout()
    plt.savefig(args.output, dpi=300, bbox_inches="tight")

if __name__ == '__main__':
    main()
