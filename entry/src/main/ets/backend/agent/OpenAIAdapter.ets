// SPDX-License-Identifier: AGPL-3.0-or-later

import type { ProviderTurnRequest } from '../../model/agent/ProviderProtocol';
import { buildResponsesPayload, buildResponsesUrl } from '../../model/agent/ProviderProtocol';
import { AgentStreamObserver, AgentStreamRequest, AgentTransportSession } from './AgentTransport';

const OPENAI_BASE_URL: string = 'https://api.openai.com/v1';

/** OpenAI 内置适配器固定走 Responses API；只展示服务端真实返回的摘要/工具事件。 */
export class OpenAIAdapter {
  createSession(request: ProviderTurnRequest, observer: AgentStreamObserver): AgentTransportSession {
    const streamRequest: AgentStreamRequest = {
      url: buildResponsesUrl(OPENAI_BASE_URL),
      apiKey: request.apiKey,
      body: buildResponsesPayload(request)
    };
    return new AgentTransportSession(streamRequest, observer);
  }
}
