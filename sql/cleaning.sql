-- World layoffs: MySQL data cleaning practice
-- Based on Alex The Analyst's MySQL tutorial. See README.md for the source.
-- Run once in an empty project schema with MySQL 8.0 or later.
-- Local file loading must be enabled on both the client and server.

CREATE DATABASE IF NOT EXISTS world_layoffs
    DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE world_layoffs;

-- Keep the existing session preference and restore it at the end.
SET @saved_sql_safe_updates = @@SESSION.sql_safe_updates;
SET SESSION sql_safe_updates = 0;

CREATE TABLE world_layoffs.layoffs (
    company TEXT,
    location TEXT,
    industry TEXT,
    total_laid_off INT,
    percentage_laid_off DOUBLE,
    `date` TEXT,
    stage TEXT,
    country TEXT,
    funds_raised_millions DOUBLE
) DEFAULT CHARSET = utf8mb4;
-- Replace this path with the absolute path to the downloaded raw CSV.
LOAD DATA LOCAL INFILE '/absolute/path/to/data/raw/layoffs.csv'
INTO TABLE layoffs
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

SELECT * FROM layoffs;

# 1. Remove Duplicates
# 2. Standardize the Data
# 3. NULL values or blank values
# 4. Remove rows excluded from this analysis and the helper column

# Create a working copy so the raw table stays unchanged.
CREATE TABLE layoffs_staging
LIKE layoffs; # Copy the table structure.

INSERT INTO layoffs_staging
SELECT * FROM layoffs; 
# INSERT INTO ... SELECT copies the rows into the staging table.

-- Remove Duplicates
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, country, stage, funds_raised_millions) AS row_num
FROM layoffs_staging;

WITH duplicate_cte AS(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, country, stage, funds_raised_millions) AS row_num
FROM layoffs_staging)
SELECT *
FROM duplicate_cte
WHERE row_num >1;
# Inspect the duplicates

CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` double DEFAULT NULL,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` double DEFAULT NULL,
  `row_num` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, country, stage, funds_raised_millions) AS row_num
FROM layoffs_staging;
# Store the row numbers in a staging table so we can delete the extra copies.

DELETE
FROM layoffs_staging2
WHERE row_num >1;

SELECT *
FROM layoffs_staging2
WHERE row_num >1;
# Check that no extra copies remain.

-- Standardizing data

SELECT company, TRIM(company)
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);

SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY 1; # order by 1 means order by the first column

SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';
# LIKE uses pattern matching. The % wildcard matches zero or more characters.
# 'Crypto%' matches values that start with Crypto.

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

SELECT DISTINCT location
FROM layoffs_staging2
ORDER BY 1;

SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2
SET country = 'United States'
WHERE country LIKE 'United States%';

-- Formatting the dates

SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y') AS converted_date
FROM layoffs_staging2;
# %m and %d parse the numeric month and day in this file; %Y is the four-digit year.
# %M is a full month name (November); %b is an abbreviation (Nov).
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- Handling NULL values

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;
# The one missing date was already NULL in the source data.

# Check missing values with IS NULL, not = NULL.

SELECT * 
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

# Inspect rows where both layoff measures are missing.

SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
OR industry = '';
# Check whether another record can supply a missing industry.

SELECT *
FROM layoffs_staging2
WHERE company = 'Airbnb';
# Inspect the known industry for this company before filling missing values.

SELECT *
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
    AND t1.location = t2.location
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL
AND TRIM(t2.industry) <> '';
# Preview the rows to update using the same conditions as the UPDATE below.
# Three left rows and two right rows produce six pairs only if every left row matches both right rows.
# For this file, the matching donors agree on industry for each missing target.

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
    AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL
AND TRIM(t2.industry) <> '';
# <> means not equal to. JOIN and WHERE select the matching rows.
# SET fills the missing industry from another matching row in the same table.

-- Data Cleaning

SELECT * 
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;
# Exclude these rows from this analysis because neither layoff measure is available.
# They are still preserved in the raw table.

DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Remove the helper column

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- Rename the table
RENAME TABLE layoffs_staging2 TO layoffs_clean;

-- Final checks: 2361 raw rows and 1995 cleaned rows.
SELECT COUNT(*) AS raw_rows FROM layoffs;
SELECT COUNT(*) AS cleaned_rows FROM layoffs_clean;

-- All three checks below should be 0.
SELECT
    SUM(LENGTH(company) <> LENGTH(TRIM(company))) AS company_names_with_extra_spaces,
    SUM(total_laid_off IS NULL AND percentage_laid_off IS NULL) AS rows_with_both_measures_missing,
    (SELECT COUNT(*) FROM layoffs_clean) -
    (SELECT COUNT(*) FROM (
        SELECT DISTINCT company, location, industry, total_laid_off,
            percentage_laid_off, `date`, stage, country, funds_raised_millions
        FROM layoffs_clean
    ) AS unique_rows) AS exact_duplicates_remaining
FROM layoffs_clean;

-- Expected: 165 missing funding values and 6 genuine zeros.
SELECT
    SUM(funds_raised_millions IS NULL) AS missing_funding,
    SUM(funds_raised_millions = 0) AS zero_funding
FROM layoffs_clean;

SET SESSION sql_safe_updates = @saved_sql_safe_updates;
