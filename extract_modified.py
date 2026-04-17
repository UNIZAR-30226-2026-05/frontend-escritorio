import os
import subprocess

# Configuration
EXTENSIONS_TO_SKIP = {'.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.pyc'}
FILES_TO_SKIP = {"extract_modified.py", "modified_codebase.txt", "package-lock.json"}

def read_file_safe(filepath):
    """Try multiple encodings to read the file."""
    encodings = ['utf-8', 'cp1252', 'latin-1', 'ascii']
    for enc in encodings:
        try:
            with open(filepath, 'r', encoding=enc) as f:
                return f.read(), enc
        except (UnicodeDecodeError, PermissionError):
            continue
    return None, None

def get_git_changes():
    """Returns a list of dictionaries containing file status and paths."""
    try:
        # -uall ensures we see every file in new directories
        result = subprocess.run(
            ['git', 'status', '--porcelain', '-uall'], 
            capture_output=True, text=True, check=True
        )
        
        changes = []
        for line in result.stdout.splitlines():
            if len(line) < 3: continue
            
            status = line[:2].strip()
            path_info = line[3:].strip()
            
            # Remove quotes if git quoted the filename
            if path_info.startswith('"') and path_info.endswith('"'):
                path_info = path_info[1:-1]

            item = {"status": status, "path": path_info, "old_path": None}

            # Handle Renamed files: "old_path -> new_path"
            if 'R' in status and " -> " in path_info:
                parts = path_info.split(" -> ")
                item["old_path"] = parts[0].strip().strip('"')
                item["path"] = parts[1].strip().strip('"')
                
            changes.append(item)
                
        return changes
        
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"Error fetching git status: {e}")
        return []

def main():
    changes = get_git_changes()
    
    if not changes:
        print("No changes found.")
        return

    output_file = "modified_codebase.txt"
    with open(output_file, "w", encoding="utf-8") as out:
        out.write("### Codebase Changes Summary ###\n\n")
        
        for change in changes:
            status = change["status"]
            rel_path = change["path"]
            filename = os.path.basename(rel_path)

            # Skip Logic
            if filename in FILES_TO_SKIP: continue
            if any(filename.lower().endswith(ext) for ext in EXTENSIONS_TO_SKIP): continue

            # Case 1: Deleted Files
            if 'D' in status:
                out.write(f"[-] {rel_path} was deleted.\n")
                print(f"Recorded deletion: {rel_path}")

            # Case 2: Relocated (Renamed) Files
            elif 'R' in status:
                out.write(f"[*] {rel_path} was relocated from {change['old_path']}.\n")
                # We also read the content of the new file location
                if os.path.isfile(rel_path):
                    content, _ = read_file_safe(rel_path)
                    if content:
                        out.write(f"\n--- {rel_path} (New Location) ---\n{content}\n\n")
                print(f"Recorded relocation: {change['old_path']} -> {rel_path}")

            # Case 3: Modified or Untracked Files
            else:
                if not os.path.isfile(rel_path): continue
                
                print(f"Processing {rel_path}")
                content, _ = read_file_safe(rel_path)
                
                if content is not None:
                    out.write(f"\n--- {rel_path} ---\n\n")
                    out.write(content)
                else:
                    out.write(f"\n[!] {rel_path} (Binary or unreadable file skipped)\n")

if __name__ == "__main__":
    main()
    print("\nDone! Saved to modified_codebase.txt")