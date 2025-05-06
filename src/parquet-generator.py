from pandas import DataFrame
import os

os.makedirs('out', exist_ok=True)

df = DataFrame(data={
        'col1': [1, 2, 3, 4, 5],
        'col2': [3, 4, 5, 6, 7],
        'col3': [4, 5, 6, 7, 8]
    }
)
df.to_parquet(
    path='out/generated_by_py.parquet',
    engine="fastparquet",
    compression=None
)
