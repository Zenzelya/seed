import fs from 'fs/promises';
import path from 'path';
import { existsSync } from 'fs';
import { fileURLToPath } from 'url';

// Получаем путь к директории, где лежит сам скрипт
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class SourceCombiner {
  constructor(options) {
    this.inputDirs = options.inputDirs || ['.'];
    // Теперь путь всегда будет относительно папки со скриптом
    this.outputFile = path.join(__dirname, options.outputFile || 'combined_code.txt');
    this.extension = options.extension || '.ts';
    this.ignoreDirs = options.ignoreDirs || ['node_modules', 'dist', '.git'];
  }

  async getFiles(dirPath) {
    if (!existsSync(dirPath)) {
      console.warn(`[Warning] Путь не найден: ${dirPath}`);
      return [];
    }

    try {
      const entries = await fs.readdir(dirPath, { withFileTypes: true });
      const tasks = entries.map(async (entry) => {
        const fullPath = path.join(dirPath, entry.name);

        if (entry.isDirectory()) {
          if (this.ignoreDirs.includes(entry.name)) return [];
          return this.getFiles(fullPath);
        }

        return entry.name.endsWith(this.extension) ? fullPath : [];
      });

      const results = await Promise.all(tasks);
      return results.flat();
    } catch (err) {
      console.error(`[Error] Ошибка чтения ${dirPath}:`, err.message);
      return [];
    }
  }

  async run() {
    try {
      const resolvedInputs = this.inputDirs.map(d => path.resolve(d));
      console.log('--- Поиск файлов в директориях ---');

      const fileDiscovery = await Promise.all(resolvedInputs.map(dir => this.getFiles(dir)));
      const files = fileDiscovery.flat();

      if (files.length === 0) {
        console.log('TS файлы не найдены.');
        return;
      }

      let combinedContent = '';

      for (const filePath of files) {
        const content = await fs.readFile(filePath, 'utf8');
        const trimmed = content.replace(/\s+/g, ' ').trim();
        // Оставляем полный путь или относительный для комментариев в файле
        const relPath = path.relative(process.cwd(), filePath);

        combinedContent += `// File: ${relPath}\n${trimmed}\n\n`;
      }

      // Записываем файл по пути, вычисленному в конструкторе
      await fs.writeFile(this.outputFile, combinedContent);

      console.log('-----------------------------------');
      console.log(`Успех! Обработано файлов: ${files.length}`);
      console.log(`Результат записан в: ${this.outputFile}`);
    } catch (error) {
      console.error('Критическая ошибка:', error.message);
      process.exit(1);
    }
  }
}

const args = process.argv.slice(2);
const dirs = args.length > 0 ? args : ['.'];

const combiner = new SourceCombiner({
  inputDirs: dirs,
  outputFile: 'combined_code.txt'
});

combiner.run();