import { broadcastMessages } from './data.js';

function loadFromStorage(key, fallback) {
    try {
        const data = localStorage.getItem(key);
        return data ? JSON.parse(data) : fallback;
    } catch (e) {
        return fallback;
    }
}

export function initBroadcast() {
    const marqueeContent = document.getElementById('marqueeContent');

    if (!marqueeContent) {
        console.warn('[Broadcast] 未找到必要的 DOM 元素');
        return;
    }

    const storedMessages = loadFromStorage('merlin_broadcast', broadcastMessages);
    const message = storedMessages.join('  ★  ');
    marqueeContent.textContent = message;

    console.log('[Broadcast] 广播模块初始化完成');
}
