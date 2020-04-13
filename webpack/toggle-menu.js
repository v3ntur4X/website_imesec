const menu = document.getElementById('hamburger-menu');
menu.addEventListener('click', () => {
  const header = document.getElementById('header');
  header.classList.toggle('header--hamburger-menu-active');
  document.body.classList.toggle('fixed-body');
});
