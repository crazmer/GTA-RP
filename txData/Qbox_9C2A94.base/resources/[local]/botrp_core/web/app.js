const hud = document.getElementById('hud');
const cash = document.getElementById('cash');
const bank = document.getElementById('bank');
const job = document.getElementById('job');

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'hide') {
    hud.classList.remove('visible');
    return;
  }
  if (data.action !== 'update') return;

  if (data.cash !== undefined && data.cash !== null) cash.textContent = data.cash;
  if (data.bank !== undefined && data.bank !== null) bank.textContent = data.bank;
  if (data.job !== undefined && data.job !== null) {
    job.textContent = data.grade ? `${data.job} · ${data.grade}` : data.job;
  }

  hud.classList.add('visible');
});
