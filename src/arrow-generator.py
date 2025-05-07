import pyarrow as pa
import pyarrow.parquet as pq
import pyarrow.feather as feather

print(pa.__version__)

days = pa.array([1, 12, 17, 23, 28], type=pa.int8())
months = pa.array([1, 3, 5, 7, 1], type=pa.int8())
years = pa.array([1990, 2000, 1995, 2000, 1995], type=pa.int16())
birthdays_table = pa.table([days, months, years],
                           names=["days", "months", "years"])

pq.write_table(birthdays_table, 'out/birthdays.parquet')
feather.write_feather(birthdays_table, 'out/birthdays.feather')
