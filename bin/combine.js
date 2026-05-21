import fs from 'fs/promises';
import path from 'path';
import { existsSync } from 'fs';
import { fileURLToPath } from 'url';

class SourceCombiner {
  constructor(options) {
    this.inputDirs = options.inputDirs || ['.'];
    this.outputFile = path.resolve(process.cwd(), options.outputFile || 'combined_code.txt');
    this.extensions = options.extensions || ['.js', '.ts', '.py'];
    this.ignoreDirs = options.ignoreDirs || ['node_modules', 'dist', '.git', '__pycache__', 'venv', '.vscode'];
  }

  /**
   * Максимальное сжатие:
   * 1. Удаляет все пустые строки.
   * 2. Удаляет лишние пробелы в начале и конце строк.
   */
  processContent(content) {
    return content
        .split('\n')
        .map(line => line.trim())
        .filter(line => line.length > 0)
        .join(' ');
  }

  async getFiles(dirPath) {
    if (!existsSync(dirPath)) return [];
    try {
      const entries = await fs.readdir(dirPath, { withFileTypes: true });
      const tasks = entries.map(async (entry) => {
        const fullPath = path.join(dirPath, entry.name);
        if (entry.isDirectory()) {
          return this.ignoreDirs.includes(entry.name) ? [] : this.getFiles(fullPath);
        }
        return this.extensions.some(ext => entry.name.endsWith(ext)) ? fullPath : [];
      });
      const results = await Promise.all(tasks);
      return results.flat();
    } catch (err) {
      return [];
    }
  }

  async run() {
    try {
      const resolvedInputs = this.inputDirs.map(d => path.resolve(d));
      const fileDiscovery = await Promise.all(resolvedInputs.map(dir => this.getFiles(dir)));
      const files = fileDiscovery.flat();

      if (files.length === 0) {
        console.log('No files found.');
        return;
      }

      let combinedContent = '';
      for (const filePath of files) {
        let content = await fs.readFile(filePath, 'utf8');
        const relPath = path.relative(process.cwd(), filePath);

        content = this.processContent(content);

        // Используем сверхкомпактные маркеры начала/конца
        combinedContent += `\n>>FILE:${relPath}\n${content}\n<<END\n`;
      }

      await fs.writeFile(this.outputFile, combinedContent);
      console.log(`Successfully compressed ${files.length} files to ${this.outputFile}`);
    } catch (error) {
      console.error('Error:', error.message);
      process.exit(1);
    }
  }
}

const rawArgs = process.argv.slice(2);
const dirs = rawArgs.filter(arg => !arg.startsWith('--'));
const inputDirs = dirs.length > 0 ? dirs : ['.'];
const isPyOnly = rawArgs.includes('--py');

const combiner = new SourceCombiner({
  inputDirs,
  extensions: isPyOnly ? ['.py'] : ['.js', '.ts', '.py', '.md', '.json']
});

combiner.run();