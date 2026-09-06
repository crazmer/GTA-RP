const app = document.getElementById('app');
const charactersEl = document.getElementById('characters');
const loadingEl = document.getElementById('loading');
const loadingTextEl = document.getElementById('loadingText');
const countEl = document.getElementById('count');
const serverNameEl = document.getElementById('serverName');
const confirmEl = document.getElementById('confirm');
const confirmTextEl = document.getElementById('confirmText');
const confirmDeleteEl = document.getElementById('confirmDelete');
const confirmCancelEl = document.getElementById('confirmCancel');

const ConfigDeleteEnabled = true;

let characters = [];
let maxCharacters = 6;
let submitting = false;
let selectedCitizenId = null;
let deleteTarget = null;
let previewTarget = null;

const post = (name, data = {}, timeoutMs = 15000) => {
    const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
    const timer = setTimeout(() => controller?.abort(), timeoutMs);
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: JSON.stringify(data),
        signal: controller?.signal
    }).then(async response => {
        clearTimeout(timer);
        let payload = {};
        try { payload = await response.json(); } catch (_) {}
        return { ok: response.ok, ...payload };
    }).catch(error => {
        clearTimeout(timer);
        return { ok: false, error: error?.name === 'AbortError' ? 'timeout' : 'nui_request_failed' };
    });
};

const money = value => `$${Number(value || 0).toLocaleString('en-US')}`;
const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char]));

function setLoading(show, text = 'Loading characters...') {
    loadingTextEl.textContent = text;
    loadingEl.classList.toggle('hidden', !show);
    charactersEl.classList.toggle('hidden', show);
}

function setSubmitting(value) {
    submitting = value;
    document.querySelectorAll('button').forEach(el => { el.disabled = value; });
}

function render() {
    countEl.textContent = `${characters.length}/${maxCharacters}`;
    charactersEl.replaceChildren();

    characters.forEach((character, index) => {
        const info = character.charinfo || {};
        const job = character.job || {};
        const grade = job.grade || {};
        const name = `${info.firstname || ''} ${info.lastname || ''}`.trim() || 'Unnamed character';
        const citizenid = String(character.citizenid || '');
        const card = document.createElement('article');
        card.className = `card${citizenid === selectedCitizenId ? ' selected' : ''}`;
        card.tabIndex = 0;
        card.dataset.citizenid = citizenid;
        card.innerHTML = `
            ${citizenid === selectedCitizenId ? '<span class="selected-badge">SELECTED</span>' : ''}
            <div class="slot">SLOT ${String(index + 1).padStart(2, '0')}</div>
            <div class="name">${escapeHtml(name)}</div>
            <div class="id">${escapeHtml(citizenid || 'Unknown ID')}</div>
            <div class="meta">
                <div>JOB<b>${escapeHtml(job.label || 'Civilian')} · ${escapeHtml(grade.name || 'Freelancer')}</b></div>
                <div>BANK<b>${money(character.money?.bank)}</b></div>
                <div>BIRTH DATE<b>${escapeHtml(info.birthdate || '—')}</b></div>
                <div>CASH<b>${money(character.money?.cash)}</b></div>
            </div>
            <div class="card-actions">
                <button class="primary play" type="button">Play <span class="button-arrow">→</span></button>
                ${ConfigDeleteEnabled ? '<button class="danger delete" type="button">Delete</button>' : ''}
            </div>`;

        card.addEventListener('click', event => {
            if (event.target.closest('button')) return;
            selectPreview(character, card);
        });
        card.addEventListener('keydown', event => {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                selectPreview(character, card);
            }
        });
        card.querySelector('.play').onclick = () => selectCharacter(citizenid);
        const deleteButton = card.querySelector('.delete');
        if (deleteButton) deleteButton.onclick = () => openDelete(name, citizenid);
        charactersEl.appendChild(card);
    });

    for (let slot = characters.length + 1; slot <= maxCharacters; slot++) {
        const card = document.createElement('article');
        card.className = 'card empty';
        card.innerHTML = `
            <div class="slot">SLOT ${String(slot).padStart(2, '0')}</div>
            <div class="empty-icon">—</div>
            <div class="name">Empty slot</div>
            <p>Character creation is currently disabled. An administrator can provision additional characters.</p>`;
        charactersEl.appendChild(card);
    }
}

function selectPreview(character, card) {
    const citizenid = String(character?.citizenid || '');
    if (!citizenid || citizenid === previewTarget || submitting) return;
    previewTarget = citizenid;
    selectedCitizenId = citizenid;
    document.querySelectorAll('.card.selected').forEach(el => el.classList.remove('selected'));
    card.classList.add('selected');
    card.querySelector('.selected-badge')?.remove();
    const badge = document.createElement('span');
    badge.className = 'selected-badge';
    badge.textContent = 'SELECTED';
    card.appendChild(badge);
    post('previewCharacter', { citizenid }, 10000);
}

async function selectCharacter(citizenid) {
    if (submitting || !citizenid) return;
    setSubmitting(true);
    const result = await post('selectCharacter', { citizenid }, 20000);
    if (!result.ok) {
        setSubmitting(false);
        const message = result?.error === 'timeout' ? 'The server took too long to respond. Please try again.' : (result?.message || 'Unable to load that character.');
        window.alert(message);
    }
}

function openDelete(name, citizenid) {
    if (submitting || !citizenid) return;
    deleteTarget = citizenid;
    confirmTextEl.textContent = `${name} will be permanently removed. This action cannot be undone.`;
    confirmEl.classList.remove('hidden');
    confirmDeleteEl.focus();
}

function closeDelete() {
    deleteTarget = null;
    confirmEl.classList.add('hidden');
}

async function deleteCharacter() {
    if (submitting || !deleteTarget) return;
    const citizenid = deleteTarget;
    closeDelete();
    setSubmitting(true);
    const result = await post('deleteCharacter', { citizenid });
    if (!result.ok) window.alert(result?.message || 'Character could not be deleted.');
    setSubmitting(false);
}

function showCharacters() {
    countEl.textContent = `${characters.length}/${maxCharacters}`;
    selectedCitizenId = null;
}

window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.serverName) serverNameEl.textContent = String(data.serverName).toUpperCase();

    if (data.action === 'open') {
        app.classList.remove('hidden');
        app.setAttribute('aria-hidden', 'false');
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
        app.setAttribute('aria-hidden', 'true');
        closeDelete();
        setSubmitting(false);
    }

    if (data.action === 'setCharacters') {
        characters = Array.isArray(data.characters) ? data.characters : [];
        maxCharacters = Math.max(1, Number(data.maxCharacters || 6));
        setLoading(false);
        render();
        showCharacters();
        setSubmitting(false);
    }
});

confirmCancelEl.onclick = closeDelete;
confirmDeleteEl.onclick = deleteCharacter;
confirmEl.addEventListener('click', event => { if (event.target === confirmEl) closeDelete(); });

document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !submitting && !confirmEl.classList.contains('hidden')) closeDelete();
});

post('ready', {}, 5000);
