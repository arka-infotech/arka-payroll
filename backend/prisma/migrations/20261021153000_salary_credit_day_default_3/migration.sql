-- Default salary credit day: 3rd of the following month (Sept period → 3 Oct pay date)
ALTER TABLE "salary_structures" ALTER COLUMN "salary_credit_day" SET DEFAULT 3;
