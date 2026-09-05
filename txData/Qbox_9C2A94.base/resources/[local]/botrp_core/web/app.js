const hud = document.getElementById('hud');
const hudCard = hud.querySelector('.hud-card');
const cash = document.getElementById('cash');
const bank = document.getElementById('bank');
const job = document.getElementById('job');
const health = document.getElementById('health');
const armor = document.getElementById('armor');
const needs = document.getElementById('needs');
const voice = document.getElementById('voice');
const connection = document.getElementById('connection');
const healthStatus = document.getElementById('healthStatus');
const armorStatus = document.getElementById('armorStatus');
const needsStatus = document.getElementById('needsStatus');
const voiceStatus = document.getElementById('voiceStatus');
const connectionStatus = document.getElementById('connectionStatus');
const moneyValues = { cash, bank };
let lastValues = {};

function pulse(element, key, value) {
  if (lastValues[key] !== undefined && lastValues[key] !== value) {
    element.classList.remove('changed');
    void element.offsetWidth;
    element.classList.add('changed');
  }
  lastValues[key] = value;
}

function setText(element, key, value) {
  if (value === undefined || value === null) return;
  const text = String(value);
  if (element.textContent !== text) pulse(element, key, text);
  element.textContent = text;
}

function setPercent(element, wrapper, key, value) {
  if (value === undefined || value === null) {
    wrapper.hidden = true;
    return;
  }
  wrapper.hidden = false;
  const numeric = Math.max(0, Math.min(100, Number(value) || 0));
  setText(element, key, `${Math.round(numeric)}%`);
  wrapper.classList.toggle('low', numeric <= 25);
}

function setVisibility(element, enabled) {
  element.hidden = enabled === false;
}

function setVoice(value, speaking, radio, muted) {
  const mode = radio ? 'Radio' : (value || 'Normal');
  setText(voice, 'voice', mode);
  voiceStatus.classList.toggle('voice-speaking', Boolean(speaking));
  voiceStatus.classList.toggle('voice-radio', Boolean(radio));
  voiceStatus.classList.toggle('voice-muted', Boolean(muted));
}

function applyLayout(data) {
  const position = data.position || 'top-left';
  const scale = Math.max(.75, Math.min(1.35, Number(data.scale) || 1));
  const opacity = Math.max(.55, Math.min(1, Number(data.opacity) || .94));
  hud.dataset.position = position;
  hud.style.setProperty('--scale', scale);
  hudCard.style.opacity = opacity;
}

window.addEventListener('message', (event) => {
  const data = event.data || {};

  if (data.action === 'hide') {
    hud.classList.remove('visible');
    return;
  }

  if (data.action !== 'update') return;

  applyLayout(data);
  setVisibility(moneyValues.cash, data.showCash);
  setVisibility(moneyValues.bank, data.showBank);
  setVisibility(healthStatus, data.showHealth);
  setVisibility(armorStatus, data.showArmor);
  setVisibility(needsStatus, data.showNeeds);
  setVisibility(voiceStatus, data.showVoice);
  setVisibility(connectionStatus, data.showConnection);

  setText(cash, 'cash', data.cash);
  setText(bank, 'bank', data.bank);

  if (data.job !== undefined && data.job !== null) {
    job.replaceChildren(document.createTextNode(String(data.job)));
    if (data.grade !== undefined && data.grade !== null && String(data.grade) !== '') {
      const separator = document.createElement('span');
      separator.setAttribute('aria-hidden', 'true');
      separator.textContent = ' · ';
      job.appendChild(separator);
      job.appendChild(document.createTextNode(String(data.grade)));
    }
  }

  setPercent(health, healthStatus, 'health', data.health);
  setPercent(armor, armorStatus, 'armor', data.armor);
  setPercent(needs, needsStatus, 'needs', data.needs);
  setVoice(data.voice, data.voiceSpeaking, data.radioActive, data.voiceMuted);

  if (data.connection !== undefined && data.connection !== null) {
    setText(connection, 'connection', `${Math.max(0, Math.round(Number(data.connection) || 0))} ms`);
  }

  if (data.enabled !== false) hud.classList.add('visible');
});
