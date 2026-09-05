const hud = document.getElementById('hud');
const $ = (id) => document.getElementById(id);

const setText = (id, value) => {
    const el = $(id);
    if (el) el.textContent = value == null ? '' : String(value);
};

const setStatusState = (id, state) => {
    const el = $(id);
    if (!el) return;
    el.classList.toggle('speaking', state === 'speaking');
    el.classList.toggle('radio', state === 'radio');
};

function showHud() {
    if (!hud) return;
    hud.classList.remove('hidden');
    hud.classList.add('visible');
}

function hideHud() {
    if (!hud) return;
    hud.classList.remove('visible');
    hud.classList.add('hidden');
}

window.addEventListener('message', (event) => {
    const d = event.data || {};
    if (!hud) return;

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
    setText('system', d.system || 'Online');

    setStatusState('voiceStatus', d.radio ? 'radio' : (d.speaking ? 'speaking' : 'normal'));

    // If Qbox data is not loaded yet, keep the card visible but show safe
    // placeholders. Once Player:SetPlayerData arrives, values are replaced.
    hud.classList.toggle('loading', d.loggedIn !== true);
    showHud();
});

window.addEventListener('DOMContentLoaded', () => {
    showHud();

    // FiveM's NUI callback is only used as a synchronization signal. Failure
    // here must never hide the HUD or affect the game UI.
    try {
        const resource = GetParentResourceName();
        if (resource) {
            fetch(`https://${resource}/ready`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            }).catch(() => {});
        }
    } catch (_) {}
});
