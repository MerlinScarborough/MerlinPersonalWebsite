import { initHeader } from './header.js';
import { initViewport } from './viewport.js';
import { initBroadcast } from './broadcast.js';
import { initTabs } from './tabs.js';

document.addEventListener('DOMContentLoaded', () => {
    console.log('====================================');
    console.log('  Merlin 个人工作台 - 系统启动中...');
    console.log('====================================');

    try {
        initHeader();
        initViewport();
        initBroadcast();
        initTabs();

        console.log('====================================');
        console.log('  ✓ 所有模块初始化完成！');
        console.log('  欢迎访问 Merlin 个人工作台');
        console.log('====================================');
    } catch (error) {
        console.error('[Main] 初始化过程中发生错误:', error);
    }
});
