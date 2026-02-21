import pandas as pd
import numpy as np
import os
from sklearn.model_selection import train_test_split
import glob

def preprocess(input_path, output_path):
    csv_files = glob.glob(f"{input_path}/*.csv")

    if not csv_files:
        raise FileNotFoundError("No dataset found in the input directory.")

    # Prioritize dataset versions
    csv_files.sort(reverse=True)  # Sort to get the latest version first

    # Choose the latest dataset
    latest_dataset = csv_files[0]
    print(f"Using dataset: {latest_dataset}")

    # Load data
    data = pd.read_csv(latest_dataset)
    
    
    # Map Severity of Illness
    severity_map = {"Minor": 0, "Moderate": 1, "Extreme": 2}
    data["Severity of Illness"] = data["Severity of Illness"].map(severity_map)
    
    # Feature Engineering
    # 1. Age processing
    data['Age'] = data['Age'].str.split('-').str[0].astype(int)
    
    # 2. Health conditions processing
    data['health_conditions'] = data['health_conditions'].fillna('None')
    data['num_health_conditions'] = data['health_conditions'].apply(
        lambda x: len(str(x).split(',')) if pd.notnull(x) else 0
    )
    
    # 3. Admission duration (using existing 'Stay (in days)')
    data['Admission_Days'] = data['Stay (in days)'].astype(int)
    
    # 4. Target encoding for Department
    department_encoding = data.groupby('Department')['Severity of Illness'].mean()
    data['Department_encoded'] = data['Department'].map(department_encoding)
    
    # 5. One-hot encoding for categorical features
    categorical_cols = [
        'Type of Admission',
        'Insurance',
        'Ward_Facility_Code',
        'gender'
    ]
    data = pd.get_dummies(data, columns=categorical_cols)
    
    # Final feature selection
    features_to_keep = [
        'Age', 'num_health_conditions', 'Admission_Days',
        'Department_encoded', 'Visitors with Patient', 'Admission_Deposit'
    ] + list(data.filter(regex='Type of Admission_|Insurance_|Ward_Facility_Code_|gender_').columns)
    
    # Remove unused columns
    data = data[features_to_keep + ['Severity of Illness']].copy()
    
    # Split data
    X = data.drop(columns=["Severity of Illness"])
    y = data["Severity of Illness"]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, stratify=y)
    
    # Save processed data
    os.makedirs(f"{output_path}/train", exist_ok=True)
    os.makedirs(f"{output_path}/test", exist_ok=True)
    
    pd.concat([X_train, y_train], axis=1).to_csv(f"{output_path}/train/train.csv", index=False)
    pd.concat([X_test, y_test], axis=1).to_csv(f"{output_path}/test/test.csv", index=False)
    
    # Print feature info for verification
    print("\nFinal training features:  ")
    print(X_train.columns.tolist())
    print(f"\nTotal features: {len(X_train.columns)}")

if __name__ == "__main__":
    preprocess("/opt/ml/processing/input", "/opt/ml/processing")
