export const examples = {
  family: 'Hola mamá, cambié de número. Necesito que me hagas una transferencia urgente. Te cuento después.',
  bank: 'BANCO EJEMPLO: Tu cuenta será bloqueada hoy. Valida tu contraseña en https://acceso-banco.example/validar para evitar el bloqueo.'
} as const;

export function findExample(id: string | null): string | undefined {
  return id && Object.hasOwn(examples, id) ? examples[id as keyof typeof examples] : undefined;
}
