export function openBackend(init: Uint8Array): number;

export function runMethodRaw(
  handle: number,
  service: number,
  method: number,
  input: Uint8Array
): Promise<Uint8Array>;

export function closeBackend(handle: number): void;
