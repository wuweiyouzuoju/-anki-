import { BackendSession } from './BackendSession';
import { NOTETYPES_METHOD, SERVICE } from './ServiceIds';
import type { NotetypeNameId, NotetypeView } from '../proto/messages/NotetypeMessages';
import {
  decodeNotetype,
  decodeNotetypeNames,
  encodeNotetypeId
} from '../proto/messages/NotetypeMessages';

/** Read-only Anki notetype boundary used by AddNotePanel's owning page. */
export class NotetypeService {
  private readonly session: BackendSession = BackendSession.getInstance();

  async getNotetypeNames(): Promise<NotetypeNameId[]> {
    const response = await this.session.run(
      SERVICE.BACKEND_NOTETYPES, NOTETYPES_METHOD.GET_NOTETYPE_NAMES, new Uint8Array(0));
    return decodeNotetypeNames(response);
  }

  async getNotetype(id: number): Promise<NotetypeView> {
    const response = await this.session.run(
      SERVICE.BACKEND_NOTETYPES, NOTETYPES_METHOD.GET_NOTETYPE, encodeNotetypeId(id));
    return decodeNotetype(response);
  }
}
