// SPDX-License-Identifier: AGPL-3.0-or-later

export interface 遮罩描述 {
  形状: 'rect';
  左: number;
  顶: number;
  宽: number;
  高: number;
  编号: number;
}

function 格式化归一化坐标(值: number): string {
  const 四舍五入: number = Math.round(值 * 10000) / 10000;
  return String(四舍五入);
}

export function 生成Occlusions字符串(遮罩列表: 遮罩描述[]): string {
  let 结果: string = '';
  for (let i = 0; i < 遮罩列表.length; i++) {
    const 遮罩: 遮罩描述 = 遮罩列表[i];
    const 左: string = 格式化归一化坐标(遮罩.左);
    const 顶: string = 格式化归一化坐标(遮罩.顶);
    const 宽: string = 格式化归一化坐标(遮罩.宽);
    const 高: string = 格式化归一化坐标(遮罩.高);
    结果 += `{{c${遮罩.编号}::image-occlusion:rect:left=${左}:top=${顶}:width=${宽}:height=${高}}}`;
  }
  return 结果;
}

export function 编号颜色(编号: number): string {
  switch (编号) {
    case 1:
      return '#E53935';
    case 2:
      return '#FB8C00';
    case 3:
      return '#FDD835';
    case 4:
      return '#43A047';
    case 5:
      return '#1E88E5';
    default:
      return '#9E9E9E';
  }
}
