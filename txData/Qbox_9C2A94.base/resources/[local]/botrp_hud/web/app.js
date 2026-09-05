const hud = document.getElementById('hud');
const $ = (id) => document.getElementById(id);
const setText = (id, value) => {
    const el = $(id);
    if (el) el.textContent = value ?? '';
};

// Never hide the NUI just because player data is late. This prevents a
// valid HUD resource from appearing to be broken after a resource restart.
hud.classList.remove('hidden');
hud.classList.add('visible');

window.addEventListener('message', (event) => {
    const d = event.data || {};

    if (d.action === 'hide') {
        hud.classList.remove('visible');
        hud.classList.add('hidden');
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
    hud.classList.remove('hidden');
    hud.classList.add('visible');
});

// If the NUI is reloaded by FiveM, make the card visible without waiting for
// a Lua message. Lua will immediately replace the placeholders with live data.
window.addEventListener('DOMContentLoaded', () => {
    hud.classList.remove('hidden');
    hud.classList.add('visible');
});
