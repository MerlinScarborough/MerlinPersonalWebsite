import { skillsData, contactData, projectsData } from './data.js';

function loadFromStorage(key, fallback) {
    try {
        const data = localStorage.getItem(key);
        return data ? JSON.parse(data) : fallback;
    } catch (e) {
        return fallback;
    }
}

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
            } else if (targetTab === 'album') {
                renderAlbum();
            } else if (targetTab === 'contact') {
                renderContact();
            }
        });
    });

    renderSkills();
    renderAlbum();
    renderContact();

    console.log('[Tabs] 选项卡模块初始化完成');
}

function getMasteryColor(mastery) {
    const colorPoints = [
        { value: 0, color: { r: 128, g: 128, b: 128 } },
        { value: 250, color: { r: 0, g: 255, b: 255 } },
        { value: 500, color: { r: 188, g: 19, b: 254 } },
        { value: 750, color: { r: 255, g: 215, b: 0 } }
    ];

    let lowerBound = colorPoints[0];
    let upperBound = colorPoints[colorPoints.length - 1];

    for (let i = 0; i < colorPoints.length - 1; i++) {
        if (mastery >= colorPoints[i].value && mastery <= colorPoints[i + 1].value) {
            lowerBound = colorPoints[i];
            upperBound = colorPoints[i + 1];
            break;
        }
    }

    if (mastery > 750) {
        return `rgb(${upperBound.color.r}, ${upperBound.color.g}, ${upperBound.color.b})`;
    }

    const range = upperBound.value - lowerBound.value;
    const position = (mastery - lowerBound.value) / range;

    const r = Math.round(lowerBound.color.r + (upperBound.color.r - lowerBound.color.r) * position);
    const g = Math.round(lowerBound.color.g + (upperBound.color.g - lowerBound.color.g) * position);
    const b = Math.round(lowerBound.color.b + (upperBound.color.b - lowerBound.color.b) * position);

    return `rgb(${r}, ${g}, ${b})`;
}

function sortSkills(skills) {
    return [...skills].sort((a, b) => {
        if (b.mastery !== a.mastery) {
            return b.mastery - a.mastery;
        }
        return a.name.localeCompare(b.name);
    });
}

function renderSkills() {
    const container = document.getElementById('skillsContainer');

    if (!container || container.children.length > 0) return;

    const storedSkills = loadFromStorage('merlin_skills', skillsData);
    const sortedSkills = sortSkills(storedSkills);

    sortedSkills.forEach((skill, index) => {
        const skillItem = document.createElement('div');
        skillItem.className = 'skill-item';
        
        const color = getMasteryColor(skill.mastery);
        
        skillItem.innerHTML = `
            <span class="skill-name" style="color: ${color}">${skill.name}</span>
            <span class="skill-mastery" style="color: ${color}">${skill.mastery}</span>
        `;
        
        skillItem.style.setProperty('--skill-color', color);
        skillItem.style.animationDelay = `${index * 50}ms`;
        
        container.appendChild(skillItem);
    });

    const disclaimer = document.createElement('div');
    disclaimer.className = 'skills-disclaimer';
    disclaimer.innerHTML = '*个人主观评分，标准是500是可以投入基本生产活动的及格线';
    container.appendChild(disclaimer);
}

function sortProjects(projects) {
    return [...projects].sort((a, b) => {
        if (a.rank !== b.rank) {
            return a.rank - b.rank;
        }
        return a.proj_name.localeCompare(b.proj_name);
    });
}

function renderAlbum() {
    const container = document.getElementById('albumContainer');

    if (!container || container.children.length > 0) return;

    const storedProjects = loadFromStorage('merlin_projects', projectsData);
    const sortedProjects = sortProjects(storedProjects);

    sortedProjects.forEach((project, index) => {
        const projectCard = document.createElement('div');
        projectCard.className = 'project-card';
        
        projectCard.innerHTML = `
            <div class="project-header">
                <span class="project-rank">#${project.rank}</span>
                <h3 class="project-name">${project.proj_name}</h3>
            </div>
            <p class="project-brief">${project.proj_brief}</p>
            <a href="${project.proj_link}" 
               class="project-link" 
               target="_blank" 
               rel="noopener noreferrer"
               ${project.proj_link === '#' ? 'onclick="return false;"' : ''}>
                查看详情 →
            </a>
        `;
        
        projectCard.style.animationDelay = `${index * 100}ms`;
        
        container.appendChild(projectCard);
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
