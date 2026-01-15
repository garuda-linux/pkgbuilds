#!/usr/bin/env python3

import os
import yaml
import sys
import sqlite3
import hashlib
import json
import re

CONFIG_DIR = '/etc/garuda/garuda-config-agent'
DATABASE = CONFIG_DIR + '/configs.db'

# Check if the system is a legacy installation
SYSTEM_LEGACY_PATCHES = os.path.exists('/etc/garuda/migrations/has_legacy_patches')

def parse_configs(directory):
    parsed_configs = {}

    if not os.path.isdir(directory):
        print(f"Error: Directory {directory} not found.", file=sys.stderr)
        return {}

    # Iterate over all files
    for filename in os.listdir(directory):
        if filename.endswith(".yaml") or filename.endswith(".yml"):
            filepath = os.path.join(directory, filename)

            try:
                with open(filepath, 'r') as f:
                    data = yaml.safe_load(f)

                    if not data or 'targetFile' not in data:
                        print(f"Skipping {filename}: Missing 'targetFile'", file=sys.stderr)
                        continue

                    target_file = data['targetFile']
                    if not "pipeline" in data:
                        print(f"Skipping {filename}: Missing 'pipeline'", file=sys.stderr)
                        continue
                    pipeline = data.get('pipeline', [])

                    orders = [step.get('order', 0) for step in pipeline]
                    if not orders:
                        print(f"Skipping {filename}: Empty pipeline", file=sys.stderr)
                        continue
                    max_order = max(orders)

                    pipeline.sort(key=lambda x: x.get('order', 0))

                    if target_file in parsed_configs:
                        print(f"Warning: Duplicate targetFile {target_file} found in {filename} and {parsed_configs[target_file]['source_file']}. Skipping.", file=sys.stderr)
                        continue

                    isBackupFile = data.get('isBackupFile', True)
                    # Default to -1 (no patches applied) if not specified
                    legacyPatchLevel = data.get('legacyPatchLevel', -1)
                    # Whether or not to auto-merge pacnew files if they are marked "original"
                    autoMerge = data.get('autoMerge', True)

                    parsed_configs[target_file] = {
                        "max_order": max_order,
                        "pipeline": pipeline,
                        "isBackupFile": isBackupFile,
                        "legacyPatchLevel": legacyPatchLevel,
                        "source_file": filepath,
                        "autoMerge": autoMerge
                    }
            except Exception as e:
                print(f"Error parsing {filename}: {e}", file=sys.stderr)

    return parsed_configs

def connect_db():
    # Connect (or create and connect) to the SQLite database
    conn = sqlite3.connect(DATABASE)

    cursor = conn.cursor()

    # Create default table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS configs (
            target_file TEXT PRIMARY KEY,
            "order" INTEGER,
            pacnew_hash TEXT,
            main_hash TEXT,
            is_original INTEGER DEFAULT 0
        )
    ''')

    # Create key value table for metadata
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS metadata (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    ''')

    conn.commit()

    return conn

def read_stdin():
    modified_files = set()
    for line in sys.stdin:
        modified_files.add("/" + line.strip())

    return modified_files

# https://stackoverflow.com/a/44873382
def sha256sum(filename):
    if not os.path.exists(filename):
        return None
    try:
        with open(filename, 'rb', buffering=0) as f:
            return hashlib.file_digest(f, 'sha256').hexdigest()
    except (OSError, ValueError):
        return None

def read_existing_files(cursor):
    cursor.execute('SELECT value FROM metadata WHERE key=?', ('existing_files',))
    row = cursor.fetchone()
    if row:
        return json.loads(row[0])
    return []

def expand_modified_files(modified_files, configs):
    additional_targets = set()
    for target_file, config in configs.items():
        if config['source_file'] in modified_files:
            additional_targets.add(target_file)
    modified_files.update(additional_targets)

def apply_pipeline(target_file, pipeline, previous_order):
    if not os.path.exists(target_file):
        print(f"Error: Target file {target_file} does not exist.", file=sys.stderr)
        return False

    try:
        with open(target_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error: Reading {target_file}: {e}", file=sys.stderr)
        return False

    if previous_order == -1:
        print(f"[{target_file}] Applying full pipeline...")
    else:
        print(f"[{target_file}] Applying pipeline incrementally from {previous_order}...")

    original_content = content

    for step in pipeline:
        if "order" not in step:
            print(f"Error: Malformed step in {target_file}: Missing 'order'", file=sys.stderr)
            return False

        order = step['order']
        if order <= previous_order:
            continue

        step_type = step.get('type')
        pattern = step.get('pattern')
        substitution = step.get('substitution')

        if not step_type or pattern is None or substitution is None:
            print(f"Error: Step {order} in {target_file} missing required fields", file=sys.stderr)
            return False

        match step_type:
            case 'revert':
                if previous_order == -1:
                    print(f"--> [{order}] Revert skipped for full application.")
                    continue
            case 'operation':
                pass
            case _:
                print(f"Error: Unknown type '{step_type}' in {target_file}", file=sys.stderr)
                return False

        try:
            print(f"--> [{order}] Applying {step_type}...")
            content = re.sub(pattern, substitution, content, flags=re.MULTILINE)
        except re.error as e:
            print(f"Error: Regex error in {target_file} (Order {order}): {e}", file=sys.stderr)
            return False

    if content != original_content:
        try:
            with open(target_file, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"[{target_file}] Pipeline applied successfully.")
            return True
        except Exception as e:
            print(f"Error: Writing {target_file}: {e}", file=sys.stderr)
            return False
    else:
        # Return True implies "Success/No Action Needed" so DB can update
        return True

def pre(configs, connection):
    modified_files = read_stdin()
    cursor = connection.cursor()
    existing_files = []

    for target_file in modified_files:
        if not os.path.exists(target_file):
            continue

        existing_files.append(target_file)

        if target_file not in configs:
            continue

        pacnew_file = target_file + ".pacnew"

        config_hash = sha256sum(target_file)
        pacnew_hash = sha256sum(pacnew_file)

        cursor.execute('''
            UPDATE configs SET
                is_original = (
                    (is_original AND main_hash = ?)
                    OR
                    (pacnew_hash IS NOT NULL AND pacnew_hash = ?)
                ),
                pacnew_hash=?,
                main_hash=?
            WHERE target_file=?
        ''', (config_hash, config_hash, pacnew_hash, config_hash, target_file))

    # Handle new files list
    cursor.execute('''
        INSERT INTO metadata (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value=excluded.value
    ''', ('existing_files', json.dumps(existing_files)))

    connection.commit()

def post(configs, connection, new_only):
    cursor = connection.cursor()

    modified_files = read_stdin()
    new_files = set()
    if new_only:
        existing_files = read_existing_files(cursor)
        new_files = set(modified_files).difference(set(existing_files))
    expand_modified_files(modified_files, configs)

    for target_file in modified_files:
        if target_file not in configs or not os.path.exists(target_file):
            continue

        config = configs[target_file]
        pipeline = config['pipeline']
        max_order = config['max_order']
        isBackupFile = config['isBackupFile']
        autoMerge = config['autoMerge']

        needs_commit = False

        if target_file in new_files:
            if not os.path.exists(target_file):
                print(f"Error: New file {target_file} does not exist.", file=sys.stderr)
                continue
            new_order = max_order

            # If application fails, set order to -1 so we retry next time
            if not apply_pipeline(target_file, pipeline, -1):
                new_order = -1

            config_hash = sha256sum(target_file)
            cursor.execute('''
                INSERT INTO configs (target_file, "order", pacnew_hash, main_hash, is_original)
                VALUES (?, ?, NULL, ?, true)
                ON CONFLICT(target_file) DO UPDATE SET
                    main_hash = excluded.main_hash,
                    is_original = true,
                    "order" = excluded."order"
            ''', (target_file, new_order, config_hash))
            connection.commit()
            continue

        cursor.execute('SELECT "order", pacnew_hash, main_hash, is_original FROM configs WHERE target_file=?', (target_file,))
        row = cursor.fetchone()

        if not row:
            legacyPatchLevel = config['legacyPatchLevel'] if SYSTEM_LEGACY_PATCHES else -1
            config_hash = sha256sum(target_file)
            cursor.execute('''
                INSERT INTO configs (target_file, "order", pacnew_hash, main_hash, is_original)
                VALUES (?, ?, NULL, ?, false)
            ''', (target_file, legacyPatchLevel, config_hash))
            row = (legacyPatchLevel, None, config_hash, 0)
            needs_commit = True

        db_order, db_pacnew_hash, db_main_hash, is_original = row
        pacnew_file = target_file + ".pacnew"
        has_pacnew = os.path.exists(pacnew_file)

        if has_pacnew:
            current_pacnew_hash = sha256sum(pacnew_file)
            pacnew_modified = (current_pacnew_hash != db_pacnew_hash and current_pacnew_hash is not None)
            if pacnew_modified or max_order > db_order:
                # NEW Pacnew files always get the full pipeline applied
                if pacnew_modified:
                    apply_pipeline(pacnew_file, pipeline, -1)
                else:
                    apply_pipeline(pacnew_file, pipeline, db_order)

                current_pacnew_hash = sha256sum(pacnew_file)

                cursor.execute('''
                    UPDATE configs SET pacnew_hash=? WHERE target_file=?
                ''', (current_pacnew_hash, target_file))
                needs_commit = True

                # If the main config file is still original, we move the pacnew to main
                if is_original == 1 and autoMerge:
                    os.replace(pacnew_file, target_file)
                    print(f"[{target_file}] Replaced original file with .pacnew")

                    config_hash = sha256sum(target_file)
                    cursor.execute('''
                        UPDATE configs SET main_hash=?, "order"=?, pacnew_hash=NULL WHERE target_file=?
                    ''', (config_hash, max_order, target_file))
                    connection.commit()
                    continue

        config_hash = sha256sum(target_file)

        # If "no backup" file changed externally, force re-run (-1)
        start_order = db_order
        if not isBackupFile and config_hash != db_main_hash and not has_pacnew:
             print(f"[{target_file}] Non-backup file changed externally; forcing re-application of pipeline.")
             start_order = -1

        # Run pipeline if we need to reset or have new steps
        if start_order == -1 or max_order > db_order:
            if apply_pipeline(target_file, pipeline, start_order):
                config_hash = sha256sum(target_file)
                cursor.execute('''
                    UPDATE configs SET "order"=?, main_hash=? WHERE target_file=?
                ''', (max_order, config_hash, target_file))
                needs_commit = True
        if needs_commit:
            connection.commit()

if __name__ == "__main__":
    configs = parse_configs(CONFIG_DIR)
    connection = connect_db()

    if len(sys.argv) < 2:
        print("Usage: garuda-config-agent.py [pre|post|postinst|markoriginal]", file=sys.stderr)
        sys.exit(1)

    mode = sys.argv[1]
    try:
        if mode == 'pre':
            pre(configs, connection)
        elif mode == 'post':
            post(configs, connection, False)
        elif mode == 'postinst':
            post(configs, connection, True)
        elif mode == 'markoriginal':
            # Mark all files as original. This is used during the ISO file creation
            cursor = connection.cursor()
            cursor.execute('UPDATE configs SET is_original=1')
            connection.commit()
    finally:
        connection.close()