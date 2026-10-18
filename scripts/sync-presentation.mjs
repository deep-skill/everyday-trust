import { cpSync, mkdirSync } from 'node:fs';
const files = ['index.html', 'slides.css', 'slides.js', 'architecture.svg', 'mark.svg'];
mkdirSync('static/presentacion', { recursive: true });
for (const file of files) cpSync(`docs/presentation/${file}`, `static/presentacion/${file}`);
