class BaseManager {
    constructor(storageKey) {
        this.storageKey = storageKey;
        this.items = [];
        this.load();
    }

    load() {
        try {
            const data = localStorage.getItem(this.storageKey);
            this.items = data ? JSON.parse(data) : [];
        } catch (e) {
            console.error(`加载 ${this.storageKey} 失败:`, e);
            this.items = [];
        }
    }

    save() {
        try {
            localStorage.setItem(this.storageKey, JSON.stringify(this.items));
        } catch (e) {
            console.error(`保存 ${this.storageKey} 失败:`, e);
            showToast('保存失败！', true);
        }
    }

    delete(index) {
        this.items.splice(index, 1);
        this.save();
    }

    showToast(msg, isError = false) {
        const toast = document.getElementById('toast');
        toast.textContent = msg;
        toast.className = 'toast show' + (isError ? ' error' : '');
        setTimeout(() => { toast.className = 'toast'; }, 3000);
    }
}

class ProjectManager extends BaseManager {
    constructor() {
        super('merlin_projects');
        this.containerId = 'projectsList';
        this.countId = 'projectCount';
    }

    render() {
        const container = document.getElementById(this.containerId);
        container.innerHTML = '';
        document.getElementById(this.countId).textContent = this.items.length;

        this.items.sort((a, b) => a.rank - b.rank || a.proj_name.localeCompare(b.proj_name));

        this.items.forEach((item, index) => {
            const el = document.createElement('div');
            el.className = 'list-item';
            el.innerHTML = `
                <div class="item-info">
                    <div class="item-title">#${item.rank} ${item.proj_name}</div>
                    <div class="item-subtitle">${item.proj_brief.substring(0, 80)}...</div>
                </div>
                <div class="item-actions">
                    <button class="btn btn-secondary btn-small" onclick="projectManager.edit(${index})">编辑</button>
                    <button class="btn btn-danger btn-small" onclick="projectManager.confirmDelete(${index})">删除</button>
                </div>
            `;
            container.appendChild(el);
        });
    }

    add() {
        openModal('添加项目', 'projects', [
            { name: 'projRank', label: '排序', type: 'number', placeholder: '数字越小越靠前', required: true },
            { name: 'projName', label: '项目名称', type: 'text', placeholder: '例如：赛博朋克城市渲染', required: true },
            { name: 'projBrief', label: '项目简介', type: 'textarea', placeholder: '描述你的职责、创新点或技术要点...', required: true },
            { name: 'projLink', label: '项目链接', type: 'url', placeholder: 'https://... 或 #（暂无链接）', value: '#' }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items.push({
                rank: parseInt(form.projRank.value),
                proj_name: form.projName.value,
                proj_brief: form.projBrief.value,
                proj_link: form.projLink.value || '#'
            });
            this.save();
            this.render();
            showToast('项目已添加！');
        });
    }

    edit(index) {
        const item = this.items[index];
        openModal('编辑项目', 'projects', [
            { name: 'projRank', label: '排序', type: 'number', value: item.rank, required: true },
            { name: 'projName', label: '项目名称', type: 'text', value: item.proj_name, required: true },
            { name: 'projBrief', label: '项目简介', type: 'textarea', value: item.proj_brief, required: true },
            { name: 'projLink', label: '项目链接', type: 'url', value: item.proj_link }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items[index] = {
                rank: parseInt(form.projRank.value),
                proj_name: form.projName.value,
                proj_brief: form.projBrief.value,
                proj_link: form.projLink.value || '#'
            };
            this.save();
            this.render();
            showToast('项目已更新！');
        }, index);
    }

    confirmDelete(index) {
        confirmDelete(`确定要删除项目 "${this.items[index].proj_name}" 吗？`, () => {
            this.delete(index);
            this.render();
            showToast('项目已删除！');
        });
    }
}

class SkillManager extends BaseManager {
    constructor() {
        super('merlin_skills');
        this.containerId = 'skillsList';
        this.countId = 'skillCount';
    }

    render() {
        const container = document.getElementById(this.containerId);
        container.innerHTML = '';
        document.getElementById(this.countId).textContent = this.items.length;

        this.items.sort((a, b) => b.mastery - a.mastery || a.name.localeCompare(b.name));

        this.items.forEach((item, index) => {
            const el = document.createElement('div');
            el.className = 'list-item';
            el.innerHTML = `
                <div class="item-info">
                    <div class="item-title">${item.name}</div>
                    <div class="item-subtitle">掌握度：${item.mastery} / 1000</div>
                </div>
                <div class="item-actions">
                    <button class="btn btn-secondary btn-small" onclick="skillManager.edit(${index})">编辑</button>
                    <button class="btn btn-danger btn-small" onclick="skillManager.confirmDelete(${index})">删除</button>
                </div>
            `;
            container.appendChild(el);
        });
    }

    add() {
        openModal('添加技能', 'skills', [
            { name: 'skillName', label: '技能名称', type: 'text', placeholder: '例如：Unreal Engine', required: true },
            { name: 'mastery', label: '掌握度 (0-1000)', type: 'number', placeholder: '500 为及格线', min: 0, max: 1000, required: true }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items.push({
                name: form.skillName.value,
                mastery: parseInt(form.mastery.value)
            });
            this.save();
            this.render();
            showToast('技能已添加！');
        });
    }

    edit(index) {
        const item = this.items[index];
        openModal('编辑技能', 'skills', [
            { name: 'skillName', label: '技能名称', type: 'text', value: item.name, required: true },
            { name: 'mastery', label: '掌握度 (0-1000)', type: 'number', value: item.mastery, min: 0, max: 1000, required: true }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items[index] = {
                name: form.skillName.value,
                mastery: parseInt(form.mastery.value)
            };
            this.save();
            this.render();
            showToast('技能已更新！');
        }, index);
    }

    confirmDelete(index) {
        confirmDelete(`确定要删除技能 "${this.items[index].name}" 吗？`, () => {
            this.delete(index);
            this.render();
            showToast('技能已删除！');
        });
    }
}

class BioManager extends BaseManager {
    constructor() {
        super('merlin_bio');
        this.containerId = 'bioList';
        this.countId = 'bioCount';
    }

    render() {
        const container = document.getElementById(this.containerId);
        container.innerHTML = '';
        document.getElementById(this.countId).textContent = this.items.length;

        this.items.forEach((item, index) => {
            const el = document.createElement('div');
            el.className = 'list-item';
            el.innerHTML = `
                <div class="item-info">
                    <div class="item-title">${item.title}</div>
                    <div class="item-subtitle">${item.content.substring(0, 100)}...</div>
                </div>
                <div class="item-actions">
                    <button class="btn btn-secondary btn-small" onclick="bioManager.edit(${index})">编辑</button>
                    <button class="btn btn-danger btn-small" onclick="bioManager.confirmDelete(${index})">删除</button>
                </div>
            `;
            container.appendChild(el);
        });
    }

    addSection() {
        openModal('添加章节', 'bio', [
            { name: 'sectionTitle', label: '章节标题', type: 'text', placeholder: '例如：关于我、关于创作...', required: true },
            { name: 'sectionContent', label: '章节内容', type: 'textarea', placeholder: '输入详细内容...', required: true }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items.push({
                title: form.sectionTitle.value,
                content: form.sectionContent.value
            });
            this.save();
            this.render();
            showToast('章节已添加！');
        });
    }

    edit(index) {
        const item = this.items[index];
        openModal('编辑章节', 'bio', [
            { name: 'sectionTitle', label: '章节标题', type: 'text', value: item.title, required: true },
            { name: 'sectionContent', label: '章节内容', type: 'textarea', value: item.content, required: true }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items[index] = {
                title: form.sectionTitle.value,
                content: form.sectionContent.value
            };
            this.save();
            this.render();
            showToast('章节已更新！');
        }, index);
    }

    confirmDelete(index) {
        confirmDelete(`确定要删除章节 "${this.items[index].title}" 吗？`, () => {
            this.delete(index);
            this.render();
            showToast('章节已删除！');
        });
    }
}

class SlideManager extends BaseManager {
    constructor() {
        super('merlin_slides');
        this.containerId = 'slidesList';
        this.countId = 'slideCount';
    }

    render() {
        const container = document.getElementById(this.containerId);
        container.innerHTML = '';
        document.getElementById(this.countId).textContent = this.items.length;

        this.items.forEach((item, index) => {
            const el = document.createElement('div');
            el.className = 'list-item';
            el.innerHTML = `
                <div class="item-info">
                    <div class="item-title">${item.title}</div>
                    <div class="item-subtitle">图片：${item.src} | 链接：${item.link || '无'}</div>
                </div>
                <div class="item-actions">
                    <button class="btn btn-secondary btn-small" onclick="slideManager.edit(${index})">编辑</button>
                    <button class="btn btn-danger btn-small" onclick="slideManager.confirmDelete(${index})">删除</button>
                </div>
            `;
            container.appendChild(el);
        });
    }

    add() {
        openModal('添加幻灯片', 'slides', [
            { name: 'slideTitle', label: '标题', type: 'text', placeholder: '例如：Cyberpunk City', required: true },
            { name: 'slideSrc', label: '图片地址', type: 'url', placeholder: 'https://... 或相对路径', required: true },
            { name: 'slideAlt', label: '替代文本', type: 'text', placeholder: '图片描述' },
            { name: 'slideLink', label: '点击跳转链接', type: 'url', placeholder: '留空表示不跳转' }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items.push({
                id: this.items.length + 1,
                src: form.slideSrc.value,
                alt: form.slideAlt.value,
                title: form.slideTitle.value,
                link: form.slideLink.value || ''
            });
            this.save();
            this.render();
            showToast('幻灯片已添加！');
        });
    }

    edit(index) {
        const item = this.items[index];
        openModal('编辑幻灯片', 'slides', [
            { name: 'slideTitle', label: '标题', type: 'text', value: item.title, required: true },
            { name: 'slideSrc', label: '图片地址', type: 'url', value: item.src, required: true },
            { name: 'slideAlt', label: '替代文本', type: 'text', value: item.alt },
            { name: 'slideLink', label: '点击跳转链接', type: 'url', value: item.link }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items[index] = {
                id: item.id,
                src: form.slideSrc.value,
                alt: form.slideAlt.value,
                title: form.slideTitle.value,
                link: form.slideLink.value || ''
            };
            this.save();
            this.render();
            showToast('幻灯片已更新！');
        }, index);
    }

    confirmDelete(index) {
        confirmDelete(`确定要删除幻灯片 "${this.items[index].title}" 吗？`, () => {
            this.delete(index);
            this.render();
            showToast('幻灯片已删除！');
        });
    }
}

class BroadcastManager extends BaseManager {
    constructor() {
        super('merlin_broadcast');
        this.containerId = 'broadcastList';
        this.countId = 'broadcastCount';
    }

    render() {
        const container = document.getElementById(this.containerId);
        container.innerHTML = '';
        document.getElementById(this.countId).textContent = this.items.length;

        this.items.forEach((item, index) => {
            const el = document.createElement('div');
            el.className = 'list-item';
            el.innerHTML = `
                <div class="item-info">
                    <div class="item-title">${item}</div>
                </div>
                <div class="item-actions">
                    <button class="btn btn-secondary btn-small" onclick="broadcastManager.edit(${index})">编辑</button>
                    <button class="btn btn-danger btn-small" onclick="broadcastManager.confirmDelete(${index})">删除</button>
                </div>
            `;
            container.appendChild(el);
        });
    }

    add() {
        openModal('添加公告', 'broadcast', [
            { name: 'message', label: '公告内容', type: 'text', placeholder: '例如：>>> 系统更新完成', required: true }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items.push(form.message.value);
            this.save();
            this.render();
            showToast('公告已添加！');
        });
    }

    edit(index) {
        openModal('编辑公告', 'broadcast', [
            { name: 'message', label: '公告内容', type: 'text', value: this.items[index], required: true }
        ], () => {
            const form = document.getElementById('modalForm');
            this.items[index] = form.message.value;
            this.save();
            this.render();
            showToast('公告已更新！');
        }, index);
    }

    confirmDelete(index) {
        confirmDelete('确定要删除这条公告吗？', () => {
            this.delete(index);
            this.render();
            showToast('公告已删除！');
        });
    }
}

let projectManager, skillManager, bioManager, slideManager, broadcastManager;
let currentCallback = null;
let currentType = '';

function initPanel() {
    projectManager = new ProjectManager();
    skillManager = new SkillManager();
    bioManager = new BioManager();
    slideManager = new SlideManager();
    broadcastManager = new BroadcastManager();

    projectManager.render();
    skillManager.render();
    bioManager.render();
    slideManager.render();
    broadcastManager.render();

    initTabs();
    initModals();
}

function initTabs() {
    document.querySelectorAll('.panel-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.panel-tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.panel-section').forEach(s => s.classList.remove('active'));

            tab.classList.add('active');
            document.getElementById('section-' + tab.dataset.panel).classList.add('active');
        });
    });
}

function initModals() {
    document.getElementById('closeModalBtn').addEventListener('click', closeModal);
    document.getElementById('cancelBtn').addEventListener('click', closeModal);
    document.getElementById('closeDeleteModal').addEventListener('click', closeDeleteModal);
    document.getElementById('cancelDeleteBtn').addEventListener('click', closeDeleteModal);

    document.getElementById('modalOverlay').addEventListener('click', (e) => {
        if (e.target === e.currentTarget) closeModal();
    });

    document.getElementById('deleteModalOverlay').addEventListener('click', (e) => {
        if (e.target === e.currentTarget) closeDeleteModal();
    });

    document.getElementById('modalForm').addEventListener('submit', (e) => {
        e.preventDefault();
        if (currentCallback) currentCallback();
        closeModal();
    });

    document.getElementById('confirmDeleteBtn').addEventListener('click', () => {
        if (window.deleteCallback) window.deleteCallback();
        closeDeleteModal();
    });
}

function openModal(title, type, fields, callback, index = -1) {
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('editIndex').value = index;
    document.getElementById('editType').value = type;
    currentType = type;
    currentCallback = callback;

    const fieldsContainer = document.getElementById('modalFields');
    fieldsContainer.innerHTML = '';

    fields.forEach(field => {
        const group = document.createElement('div');
        group.className = 'form-group';

        const label = document.createElement('label');
        label.textContent = field.label;
        label.setAttribute('for', field.name);
        group.appendChild(label);

        let input;
        if (field.type === 'textarea') {
            input = document.createElement('textarea');
            input.rows = 4;
        } else {
            input = document.createElement('input');
            input.type = field.type;
        }

        input.id = field.name;
        input.name = field.name;
        if (field.placeholder) input.placeholder = field.placeholder;
        if (field.value !== undefined) input.value = field.value;
        if (field.required) input.required = true;
        if (field.min !== undefined) input.min = field.min;
        if (field.max !== undefined) input.max = field.max;

        group.appendChild(input);

        if (field.hint) {
            const small = document.createElement('small');
            small.textContent = field.hint;
            group.appendChild(small);
        }

        fieldsContainer.appendChild(group);
    });

    document.getElementById('modalOverlay').classList.add('active');
}

function closeModal() {
    document.getElementById('modalOverlay').classList.remove('active');
    currentCallback = null;
}

function confirmDelete(message, callback) {
    document.getElementById('deleteMessage').textContent = message;
    document.getElementById('deleteModalOverlay').classList.add('active');
    window.deleteCallback = callback;
}

function closeDeleteModal() {
    document.getElementById('deleteModalOverlay').classList.remove('active');
    window.deleteCallback = null;
}

function showToast(message, isError = false) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = 'toast show' + (isError ? ' error' : '');
    setTimeout(() => { toast.className = 'toast'; }, 3000);
}

document.addEventListener('DOMContentLoaded', initPanel);
