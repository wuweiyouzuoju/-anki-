import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HAS_EXTENSION = /\.[cm]?[jt]s$/;
const RESOLVABLE_EXTENSIONS = ['.ts', '.ets'];

export async function resolve(specifier, context, nextResolve) {
  const isRelative = specifier.startsWith('./') || specifier.startsWith('../');
  if (isRelative && !HAS_EXTENSION.test(specifier) && context.parentURL) {
    const candidate = new URL(specifier, context.parentURL);
    if (candidate.protocol === 'file:') {
      const basePath = fileURLToPath(candidate);
      for (const ext of RESOLVABLE_EXTENSIONS) {
        const file = `${basePath}${ext}`;
        if (existsSync(file)) {
          return nextResolve(pathToFileURL(file).href, context);
        }
      }
    }
  }
  return nextResolve(specifier, context);
}

export async function load(url, context, nextLoad) {
  if (url.endsWith('.ets')) {
    const source = readFileSync(fileURLToPath(url), 'utf8')
      .replace(/^[ \t]*@(Observed|ObservedV2|Track|Trace)[ \t]*\r?$/gm, '')
      .replace(/^([ \t]*)@(Observed|ObservedV2|Track|Trace)[ \t]+/gm, '$1');
    return {
      format: 'module-typescript',
      source,
      shortCircuit: true
    };
  }
  return nextLoad(url, context);
}
