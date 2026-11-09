const wheel = document.querySelector('#wheel');
const close = document.querySelector('#close');
const sectors = document.querySelector('#sectors');
const actions = document.querySelector('#actions');
const target = document.querySelector('#target');
const targetPanel = document.querySelector('#target-panel');
const options = document.querySelector('#options');
const notice = document.querySelector('#notice');
const svgNS = 'http://www.w3.org/2000/svg';
let sending = false;
let noticeTimer;

const icons = {
    shirt: '<path d="m8 3-5 3-2 5 4 2 2-3v11h10V10l2 3 4-2-2-5-5-3a4 4 0 0 1-8 0Z"/>',
    pants: '<path d="M6 3h12l1 18h-5l-2-11-2 11H5L6 3Zm0 4h12"/>',
    shoe: '<path d="M2 16v-4l4 1 3-6 4 2 2 4 5 2 2 2v3H2v-4Zm0 1h20"/>',
    hat: '<path d="M3 14a9 9 0 0 1 18 0v2H3v-2Zm0 2h18l2 2H1l2-2ZM12 5V3"/>',
    glasses: '<circle cx="6.5" cy="13" r="4"/><circle cx="17.5" cy="13" r="4"/><path d="M10.5 12a2 2 0 0 1 3 0M1 10l2 1m18 0 2-1"/>',
    food: '<path d="M3 10a9 6 0 0 1 18 0H3Zm-1 4h20M3 18h18a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3Z"/>',
    water: '<path d="M12 2C9 7 5 11 5 15a7 7 0 0 0 14 0c0-4-4-8-7-13Z"/><path d="M8 15a4 4 0 0 0 4 4"/>'
};

async function post(endpoint, data = {}) {
    const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });
    if (!response.ok) throw new Error('NUI ' + response.status);
    return response.json();
}

async function sendAction(endpoint, data) {
    if (wheel.hidden || sending) return;
    sending = true;
    try {
        await post(endpoint, data);
    } catch {
        showNotice('Action indisponible.');
    } finally {
        sending = false;
    }
}

function point(angle, radius) {
    return [200 + radius * Math.cos(angle), 200 + radius * Math.sin(angle)];
}

function sectorPath(angle, half) {
    const start = angle - half;
    const end = angle + half;
    return `M ${point(start, 194)} A 194 194 0 0 1 ${point(end, 194)}
        L ${point(end, 70)} A 70 70 0 0 0 ${point(start, 70)} Z`;
}

function openWheel(items) {
    sectors.replaceChildren();
    actions.replaceChildren();
    const step = Math.PI * 2 / items.length;

    items.forEach((item, index) => {
        const angle = -Math.PI / 2 + step * index;
        const sector = document.createElementNS(svgNS, 'path');
        sector.setAttribute('d', sectorPath(angle, step / 2 - 0.025));
        sector.classList.toggle('disabled', item.disabled === true);
        sector.addEventListener('click', () => {
            if (!item.disabled) sendAction('select', { id: item.id });
        });
        sectors.append(sector);

        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'action';
        button.disabled = item.disabled === true;
        const [x, y] = point(angle, 132);
        button.style.left = (x / 4) + '%';
        button.style.top = (y / 4) + '%';

        const icon = document.createElementNS(svgNS, 'svg');
        icon.setAttribute('viewBox', '0 0 24 24');
        icon.setAttribute('aria-hidden', 'true');
        icon.innerHTML = icons[item.icon] ?? '';
        const label = document.createElement('strong');
        label.textContent = item.label;
        const detail = document.createElement('small');
        detail.textContent = item.detail;
        button.append(icon, label, detail);

        const highlight = () => sector.classList.toggle(
            'active', !button.disabled && button.matches(':hover, :focus-visible')
        );
        button.addEventListener('pointerenter', highlight);
        button.addEventListener('pointerleave', highlight);
        button.addEventListener('focus', highlight);
        button.addEventListener('blur', highlight);
        button.addEventListener('click', () => sendAction('select', { id: item.id }));
        actions.append(button);
    });

    wheel.hidden = false;
}

function renderTarget(data) {
    target.hidden = !data.visible;
    if (target.hidden) return;

    const labels = Array.isArray(data.options) ? data.options : [];
    const selectedIndex = data.selected - 1;
    const start = Math.max(0, Math.min(selectedIndex - 2, labels.length - 5));
    targetPanel.hidden = labels.length === 0;
    target.classList.toggle('active', labels.length > 0);
    options.replaceChildren();

    labels.slice(start, start + 5).forEach((label, index) => {
        const row = document.createElement('li');
        row.textContent = label;
        row.classList.toggle('selected', start + index === selectedIndex);
        options.append(row);
    });
}

function showNotice(message) {
    clearTimeout(noticeTimer);
    notice.textContent = message;
    notice.hidden = false;
    noticeTimer = setTimeout(() => { notice.hidden = true; }, 2800);
}

close.addEventListener('click', () => sendAction('close'));
wheel.addEventListener('click', (event) => {
    if (!event.target.closest('button, #sectors path')) sendAction('close');
});
window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !wheel.hidden) {
        event.preventDefault();
        sendAction('close');
    }
});

window.addEventListener('message', ({ data }) => {
    if (data?.type === 'wheel') {
        if (data.visible && Array.isArray(data.actions)) openWheel(data.actions);
        else wheel.hidden = true;
    }
    if (data?.type === 'target') renderTarget(data);
    if (data?.type === 'notice') showNotice(data.message);
});

if (typeof GetParentResourceName === 'function') {
    const signalReady = () => post('ready').catch(() => setTimeout(signalReady, 500));
    signalReady();
}
