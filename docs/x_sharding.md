# x_sharding - Database Table Sharding Tool

## Overview

`x_sharding` is a Python3 script that transforms single-table CREATE TABLE statements into sharded database table definitions based on specified sharding rules. The script supports two modes:

1. **Single Database Mode**: Only table sharding within one database (no CREATE DATABASE/USE statements)
2. **Multiple Database Mode**: Both database and table sharding with CREATE DATABASE/USE statements

## Features

- **Parse SQL CREATE TABLE statements** from input files
- **Parse DROP TABLE IF EXISTS statements** and associate with CREATE TABLE statements
- **Parse CREATE [UNIQUE] INDEX statements** and associate with corresponding tables
- **Generate sharded databases** with specified number of database shards
- **Distribute tables across shards** with configurable table count per shard
- **Selective table sharding** - specify which tables to shard, skip others
- **Table suffix control** - reset table numbering per database or continue sequentially
- **Zero-padding support** for consistent naming conventions
- **Automatic output file naming** with customizable suffix
- **Cross-platform compatibility** (Linux/macOS)

## Usage

```bash
# Single Database Mode (only table sharding)
x_sharding --input input.sql --table-count 16

# Multiple Database Mode (database + table sharding)
x_sharding --input input.sql --db-count 4 --table-count 16 --db-name shard
```

### Parameters

- `--input, -i`: Input SQL file containing CREATE TABLE statements (required)
- `--table-count, -t`: Total number of tables to generate (required)
- `--db-count, -d`: Number of databases to create (optional, single database mode if not specified)
- `--db-name, -n`: Database name prefix (required when `--db-count` is specified)
- `--tables, -s`: Comma-separated list of table names to shard (optional, shard all tables if not specified)
- `--reset-per-db, -r`: Reset table numbering for each database (optional, continue sequential numbering by default)
- `--pad-zero, -p`: Add zero-padding to table names for consistent sorting (optional)
- `--output, -o`: Output SQL file path (default: `{input}_sharding.sql`)
- `--help, -h`: Show help message

### Examples

#### Single Database Mode (Only Table Sharding)
```bash
# Generate 16 sharded tables in single database (table numbering starts from 0)
x_sharding --input schema.sql --table-count 16

# With selective table sharding
x_sharding --input schema.sql --table-count 12 --tables "user,order"

# With zero-padding
x_sharding --input schema.sql --table-count 8 --pad-zero
```

#### Multiple Database Mode (Database + Table Sharding)
```bash
# Create 4 databases with 16 tables total (4 tables per database)
x_sharding --input input.sql --db-count 4 --table-count 16 --db-name shard

# Selective table sharding across multiple databases
x_sharding --input schema.sql --db-count 3 --table-count 12 --db-name shard --tables "user,order"

# Reset table numbering per database (table_0, table_1 in each db)
x_sharding --input schema.sql --db-count 2 --table-count 8 --db-name shard --reset-per-db

# Combined features with zero-padding
x_sharding --input db_schema.sql --db-count 4 --table-count 16 --db-name shard --tables "user" --reset-per-db --pad-zero
```

#### Custom Output File
```bash
# Specify custom output filename
x_sharding --input db_schema.sql --db-count 2 --table-count 8 --db-name shard --output production_shards.sql
```

## Input File Format

The input SQL file should contain standard CREATE TABLE statements and can optionally include:

- **DROP TABLE IF EXISTS statements** - Automatically associated with CREATE TABLE statements
- **CREATE [UNIQUE] INDEX statements** - Automatically associated with corresponding tables

The script extracts and links these statements to generate complete sharded schemas.

**Example Input:**
```sql
DROP TABLE IF EXISTS users;
CREATE TABLE `users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Indexes for users table
CREATE INDEX idx_users_email ON users(email);
CREATE UNIQUE INDEX idx_users_username ON users(username);

DROP TABLE IF EXISTS orders;
CREATE TABLE `orders` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Indexes for orders table
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
```

**Note**: In this example, the DROP TABLE and CREATE INDEX statements are automatically associated with their corresponding CREATE TABLE statements. When using `--tables` filter, only specified tables and their associated statements will be included in the output.

## Output Format

### Mode-Specific Behavior

#### Single Database Mode (--db-count not specified)
- **No CREATE DATABASE statements**: Only DROP, CREATE TABLE, and CREATE INDEX statements are generated
- **Table numbering**: Starts from 0 (`users_0`, `users_1`, `orders_2`, ...)
- **Use case**: When you want to shard tables within an existing database

#### Multiple Database Mode (--db-count specified)
- **CREATE DATABASE statements**: Generated for each database using `--db-name` prefix
- **USE statements**: Generated to switch to each database before creating tables
- **Complete statement sets**: DROP, CREATE TABLE, and CREATE INDEX statements for each table
- **Table numbering**: Starts from 0 in each database unless sequential numbering is used

### Database Distribution Logic

The script distributes tables across databases using the following logic:
- Tables are filtered based on `--tables` parameter (if specified)
- Filtered tables and their associated DROP/INDEX statements are distributed round-robin across all databases
- Each selected table generates `table_count / db_count` instances with complete statement sets (in multi-database mode)
- The distribution ensures even table distribution across shards

### Table Naming Conventions

#### Table Numbering Behavior

**Sequential Numbering (default)**: Table suffixes continue across all databases (multi-database mode only)
- `db1`: `user_0`, `order_1`, `user_2`, `order_3`, ...
- `db2`: `user_4`, `order_5`, `user_6`, `order_7`, ...

**Reset Per Database (`--reset-per-db`)**: Table numbering resets for each database
- `db1`: `user_0`, `order_1`, `user_2`, `order_3`, ...
- `db2`: `user_0`, `order_1`, `user_2`, `order_3`, ...
- **Single Database Mode**: Always starts from 0 (`user_0`, `user_1`, ...)

#### Zero-padding Options

**Without Zero-padding (`--pad-zero` not specified):**
- Tables: `user_0`, `user_1`, `order_0`, `order_1`, ...

**With Zero-padding (`--pad-zero` specified):**
- Tables: `user_000`, `user_001`, `order_000`, `order_001`, ... (padding based on max digits)

#### Database Naming (Multi-Database Mode Only)

Database names use the `--db-name` prefix with zero-padding if `--pad-zero` is enabled:
- Without padding: `shard0`, `shard1`, `shard2`, ...
- With padding: `shard000`, `shard001`, `shard002`, ...

### Selective Table Sharding

When `--tables` parameter is specified:
- **Included tables**: Only specified tables are processed and sharded
- **Excluded tables**: Tables not in the list are completely omitted from output
- **Distribution**: Only selected tables participate in round-robin distribution
- **Count calculation**: `table_count` applies only to selected tables

**Example** with `--tables "user,order"`:
- Input tables: `user`, `order`, `config`, `log`
- Processed tables: `user`, `order` only
- Output: Only sharded versions of `user` and `order` tables appear

### Example Output

#### Example 1: Single Database Mode
For input with `users` and `orders` tables (including DROP and INDEX statements), `--table-count 4`, with zero-padding:

```sql
DROP TABLE IF EXISTS users_000;
CREATE TABLE `users_000` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_users_email ON `users_000`(email);
CREATE UNIQUE INDEX idx_users_username ON `users_000`(username);

DROP TABLE IF EXISTS orders_001;
CREATE TABLE `orders_001` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_orders_user_id ON `orders_001`(user_id);
CREATE INDEX idx_orders_status ON `orders_001`(status);

DROP TABLE IF EXISTS users_002;
CREATE TABLE `users_002` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_users_002_email ON `users_002`(email);
CREATE UNIQUE INDEX idx_users_002_username ON `users_002`(username);

DROP TABLE IF EXISTS orders_003;
CREATE TABLE `orders_003` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_orders_003_user_id ON `orders_003`(user_id);
CREATE INDEX idx_orders_003_status ON `orders_003`(status);
```

#### Example 2: Multi-Database Mode (Sequential Numbering)
For input with `users` and `orders` tables (including DROP and INDEX statements), `--db-count 2`, `--table-count 8`, `--db-name shard`, with zero-padding:

```sql
-- Sharded database: shard00
CREATE DATABASE IF NOT EXISTS `shard00` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `shard00`;

DROP TABLE IF EXISTS users_000;
CREATE TABLE `users_000` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_users_email ON `users_000`(email);
CREATE UNIQUE INDEX idx_users_username ON `users_000`(username);

DROP TABLE IF EXISTS orders_001;
CREATE TABLE `orders_001` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_orders_user_id ON `orders_001`(user_id);
CREATE INDEX idx_orders_status ON `orders_001`(status);

-- Sharded database: shard01
CREATE DATABASE IF NOT EXISTS `shard01` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `shard01`;

DROP TABLE IF EXISTS users_002;
CREATE TABLE `users_002` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_users_email ON `users_002`(email);
CREATE UNIQUE INDEX idx_users_username ON `users_002`(username);

DROP TABLE IF EXISTS orders_003;
CREATE TABLE `orders_003` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_orders_user_id ON `orders_003`(user_id);
CREATE INDEX idx_orders_status ON `orders_003`(status);
```

#### Example 3: Reset Per Database
Same input with `--reset-per-db` flag:

```sql
-- Sharded database: shard00
CREATE DATABASE IF NOT EXISTS `shard00` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `shard00`;

DROP TABLE IF EXISTS users_000;
CREATE TABLE `users_000` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_users_email ON `users_000`(email);
CREATE UNIQUE INDEX idx_users_username ON `users_000`(username);

DROP TABLE IF EXISTS orders_001;
CREATE TABLE `orders_001` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_orders_user_id ON `orders_001`(user_id);
CREATE INDEX idx_orders_status ON `orders_001`(status);

-- Sharded database: shard01
CREATE DATABASE IF NOT EXISTS `shard01` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `shard01`;

DROP TABLE IF EXISTS users_000;
CREATE TABLE `users_000` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_users_email ON `users_000`(email);
CREATE UNIQUE INDEX idx_users_username ON `users_000`(username);

DROP TABLE IF EXISTS orders_001;
CREATE TABLE `orders_001` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE INDEX idx_orders_user_id ON `orders_001`(user_id);
CREATE INDEX idx_orders_status ON `orders_001`(status);
```

#### Example 4: Selective Table Sharding
With `--tables "users"`, `--table-count 4` (single database mode):

```sql
CREATE TABLE `user_000` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `user_001` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `user_002` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `user_003` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Note**: The `orders` and `config` tables and all their associated DROP and INDEX statements are completely omitted from the output when using `--tables "users"`.

## Algorithm

### Table Distribution

1. **Parse Input**: Extract all CREATE TABLE, DROP TABLE IF EXISTS, and CREATE [UNIQUE] INDEX statements from input file
2. **Link Statements**: Associate DROP and INDEX statements with their corresponding CREATE TABLE statements
3. **Filter Tables**: Apply `--tables` filter if specified (include only specified tables and their associated statements)
4. **Calculate Distribution**: Determine how many instances of each filtered table to create
5. **Round-robin Assignment**: Distribute complete statement sets across databases evenly
6. **Generate Output**: Create SQL statements for DROP, CREATE TABLE, and CREATE INDEX with appropriate sharded naming

### Pseudo-code

```
tables = parse_sql(input_file)  # Creates TableDefinition objects with associated DROP/INDEX statements

# Apply table filter if specified
if --tables specified:
    tables = filter_tables(tables, --tables_list)  # Only includes specified tables and their statements

tables_per_db = table_count // db_count
global_table_counter = 1

for db_index in 1..db_count:
    create_database_statement(db_name)

    # Reset table counter per database if --reset-per-db flag
    if --reset-per-db:
        db_table_counter = 1

    for table_index in 1..tables_per_db:
        original_table = tables[(table_index - 1) % len(tables)]

        if --reset-per-db:
            table_suffix = db_table_counter
            db_table_counter += 1
        else:
            table_suffix = global_table_counter
            global_table_counter += 1

        sharded_table_name = generate_table_name(original_table.name, table_suffix, --pad-zero)

        # Generate complete statement set for this table shard
        if original_table.drop_statement:
            create_drop_table_statement(original_table.drop_statement, sharded_table_name)

        create_table_statement(original_table.full_statement, sharded_table_name)

        for index_statement in original_table.index_statements:
            sharded_index_name = generate_sharded_index_name(index_statement.name, original_table.name, table_suffix)
            create_index_statement(index_statement, sharded_table_name, sharded_index_name)
```

## Error Handling

The script handles the following error conditions:

- **Missing input file**: Validates file existence and readability
- **Invalid parameters**: Validates numeric parameters are positive integers
- **Table filtering errors**: Warns if specified tables don't exist in input
- **SQL parsing errors**: Attempts to continue with valid tables if some fail to parse
- **File permission errors**: Provides clear messages for output file issues
- **Invalid table counts**: Ensures table_count is compatible with db_count and available tables

## Dependencies

- **Python 3.6+**: Standard Python installation
- **Standard libraries only**: `argparse`, `re`, `os`, `sys`, `pathlib`

No external dependencies required.

## Installation

Place the `x_sharding` script in `~/.local/xbin/` (or any directory in your PATH):

```bash
# Make executable
chmod +x ~/.local/xbin/x_sharding

# Verify installation
x_sharding --help
```

## Testing

Create a test input file and verify output:

```bash
# Create test input
cat > test_schema.sql << 'EOF'
CREATE TABLE `user` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
EOF

# Test sharding
x_sharding --input test_schema.sql --db-count 2 --table-count 4 --pad-zero

# Verify output
cat test_schema_sharding.sql
```

## Limitations

- **Regex-based parsing**: Uses regex patterns for SQL parsing (may not handle complex SQL edge cases)
- **Statement association**: DROP and INDEX statements must appear after their CREATE TABLE statements
- **Basic index support**: Only supports simple CREATE [UNIQUE] INDEX syntax (no functional indexes, partial indexes, etc.)
- **Fixed distribution**: Uses round-robin distribution (custom hashing not supported)
- **No foreign key handling**: Foreign key relationships between tables are not automatically adjusted

## Future Enhancements

- **Custom sharding algorithms**: Support for hash-based or range-based sharding
- **Foreign key preservation**: Automatic foreign key relationship adjustment
- **Advanced SQL parsing**: Support for more complex SQL constructs
- **Configuration files**: Support for external configuration files
- **Multiple database types**: Support for PostgreSQL, SQLite, etc.