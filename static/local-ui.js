(function () {
	'use strict';

	var THEME_CLASSES = ['theme-light', 'theme-dark', 'theme-high-contrast'];

	function applyTheme(theme) {
		if (!/^(light|dark|high-contrast)$/.test(theme)) theme = 'dark';
		var root = document.documentElement;
		THEME_CLASSES.forEach(function (cls) { root.classList.remove(cls); });
		root.classList.add('theme-' + theme);
		try { localStorage.setItem('theme', theme); } catch (e) {}
		document.querySelectorAll('.theme-control[data-theme-to]').forEach(function (btn) {
			var selected = btn.getAttribute('data-theme-to') === theme;
			btn.classList.toggle('is-selected', selected);
			btn.setAttribute('aria-checked', selected ? 'true' : 'false');
		});
	}

	function initTheme() {
		var stored = null;
		try { stored = localStorage.getItem('theme'); } catch (e) {}
		applyTheme(/^(light|dark|high-contrast)$/.test(stored) ? stored : 'dark');

		document.querySelectorAll('.theme-dropdown-trigger').forEach(function (trigger) {
			trigger.addEventListener('click', function (e) {
				e.stopPropagation();
				var expanded = trigger.getAttribute('aria-expanded') === 'true';
				trigger.setAttribute('aria-expanded', expanded ? 'false' : 'true');
			});
		});

		document.querySelectorAll('.theme-control[data-theme-to]').forEach(function (btn) {
			btn.addEventListener('click', function () {
				applyTheme(btn.getAttribute('data-theme-to'));
				document.querySelectorAll('.theme-dropdown-trigger').forEach(function (t) {
					t.setAttribute('aria-expanded', 'false');
				});
			});
		});
	}

	function closeAllPanels(exceptBtn) {
		document.querySelectorAll('panel-controller').forEach(function (ctrl) {
			var btn = ctrl.querySelector('button[aria-controls]');
			var panel = ctrl.querySelector('.site-header-panel');
			if (!btn || !panel || btn === exceptBtn) return;
			btn.setAttribute('aria-expanded', 'false');
			panel.setAttribute('hidden', '');
		});
	}

	function initHeaderPanels() {
		document.querySelectorAll('panel-controller').forEach(function (ctrl) {
			var btn = ctrl.querySelector('button[aria-controls]');
			var panel = ctrl.querySelector('.site-header-panel');
			if (!btn || !panel) return;
			btn.addEventListener('click', function (e) {
				e.stopPropagation();
				var isOpen = btn.getAttribute('aria-expanded') === 'true';
				closeAllPanels(btn);
				btn.setAttribute('aria-expanded', isOpen ? 'false' : 'true');
				if (isOpen) panel.setAttribute('hidden', '');
				else panel.removeAttribute('hidden');
			});
		});
	}

	function initSearch() {
		document.querySelectorAll('search-expander').forEach(function (expander) {
			var openBtn = expander.querySelector('[data-search-expander-trigger-open]');
			var closeBtn = expander.querySelector('[data-search-expander-trigger-close]');
			var box = expander.querySelector('[id^="ms--site-header-search"]');
			var input = expander.querySelector('input[type="search"]');
			if (!openBtn || !closeBtn || !box) return;
			openBtn.addEventListener('click', function () {
				box.removeAttribute('hidden');
				openBtn.setAttribute('hidden', '');
				if (input) input.focus();
			});
			closeBtn.addEventListener('click', function () {
				box.setAttribute('hidden', '');
				openBtn.removeAttribute('hidden');
			});
		});
	}

	document.addEventListener('click', function (e) {
		if (!e.target.closest('panel-controller')) closeAllPanels(null);
		if (!e.target.closest('.dropdown')) {
			document.querySelectorAll('.theme-dropdown-trigger').forEach(function (t) {
				t.setAttribute('aria-expanded', 'false');
			});
		}
	});

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', function () {
			initTheme();
			initHeaderPanels();
			initSearch();
		});
	} else {
		initTheme();
		initHeaderPanels();
		initSearch();
	}
})();
