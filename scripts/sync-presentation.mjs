import { createHash } from 'node:crypto';
import { cpSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
const files = ['index.html', 'slides.css', 'slides.js', 'architecture.svg', 'mark.svg'];
mkdirSync('static/presentacion', { recursive: true });
for (const file of files) cpSync(`docs/presentation/${file}`, `static/presentacion/${file}`);
const html = readFileSync('docs/presentation/index.html', 'utf8').replace(
  /(href|src)="(slides\.css|slides\.js|architecture\.svg|mark\.svg)"/g,
  (_, attribute, file) => {
    const version = createHash('sha256').update(readFileSync(`docs/presentation/${file}`)).digest('hex').slice(0, 12);
    return `${attribute}="${file}?v=${version}"`;
  }
);
writeFileSync('static/presentacion/index.html', html);
