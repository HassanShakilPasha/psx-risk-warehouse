# Run in a Databricks notebook (DVA workspace). Builds the 3 source CSVs for the DWBI project.
# psx_market_summary.csv: every line of every original PSX daily file, untouched (all values kept as text).
# psx_sectors.csv, sbp_policy_rate.csv: the PSX sector list and SBP policy decisions.
import csv
import glob
import gzip
import io
import os
import zipfile

SRC = "/Volumes/workspace/bronze/raw_landing/mkt_summary"
OUT = "/Volumes/workspace/bronze/raw_landing/_dwbi_export"
os.makedirs(OUT, exist_ok=True)

FIELDS = ["trade_date", "symbol", "sector_code", "company_name", "open", "high", "low", "close", "volume", "ldcp", "extra_1", "extra_2", "extra_3"]


def read_z(path):
    data = open(path, "rb").read()
    if data[:2] == b"PK":
        z = zipfile.ZipFile(io.BytesIO(data))
        return z.read(z.namelist()[0]).decode("latin-1")
    return gzip.decompress(data).decode("latin-1")


files = sorted(glob.glob(f"{SRC}/*/*.Z"))
rows = 0
with open(f"{OUT}/psx_market_summary.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(FIELDS + ["source_file"])
    for path in files:
        for line in read_z(path).splitlines():
            if not line.strip():
                continue
            parts = line.split("|")
            if len(parts) > len(FIELDS):
                parts = parts[:len(FIELDS) - 1] + ["|".join(parts[len(FIELDS) - 1:])]
            parts += [""] * (len(FIELDS) - len(parts))
            w.writerow(parts + [os.path.basename(path)])
            rows += 1
print(f"psx_market_summary.csv: {len(files)} files, {rows} rows")

# Reference lists (compiled from the PSX sector list and SBP monetary policy statements).
sectors = spark.table("workspace.gold.ref_sector").toPandas()
print("ref_sector columns:", list(sectors.columns))
sectors = sectors.iloc[:, :3]
sectors.columns = ["sector_code", "sector_name", "security_type"]
sectors.to_csv(f"{OUT}/psx_sectors.csv", index=False)

rates = spark.table("workspace.gold.ref_policy_rate").toPandas()
print("ref_policy_rate columns:", list(rates.columns))
rates = rates.iloc[:, :4]
rates.columns = ["effective_date", "policy_rate", "previous_rate", "change_bps"]
rates.to_csv(f"{OUT}/sbp_policy_rate.csv", index=False)
print("Done. Download the 3 files from", OUT)
