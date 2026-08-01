// SPDX-License-Identifier: AGPL-3.0-or-later

import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { commentManager } from '@kit.AppGalleryKit';

const 日志域: number = 0x0001;
const 日志标签: string = '好评引导';

export function 打开应用内好评(上下文: common.UIAbilityContext, 包名: string): void {
  try {
    commentManager.showCommentDialog(上下文).then(() => {
      hilog.info(日志域, 日志标签, 'showCommentDialog 成功');
    }).catch((错误: BusinessError) => {
      hilog.error(日志域, 日志标签, `showCommentDialog 失败 code=${错误.code} msg=${错误.message}`);
      跳转应用市场详情页(上下文, 包名);
    });
  } catch (错误) {
    hilog.error(日志域, 日志标签, `showCommentDialog 同步异常: ${错误}`);
    跳转应用市场详情页(上下文, 包名);
  }
}

export function 跳转应用市场详情页(上下文: common.UIAbilityContext, 包名: string): void {
  hilog.info(日志域, 日志标签, `回退 DeepLink 跳应用市场详情页，包名=${包名}`);
  const want: Want = {
    uri: `store://appgallery.huawei.com/app/detail?id=${包名}`
  };
  上下文.startAbility(want).then(() => {
    hilog.info(日志域, 日志标签, '回退 DeepLink 拉起应用市场成功');
  }).catch((错误: BusinessError) => {
    hilog.error(日志域, 日志标签, `回退 DeepLink 失败 code=${错误.code} msg=${错误.message}`);
    显示Toast(上下文, $r('app.string.about_rate_failed_fallback'));
  });
}

async function 显示Toast(上下文: common.UIAbilityContext, 文案: Resource): Promise<void> {
  try {
    const 主窗口: window.Window = await window.getLastWindow(上下文);
    主窗口.getUIContext().getPromptAction().showToast({
      message: 文案,
      duration: 3000
    });
  } catch (错误) {
  }
}
