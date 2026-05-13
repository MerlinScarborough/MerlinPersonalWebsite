import { broadcastMessages } from './data.js';

export function initBroadcast() {
    const marqueeContent = document.getElementById('marqueeContent');

    if (!marqueeContent) {
        console.warn('[Broadcast] 未找到必要的 DOM 元素');
        return;
    }

    const message = broadcastMessages.join('  ★  ');
    marqueeContent.textContent = message;

    console.log('[Broadcast] 广播模块初始化完成');
}
