const hud = document.getElementById('hud');
const $ = (id) => document.getElementById(id);
const setText = (id, value) => {
    const el = $(id);
    if (el) el.textContent = value ?? '';
};

function showHud() {
    hud.classList.remove('hidden');
    hud.classList.add('visible');
}

function hideHud() {
    hud.classList.remove('visible');
    hud.classList.add('hidden');
}

window.addEventListener('message', (event) => {
    const d = event.data || {};

    if (d.action === 'hide') {
        hideHud();
        return;
    }

    if (d.action !== 'update') return;

    setText('cash', d.cash ?? '$0');
    setText('bank', d.bank ?? '$0');
    setText('job', `${d.job || 'Civilian'} · ${d.grade || 'Freelancer'}`);
    setText('health', `${d.health ?? 0}%`);
    setText('armor', `${d.armor ?? 0}%`);
    setText('needs', d.needs == null ? '--%' : `${d.needs}%`);
    setText('voice', d.radio ? 'Radio' : (d.voice || 'Normal'));
    setText('ping', d.ping == null ? '-- ms' : `${d.ping} ms`);

    hud.classList.toggle('speaking', d.speaking === true);
    hud.classList.toggle('radio', d.radio === true);
    showHud();
});

window.addEventListener('DOMContentLoaded', () => {
    // The page is intentionally transparent and the card is visible by
    // default, so a NUI startup/message race can never turn the game screen
    // into a black overlay.
    showHud();

    try {
        fetch(`https://${GetParentResourceName()}/ready`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        }).catch(() => {});
    } catch (_) {
        // Browser preview outside FiveM has no GetParentResourceName().
    }
});
