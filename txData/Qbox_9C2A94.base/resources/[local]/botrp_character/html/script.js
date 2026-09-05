const app = document.getElementById('app');
const charactersEl = document.getElementById('characters');
const createEl = document.getElementById('create');
const countEl = document.getElementById('count');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');

let characters = [];
let maxCharacters = 6;

const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(data)
}).catch(() => {});

const money = value => `$${Number(value || 0).toLocaleString('en-US')}`;

function render() {
    countEl.textContent = characters.length;
    charactersEl.innerHTML = '';

    characters.forEach((character, index) => {
        const info = character.charinfo || {};
        const job = character.job || {};
        const grade = job.grade || {};
        const card = document.createElement('article');
        card.className = 'card';
        card.innerHTML = `
            <div class="slot">SLOT ${String(index + 1).padStart(2, '0')}</div>
            <div class="name">${escapeHtml(`${info.firstname || ''} ${info.lastname || ''}`.trim())}</div>
            <div class="id">${escapeHtml(character.citizenid || 'Unknown ID')}</div>
            <div class="meta">
                <div>JOB<b>${escapeHtml(job.label || 'Civilian')} · ${escapeHtml(grade.name || 'Freelancer')}</b></div>
                <div>BANK<b>${money(character.money?.bank)}</b></div>
                <div>BIRTH DATE<b>${escapeHtml(info.birthdate || '—')}</b></div>
                <div>CASH<b>${money(character.money?.cash)}</b></div>
            </div>
            <div class="card-actions">
                <button class="primary play">Play</button>
                <button class="danger delete">Delete</button>
            </div>`;

        card.querySelector('.play').onclick = () => post('selectCharacter', {citizenid: character.citizenid});
        card.querySelector('.delete').onclick = () => {
            if (confirm(`Delete ${info.firstname || ''} ${info.lastname || ''}? This cannot be undone.`)) {
                post('deleteCharacter', {citizenid: character.citizenid});
            }
        };
        charactersEl.appendChild(card);
    });

    if (characters.length < maxCharacters) {
        const card = document.createElement('article');
        card.className = 'card empty';
        card.innerHTML = `<div class="slot">SLOT ${String(characters.length + 1).padStart(2, '0')}</div><div class="name">New character</div><p>Create a new identity and start a new story.</p><div class="actions"><button class="primary">Create character</button></div>`;
        card.querySelector('button').onclick = showCreate;
        charactersEl.appendChild(card);
    }
}

function showCreate() {
    charactersEl.classList.add('hidden');
    createEl.classList.remove('hidden');
    titleEl.textContent = 'Create your character';
    subtitleEl.textContent = 'Give your character a name, background and identity.';
}

function showCharacters() {
    createEl.classList.add('hidden');
    charactersEl.classList.remove('hidden');
    titleEl.textContent = 'Choose your character';
    subtitleEl.textContent = 'Continue your story or create someone new.';
}

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char]));
}

window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'open') app.classList.remove('hidden');
    if (data.action === 'close') app.classList.add('hidden');
    if (data.action === 'setCharacters') {
        characters = Array.isArray(data.characters) ? data.characters : [];
        maxCharacters = Number(data.maxCharacters || 6);
        render();
        showCharacters();
    }
});

document.getElementById('cancel').onclick = showCharacters;
document.getElementById('createBtn').onclick = () => {
    post('createCharacter', {
        firstname: document.getElementById('firstname').value,
        lastname: document.getElementById('lastname').value,
        nationality: document.getElementById('nationality').value,
        birthdate: document.getElementById('birthdate').value,
        gender: Number(document.getElementById('gender').value)
    });
};

post('ready');
