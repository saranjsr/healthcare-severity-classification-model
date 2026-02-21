import pandas as pd
import json
import os

def main():
    # Load training data
    train_data = pd.read_csv("/opt/ml/processing/input/train.csv")

    # Exclude "Severity of Illness" from baseline statistics
    if "Severity of Illness" in train_data.columns:
        train_data = train_data.drop(columns=["Severity of Illness"])

    # Calculate basic stats
    baseline_stats = {
        "feature_stats": {
            col: {
                "mean": float(train_data[col].mean()),
                "std": float(train_data[col].std()),
                "min": float(train_data[col].min()),
                "max": float(train_data[col].max()),
                "distribution": train_data[col].value_counts(normalize=True).to_dict()
            } for col in train_data.columns
        }
    }

    # Save updated baseline stats
    output_path = "/opt/ml/processing/output/baseline_stats.json"
    with open(output_path, "w") as f:
        json.dump(baseline_stats, f)

    print(f"✅ Baseline statistics saved at: {output_path}")
    print(f"✅ Features included in baseline: {list(train_data.columns)}")

if __name__ == "__main__":
    main()
