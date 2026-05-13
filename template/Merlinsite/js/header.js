export function initHeader() {
    const header = document.getElementById('header');
    const logo = document.querySelector('.logo');

    if (!header || !logo) {
        console.warn('[Header] 未找到必要的 DOM 元素');
        return;
    }

    logo.addEventListener('mouseenter', () => {
        logo.style.transform = 'scale(1.05)';
        logo.style.transition = 'transform 0.3s ease';
    });

    logo.addEventListener('mouseleave', () => {
        logo.style.transform = 'scale(1)';
    });

    console.log('[Header] Logo 模块初始化完成');
}
