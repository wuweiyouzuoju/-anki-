// CollectionService：撤销/重做域的高层调用封装（T2）。
// 职责：查询 undo/redo 可用状态、执行撤销/重做；不持有 UI 状态。
// 方法索引来源：ServiceIds.ts（提取自 Anki 26.05 生成代码）。
//
// 链路语义（与桌面 Anki reviewer.py 一致）：
// - UndoStatus.undo/redo 为可撤销/重做操作的本地化描述文案，空串表示该方向不可操作；
// - Undo 撤销最近一次操作（如评分），被撤销的卡片由 Rust core 放回学习队列顶部，
//   调用方撤销后应重新取卡；
// - Redo 仅在服务层封装备用，UI 不暴露（上游移动端惯例）。

import { BackendSession } from './BackendSession';
import { COLLECTION_METHOD, SERVICE } from './ServiceIds';
import type {
  OpChangesAfterUndo,
  UndoStatus
} from '../proto/messages/CollectionMessages';
import {
  decodeCheckDatabaseResponse,
  decodeOpChangesAfterUndo,
  decodeUndoStatus
} from '../proto/messages/CollectionMessages';

export class CollectionService {
  private readonly session: BackendSession = BackendSession.getInstance();

  /** 查询撤销/重做状态；undo/redo 描述为空串表示对应方向不可用。 */
  async getUndoStatus(): Promise<UndoStatus> {
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_COLLECTION, COLLECTION_METHOD.GET_UNDO_STATUS, new Uint8Array(0));
    return decodeUndoStatus(response);
  }

  /** 撤销最近一次操作；评分被撤销后卡片回到队列顶部，调用方应重新取卡。 */
  async undo(): Promise<OpChangesAfterUndo> {
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_COLLECTION, COLLECTION_METHOD.UNDO, new Uint8Array(0));
    return decodeOpChangesAfterUndo(response);
  }

  /** 重做最近一次被撤销的操作；仅服务层备用，UI 不暴露。 */
  async redo(): Promise<OpChangesAfterUndo> {
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_COLLECTION, COLLECTION_METHOD.REDO, new Uint8Array(0));
    return decodeOpChangesAfterUndo(response);
  }

  /** 检查数据库完整性；返回本地化问题列表，空数组表示检查通过。 */
  async checkDatabase(): Promise<string[]> {
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_COLLECTION, COLLECTION_METHOD.CHECK_DATABASE, new Uint8Array(0));
    return decodeCheckDatabaseResponse(response);
  }
}
