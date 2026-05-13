import { skillsData, contactData } from './data.js';

export function initTabs() {
    const tabButtons = document.querySelectorAll('.tab-btn');
    const tabPanes = document.querySelectorAll('.tab-pane');

    if (tabButtons.length === 0 || tabPanes.length === 0) {
        console.warn('[Tabs] 未找到必要的 DOM 元素');
        return;
    }

    tabButtons.forEach(button => {
        button.addEventListener('click', () => {
            const targetTab = button.getAttribute('data-tab');

            tabButtons.forEach(btn => btn.classList.remove('active'));
            tabPanes.forEach(pane => pane.classList.remove('active'));

            button.classList.add('active');

            const targetPane = document.getElementById(targetTab);
            if (targetPane) {
                targetPane.classList.add('active');
            }

            if (targetTab === 'skills') {
                renderSkills();
            } else if (targetTab === 'contact') {
                renderContact();
            }
        });
    });

    renderSkills();
    renderContact();

    console.log('[Tabs] 选项卡模块初始化完成');
}

function renderSkills() {
    const container = document.getElementById('skillsContainer');

    if (!container || container.children.length > 0) return;

    skillsData.forEach(skill => {
        const skillItem = document.createElement('div');
        skillItem.className = 'skill-item';
        skillItem.innerHTML = `
            <div class="skill-header">
                <span class="skill-name">${skill.name}</span>
                <span class="skill-level">${skill.level}%</span>
            </div>
            <div class="skill-bar">
                <div class="skill-progress" style="width: 0%"></div>
            </div>
        `;
        container.appendChild(skillItem);

        setTimeout(() => {
            const progressBar = skillItem.querySelector('.skill-progress');
            if (progressBar) {
                progressBar.style.width = `${skill.level}%`;
            }
        }, 100);
    });
}

function renderContact() {
    const container = document.getElementById('contactList');

    if (!container || container.children.length > 0) return;

    contactData.forEach(contact => {
        const contactItem = document.createElement('div');
        contactItem.className = 'contact-item';
        contactItem.innerHTML = `
            <span class="contact-icon">${contact.icon}</span>
            <div class="contact-info">
                <span class="contact-label">${contact.label}</span>
                <span class="contact-value">${contact.value}</span>
            </div>
        `;

        if (contact.link && contact.link !== '#') {
            contactItem.addEventListener('click', () => {
                window.open(contact.link, '_blank');
            });
        }

        container.appendChild(contactItem);
    });
}
