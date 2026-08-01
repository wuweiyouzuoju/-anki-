import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

const SERVICE_IDS = 'entry/src/main/ets/backend/服务索引.ts';
const STATS_SERVICE = 'entry/src/main/ets/backend/统计服务.ts';
const INDEX_PAGE = 'entry/src/main/ets/pages/首页.ets';
const MAPPER = 'entry/src/main/ets/model/主页快照映射器.ets';

test('service ids pin backend stats service 43 and graphs method 2', () => {
  const ids = read(SERVICE_IDS);
  assert.match(ids, /后端统计:\s*43/, 'backend.rs: 43 => run_backend_stats_service_method');
  assert.match(ids, /图表:\s*2/, 'backend.rs: method 2 => Backend::graphs');
});

test('stats service wraps the graphs call through the shared session', () => {
  const service = read(STATS_SERVICE);
  assert.match(service, /async 获取图表统计\(天数: number\): Promise<GraphsView>/);
  assert.match(service, /服务号\.后端统计/);
  assert.match(service, /统计方法\.图表/);
  assert.match(service, /encodeGraphsRequest\(天数\)/);
  assert.match(service, /decodeGraphsResponse\(响应字节\)/);
  assert.doesNotMatch(service, /new 后端客户端/, 'must go through 后端会话');
});

test('home wires graphs into the snapshot and degrades quietly', () => {
  const index = read(INDEX_PAGE);
  assert.match(index, /import \{ 统计服务 \} from '..\/backend\/统计服务'/);
  assert.match(index, /静默加载图表\(\): Promise<GraphsView \| null>/);
  assert.match(index, /构建主页快照\(tree, graphs/);
  assert.match(index, /构建月历\(new Date\(\), snapshot\.reviewCountsByDate\)/);

  const method = index.match(/private async 静默加载图表[\s\S]*?\n  \}/);
  assert.notEqual(method, null);
  assert.match(method[0], /统计服务实例\.获取图表统计\(new Date\(\)\.getDate\(\)\)/,
    'lookback window covers the current month only');
  assert.match(method[0], /catch \(error\)[\s\S]*?return null/,
    'stats failure must degrade to the empty state without blocking home');
});

test('mapper keeps empty states when graphs data is absent', () => {
  const mapper = read(MAPPER);
  assert.match(mapper, /图表数据: GraphsView \| null = null/);
  assert.match(mapper, /图表数据\.fsrs/, 'memory requires the fsrs flag');
  assert.match(mapper, /average > 0/, 'memory requires real fsrs memory-state data');
  assert.match(mapper, /average \/ 100/, 'backend percent scale converts to 0-1 ratio');
});
