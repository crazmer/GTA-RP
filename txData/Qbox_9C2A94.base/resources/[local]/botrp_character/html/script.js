const app = document.getElementById('app');
const charactersEl = document.getElementById('characters');
const createEl = document.getElementById('create');
const countEl = document.getElementById('count');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
const serverNameEl = document.getElementById('serverName');

let characters = [];
let maxCharacters = 6;
let submitting = false;

const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json; charset=UTF-8'},
    body: JSON.stringify(data)
}).catch(() => null);

const money = value => `$${Number(value || 0).toLocaleString('en-US')}`;
const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char]));

function render() {
    countEl.textContent = `${characters.length}/${maxCharacters}`;
    charactersEl.replaceChildren();

    characters.forEach((character, index) => {
        const info = character.charinfo || {};
        const job = character.job || {};
        const grade = job.grade || {};
        const name = `${info.firstname || ''} ${info.lastname || ''}`.trim() || 'Unnamed character';
        const card = document.createElement('article');
        card.className = 'card';
        card.innerHTML = `
            <div class="slot">SLOT ${String(index + 1).padStart(2, '0')}</div>
            <div class="name">${escapeHtml(name)}</div>
            <div class="id">${escapeHtml(character.citizenid || 'Unknown ID')}</div>
            <div class="meta">
                <div>JOB<b>${escapeHtml(job.label || 'Civilian')} · ${escapeHtml(grade.name || 'Freelancer')}</b></div>
                <div>BANK<b>${money(character.money?.bank)}</b></div>
                <div>BIRTH DATE<b>${escapeHtml(info.birthdate || '—')}</b></div>
                <div>CASH<b>${money(character.money?.cash)}</b></div>
            </div>
            <div class="card-actions">
                <button class="primary play" type="button">Play</button>
                <button class="danger delete" type="button">Delete</button>
            </div>`;

        card.querySelector('.play').onclick = () => selectCharacter(character.citizenid);
        card.querySelector('.delete').onclick = () => {
            if (submitting) return;
            if (confirm(`Delete ${name}? This cannot be undone.`)) deleteCharacter(character.citizenid);
        };
        charactersEl.appendChild(card);
    });

    if (characters.length < maxCharacters) {
        const card = document.createElement('article');
        card.className = 'card empty';
        card.innerHTML = `<div class="slot">SLOT ${String(characters.length + 1).padStart(2, '0')}</div><div class="name">New character</div><p>Create a new identity and start a new story.</p><div class="actions"><button class="primary" type="button">Create character</button></div>`;
        card.querySelector('button').onclick = showCreate;
        charactersEl.appendChild(card);
    }
}

function setSubmitting(value) {
    submitting = value;
    document.querySelectorAll('button,input,select').forEach(el => { el.disabled = value; });
}

async function selectCharacter(citizenid) {
    if (submitting || !citizenid) return;
    setSubmitting(true);
    await post('selectCharacter', { citizenid });
}

async function deleteCharacter(citizenid) {
    if (submitting || !citizenid) return;
    setSubmitting(true);
    await post('deleteCharacter', { citizenid });
    setSubmitting(false);
}

function showCreate() {
    charactersEl.classList.add('hidden');
    createEl.classList.remove('hidden');
    titleEl.textContent = 'Create your character';
    subtitleEl.textContent = 'Give your character a name, background and identity.';
    document.getElementById('firstname').focus();
}

function showCharacters() {
    createEl.classList.add('hidden');
    charactersEl.classList.remove('hidden');
    titleEl.textContent = 'Choose your character';
    subtitleEl.textContent = 'Continue your story or create someone new.';
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
        setSubmitting(false);
    }
    if (data.action === 'setCharacters') {
        characters = Array.isArray(data.characters) ? data.characters : [];
        maxCharacters = Math.max(1, Number(data.maxCharacters || 6));
        render();
        showCharacters();
        setSubmitting(false);
    }
});

document.getElementById('cancel').onclick = () => {
    if (!submitting) showCharacters();
};

document.getElementById('createBtn').onclick = async () => {
    if (submitting) return;
    const firstname = document.getElementById('firstname').value.trim();
    const lastname = document.getElementById('lastname').value.trim();
    const nationality = document.getElementById('nationality').value.trim();
    const birthdate = document.getElementById('birthdate').value;
    const gender = Number(document.getElementById('gender').value);

    if (firstname.length < 2 || lastname.length < 2 || nationality.length < 2 || !birthdate) return;

    setSubmitting(true);
    await post('createCharacter', { firstname, lastname, nationality, birthdate, gender });
};

document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !submitting && !createEl.classList.contains('hidden')) showCharacters();
});

post('ready');
