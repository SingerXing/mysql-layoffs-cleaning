# World layoffs data cleaning

This is my MySQL data cleaning practice project, based on Alex The Analyst's tutorial. I worked through duplicates, inconsistent labels, text dates, and missing values, then exported the cleaned table for analysis.

## Files

| File | Contents |
| --- | --- |
| [sql/cleaning.sql](sql/cleaning.sql) | Import, cleaning steps, inspection queries, and final checks |
| [data/raw/layoffs.csv](data/raw/layoffs.csv) | Original dataset, unchanged |
| [data/cleaned/layoffs_clean.csv](data/cleaned/layoffs_clean.csv) | Cleaned export with 1,995 rows |

## Cleaning steps

| Step | Result |
| --- | --- |
| Import the original CSV | 2,361 rows |
| Remove exact duplicates across all nine columns | 5 removed; 2,356 remain |
| Trim company names | 11 values corrected before the final row exclusions |
| Standardize industry labels | 3 values changed to `Crypto` |
| Standardize country labels | 4 values changed to `United States` |
| Convert dates from text to `DATE` | 2,355 dates converted; one existing missing date retained |
| Fill missing industries from matching company/location records | 3 values filled |
| Exclude rows missing both layoff measures | 361 removed; **1,995 remain** |
| Remove the `row_num` helper and rename the table | Final table: `layoffs_clean` |

The raw table is preserved. Rows missing both `total_laid_off` and `percentage_laid_off` are excluded because this project focuses on those measures. They could still be useful for other questions.

The matching records agreed on industry for the three values filled here. For another dataset, conflicting industries would need to be reviewed before using the same join.

## Validation

The cleaned export was compared with the expected transformations of the original CSV across all nine columns. There were no missing or unexpected rows, no exact duplicates, and no company names with extra spaces.

Some values remain missing:

| Column | Missing values in the cleaned data |
| --- | ---: |
| `total_laid_off` | 378 |
| `percentage_laid_off` | 423 |
| `funds_raised_millions` | 165 |
| `industry` | 1 |
| `date` | 1 |

Six funding values are genuine zeros. I kept these separate from missing funding values rather than replacing every zero with `NULL`.

## Running the SQL

1. Download or clone this repository and open `sql/cleaning.sql` in MySQL Workbench. MySQL 8.0 or later is required for `ROW_NUMBER()`.
2. Use an empty `world_layoffs` project schema. The script creates the schema if needed and is intended to run once in order. Existing project tables will cause a table-already-exists error.
3. Replace `/absolute/path/to/data/raw/layoffs.csv` in the `LOAD DATA` statement with the absolute path to your downloaded raw file.
4. Enable `LOCAL INFILE` on your MySQL server and client connection. Reconnect after changing the client connection setting.
5. Run the script in order. The final checks should return 2,361 raw rows, 1,995 cleaned rows, and zero duplicates, untrimmed company names, or rows missing both layoff measures.

The script temporarily disables safe-update mode for its session and restores the previous setting at the end. If execution stops early, restore it with `SET SESSION sql_safe_updates = @saved_sql_safe_updates;`.

Both CSVs use UTF-8. The raw file uses CRLF line endings, so its import uses `LINES TERMINATED BY '\r\n'`. The cleaned export uses LF. `.gitattributes` preserves the raw file's line endings when cloning. Both CSVs use the unquoted token `NULL` for SQL missing values. The raw CSV also contains three empty industry fields, which the script fills from matching records. Treat `NULL` as missing when reading these files into another tool.

## Source and credit

- [Alex The Analyst's MySQL YouTube Series](https://github.com/AlexTheAnalyst/MySQL-YouTube-Series): tutorial and starting dataset.
- [Original layoffs.csv](https://github.com/AlexTheAnalyst/MySQL-YouTube-Series/blob/main/layoffs.csv).

This repository documents a guided learning project and the checks used to verify the result.
