// SPDX-License-Identifier: AGPL-3.0-or-later

import type { ProviderTurnRequest } from '../../model/agent/ProviderProtocol';
import {
  buildResponsesPayload,
  buildResponsesUrl,
  ProviderProtocolError
} from '../../model/agent/ProviderProtocol';
import { AgentStreamObserver, AgentStreamRequest, AgentTransportSession } from './AgentTransport';

/**
 * 自定义厂商采用明确的 Responses 兼容契约。它不会静默切换到另一厂商，
 * 也不会在收到部分输出后改走另一个端点，避免重复执行工具。
 */
export class CustomAdapter {
  createSession(request: ProviderTurnRequest, observer: AgentStreamObserver): AgentTransportSession {
    const baseUrl: string = request.baseUrl.trim();
    if (!baseUrl.startsWith('https://')) {
      throw new ProviderProtocolError('custom_endpoint_must_be_https');
    }
    const streamRequest: AgentStreamRequest = {
      url: buildResponsesUrl(baseUrl),
      apiKey: request.apiKey,
      body: buildResponsesPayload(request)
    };
    return new AgentTransportSession(streamRequest, observer);
  }
}
