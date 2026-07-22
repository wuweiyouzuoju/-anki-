// 注册 ts-extension-hook：npm test 启动时经 --import 加载本文件。
import { register } from 'node:module';

register('./ts-extension-hook.mjs', import.meta.url);
