// 首页统计接线契约测试（T6）：
// - ServiceIds 的 BACKEND_STATS=43 / STATS_METHOD.GRAPHS=2 与 backend.rs 构建产物一致；
// - StatsService 只经 BackendSession 走 Graphs 调用，search 固定空串（全库）；
// - Index.ets 拉取失败静默降级（返回 null），快照照常构建，热力/记忆率回落空态。
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

const SERVICE_IDS = 'entry/src/main/ets/backend/ServiceIds.ts';
const STATS_SERVICE = 'entry/src/main/ets/backend/StatsService.ts';
const INDEX_PAGE = 'entry/src/main/ets/pages/Index.ets';
const MAPPER = 'entry/src/main/ets/model/HomeSnapshotMapper.ets';

test('service ids pin backend stats service 43 and graphs method 2', () => {
  const ids = read(SERVICE_IDS);
  assert.match(ids, /BACKEND_STATS: 43/, 'backend.rs: 43 => run_backend_stats_service_method');
  assert.match(ids, /GRAPHS: 2/, 'backend.rs: method 2 => Backend::graphs');
});

test('stats service wraps the graphs call through the shared session', () => {
  const service = read(STATS_SERVICE);
  assert.match(service, /async getGraphs\(days: number\): Promise<GraphsView>/);
  assert.match(service, /SERVICE\.BACKEND_STATS/);
  assert.match(service, /STATS_METHOD\.GRAPHS/);
  assert.match(service, /encodeGraphsRequest\(days\)/);
  assert.match(service, /decodeGraphsResponse\(response\)/);
  assert.doesNotMatch(service, /new BackendClient/, 'must go through BackendSession');
});

test('home wires graphs into the snapshot and degrades quietly', () => {
  const index = read(INDEX_PAGE);
  assert.match(index, /import \{ StatsService \} from '..\/backend\/StatsService'/);
  assert.match(index, /loadGraphsQuietly\(\): Promise<GraphsView \| null>/);
  assert.match(index, /buildHomeSnapshot\(tree, graphs/);
  assert.match(index, /buildMonthCalendar\(new Date\(\), snapshot\.reviewCountsByDate\)/);

  const method = index.match(/private async loadGraphsQuietly[\s\S]*?\n  \}/);
  assert.notEqual(method, null);
  assert.match(method[0], /statsService\.getGraphs\(new Date\(\)\.getDate\(\)\)/,
    'lookback window covers the current month only');
  assert.match(method[0], /catch \(error\)[\s\S]*?return null/,
    'stats failure must degrade to the empty state without blocking home');
});

test('mapper keeps empty states when graphs data is absent', () => {
  const mapper = read(MAPPER);
  assert.match(mapper, /graphs: GraphsView \| null = null/);
  assert.match(mapper, /graphs\.fsrs/, 'memory requires the fsrs flag');
  assert.match(mapper, /average > 0/, 'memory requires real fsrs memory-state data');
  assert.match(mapper, /average \/ 100/, 'backend percent scale converts to 0-1 ratio');
});
