# Every migration runs against tables with millions of rows in production.
StrongMigrations.start_after = 2026_11_01_000000
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour
StrongMigrations.auto_analyze = true
StrongMigrations.target_version = 16
