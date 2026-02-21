import pandas as pd
import xgboost as xgb
import json
import tarfile
import os
import numpy as np
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix

def evaluate():
    try:
        # ================= Model Handling =================
        model_dir = "/opt/ml/processing/model"
        model_tar_path = os.path.join(model_dir, "model.tar.gz")
        
        # Validate model.tar.gz exists
        if not os.path.exists(model_tar_path):
            available_files = os.listdir(model_dir)
            raise FileNotFoundError(f"model.tar.gz not found. Available: {available_files}")
        
        # Extract directly to model_dir (no subdirectory)
        with tarfile.open(model_tar_path) as tar:
            tar.extractall(path=model_dir)
        
        # Load model directly (we know the filename now)
        model_path = os.path.join(model_dir, "xgboost-model")
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found at {model_path}")
        
        # ================= Data Loading =================
        test_path = "/opt/ml/processing/test/test.csv"
        if not os.path.exists(test_path):
            raise FileNotFoundError(f"Test data not found at {test_path}")
        
        test_data = pd.read_csv(test_path)
        
        # Preserve original feature validation
        required_features = [
            'Age', 'num_health_conditions', 'Admission_Days',
            'Department_encoded', 'Visitors with Patient', 'Admission_Deposit'
        ] + [col for col in test_data.columns if col.startswith(('Type of Admission_', 'Insurance_', 'Ward_Facility_Code_', 'gender_'))]
        
        missing = [f for f in required_features if f not in test_data.columns]
        if missing:
            raise ValueError(f"Missing test features: {missing}")
        
        X_test = test_data.drop(columns=["Severity of Illness"])
        y_test = test_data["Severity of Illness"].values
        
        # ================= Load Model & Get Features =================
        model = xgb.Booster()
        model.load_model(model_path)
        
        # Get feature names from model instead of file
        try:
            model_feature_names = model.feature_names
            if model_feature_names is None:
                raise AttributeError
        except AttributeError:
            model_feature_names = [f"f{i}" for i in range(len(X_test.columns))]
            print("Warning: Model doesn't contain feature names - using generated names")
        
        # ================= Feature Validation =================
        if len(model_feature_names) != len(X_test.columns):
            raise ValueError(
                f"Feature count mismatch! Model expects {len(model_feature_names)}, "
                f"Test data has {len(X_test.columns)}"
            )
        
        # Assign model's feature names to test data
        X_test.columns = model_feature_names
        
        # ================= Prediction =================
        dtest = xgb.DMatrix(X_test.values, feature_names=model_feature_names)
        raw_preds = model.predict(dtest)
        y_pred = np.argmax(raw_preds, axis=1)
        
        # ================= Metrics =================
        metrics = {
            "accuracy": accuracy_score(y_test, y_pred),
            "classification_report": classification_report(y_test, y_pred, output_dict=True),
            "confusion_matrix": confusion_matrix(y_test, y_pred).tolist(),
            "feature_importance": model.get_score(importance_type='weight')
        }
        
        # Save results
        output_dir = "/opt/ml/processing/evaluation"
        os.makedirs(output_dir, exist_ok=True)
        
        with open(os.path.join(output_dir, "evaluation.json"), "w") as f:
            json.dump(metrics, f)
            
        print("Evaluation completed successfully")
    
    except Exception as e:
        print(f"Evaluation failed: {str(e)}")
        raise

if __name__ == "__main__":
    evaluate()