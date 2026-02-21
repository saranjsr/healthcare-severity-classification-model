import json
import pandas as pd
import numpy as np
import os
import glob
import boto3
import re
import logging
from datetime import datetime
from scipy.stats import ks_2samp

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
DRIFT_THRESHOLD = 0.01
PSI_THRESHOLD = 0.02
CLOUDWATCH_NAMESPACE = "SageMaker/ModelMonitoring"
BASELINE_STATS_PATH = "/opt/ml/processing/baseline/baseline_stats.json"

def parse_captured_data(record):
    """Parse captured inference data from SageMaker JSONL format"""
    try:
        input_data = record["captureData"]["endpointInput"]["data"]
        features = [float(x) for x in input_data.split(",")]  # Convert CSV to list of floats
        prediction = record["captureData"]["endpointOutput"]["data"].strip()
        return {"features": features, "prediction": prediction, "event_time": record["eventMetadata"]["inferenceTime"]}
    except Exception as e:
        logger.error(f"Error parsing record: {str(e)}")
        return None

def calculate_psi(expected, actual, num_bins=10):
    """Calculate Population Stability Index (PSI)"""
    try:
        if len(expected) == 0 or len(actual) == 0:
            return np.nan
        breakpoints = np.histogram_bin_edges(expected, bins=num_bins)
        expected_hist = np.histogram(expected, bins=breakpoints)[0]
        actual_hist = np.histogram(actual, bins=breakpoints)[0]
        expected_hist = expected_hist.astype(np.float64) + 1e-6
        actual_hist = actual_hist.astype(np.float64) + 1e-6
        expected_perc = expected_hist / np.sum(expected_hist)
        actual_perc = actual_hist / np.sum(actual_hist)
        psi_values = (actual_perc - expected_perc) * np.log(actual_perc / expected_perc)
        return np.sum(psi_values)
    except Exception as e:
        logger.error(f"PSI calculation failed: {str(e)}")
        return np.nan

def push_cloudwatch_metric(metric_name, feature, value):
    """Send custom drift metrics to CloudWatch"""
    cloudwatch = boto3.client('cloudwatch', region_name='eu-north-1')
    
    try:
        metric_data = {
            'MetricName': metric_name,
            'Dimensions': [{'Name': 'Feature', 'Value': re.sub(r'[^A-Za-z0-9_]', '_', feature)[:255]}],
            'Timestamp': datetime.utcnow(),
            'Value': float(value),
            'Unit': 'None'
        }
        logger.info(f"Pushing metric: {metric_data}")

        response = cloudwatch.put_metric_data(
            Namespace=CLOUDWATCH_NAMESPACE,
            MetricData=[metric_data]
        )
        logger.info(f" Successfully pushed {metric_name} for {feature}: {value}")

    except Exception as e:
        logger.error(f"Failed to push {metric_name} for {feature}: {str(e)}")


def main():
    # 1. Load captured data
    records = []
    parse_errors = 0
    for file in glob.glob('/opt/ml/processing/input/**/*.jsonl', recursive=True):
        try:
            with open(file) as f:
                for line in f:
                    try:
                        record = json.loads(line)
                        parsed = parse_captured_data(record)
                        if parsed:
                            records.append(parsed)
                        else:
                            parse_errors += 1
                    except Exception as e:
                        parse_errors += 1
                        logger.warning(f"Failed to parse line in {file}: {str(e)}")
        except Exception as e:
            logger.error(f"Failed to process file {file}: {str(e)}")
            continue

    logger.info(f"Successfully parsed {len(records)} records ({parse_errors} errors)")
    if len(records) < 10:
        raise ValueError(f"Insufficient valid data: {len(records)} records (need at least 10)")

    df = pd.DataFrame(records)
    features_df = pd.DataFrame(df['features'].tolist())

    # 2. Load baseline statistics
    if not os.path.exists(BASELINE_STATS_PATH):
        raise FileNotFoundError(f"Baseline stats not found at {BASELINE_STATS_PATH}")

    with open(BASELINE_STATS_PATH) as f:
        baseline_stats = json.load(f)

    # 3. Use actual feature names from baseline stats
    feature_names = list(baseline_stats["feature_stats"].keys())
    if len(feature_names) != features_df.shape[1]:
        logger.error(f"Feature mismatch! Expected {len(feature_names)} but got {features_df.shape[1]}")
        raise ValueError("Captured features do not match training features.")

    features_df.columns = feature_names 

    # 4. Introduce Controlled Drift
    np.random.seed(42)
    drift_features = ['Age', 'Admission_Days', 'Admission_Deposit']
    for feature in drift_features:
        if feature in features_df.columns:
            features_df[feature] *= np.random.uniform(2.0, 5.0, size=len(features_df))  
            features_df[feature] += np.random.normal(loc=50, scale=100, size=len(features_df))
    logger.info(f"Drift applied to: {drift_features}")

    # 5. Drift Detection
    drift_report = {}
    for col in features_df.columns:
        if col not in baseline_stats["feature_stats"]:
            logger.warning(f"Skipping {col} - Not found in baseline stats")
            continue
        
        baseline_mean = baseline_stats["feature_stats"][col]["mean"]
        baseline_values = pd.Series([baseline_mean] * 1000)

        current_values = features_df[col].dropna()
        ks_stat, ks_pvalue = ks_2samp(baseline_values, current_values)
        psi = calculate_psi(baseline_values, current_values)

        drift_report[col] = {
            "ks_pvalue": float(ks_pvalue),
            "psi": float(psi),
            "drift_detected": bool(ks_pvalue < DRIFT_THRESHOLD or psi > PSI_THRESHOLD) 
        }

        push_cloudwatch_metric("KS_PValue", col, ks_pvalue)
        push_cloudwatch_metric("PSI", col, psi)

    # 6. Save final report
    report = {
        "drift_analysis": drift_report,
        "timestamp": datetime.utcnow().isoformat()
    }

    with open('/opt/ml/processing/output/drift_report.json', 'w') as f:
        json.dump(report, f, default=str) 

    logger.info("Monitoring completed successfully")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.error(f"Monitoring failed: {str(e)}", exc_info=True)
        raise
