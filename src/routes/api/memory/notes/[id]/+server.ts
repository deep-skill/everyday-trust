import { json, type RequestHandler } from '@sveltejs/kit';
import { MemoryUnavailable } from '$lib/server/atomic-memory';
import { memoryError, noteContext } from '$lib/server/memory';

export const DELETE: RequestHandler = async ({ cookies, params }) => {
  const context = await noteContext(cookies);
  if (context.failure) return context.failure;
  try {
    // Only notes this app wrote for the current holder can be removed from here.
    const owned = (await context.memory.list(context.subject)).some(note => note.id === params.id);
    // remove() is true only when the provider confirms `success: true`.
    if (!owned || !(await context.memory.remove(context.subject, params.id ?? ''))) return memoryError(404, 'not_found', 'Esa nota ya no existe.');
    return json({ deleted: true }, { headers: { 'cache-control': 'no-store' } });
  } catch (error) {
    if (error instanceof MemoryUnavailable) return memoryError(503, 'memory_unavailable', 'Atomic Memory no respondió. La nota sigue guardada; inténtalo de nuevo.');
    throw error;
  }
};
