import { existsSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REQUIRED = [
  'node',
  'git',
  'devEcoRoot',
  'java',
  'rustc',
  'cargo',
  'ohosClang',
  'cmake',
  'ninja',
  'hvigor'
];

export function evaluateEnvironment(probe) {
  const missingRequired = REQUIRED.filter((name) => !probe[name]);
  const missingOptional = [];
  const problems = [];

  if (probe.harmonyApi == null) {
    problems.push('HarmonyOS compile SDK API could not be determined.');
  } else if (Number(probe.harmonyApi) < 23) {
    problems.push(`HarmonyOS compile SDK API 23 or newer is required; found API ${probe.harmonyApi}.`);
  }

  if (probe.rustc) {
    // 与 workspace rust-version = "1.92" 对齐：接受 1.92 系列的任意补丁版本。
    const version = String(probe.rustc).match(/(\d+)\.(\d+)\.\d+/);
    if (!version || version[1] !== '1' || version[2] !== '92') {
      problems.push(`Rust 1.92.x is required; found ${probe.rustc}.`);
    }
  }

  return {
    ok: missingRequired.length === 0 && problems.length === 0,
    missingRequired,
    missingOptional,
    problems,
    probe
  };
}

function commandVersion(command, args = ['--version']) {
  try {
    return execFileSync(command, args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim().split(/\r?\n/, 1)[0];
  } catch {
    return null;
  }
}

function firstExisting(paths) {
  return paths.find((candidate) => candidate && existsSync(candidate)) ?? null;
}

function discoverDevEcoRoot() {
  return firstExisting([
    process.env.DEVECO_HOME,
    process.env.DEVECO_SDK_HOME,
    'C:\\Program Files\\Huawei\\DevEco Studio'
  ]);
}

export function projectToolchainCommands(toolchainRoot) {
  const executableSuffix = process.platform === 'win32' ? '.exe' : '';
  const binRoot = path.join(toolchainRoot, 'cargo', 'bin');
  return {
    rustc: path.join(binRoot, `rustc${executableSuffix}`),
    cargo: path.join(binRoot, `cargo${executableSuffix}`)
  };
}

export function discoverEnvironment() {
  const workspaceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const localCommands = projectToolchainCommands(
    path.join(workspaceRoot, 'work', 'toolchains')
  );
  const devEcoRoot = discoverDevEcoRoot();
  const sdkRoot = devEcoRoot ? path.join(devEcoRoot, 'sdk', 'default') : null;
  const nativeRoot = sdkRoot ? path.join(sdkRoot, 'openharmony', 'native') : null;
  const sdkManifest = sdkRoot ? path.join(sdkRoot, 'sdk-pkg.json') : null;

  let harmonyApi = null;
  if (sdkManifest && existsSync(sdkManifest)) {
    try {
      harmonyApi = Number(JSON.parse(readFileSync(sdkManifest, 'utf8')).data.apiVersion);
    } catch {
      harmonyApi = null;
    }
  }

  return {
    node: commandVersion(process.execPath),
    git: commandVersion('git'),
    devEcoRoot,
    harmonyApi,
    java: firstExisting([
      devEcoRoot && path.join(devEcoRoot, 'jbr', 'bin', 'java.exe'),
      devEcoRoot && path.join(devEcoRoot, 'jbr', 'bin', 'java')
    ]),
    rustc: commandVersion(firstExisting([localCommands.rustc]) ?? 'rustc'),
    cargo: commandVersion(firstExisting([localCommands.cargo]) ?? 'cargo'),
    ohosClang: firstExisting([
      nativeRoot && path.join(nativeRoot, 'llvm', 'bin', 'clang++.exe'),
      nativeRoot && path.join(nativeRoot, 'llvm', 'bin', 'clang++')
    ]),
    cmake: firstExisting([
      nativeRoot && path.join(nativeRoot, 'build-tools', 'cmake', 'bin', 'cmake.exe'),
      nativeRoot && path.join(nativeRoot, 'build-tools', 'cmake', 'bin', 'cmake')
    ]),
    ninja: firstExisting([
      nativeRoot && path.join(nativeRoot, 'build-tools', 'cmake', 'bin', 'ninja.exe'),
      nativeRoot && path.join(nativeRoot, 'build-tools', 'cmake', 'bin', 'ninja')
    ]),
    hvigor: firstExisting([
      devEcoRoot && path.join(devEcoRoot, 'tools', 'hvigor', 'bin', 'hvigorw.bat'),
      devEcoRoot && path.join(devEcoRoot, 'tools', 'hvigor', 'bin', 'hvigorw')
    ])
  };
}

function printResult(result) {
  console.log(JSON.stringify(result.probe, null, 2));
  if (result.missingRequired.length) {
    console.error(`Missing required tools: ${result.missingRequired.join(', ')}`);
  }
  for (const problem of result.problems) {
    console.error(problem);
  }
  console.log(result.ok ? 'jidecards toolchain is ready.' : 'jidecards toolchain is not ready.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = evaluateEnvironment(discoverEnvironment());
  printResult(result);
  process.exitCode = result.ok ? 0 : 1;
}
