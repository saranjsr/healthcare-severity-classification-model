import pandas as pd
import xgboost as xgb
import os
import numpy as np
from sklearn.model_selection import train_test_split

class SageMakerMetricCallback(xgb.callback.TrainingCallback):
    """Logs metrics in SageMaker-compatible format"""
    def after_iteration(self, model, epoch, evals_log):
        if evals_log:
            for dataset, metrics in evals_log.items():
                for metric, values in metrics.items():
                    # Format: [epoch] validation_0-merror:0.12345
                    print(f"[{epoch}] {dataset}-{metric}:{values[-1]:.5f}") 
        return False

def train():
    # Load and validate data
    train_data = pd.read_csv("/opt/ml/input/data/train/train.csv")
    
    # Preserve original feature engineering
    required_features = [
        'Age', 'num_health_conditions', 'Admission_Days',
        'Department_encoded', 'Visitors with Patient', 'Admission_Deposit'
    ] + [col for col in train_data.columns if col.startswith(('Type of Admission_', 'Insurance_', 'Ward_Facility_Code_', 'gender_'))]
    
    missing = [f for f in required_features if f not in train_data.columns]
    if missing:
        raise ValueError(f"Missing features: {missing}")

    # Prepare data with original splits
    X = train_data.drop(columns=["Severity of Illness"])
    y = train_data["Severity of Illness"].values
    
    # Maintain stratified split
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=42
    )
    
    # Create native XGBoost DMatrix format
    dtrain = xgb.DMatrix(X_train, label=y_train, enable_categorical=False)
    dval = xgb.DMatrix(X_val, label=y_val, enable_categorical=False)
    
    # Original model configuration
    params = {
        "objective": "multi:softprob",
        "num_class": 3,
        "eval_metric": ["merror", "mlogloss"],
        "early_stopping_rounds": 50,
        "tree_method": "hist"
    }
    
    # Train using native XGBoost API
    model = xgb.train(
        params,
        dtrain,
        evals=[(dval, "validation")],
        callbacks=[SageMakerMetricCallback()]
    )
    
    # Save ONLY the essential model file
    model_dir = "/opt/ml/model"
    model.save_model(os.path.join(model_dir, "xgboost-model"))
    
    print("Model saved successfully in SageMaker-compatible format.")

if __name__ == "__main__":
    train()
