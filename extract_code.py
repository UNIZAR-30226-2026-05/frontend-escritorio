import os
import pathspec

# 1. Configuración de archivos y carpetas a ignorar
IGNORE_PATTERNS = {
    '.git', '__pycache__', 'node_modules', 'venv', '.env', 
    '.DS_Store', '.idea', '.vscode', 'build', 'dist'
}

# 2. Extensiones de archivos no textuales (binarios)
EXTENSIONS_TO_SKIP = {
    '.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.pyc',
    '.exe', '.bin', '.dll', '.so', '.dylib', '.sqlite', '.db', 
    '.woff', '.ttf', '.mp3', '.mp4', '.mov', '.wav', '.pickle', '.pkl'
}

def read_file_safe(filepath):
    """Intenta leer archivos con múltiples codificaciones y detecta binarios."""
    # Añadimos utf-16 y utf-8-sig para archivos de Windows/PowerShell
    encodings = ['utf-8', 'utf-8-sig', 'utf-16', 'cp1252', 'latin-1']
    
    for enc in encodings:
        try:
            with open(filepath, 'r', encoding=enc) as f:
                content = f.read()
                
                # PROTECCIÓN EXTRA: Si el archivo contiene el carácter nulo '\0', 
                # casi con seguridad es un archivo binario mal interpretado.
                if '\0' in content:
                    return None, None
                    
                return content, enc
        except (UnicodeDecodeError, PermissionError):
            continue
    return None, None

def load_gitignore(root):
    path = os.path.join(root, '.gitignore')
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            return pathspec.PathSpec.from_lines('gitwildmatch', f)
    return None

def main():
    root = "."  # Se ejecuta en la carpeta donde lo pongas
    gitignore = load_gitignore(root)
    output_filename = "codebase.txt"
    script_name = os.path.basename(__file__)
    
    print(f"Iniciando extracción en: {os.path.abspath(root)}")
    
    with open(output_filename, "w", encoding="utf-8") as out:
        for dirpath, dirnames, filenames in os.walk(root):
            # Filtrar carpetas ocultas o en lista de ignorados
            dirnames[:] = [d for d in dirnames if d not in IGNORE_PATTERNS and not d.startswith('.')]
            
            for filename in filenames:
                filepath = os.path.join(dirpath, filename)
                rel_path = os.path.relpath(filepath, root)

                # Reglas de exclusión
                if filename in IGNORE_PATTERNS or filename.startswith('.'): continue
                if any(filename.lower().endswith(ext) for ext in EXTENSIONS_TO_SKIP): continue
                if gitignore and gitignore.match_file(rel_path): continue
                if filename == output_filename: continue
                if filename == script_name: continue

                content, enc = read_file_safe(filepath)
                
                if content is not None:
                    print(f"Añadido: {rel_path} ({enc})")
                    out.write(f"\n\n{'='*20}\n FILE: {rel_path}\n{'='*20}\n\n")
                    out.write(content)
                else:
                    # Esto evita que los caracteres ilegales entren al archivo
                    print(f"Saltado (binario o ilegible): {rel_path}")

if __name__ == "__main__":
    main()
    print(f"\n¡Listo! Todo el código se ha guardado en: codebase.txt")