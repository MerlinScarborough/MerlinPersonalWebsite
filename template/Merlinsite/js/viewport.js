import { slideData } from './data.js';

function loadFromStorage(key, fallback) {
    try {
        const data = localStorage.getItem(key);
        return data ? JSON.parse(data) : fallback;
    } catch (e) {
        return fallback;
    }
}

let currentSlide = 0;
let slideInterval = null;
let slides = [];
let indicators = [];
let storedSlideData = [];

export function initViewport() {
    const viewport = document.getElementById('viewport');
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');
    const indicatorsContainer = document.getElementById('slideIndicators');

    if (!viewport || !prevBtn || !nextBtn) {
        console.warn('[Viewport] 未找到必要的 DOM 元素');
        return;
    }

    slides = document.querySelectorAll('.slide');

    if (slides.length === 0) {
        console.warn('[Viewport] 未找到幻灯片元素');
        return;
    }

    storedSlideData = loadFromStorage('merlin_slides', slideData);
    loadSlides();
    createIndicators(indicatorsContainer);
    showSlide(0);

    prevBtn.addEventListener('click', () => {
        changeSlide(-1);
        resetAutoPlay();
    });

    nextBtn.addEventListener('click', () => {
        changeSlide(1);
        resetAutoPlay();
    });

    startAutoPlay();

    console.log('[Viewport] 幻灯片模块初始化完成');
}

function loadSlides() {
    const slideImages = document.querySelectorAll('.slide-image');

    storedSlideData.forEach((data, index) => {
        if (slideImages[index]) {
            slideImages[index].src = data.src;
            slideImages[index].alt = data.alt || '';
            slideImages[index].title = data.title || '';

            if (data.link) {
                slideImages[index].style.cursor = 'pointer';
                slideImages[index].onclick = () => {
                    window.open(data.link, '_blank');
                };
            }
        }
    });
}

function createIndicators(container) {
    if (!container) return;

    container.innerHTML = '';
    indicators = [];

    storedSlideData.forEach((_, index) => {
        const indicator = document.createElement('div');
        indicator.className = `indicator ${index === 0 ? 'active' : ''}`;
        indicator.addEventListener('click', () => {
            goToSlide(index);
            resetAutoPlay();
        });
        container.appendChild(indicator);
        indicators.push(indicator);
    });
}

function showSlide(index) {
    slides.forEach((slide, i) => {
        slide.classList.remove('active');
        if (indicators[i]) {
            indicators[i].classList.remove('active');
        }
    });

    currentSlide = index;

    if (slides[currentSlide]) {
        slides[currentSlide].classList.add('active');
    }

    if (indicators[currentSlide]) {
        indicators[currentSlide].classList.add('active');
    }
}

function changeSlide(direction) {
    const totalSlides = slides.length;
    currentSlide = (currentSlide + direction + totalSlides) % totalSlides;
    showSlide(currentSlide);
}

function goToSlide(index) {
    const totalSlides = slides.length;
    currentSlide = index % totalSlides;
    showSlide(currentSlide);
}

function startAutoPlay() {
    stopAutoPlay();
    slideInterval = setInterval(() => {
        changeSlide(1);
    }, 5000);
}

function stopAutoPlay() {
    if (slideInterval) {
        clearInterval(slideInterval);
        slideInterval = null;
    }
}

function resetAutoPlay() {
    stopAutoPlay();
    startAutoPlay();
}
