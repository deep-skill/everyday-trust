import { readFileSync } from 'node:fs';
const required = ['ORIGIN','API_BASE_URL','API_SERVICE_TOKEN','WEB_DATABASE_URL','DATABASE_CA_FILE','COGNITO_ISSUER','COGNITO_CLIENT_ID','COGNITO_CLIENT_SECRET','COGNITO_DOMAIN','SESSION_ENCRYPTION_KEY'];
for (const key of required) if (!process.env[key]) throw new Error(`Missing runtime setting: ${key}`);
if (new URL(process.env.ORIGIN).protocol !== 'https:') throw new Error('HTTPS origin required');
if (Buffer.from(process.env.SESSION_ENCRYPTION_KEY, 'base64').length !== 32 || process.env.API_SERVICE_TOKEN.length < 32) throw new Error('Invalid runtime keys');
readFileSync(process.env.DATABASE_CA_FILE);
await import('../build/index.js');
