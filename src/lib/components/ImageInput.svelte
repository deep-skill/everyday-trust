<script lang="ts">
  import { onDestroy } from 'svelte';
  let { onchange, onbusy, disabled = false }: {
    onchange: (image: string | null) => void;
    onbusy?: (busy: boolean) => void;
    disabled?: boolean;
  } = $props();
  let error = $state(''), ready = $state(false), busy = $state(false);
  let fileInput: HTMLInputElement;
  let version = 0;
  const limit = 2 * 1024 * 1024;
  onDestroy(() => { version++; onbusy?.(false); });

  function clear() {
    version++; ready = false; error = ''; busy = false;
    if (fileInput) fileInput.value = '';
    onchange(null); onbusy?.(false);
  }

  async function select() {
    const file = fileInput.files?.[0];
    const current = ++version;
    error = ''; ready = false; onchange(null);
    if (!file) return;
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      error = 'Elige una imagen JPEG, PNG o WebP.'; fileInput.value = ''; return;
    }
    if (file.size > limit) {
      error = 'La captura debe pesar como máximo 2 MB.'; fileInput.value = ''; return;
    }
    busy = true; onbusy?.(true);
    let bitmap: ImageBitmap | undefined;
    try {
      bitmap = await createImageBitmap(file);
      if (bitmap.width < 1 || bitmap.height < 1 || bitmap.width * bitmap.height > 40_000_000) throw new Error('invalid_image');
      const scale = Math.min(1, 1280 / Math.max(bitmap.width, bitmap.height));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(bitmap.width * scale));
      canvas.height = Math.max(1, Math.round(bitmap.height * scale));
      const context = canvas.getContext('2d');
      if (!context) throw new Error('invalid_image');
      context.fillStyle = '#ffffff'; context.fillRect(0, 0, canvas.width, canvas.height);
      context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      // Drawing and encoding creates fresh image bytes without the original EXIF metadata.
      const encoded = await new Promise<Blob>((resolve, reject) => {
        canvas.toBlob(blob => blob ? resolve(blob) : reject(new Error('invalid_image')), 'image/jpeg', .9);
      });
      canvas.width = 0; canvas.height = 0;
      if (encoded.size > limit) throw new Error('too_large');
      const image = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => typeof reader.result === 'string' ? resolve(reader.result) : reject(new Error('invalid_image'));
        reader.onerror = () => reject(new Error('invalid_image'));
        reader.readAsDataURL(encoded);
      });
      if (current !== version) return;
      ready = true; onchange(image);
    } catch (failure) {
      if (current !== version) return;
      error = (failure as Error).message === 'too_large'
        ? 'La captura sigue siendo muy grande. Prueba recortarla antes de subirla.'
        : 'No pudimos leer la imagen. Prueba otra captura JPEG, PNG o WebP.';
      fileInput.value = '';
    } finally {
      bitmap?.close();
      if (current === version) { busy = false; onbusy?.(false); }
    }
  }
</script>

<div class="image-input">
  <label for="message-image">También puedes subir una captura</label>
  <input bind:this={fileInput} id="message-image" type="file" accept="image/jpeg,image/png,image/webp" onchange={select} disabled={disabled || busy} aria-describedby="image-privacy" />
  {#if busy}<p role="status">Preparando la captura…</p>{/if}
  {#if ready}<p class="image-ready" role="status">Captura lista. Cuenta como dos consultas. <button type="button" class="quiet-button" onclick={clear} {disabled}>Quitar</button></p>{/if}
  {#if error}<p class="image-error" role="alert">{error}</p>{/if}
  <p id="image-privacy">JPEG, PNG o WebP, hasta 2 MB. Quitamos los metadatos y reducimos el tamaño. Recorta claves, códigos, DNI y datos personales antes de subirla. Durante este piloto Meta procesa la captura con Muse Spark Contributor y puede usarla para entrenamiento. No la guardamos en el historial.</p>
</div>

<style>
  .image-input { margin-top: 1rem; border-top: 1px solid #e2e8f0; padding-top: 1rem; }
  label { display: block; font-weight: 600; color: #334155; font-size: .95rem; margin-bottom: .6rem; }
  input { display: block; max-width: 100%; color: #475569; font: inherit; font-size: .9rem; }
  input::file-selector-button { padding: .55rem .8rem; margin-right: .7rem; border: 1px solid #cbd5e1; border-radius: .5rem; background: #ffffff; color: #1d4ed8; cursor: pointer; }
  p { color: #64748b; font-size: .85rem; line-height: 1.6; margin: .7rem 0 0; }
  .image-ready { color: #334155; }
  .image-error { color: #b91c1c; }
</style>
