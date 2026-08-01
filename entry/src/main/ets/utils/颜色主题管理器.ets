// SPDX-License-Identifier: AGPL-3.0-or-later

import { 颜色主题, 颜色键, 解析主题色板 } from '../model/颜色主题';

export function 应用颜色主题(主题: 颜色主题, 是否深色: boolean): void {
  const 色板 = 解析主题色板(主题, 是否深色);
  AppStorage.setOrCreate<string>(颜色键.动作主色, 色板.动作主色);
  AppStorage.setOrCreate<string>(颜色键.动作主色悬停, 色板.动作主色悬停);
  AppStorage.setOrCreate<string>(颜色键.动作主色按下, 色板.动作主色按下);
  AppStorage.setOrCreate<string>(颜色键.主色按钮背景, 色板.主色按钮背景);
  AppStorage.setOrCreate<string>(颜色键.主色按钮按下, 色板.主色按钮按下);
  AppStorage.setOrCreate<string>(颜色键.主色容器, 色板.主色容器);
  AppStorage.setOrCreate<string>(颜色键.主色容器悬停, 色板.主色容器悬停);
  AppStorage.setOrCreate<string>(颜色键.主色边框, 色板.主色边框);
  AppStorage.setOrCreate<string>(颜色键.主色图标, 色板.主色图标);
  AppStorage.setOrCreate<string>(颜色键.主色文字, 色板.主色文字);
  AppStorage.setOrCreate<string>(颜色键.选中背景, 色板.选中背景);
  AppStorage.setOrCreate<string>(颜色键.新卡计数色, 色板.新卡计数色);
  AppStorage.setOrCreate<string>(颜色键.学习中计数色, 色板.学习中计数色);
  AppStorage.setOrCreate<string>(颜色键.复习中计数色, 色板.复习中计数色);
  AppStorage.setOrCreate<string>(颜色键.热力1, 色板.热力1);
  AppStorage.setOrCreate<string>(颜色键.热力2, 色板.热力2);
  AppStorage.setOrCreate<string>(颜色键.热力3, 色板.热力3);
  AppStorage.setOrCreate<string>(颜色键.热力4, 色板.热力4);
  AppStorage.setOrCreate<string>(颜色键.页面底色微染, 色板.页面底色微染);
}
