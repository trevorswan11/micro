import json
import os
import sys

if not len(sys.argv) == 3:
    print("Error: Missing arguments for the cdb and include file")
    exit(1)

COMPILE_COMMANDS_PATH = sys.argv[1]
INCLUDE_DIRS_FILE = sys.argv[2]

# Read the custom generated includes file
with open(INCLUDE_DIRS_FILE, "r") as f:
    raw_paths = f.read().strip().split(";")
    new_includes = list(dict.fromkeys([f"-I{path}" for path in raw_paths if path]))

if not os.path.exists(COMPILE_COMMANDS_PATH):
    print(f"Error: {COMPILE_COMMANDS_PATH} not found.")
    exit(1)

# Read the entire json file
with open(COMPILE_COMMANDS_PATH, "r") as f:
    commands = json.load(f)

hashed_new_includes = set(new_includes)
for entry in commands:
    if "command" in entry:
        parts = entry["command"].split()
        compiler = parts[0]
        existing_args = parts[1:]

        # Filter out includes that aren't there already to prevent cdb ballooning
        filtered_args = filter(lambda s: s not in hashed_new_includes, existing_args)
        entry["command"] = (
            f"{compiler} {' '.join(new_includes)} {' '.join(filtered_args)}"
        )

# Write the json back out
with open(COMPILE_COMMANDS_PATH, "w") as f:
    json.dump(commands, f, indent=2)
